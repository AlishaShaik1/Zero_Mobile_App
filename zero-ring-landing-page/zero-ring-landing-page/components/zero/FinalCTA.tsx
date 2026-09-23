"use client"

import { motion } from "framer-motion"
import { useState } from "react"
import PreorderModal from "./PreorderModal"

export default function FinalCTA() {
  const [modal, setModal] = useState<false | "early" | "regular">(false)

  return (
    <>
      <PreorderModal isOpen={!!modal} onClose={() => setModal(false)} plan={modal || "regular"} />

      <motion.section
        initial={{ opacity: 0, y: 30 }}
        whileInView={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.6, ease: "easeOut" }}
        viewport={{ once: true, margin: "-40px" }}
        style={{ background: "#0A0A0A", padding: "56px 24px" }}
        className="md:py-20"
      >
        <div style={{ maxWidth: 640, margin: "0 auto", textAlign: "center" }}>
          <p style={{ fontFamily: "var(--font-space-mono)", fontSize: 10, letterSpacing: "3px", textTransform: "uppercase", color: "#00C8FF", marginBottom: 12 }}>
            NOW OPEN
          </p>

          <h2 style={{ fontFamily: "var(--font-space-grotesk)", fontWeight: 800, fontSize: "clamp(38px, 8vw, 56px)", letterSpacing: "-2.5px", lineHeight: 0.95, margin: "0 0 16px", color: "#F4F3EF" }}>
            Your AI is waiting.
          </h2>

          <p style={{ fontFamily: "var(--font-space-grotesk)", fontSize: 15, color: "#888880", marginBottom: 32 }}>
            The first AI companion that lives on your finger.
          </p>

          <div style={{ display: "flex", flexWrap: "wrap", justifyContent: "center", gap: 12 }}>
            <button
              onClick={() => setModal("regular")}
              style={{ background: "#00C8FF", color: "#0A0A0A", border: "2px solid #00C8FF", borderRadius: 8, padding: "12px 24px", fontFamily: "var(--font-space-grotesk)", fontWeight: 700, fontSize: 14, cursor: "pointer", transition: "all 150ms" }}
              onMouseEnter={e => { const b = e.currentTarget as HTMLButtonElement; b.style.transform = "translate(-2px,-2px)"; b.style.boxShadow = "4px 4px 0 #F4F3EF" }}
              onMouseLeave={e => { const b = e.currentTarget as HTMLButtonElement; b.style.transform = "translate(0,0)"; b.style.boxShadow = "none" }}
            >
              Pre-order ₹14,999 →
            </button>
            <button
              onClick={() => setModal("early")}
              style={{ background: "transparent", color: "#F4F3EF", border: "2px solid #F4F3EF", borderRadius: 8, padding: "12px 24px", fontFamily: "var(--font-space-grotesk)", fontWeight: 700, fontSize: 14, cursor: "pointer", transition: "all 150ms" }}
              onMouseEnter={e => { const b = e.currentTarget as HTMLButtonElement; b.style.background = "#F4F3EF"; b.style.color = "#0A0A0A" }}
              onMouseLeave={e => { const b = e.currentTarget as HTMLButtonElement; b.style.background = "transparent"; b.style.color = "#F4F3EF" }}
            >
              Early bird ₹11,999
            </button>
          </div>
          
          <p style={{ fontFamily: "var(--font-space-mono)", fontSize: 10, color: "#555550", letterSpacing: "1px", marginTop: 20 }}>
            Limited first batch · Ships Q3 2026 · No payment now
          </p>
        </div>
      </motion.section>
    </>
  )
}
