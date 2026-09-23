"use client"

import { motion, type Variants } from "framer-motion"

const sectionVariants: Variants = {
  hidden: { opacity: 0, y: 30 },
  visible: { opacity: 1, y: 0, transition: { duration: 0.6, ease: [0.16, 1, 0.3, 1] as any } },
}

function ZeroCloudLogo() {
  return (
    <svg width="56" height="46" viewBox="0 0 64 52" fill="none" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">
      <path d="M12 40 Q4 40 4 32 Q4 24 12 23 Q11 12 22 10 Q28 4 36 8 Q44 4 50 10 Q60 10 60 20 Q64 22 62 30 Q62 40 52 40 Z" fill="#F4F3EF" stroke="#0A0A0A" strokeWidth="2" strokeLinejoin="round" />
      <path d="M22 26 Q24 24 26 26" stroke="#0A0A0A" strokeWidth="2" strokeLinecap="round" fill="none" />
      <path d="M36 26 Q38 24 40 26" stroke="#0A0A0A" strokeWidth="2" strokeLinecap="round" fill="none" />
      <path d="M24 33 Q31 38 38 33" stroke="#0A0A0A" strokeWidth="2" strokeLinecap="round" fill="none" />
    </svg>
  )
}

export default function ZeroCowork() {
  return (
    <motion.section
      variants={sectionVariants}
      initial="hidden"
      whileInView="visible"
      viewport={{ once: true, margin: "-50px" }}
      style={{ background: "#F4F3EF" }}
      className="px-5 py-14 md:px-6 md:py-16"
    >
      <div style={{ maxWidth: 1100, margin: "0 auto" }}>
      <p
        style={{
          fontFamily: "var(--font-space-mono)",
          fontSize: 10,
          letterSpacing: "3px",
          textTransform: "uppercase",
          color: "#00C8FF",
          marginBottom: 12,
        }}
      >
        ZERO COWORK
      </p>

      <h2
        style={{
          fontFamily: "var(--font-space-grotesk)",
          fontWeight: 800,
          fontSize: "clamp(34px, 7vw, 56px)",
          lineHeight: 0.95,
          letterSpacing: "-2px",
          color: "#0A0A0A",
          margin: 0,
        }}
      >
        Your AI work
        <br />
        buddy.
      </h2>

      <p
        style={{
          fontFamily: "var(--font-space-grotesk)",
          fontSize: 14,
          color: "#666660",
          lineHeight: 1.65,
          maxWidth: 300,
          marginTop: 14,
        }}
      >
        Stuck? Just ask Zero. It sees your screen and whispers the answer.
      </p>

      {/* Code card */}
      <div
        className="mt-8"
        style={{
          border: "2px solid #0A0A0A",
          borderRadius: 14,
          background: "#FFFFFF",
          boxShadow: "5px 5px 0 #0A0A0A",
          overflow: "hidden",
        }}
      >
        {/* Top bar */}
        <div
          style={{
            height: 40,
            background: "#0A0A0A",
            display: "flex",
            alignItems: "center",
            padding: "0 16px",
            gap: 8,
          }}
        >
          <span style={{ width: 10, height: 10, borderRadius: "50%", background: "#FF5F56", display: "inline-block" }} />
          <span style={{ width: 10, height: 10, borderRadius: "50%", background: "#FFBD2E", display: "inline-block" }} />
          <span style={{ width: 10, height: 10, borderRadius: "50%", background: "#27C93F", display: "inline-block" }} />
          <span
            className="hidden sm:inline ml-auto"
            style={{ fontFamily: "var(--font-space-mono)", fontSize: 11, color: "#666666" }}
          >
            zero cowork — Your AI Work Buddy
          </span>
        </div>

        {/* Code body */}
        <div style={{ padding: 20, background: "#0F0F0F" }}>
          <div style={{ fontFamily: "var(--font-space-mono)", fontSize: 12, lineHeight: 1.9 }}>
            <span style={{ color: "#666666" }}>{"// Zero is watching your screen..."}</span>
          </div>
          <div style={{ fontFamily: "var(--font-space-mono)", fontSize: 12, lineHeight: 1.9 }}>
            <span style={{ color: "#00C8FF" }}>You: </span>
            <span style={{ color: "#E0E0E0" }}>{"why isn't this working?"}</span>
          </div>
          <div style={{ fontFamily: "var(--font-space-mono)", fontSize: 12, lineHeight: 1.9 }}>
            <span style={{ color: "#C3E88D" }}>{"// Zero found it in 0.3s"}</span>
          </div>
          <div style={{ fontFamily: "var(--font-space-mono)", fontSize: 12, lineHeight: 1.9, display: "flex", alignItems: "center", gap: 4 }}>
            <span style={{ color: "#00C8FF" }}>Zero: </span>
            <span style={{ color: "#E0E0E0" }}>You forgot to save the file. Fixed.</span>
            <span className="blink-cursor" style={{ display: "inline-block", width: 8, height: 14, background: "#00C8FF", marginLeft: 2 }} />
          </div>
        </div>
      </div>

      {/* Zero Cowork logo */}
      <div className="flex flex-col items-center mt-10 gap-2">
        <ZeroCloudLogo />
        <span style={{ fontFamily: "var(--font-space-mono)", fontWeight: 700, fontSize: 13, color: "#0A0A0A" }}>
          Zero Cowork
        </span>
        <span style={{ fontFamily: "var(--font-space-mono)", fontSize: 10, letterSpacing: "2px", textTransform: "uppercase", color: "#888880" }}>
          Coming Soon
        </span>
      </div>
      </div>
    </motion.section>
  )
}
