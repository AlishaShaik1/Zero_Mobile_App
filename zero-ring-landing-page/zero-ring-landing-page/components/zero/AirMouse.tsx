"use client"

import { motion, type Variants } from "framer-motion"

const sectionVariants: Variants = {
  hidden: { opacity: 0, y: 30 },
  visible: { opacity: 1, y: 0, transition: { duration: 0.6, ease: [0.16, 1, 0.3, 1] as any } },
}

const features = [
  { label: "Air Pointer", desc: "Move freely across any screen" },
  { label: "Air Click", desc: "Tap to select anything" },
  { label: "Air Scroll", desc: "Scroll with a wrist tilt" },
  { label: "Universal", desc: "Windows, Mac, Android TV" },
]

export default function AirMouse() {
  return (
    <motion.section
      variants={sectionVariants}
      initial="hidden"
      whileInView="visible"
      viewport={{ once: true, margin: "-50px" }}
      style={{ background: "#F4F3EF" }}
      className="pt-14 md:pt-16"
    >
      {/* Text block */}
      <div className="px-5 md:px-6">
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
            AIR MOUSE
          </p>
          <h2
            style={{
              fontFamily: "var(--font-space-grotesk)",
              fontWeight: 800,
              fontSize: "clamp(38px, 8vw, 60px)",
              lineHeight: 0.95,
              letterSpacing: "-2px",
              color: "#0A0A0A",
              margin: 0,
            }}
          >
            Move. Point.
            <br />
            No mouse needed.
          </h2>
          <p
            style={{
              fontFamily: "var(--font-space-grotesk)",
              fontSize: 14,
              color: "#666660",
              lineHeight: 1.6,
              maxWidth: 280,
              marginTop: 12,
            }}
          >
            Point your finger, move the cursor. Any screen, zero setup.
          </p>
        </div>
      </div>

      {/* Full-bleed image */}
      <div className="mt-8">
        <img
          src="/zero_air_mouse.png"
          alt="Hand wearing Zero Ring pointing at a MacBook with a glowing cursor trail"
          className="w-full block object-cover border-t-2 border-b-2 border-[#0A0A0A]"
        />
      </div>

      {/* Feature grid card */}
      <div className="px-4 pb-14 md:px-6 md:pb-16">
        <div style={{ maxWidth: 1100, margin: "0 auto" }}>
          <div
            className="mt-4"
            style={{
              background: "#FFFFFF",
              border: "2px solid #0A0A0A",
              borderRadius: 14,
              padding: 20,
              boxShadow: "4px 4px 0 #0A0A0A",
            }}
          >
            <div className="grid grid-cols-2 gap-4">
              {features.map((f, i) => (
                <div
                  key={f.label}
                  style={{
                    borderRight: i % 2 === 0 ? "1px solid rgba(0,0,0,0.08)" : "none",
                    borderBottom: i < 2 ? "1px solid rgba(0,0,0,0.08)" : "none",
                    paddingRight: i % 2 === 0 ? 16 : 0,
                    paddingBottom: i < 2 ? 16 : 0,
                  }}
                >
                  <p style={{ fontFamily: "var(--font-space-grotesk)", fontWeight: 700, fontSize: 13, color: "#0A0A0A", margin: "0 0 4px" }}>
                    {f.label}
                  </p>
                  <p style={{ fontFamily: "var(--font-space-grotesk)", fontSize: 12, color: "#666660", margin: 0, lineHeight: 1.5 }}>
                    {f.desc}
                  </p>
                </div>
              ))}
            </div>
          </div>
        </div>
      </div>
    </motion.section>
  )
}
