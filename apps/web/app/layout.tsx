import "./globals.css";
import type { Metadata } from "next";
import Link from "next/link";
import type { ReactNode } from "react";

export const metadata: Metadata = {
  title: "Jarvis Assistant",
  description: "AI assistant team project skeleton"
};

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="ko">
      <body>
        <div className="shell">
          <nav
            style={{
              display: "flex",
              justifyContent: "space-between",
              alignItems: "center",
              marginBottom: 20
            }}
          >
            <Link href="/" style={{ fontSize: 24, fontWeight: 700 }}>
              Jarvis Assistant
            </Link>
            <div style={{ display: "flex", gap: 12 }}>
              <Link href="/">Home</Link>
              <Link href="/admin">Admin</Link>
              <Link href="/briefing">Briefing</Link>
            </div>
          </nav>
          {children}
        </div>
      </body>
    </html>
  );
}
