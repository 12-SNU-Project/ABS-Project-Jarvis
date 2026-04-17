import { runMorningBriefing } from "../../team/baemingyu-orchestrator";

export default async function BriefingPage() {
  const result = await runMorningBriefing();

  return (
    <section className="panel-grid">
      <article className="card span-12">
        <p className="eyebrow">Morning Briefing</p>
        <h1 className="page-title">{result.headline}</h1>
        <p className="page-subtitle">{result.summary}</p>
      </article>

      {result.sections.map((section) => (
        <article key={section.title} className="card span-4">
          <span className="badge">{section.key}</span>
          <h3>{section.title}</h3>
          <p style={{ color: "var(--muted)", lineHeight: 1.7 }}>{section.content}</p>
        </article>
      ))}

      <article className="card span-12">
        <span className="badge">Follow-ups</span>
        <ul className="bullet-list">
          {result.followUps.map((item) => (
            <li key={item}>{item}</li>
          ))}
        </ul>
      </article>
    </section>
  );
}
