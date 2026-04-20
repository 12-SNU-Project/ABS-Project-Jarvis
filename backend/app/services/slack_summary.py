from __future__ import annotations

import re
import time
from typing import Any

from openai import OpenAI
from slack_sdk import WebClient
from slack_sdk.errors import SlackApiError

from app.core.config import get_settings
from app.providers.mock_provider import load_mock
from .logging_service import extract_openai_response_metrics, log_feature_run


def _normalize_text(text: str) -> str:
    return re.sub(r"\s+", " ", text).strip()


SUMMARY_LINE_COUNT = 5
SLACK_PAGE_SIZE = 200


def _format_mock_messages(data: dict[str, Any]) -> list[dict[str, str]]:
    messages: list[dict[str, str]] = []
    for index, channel in enumerate(data["channels"], start=1):
        messages.append(
            {
                "user": f"mock-user-{index}",
                "text": channel["summary"],
                "ts": f"mock-{index}",
            }
        )
        for action_index, item in enumerate(channel.get("action_items", []), start=1):
            messages.append(
                {
                    "user": f"mock-user-{index}",
                    "text": item,
                    "ts": f"mock-{index}-{action_index}",
                }
            )
    return messages


def _build_mock_summary(user_input: str, date: str, channel_id: str, lookback_hours: int) -> dict[str, Any]:
    data = load_mock("slack")
    mock_messages = _format_mock_messages(data)
    summary_lines = [channel["summary"] for channel in data["channels"]]
    action_items = [
        item
        for channel in data["channels"]
        for item in channel.get("action_items", [])
    ]
    summary_lines.extend(action_items)
    while len(summary_lines) < SUMMARY_LINE_COUNT:
        summary_lines.append("추가로 긴급하게 공유된 내용은 없습니다.")
    return {
        "owner": "문이현",
        "feature": "slack_summary",
        "date": date,
        "channel_id": channel_id,
        "channel_name": channel_id or "#mock-slack",
        "lookback_hours": lookback_hours,
        "message_count": len(mock_messages),
        "summary": "\n".join(summary_lines[:SUMMARY_LINE_COUNT]),
        "summary_lines": summary_lines[:SUMMARY_LINE_COUNT],
        "messages": mock_messages,
        "model": "mock",
        "uses_mock": True,
        "context": f"'{user_input}' 요청 기준 mock Slack 데이터를 요약했습니다.",
    }


def _fetch_channel_name(client: WebClient, channel_id: str) -> str:
    response = client.conversations_info(channel=channel_id)
    channel = response.get("channel", {})
    name = channel.get("name")
    return f"#{name}" if name else channel_id


def _fetch_recent_messages(client: WebClient, channel_id: str, lookback_hours: int) -> list[dict[str, str]]:
    oldest = str(time.time() - (lookback_hours * 60 * 60))
    messages: list[dict[str, str]] = []
    cursor: str | None = None

    while True:
        params: dict[str, Any] = {
            "channel": channel_id,
            "limit": SLACK_PAGE_SIZE,
            "oldest": oldest,
            "inclusive": True,
        }
        if cursor:
            params["cursor"] = cursor

        response = client.conversations_history(**params)
        for message in response.get("messages", []):
            text = _normalize_text(message.get("text", ""))
            if not text:
                continue
            if message.get("subtype") in {"channel_join", "channel_leave"}:
                continue
            messages.append(
                {
                    "user": message.get("user") or message.get("bot_id") or "unknown",
                    "text": text,
                    "ts": message.get("ts", ""),
                }
            )

        cursor = response.get("response_metadata", {}).get("next_cursor") or None
        if not cursor:
            break

    messages.sort(key=lambda item: float(item["ts"]) if item["ts"] else 0.0)
    return messages


def _summarize_with_openai(
    *,
    messages: list[dict[str, str]],
    user_input: str,
    channel_name: str,
    lookback_hours: int,
    model: str,
    api_key: str,
    site_url: str,
    site_name: str,
) -> tuple[list[str], dict[str, int]]:
    if not messages:
        return [
            f"{channel_name} 채널에 최근 {lookback_hours}시간 동안 확인할 메시지가 없습니다.",
            "즉시 대응이 필요한 논의도 보이지 않습니다.",
            "새 대화가 쌓이면 다시 요약하면 됩니다.",
            "필요하면 조회 기간을 늘려 다시 요약할 수 있습니다.",
            "현재는 공유할 결정사항이나 액션 아이템이 없습니다.",
        ], {"prompt_tokens": 0, "completion_tokens": 0, "total_tokens": 0}

    transcript = "\n".join(
        f"- {message['user']}: {message['text'][:500]}" for message in messages
    )
    default_headers = {}
    if site_url:
        default_headers["HTTP-Referer"] = site_url
    if site_name:
        default_headers["X-OpenRouter-Title"] = site_name

    client = OpenAI(
        api_key=api_key,
        base_url="https://openrouter.ai/api/v1",
        default_headers=default_headers or None,
    )
    response = client.responses.create(
        model=model,
        input=[
            {
                "role": "system",
                "content": (
                    "You summarize Slack conversations for a backend API. "
                    "Return exactly 5 concise lines in Korean. "
                    "Each line should capture concrete discussion points, decisions, blockers, schedule, or next actions. "
                    "Do not include bullets, numbering, or extra commentary."
                ),
            },
            {
                "role": "user",
                "content": (
                    f"사용자 요청: {user_input}\n"
                    f"채널: {channel_name}\n"
                    f"최근 메시지:\n{transcript}"
                ),
            },
        ],
    )
    metrics = extract_openai_response_metrics(response)
    raw_text = (response.output_text or "").strip()
    lines = [line.strip("-• ").strip() for line in raw_text.splitlines() if line.strip()]
    if len(lines) == 1:
        lines = [part.strip() for part in re.split(r"[.\n]", raw_text) if part.strip()]
    lines = lines[:SUMMARY_LINE_COUNT]
    while len(lines) < SUMMARY_LINE_COUNT:
        lines.append("추가로 확인된 중요한 내용은 없습니다.")
    return lines, metrics


def summarize_slack_channel(channel_id: str, user_input: str, date: str, lookback_hours: int) -> dict[str, Any]:
    settings = get_settings()
    if lookback_hours < 1 or lookback_hours > 168:
        raise ValueError("lookback_hours must be between 1 and 168.")

    if settings.use_mocks:
        return _build_mock_summary(
            user_input=user_input,
            date=date,
            channel_id=channel_id,
            lookback_hours=lookback_hours,
        )

    if not settings.slack_bot_token:
        raise RuntimeError("SLACK_BOT_TOKEN is missing. Add it to .env and restart the server.")
    if not settings.openrouter_api_key:
        raise RuntimeError("OPENROUTER_API_KEY is missing. Add it to .env and restart the server.")

    client = WebClient(token=settings.slack_bot_token)
    try:
        channel_name = _fetch_channel_name(client, channel_id)
        messages = _fetch_recent_messages(client, channel_id, lookback_hours)
    except SlackApiError as exc:
        error_message = exc.response.get("error", "unknown_slack_error")
        if error_message == "not_in_channel":
            raise RuntimeError(
                "Slack bot is not in the channel. Invite the app to that channel with /invite @your-app-name and try again."
            ) from exc
        if error_message == "missing_scope":
            raise RuntimeError(
                "Slack app is missing required scopes. Add channels:read and channels:history, then reinstall the app."
            ) from exc
        if error_message == "invalid_auth":
            raise RuntimeError(
                "Slack bot token is invalid. Check SLACK_BOT_TOKEN in .env and reinstall the app if needed."
            ) from exc
        raise RuntimeError(f"Slack API request failed: {error_message}") from exc
    except Exception as exc:
        raise RuntimeError(f"Failed to read Slack messages: {exc}") from exc

    try:
        summary_lines, metrics = _summarize_with_openai(
            messages=messages,
            user_input=user_input,
            channel_name=channel_name,
            lookback_hours=lookback_hours,
            model=settings.openrouter_model,
            api_key=settings.openrouter_api_key,
            site_url=settings.openrouter_site_url,
            site_name=settings.openrouter_site_name,
        )
    except Exception as exc:
        raise RuntimeError(f"OpenRouter summarization failed: {exc}") from exc
    
    log_feature_run(
        run_id=f"slack_summary-{int(time.time())}",
        feature="slack_summary",
        owner="문이현",
        status="success",
        used_llm=True,
        latency_ms=int(metrics.get("latency_sec", 0) * 1000),
        prompt_tokens=metrics.get("input_tokens"),
        completion_tokens=metrics.get("output_tokens"),
        total_tokens=metrics.get("total_tokens"),
    )
    
    return {
        "owner": "문이현",
        "feature": "slack_summary",
        "date": date,
        "channel_id": channel_id,
        "channel_name": channel_name,
        "lookback_hours": lookback_hours,
        "message_count": len(messages),
        "summary": "\n".join(summary_lines),
        "summary_lines": summary_lines,
        "messages": messages,
        "model": settings.openrouter_model,
        "uses_mock": False,
    }


def get_slack_brief(user_input: str, date: str) -> dict:
    settings = get_settings()
    channel_id = settings.slack_channel_id or "mock-channel"
    summary_payload = summarize_slack_channel(
        channel_id=channel_id,
        user_input=user_input,
        date=date,
        lookback_hours=settings.slack_lookback_hours,
    )
    return {
        "owner": "문이현",
        "feature": "slack_summary",
        "date": date,
        "summary": summary_payload["summary"],
        "channels": [
            {
                "channel": summary_payload["channel_name"],
                "summary": summary_payload["summary_lines"][0],
                "action_items": summary_payload["summary_lines"][1:],
            }
        ],
        "uses_mock": summary_payload["uses_mock"],
    }
