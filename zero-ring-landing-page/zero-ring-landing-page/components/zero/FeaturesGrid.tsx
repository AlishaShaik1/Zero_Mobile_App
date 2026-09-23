"use client"

import { motion } from "framer-motion"

function MicIcon() {
  return <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true"><rect x="9" y="2" width="6" height="12" rx="3" /><path d="M5 10a7 7 0 0 0 14 0" /><line x1="12" y1="19" x2="12" y2="22" /><line x1="8" y1="22" x2="16" y2="22" /></svg>
}
function CameraIcon() {
  return <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true"><path d="M23 19a2 2 0 0 1-2 2H3a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h4l2-3h6l2 3h4a2 2 0 0 1 2 2z" /><circle cx="12" cy="13" r="4" /></svg>
}
function CursorIcon() {
  return <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true"><path d="M4 4l7.07 17 2.51-7.39L21 11.07z" /></svg>
}
function PhoneIcon() {
  return <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true"><rect x="5" y="2" width="14" height="20" rx="2" /><line x1="12" y1="18" x2="12" y2="18" strokeWidth="3" strokeLinecap="round" /></svg>
}
function CodeIcon() {
  return <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true"><polyline points="16 18 22 12 16 6" /><polyline points="8 6 2 12 8 18" /></svg>
}
function VideoIcon() {
  return <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true"><polygon points="23 7 16 12 23 17 23 7" /><rect x="1" y="5" width="15" height="14" rx="2" /></svg>
}

const cards = [
  { num: "01", Icon: MicIcon, name: "Voice Commands", desc: "Calls, messages, orders — your voice is the interface." },
  { num: "02", Icon: CameraIcon, name: "See The World", desc: "Point at anything. Zero reads, identifies, translates." },
  { num: "03", Icon: CursorIcon, name: "Air Mouse", desc: "Control any screen mid-air. No mouse, no trackpad." },
  { num: "04", Icon: PhoneIcon, name: "Full Phone Control", desc: "Calls, payments, food — all from your ring." },
  { num: "05", Icon: CodeIcon, name: "Zero Cowork", desc: "Your AI dev partner. Reads your screen, fixes bugs." },
  { num: "06", Icon: VideoIcon, name: "First-Person Camera", desc: "Capture what you see, exactly when you see it." },
]

export default function FeaturesGrid() {
  return (
    <motion.section
      initial={{ opacity: 0, y: 30 }}
      whileInView={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.6, ease: "easeOut" }}
      viewport={{ once: true, margin: "-50px" }}
      style={{ background: "#F4F3EF", borderTop: "2px solid #0A0A0A" }}
      className="px-5 py-12 md:px-6 md:py-16"
    >
      <div style={{ maxWidth: 1100, margin: "0 auto" }}>
        <p style={{ fontFamily: "var(--font-space-mono)", fontSize: 10, letterSpacing: "3px", textTransform: "uppercase", color: "#00C8FF", marginBottom: 12 }}>
          WHAT ZERO CAN DO
        </p>
        <h2
          style={{
            fontFamily: "var(--font-space-grotesk)",
            fontWeight: 800,
            fontSize: "clamp(34px, 7vw, 48px)",
            color: "#0A0A0A",
            letterSpacing: "-2px",
            margin: "0 0 4px",
          }}
        >
          Everything.
        </h2>
        <p style={{ fontFamily: "var(--font-space-grotesk)", fontSize: 14, color: "#666660", margin: "0 0 36px" }}>
          One ring. Infinite actions.
        </p>

        <div className="grid grid-cols-2 gap-y-10 gap-x-6 lg:grid-cols-3">
          {cards.map((card, i) => (
            <motion.div
              key={card.name}
              initial={{ opacity: 0, y: 16 }}
              whileInView={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.4, delay: i * 0.05, ease: "easeOut" }}
              viewport={{ once: true }}
              style={{ paddingRight: 10 }}
            >
              <div style={{ display: "flex", alignItems: "center", gap: 12, marginBottom: 8 }}>
                <div style={{ width: 36, height: 36, background: "#0A0A0A", borderRadius: 8, display: "flex", alignItems: "center", justifyContent: "center", color: "#F4F3EF", flexShrink: 0 }}>
                  <span style={{ transform: "scale(0.8)" }}><card.Icon /></span>
                </div>
                <p style={{ fontFamily: "var(--font-space-grotesk)", fontSize: 15, fontWeight: 700, color: "#0A0A0A", margin: 0, lineHeight: 1.2 }}>{card.name}</p>
              </div>
              <p style={{ fontFamily: "var(--font-space-grotesk)", fontSize: 13, color: "#666660", lineHeight: 1.55, margin: 0 }}>{card.desc}</p>
            </motion.div>
          ))}
        </div>
      </div>
    </motion.section>
  )
}
