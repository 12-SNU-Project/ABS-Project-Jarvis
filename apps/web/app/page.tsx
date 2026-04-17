import Link from "next/link";
import { runMorningBriefing, listTeamFolders } from "../team/baemingyu-orchestrator";
import {
  apiRouteNotes,
  demoPresentationPlan,
  homeIntro
} from "../team/oseungdam-ui";

export default async function HomePage() {
  const briefing = await runMorningBriefing({
    userInput: "오늘 외출 준비 브리핑 정리해줘"
  });
  const folders = listTeamFolders();

  return (
    <>
      <section className="hero">
        <div className="hero-inner">
          <div>
            <p className="eyebrow">{homeIntro.eyebrow}</p>
            <h1>{homeIntro.title}</h1>
            <p>{homeIntro.description}</p>
            <div className="cta-row">
              <Link href="/briefing" className="button primary">
                브리핑 화면 보기
              </Link>
              <Link href="/admin" className="button secondary">
                Admin 보기
              </Link>
            </div>
          </div>
          <div className="card" style={{ background: "rgba(255, 247, 236, 0.75)" }}>
            <span className="mini-label">메인 에이전트 응답 샘플</span>
            <h3 style={{ marginTop: 0 }}>{briefing.headline}</h3>
            <p>{briefing.summary}</p>
            <ul className="bullet-list">
              {briefing.sections.map((section) => (
                <li key={section.title}>
                  <strong>{section.title}</strong>
                  <div style={{ color: "var(--muted)", marginTop: 6 }}>{section.content}</div>
                </li>
              ))}
            </ul>
          </div>
        </div>
      </section>

      <section className="panel-grid">
        <article className="card span-4">
          <span className="badge">사람별 폴더</span>
          <ul className="feature-list">
            {folders.map((folder) => (
              <li key={folder.folder} className="feature-row">
                <div>
                  <strong>{folder.ownerName}</strong>
                  <div style={{ color: "var(--muted)" }}>{folder.role}</div>
                </div>
                <span>{folder.receives.join(", ")}</span>
              </li>
            ))}
          </ul>
        </article>

        <article className="card span-8">
          <span className="badge">발표 데모 흐름</span>
          <ul className="timeline">
            {demoPresentationPlan.map((step) => (
              <li key={step.title} className="timeline-item">
                <div>
                  <strong>{step.title}</strong>
                  <div style={{ color: "var(--muted)", marginTop: 4 }}>{step.description}</div>
                </div>
                <span>{step.owner}</span>
              </li>
            ))}
          </ul>
        </article>

        <article className="card span-12">
          <span className="badge">폴더 간 통신</span>
          <div className="code-block">
            {`User Input
  -> baemingyu-orchestrator
      -> josubin-weather
      -> kimjaehee-calendar
      -> moonihyeon-slack
  -> final briefing
  -> oseungdam-ui
  -> najeongyeon-admin`}
          </div>
        </article>

        <article className="card span-12">
          <span className="badge">API Routes</span>
          <ul className="timeline">
            {apiRouteNotes.map((item) => (
              <li key={item.route} className="timeline-item">
                <div>
                  <strong>{item.route}</strong>
                  <div style={{ color: "var(--muted)", marginTop: 4 }}>
                    {item.description}
                  </div>
                </div>
                <span>ready</span>
              </li>
            ))}
          </ul>
        </article>
      </section>
    </>
  );
}
