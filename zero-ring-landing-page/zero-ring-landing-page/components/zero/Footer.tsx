"use client"

import ZeroLogo from "./ZeroLogo"

export default function Footer() {
  return (
    <footer
      style={{ background: "#111110", borderTop: "1px solid rgba(255,255,255,0.07)" }}
      className="px-5 pt-10 pb-8 md:px-6 md:pt-12 md:pb-10"
    >
      <div style={{ maxWidth: 1100, margin: "0 auto" }}>
      <div
        style={{
          display: "flex",
          flexDirection: "column",
          gap: 24,
        }}
        className="md:flex-row md:justify-between md:items-start"
      >
        {/* Left */}
        <div>
          <ZeroLogo size={0.42} color="#FFFFFF" />
          <p
            style={{
              fontFamily: "var(--font-space-grotesk)",
              fontSize: 12,
              color: "#444444",
              marginTop: 8,
            }}
          >
            Built in India 🇮🇳 · Zero Tech
          </p>
        </div>

        {/* Right links */}
        <nav
          aria-label="Footer navigation"
          style={{
            display: "flex",
            flexDirection: "row",
            gap: 20,
          }}
        >
          {["Privacy", "Contact", "Docs"].map((link) => (
            <a
              key={link}
              href="#"
              style={{
                fontFamily: "var(--font-space-grotesk)",
                fontSize: 13,
                color: "#666666",
                textDecoration: "none",
                transition: "color 150ms",
                minHeight: 44,
                display: "flex",
                alignItems: "center",
              }}
              onMouseEnter={(e) => {
                (e.currentTarget as HTMLAnchorElement).style.color = "#FFFFFF"
              }}
              onMouseLeave={(e) => {
                (e.currentTarget as HTMLAnchorElement).style.color = "#666666"
              }}
            >
              {link}
            </a>
          ))}
        </nav>
      </div>

      {/* Bottom bar */}
      <div
        style={{
          borderTop: "1px solid rgba(255,255,255,0.06)",
          marginTop: 32,
          paddingTop: 20,
          display: "flex",
          justifyContent: "space-between",
          flexWrap: "wrap",
          gap: 8,
        }}
      >
        <span
          style={{
            fontFamily: "var(--font-space-mono)",
            fontSize: 11,
            color: "#444444",
          }}
        >
          © 2026 Zero Tech. All rights reserved.
        </span>
        <span
          style={{
            fontFamily: "var(--font-space-mono)",
            fontSize: 11,
            color: "#444444",
          }}
        >
          zero-tech.in
        </span>
      </div>
      </div>
    </footer>
  )
}
