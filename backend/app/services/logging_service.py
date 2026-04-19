import time
from functools import wraps

from .sqlite import get_db_connection, init_db
from typing import Optional, List, Dict


def log_feature_run(run_id: str, feature: str, owner: str, status: str, uses_mock: bool, latency_ms: int, prompt_tokens: int, completion_tokens: int, total_tokens: int):
    """
    feature_runs 테이블에 실행 로그를 저장. DB/타입/입력값 오류 발생 시 print로 에러 로깅.
    """
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute(
            '''INSERT INTO feature_runs (run_id, feature, owner, status, uses_mock, latency_ms, prompt_tokens, completion_tokens, total_tokens)
               VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)''',
            (
                run_id,
                feature,
                owner,
                status,
                int(uses_mock),
                int(latency_ms),
                int(prompt_tokens),
                int(completion_tokens),
                int(total_tokens),
            )
        )
        conn.commit()
    except Exception as e:
        print(f"[log_feature_run] Error logging feature run: {e}\nparams: run_id={run_id}, feature={feature}, owner={owner}, status={status}, uses_mock={uses_mock}, latency_ms={latency_ms}, prompt_tokens={prompt_tokens}, completion_tokens={completion_tokens}, total_tokens={total_tokens}")
    finally:
        if conn:
            try:
                conn.close()
            except Exception:
                pass


def get_recent_feature_runs(limit: int = 20) -> List[Dict]:
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute('''
        SELECT * FROM feature_runs ORDER BY created_at DESC LIMIT ?
    ''', (limit,))
    rows = cursor.fetchall()
    conn.close()
    return [dict(row) for row in rows]


def extract_openai_response_metrics(resp) -> dict:
    """
    OpenAI API 응답에서 주요 메타데이터, 토큰 사용량, 비율, 텍스트 등 통계값을 추출합니다.
    """
    # 기본값
    request_id = getattr(resp, "id", None)
    model = getattr(resp, "model", None)
    status = getattr(resp, "status", None)
    started_at = getattr(resp, "created_at", None)
    finished_at = getattr(resp, "completed_at", None)
    latency_sec = (finished_at - started_at) if finished_at and started_at else None

    usage = getattr(resp, "usage", None)
    input_tokens = getattr(usage, "input_tokens", None) if usage else None
    output_tokens = getattr(usage, "output_tokens", None) if usage else None
    total_tokens = getattr(usage, "total_tokens", None) if usage else None

    input_tokens_details = getattr(usage, "input_tokens_details", None) if usage else None
    output_tokens_details = getattr(usage, "output_tokens_details", None) if usage else None
    cached_tokens = getattr(input_tokens_details, "cached_tokens", None) if input_tokens_details else None
    reasoning_tokens = getattr(output_tokens_details, "reasoning_tokens", None) if output_tokens_details else None

    # 비율 계산
    cache_ratio = (cached_tokens / input_tokens) if cached_tokens is not None and input_tokens else None
    reasoning_ratio = (reasoning_tokens / output_tokens) if reasoning_tokens is not None and output_tokens else None
    output_efficiency = (output_tokens / total_tokens) if output_tokens and total_tokens else None

    # 이 값들 다 정상적으로 출력되는지 로그 남기기
    print(f"[extract_openai_response_metrics] request_id={request_id}, model={model}, status={status}, latency_sec={latency_sec}, input_tokens={input_tokens}, output_tokens={output_tokens}, total_tokens={total_tokens}, cached_tokens={cached_tokens}, reasoning_tokens={reasoning_tokens}, cache_ratio={cache_ratio}, reasoning_ratio={reasoning_ratio}, output_efficiency={output_efficiency}")

    # 텍스트 추출 (현재 응답 형태 기준)
    text = None
    try:
        text = resp.output[0].content[0].text
    except Exception:
        text = None

    return {
        "request_id": request_id,
        "model": model,
        "status": status,
        "started_at": started_at,
        "finished_at": finished_at,
        "latency_sec": latency_sec,
        "input_tokens": input_tokens,
        "output_tokens": output_tokens,
        "total_tokens": total_tokens,
        "cached_tokens": cached_tokens,
        "reasoning_tokens": reasoning_tokens,
        "cache_ratio": cache_ratio,
        "reasoning_ratio": reasoning_ratio,
        "output_efficiency": output_efficiency,
        "text": text,
    }
