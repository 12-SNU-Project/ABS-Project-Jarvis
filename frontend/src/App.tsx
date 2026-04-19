import { Bot, CalendarDays, CloudSun, PanelRightOpen, ShieldCheck } from "lucide-react";
import { useState } from "react";

import { SlackSummaryPanel } from "./features/slack/components/SlackSummaryPanel";

type FeatureKey = "weather" | "calendar" | "slack" | "admin";

const featureMeta: Record<
  FeatureKey,
  { label: string; title: string; description: string; icon: typeof CloudSun }
> = {
  weather: {
    label: "Weather",
    title: "날씨 브리핑",
    description: "날씨 기능 UI는 아직 연결 전입니다. 버튼 구조만 먼저 준비해두었습니다.",
    icon: CloudSun,
  },
  calendar: {
    label: "Calendar",
    title: "일정 브리핑",
    description: "캘린더 기능 UI는 아직 연결 전입니다. 이후 API만 연결하면 같은 구조로 확장할 수 있습니다.",
    icon: CalendarDays,
  },
  slack: {
    label: "Slack",
    title: "Slack 요약",
    description: "최근 24시간 전체 대화를 5줄로 요약하는 실연동 데모 화면입니다.",
    icon: Bot,
  },
  admin: {
    label: "Admin",
    title: "Admin 요약",
    description: "관리자 대시보드 기능 UI는 아직 연결 전입니다. 버튼 진입 구조만 맞춰두었습니다.",
    icon: ShieldCheck,
  },
};

const features: FeatureKey[] = ["weather", "calendar", "slack", "admin"];

function PlaceholderPanel({
  feature,
}: {
  feature: Exclude<FeatureKey, "slack">;
}) {
  const meta = featureMeta[feature];
  const Icon = meta.icon;

  return (
    <section className="feature-card">
      <div className="feature-card__badge">AI</div>
      <h2>{meta.title}</h2>
      <p>{meta.description}</p>
      <div className="placeholder-card">
        <Icon size={36} />
        <span>{meta.label} API 연결 대기 중</span>
      </div>
    </section>
  );
}

export default function App() {
  const [activeFeature, setActiveFeature] = useState<FeatureKey>("slack");
  const activeMeta = featureMeta[activeFeature];

  return (
    <div className="app-shell">
      <div className="app-shell__glow app-shell__glow--left" />
      <div className="app-shell__glow app-shell__glow--right" />

      <main className="dashboard">
        <section className="hero-panel">
          <div className="hero-panel__bubble">
            <span className="hero-panel__label">AI</span>
            <p>{activeMeta.title}을(를) 확인해 드립니다.</p>
          </div>

          <div className="hero-panel__core">
            <div className="hero-panel__avatar">
              <Bot size={92} />
            </div>
            <div className="hero-panel__summary">
              <PanelRightOpen size={18} />
              <span>{activeMeta.description}</span>
            </div>
          </div>
        </section>

        <aside className="feature-nav">
          {features.map((feature) => {
            const meta = featureMeta[feature];
            return (
              <button
                key={feature}
                className={`feature-nav__button ${activeFeature === feature ? "is-active" : ""}`}
                type="button"
                onClick={() => setActiveFeature(feature)}
              >
                {meta.label}
              </button>
            );
          })}
        </aside>

        <section className="detail-panel">
          {activeFeature === "slack" ? (
            <SlackSummaryPanel />
          ) : (
            <PlaceholderPanel feature={activeFeature} />
          )}
        </section>
      </main>
    </div>
  );
}
