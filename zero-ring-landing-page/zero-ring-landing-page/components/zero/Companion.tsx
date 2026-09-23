"use client"

import { motion } from "framer-motion"

const features = [
  { icon: "○", label: "Zero Face", sub: "Glowing eyes that react to you" },
  { icon: "◎", label: "Zero Voice", sub: "Whispers answers in your ear" },
  { icon: "◉", label: "Zero Sight", sub: "Sees what you see, live" },
  { icon: "✦", label: "Zero Mind", sub: "Always thinking, always ready" },
]

export default function Companion() {
  return (
    <motion.section
      initial={{ opacity: 0, y: 30 }}
      whileInView={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.6, ease: "easeOut" }}
      viewport={{ once: true, margin: "-50px" }}
      style={{ background: "#F4F3EF", overflow: "hidden" }}
    >
      {/* Header */}
      <div className="px-5 pt-14 pb-6 md:px-6 md:pt-16 md:pb-8">
        <div style={{ maxWidth: 1100, margin: "0 auto" }}>
          <p
            style={{
              fontFamily: "var(--font-space-mono)",
              fontSize: 10,
              letterSpacing: "3px",
              textTransform: "uppercase",
              color: "#00C8FF",
              marginBottom: 14,
            }}
          >
            MEET ZERO
          </p>
          <h2
            style={{
              fontFamily: "var(--font-space-grotesk)",
              fontWeight: 800,
              fontSize: "clamp(38px, 9vw, 64px)",
              lineHeight: 0.93,
              letterSpacing: "-2.5px",
              color: "#0A0A0A",
              margin: 0,
            }}
          >
            Not a ring.
            <br />
            <span style={{ color: "#00C8FF" }}>A mind.</span>
          </h2>
          <p
            style={{
              fontFamily: "var(--font-space-grotesk)",
              fontSize: 14,
              color: "#888880",
              lineHeight: 1.65,
              maxWidth: 320,
              marginTop: 14,
              marginBottom: 0,
            }}
          >
            Eyes, voice, and AI — worn on your finger. Zero sees the world with you and acts before you ask.
          </p>
        </div>
      </div>

      {/* Image with overlaid feature pills */}
      <div
        style={{
          position: "relative",
          borderTop: "2px solid #0A0A0A",
          borderBottom: "2px solid #0A0A0A",
          overflow: "hidden",
        }}
      >
        <img
          src="/zero_ring_chameleon.jpg"
          alt="Zero Ring — AI-powered smart ring featured with a transparent mechanical chameleon"
          style={{
            width: "100%",
            display: "block",
            objectFit: "cover",
            maxHeight: 420,
          }}
        />
        {/* Bottom fade */}
        <div
          aria-hidden="true"
          style={{
            position: "absolute",
            bottom: 0,
            left: 0,
            right: 0,
            height: "50%",
            background: "linear-gradient(to top, rgba(244,243,239,0.95) 0%, transparent 100%)",
            pointerEvents: "none",
          }}
        />
      </div>

      {/* 4 feature cards in a single rounded card — matches AirMouse style */}
      <div className="px-4 pb-10 pt-4 md:px-6">
        <div style={{ maxWidth: 1100, margin: "0 auto" }}>
          <div
            style={{
              background: "#FFFFFF",
              border: "2px solid #0A0A0A",
              borderRadius: 14,
              boxShadow: "4px 4px 0 #0A0A0A",
              overflow: "hidden",
            }}
          >
            <div className="grid grid-cols-2">
              {features.map((f, i) => (
                <motion.div
                  key={f.label}
                  initial={{ opacity: 0, y: 10 }}
                  whileInView={{ opacity: 1, y: 0 }}
                  transition={{ duration: 0.35, delay: i * 0.07, ease: "easeOut" }}
                  viewport={{ once: true }}
                  className="flex flex-col gap-1 p-5 md:p-6"
                  style={{
                    borderRight: i % 2 === 0 ? "1px solid rgba(0,0,0,0.1)" : "none",
                    borderBottom: i < 2 ? "1px solid rgba(0,0,0,0.1)" : "none",
                  }}
                >
                  <span
                    style={{
                      fontFamily: "var(--font-space-mono)",
                      fontSize: 18,
                      color: "#00C8FF",
                      lineHeight: 1,
                      marginBottom: 6,
                    }}
                  >
                    {f.icon}
                  </span>
                  <span
                    style={{
                      fontFamily: "var(--font-space-grotesk)",
                      fontWeight: 700,
                      fontSize: 13,
                      color: "#0A0A0A",
                      letterSpacing: "-0.2px",
                    }}
                  >
                    {f.label}
                  </span>
                  <span
                    style={{
                      fontFamily: "var(--font-space-grotesk)",
                      fontSize: 12,
                      color: "#888880",
                      lineHeight: 1.5,
                    }}
                  >
                    {f.sub}
                  </span>
                </motion.div>
              ))}
            </div>
          </div>
        </div>
      </div>
    </motion.section>
  )
}
