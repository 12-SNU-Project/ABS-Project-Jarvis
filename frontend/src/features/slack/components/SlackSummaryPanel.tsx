import axios from "axios";
import { LoaderCircle, MessagesSquare, Radio, Sparkles } from "lucide-react";
import { FormEvent, useState } from "react";

import { slackApi } from "../api/slackApi";
import type { SlackSummaryRequest, SlackSummaryResponse } from "../types/slack";

const initialForm: SlackSummaryRequest = {
  channel_id: "C0A46076AEM",
  user_input: "최근 1일 대화 핵심을 5줄로 요약해줘",
  date: "2026-04-19",
  lookback_hours: 24,
};

export function SlackSummaryPanel() {
  const [form, setForm] = useState<SlackSummaryRequest>(initialForm);
  const [data, setData] = useState<SlackSummaryResponse | null>(null);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const handleSubmit = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    setIsLoading(true);
    setError(null);

    try {
      const response = await slackApi.getSlackSummary(form);
      setData(response);
    } catch (err) {
      if (axios.isAxiosError(err)) {
        setError(err.response?.data?.detail ?? err.message);
      } else {
        setError("Slack 요약 요청 중 알 수 없는 오류가 발생했습니다.");
      }
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <section className="slack-panel">
      <header className="slack-panel__header">
        <div>
          <div className="section-kicker">
            <span>Live</span>
            <span>Slack module</span>
          </div>
          <h3>Slack conversation digest</h3>
          <p>
            채널, 조회 기간, 프롬프트를 조정하면서 실제 요약 응답과 원문을 같은 화면에서
            검토할 수 있습니다. 데모가 아니라 운영 검수용 패널처럼 읽히도록 구성했습니다.
          </p>
        </div>
        <div className="slack-panel__pill">
          <Radio size={16} style={{ marginRight: 8, verticalAlign: "text-bottom" }} />
          FastAPI endpoint connected
        </div>
      </header>

      <form className="slack-form" onSubmit={handleSubmit}>
        <div className="slack-form__group">
          <label htmlFor="channel_id">Channel ID</label>
          <input
            id="channel_id"
            value={form.channel_id}
            onChange={(event) => setForm((prev) => ({ ...prev, channel_id: event.target.value }))}
            placeholder="C0123456789"
          />
        </div>

        <div className="slack-form__group">
          <label htmlFor="date">Date</label>
          <input
            id="date"
            value={form.date}
            onChange={(event) => setForm((prev) => ({ ...prev, date: event.target.value }))}
            placeholder="2026-04-19"
          />
        </div>

        <div className="slack-form__group">
          <label htmlFor="lookback_hours">Lookback Hours</label>
          <input
            id="lookback_hours"
            type="number"
            min={1}
            max={168}
            value={form.lookback_hours}
            onChange={(event) =>
              setForm((prev) => ({
                ...prev,
                lookback_hours: Number(event.target.value),
              }))
            }
          />
        </div>

        <div className="slack-form__group slack-form__group--wide">
          <label htmlFor="user_input">Prompt</label>
          <input
            id="user_input"
            value={form.user_input}
            onChange={(event) => setForm((prev) => ({ ...prev, user_input: event.target.value }))}
            placeholder="최근 1일 대화 핵심을 5줄로 요약해줘"
          />
        </div>

        <button className="slack-form__submit" type="submit" disabled={isLoading}>
          {isLoading ? "요약 생성 중..." : "요약 불러오기"}
        </button>
      </form>

      {error ? <div className="slack-state slack-state--error">{error}</div> : null}

      <div className="slack-grid">
        <section className="slack-card">
          <div className="section-kicker">
            <Sparkles size={14} style={{ marginRight: 6, verticalAlign: "text-bottom" }} />
            <span>Summary</span>
          </div>

          {isLoading ? (
            <div className="slack-empty">
              <LoaderCircle size={18} style={{ marginRight: 8, verticalAlign: "text-bottom" }} />
              Slack 대화를 읽고 핵심 흐름을 정리하고 있습니다.
            </div>
          ) : data ? (
            <>
              <h3>{data.channel_name}</h3>
              <div className="slack-card__meta">
                <span>{data.lookback_hours}시간 조회</span>
                <span>메시지 {data.message_count}개</span>
                <span>{data.uses_mock ? "Mock" : "Live"}</span>
                <span>{data.model}</span>
              </div>
              <ol className="slack-summary-list">
                {data.summary_lines.map((line, index) => (
                  <li key={`${index}-${line}`}>
                    <span className="slack-summary-list__index">{index + 1}</span>
                    <span>{line}</span>
                  </li>
                ))}
              </ol>
            </>
          ) : (
            <div className="slack-empty">
              입력값을 조정한 뒤 요청을 실행하면, 요약 결과와 메타데이터가 이 카드에
              정리됩니다.
            </div>
          )}
        </section>

        <section className="slack-card">
          <div className="section-kicker">
            <MessagesSquare size={14} style={{ marginRight: 6, verticalAlign: "text-bottom" }} />
            <span>Raw messages</span>
          </div>

          {data?.messages.length ? (
            <ul className="slack-message-list">
              {data.messages.map((message) => (
                <li key={message.ts}>
                  <strong>{message.user}</strong>
                  <p>{message.text}</p>
                </li>
              ))}
            </ul>
          ) : (
            <div className="slack-empty">
              아직 불러온 메시지가 없습니다. 요청을 실행하면 최근 원문이 이 영역에
              정리됩니다.
            </div>
          )}
        </section>
      </div>
    </section>
  );
}
