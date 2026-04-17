import { buildNajeongyeonAdminSummary } from "../../team/najeongyeon-admin";

export default async function AdminPage() {
  const summary = await buildNajeongyeonAdminSummary();
  const maxTokens = Math.max(...summary.tokenUsage.map((metric) => metric.totalTokens));

  return (
    <section className="panel-grid">
      <article className="card span-12">
        <p className="eyebrow">Admin Dashboard</p>
        <h1 className="page-title">토큰 사용량과 에이전트 흐름</h1>
        <p className="page-subtitle">
          구현 난이도는 낮추고, 발표 때는 "무슨 기능이 가장 비싼지"와 "어떤 순서로 에이전트가
          돌았는지"를 보여줄 수 있도록 만든 뼈대입니다.
        </p>
      </article>

      <article className="card span-5">
        <span className="badge">Token Usage</span>
        <ul className="kpi-list">
          {summary.tokenUsage.map((metric) => (
            <li key={metric.key}>
              <div className="stat">
                <div>
                  <strong>{metric.totalTokens}</strong>
                  <div style={{ color: "var(--muted)" }}>{metric.label}</div>
                </div>
                <div
                  style={{
                    width: 140,
                    height: 10,
                    borderRadius: 999,
                    background: "rgba(46, 38, 24, 0.08)",
                    overflow: "hidden"
                  }}
                >
                  <div
                    style={{
                      width: `${(metric.totalTokens / maxTokens) * 100}%`,
                      height: "100%",
                      background: "linear-gradient(90deg, #cb5c32, #ef9a62)"
                    }}
                  />
                </div>
              </div>
            </li>
          ))}
        </ul>
      </article>

      <article className="card span-7">
        <span className="badge">Agent Graph</span>
        <div className="graph">
          <div className="graph-node" style={{ top: 24, left: 24 }}>
            Main Orchestrator
          </div>
          <div className="graph-node" style={{ top: 110, left: 70 }}>
            Weather
          </div>
          <div className="graph-node" style={{ top: 180, left: 250 }}>
            Calendar
          </div>
          <div className="graph-node" style={{ top: 80, right: 90 }}>
            Slack
          </div>
          <div className="graph-node" style={{ bottom: 24, right: 30 }}>
            Briefing Composer
          </div>
        </div>
      </article>

      <article className="card span-12">
        <span className="badge">최근 실행 로그</span>
        <ul className="timeline">
          {summary.recentRuns.map((run) => (
            <li key={`${run.ownerName}-${run.role}`} className="timeline-item">
              <div>
                <strong>{run.ownerName}</strong>
                <div style={{ color: "var(--muted)", marginTop: 4 }}>{run.summary}</div>
              </div>
              <span>
                {run.status} · {run.durationMs}ms
              </span>
            </li>
          ))}
        </ul>
      </article>

      <article className="card span-12">
        <span className="badge">Folder Ownership</span>
        <ul className="timeline">
          {summary.folders.map((folder) => (
            <li key={folder.folder} className="timeline-item">
              <div>
                <strong>{folder.ownerName}</strong>
                <div style={{ color: "var(--muted)", marginTop: 4 }}>
                  {folder.role}
                </div>
              </div>
              <span>{folder.returns.join(", ")}</span>
            </li>
          ))}
        </ul>
      </article>
    </section>
  );
}
