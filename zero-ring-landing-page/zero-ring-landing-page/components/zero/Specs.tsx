"use client"

import { motion } from "framer-motion"

const specs = [
  { name: "Intelligence", value: "3 AI models, on-device + cloud" },
  { name: "Vision", value: "Wide-angle point-and-know camera" },
  { name: "Display", value: "Mini OLED with expressive face" },
  { name: "Voice", value: "Crystal-clear mic + speaker" },
  { name: "Control", value: "Air cursor on any screen" },
  { name: "Battery", value: "All-day flexible cell" },
  { name: "Charging", value: "Magnetic dock, 90 min full" },
  { name: "Connectivity", value: "Bluetooth + Wi-Fi, no hub" },
  { name: "Shell", value: "Crystal-clear body" },
]

export default function Specs() {
  return (
    <motion.section
      initial={{ opacity: 0, y: 30 }}
      whileInView={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.6, ease: "easeOut" }}
      viewport={{ once: true, margin: "-50px" }}
      style={{ background: "#F4F3EF" }}
      className="px-5 py-10 md:px-6 md:py-12"
    >
      <div style={{ maxWidth: 1100, margin: "0 auto" }}>
      <p style={{ fontFamily: "var(--font-space-mono)", fontSize: 10, letterSpacing: "3px", textTransform: "uppercase", color: "#00C8FF", marginBottom: 6 }}>
        INSIDE THE RING
      </p>
      <h2
        style={{
          fontFamily: "var(--font-space-grotesk)",
          fontWeight: 800,
          fontSize: "clamp(34px, 6vw, 48px)",
          letterSpacing: "-2px",
          color: "#0A0A0A",
          margin: "0 0 16px",
        }}
      >
        What&apos;s inside.
      </h2>

      <div style={{ border: "2px solid #0A0A0A", borderRadius: 12, overflow: "hidden" }}>
        {specs.map((spec, i) => (
          <motion.div
            key={spec.name}
            initial={{ opacity: 0, x: -10 }}
            whileInView={{ opacity: 1, x: 0 }}
            transition={{ duration: 0.3, delay: i * 0.05, ease: "easeOut" }}
            viewport={{ once: true }}
            className="flex flex-row justify-between items-center gap-3"
            style={{
              padding: "11px 20px",
              borderBottom: i < specs.length - 1 ? "1px solid rgba(0,0,0,0.1)" : "none",
              transition: "background 150ms",
            }}
            onMouseEnter={(e) => { (e.currentTarget as HTMLDivElement).style.background = "rgba(0,200,255,0.05)" }}
            onMouseLeave={(e) => { (e.currentTarget as HTMLDivElement).style.background = "transparent" }}
          >
            <span style={{ fontFamily: "var(--font-space-mono)", fontSize: 12, fontWeight: 700, color: "#0A0A0A", flexShrink: 0 }}>
              {spec.name}
            </span>
            <span style={{ fontFamily: "var(--font-space-grotesk)", fontSize: 13, fontWeight: 500, color: "#666660", textAlign: "right" }}>
              {spec.value}
            </span>
          </motion.div>
        ))}
      </div>
      </div>
    </motion.section>
  )
}
