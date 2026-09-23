"use client"

import { motion } from "framer-motion"
import { useState } from "react"
import PreorderModal from "./PreorderModal"

const STATS = [
  { val: "Q3 2026", label: "Ships" },
  { val: "100", label: "First batch" },
  { val: "$199", label: "Kickstarter" },
  { val: "3 AI", label: "Models" },
]

export default function Hero() {
  const [modal, setModal] = useState<false | "early" | "regular">(false)

  return (
    <>
      <PreorderModal isOpen={!!modal} onClose={() => setModal(false)} plan={modal || "early"} />

      <section style={{ background: "#F4F3EF", overflow: "hidden", width: "100%" }}>
        <div style={{ maxWidth: 1120, margin: "0 auto", padding: "36px 20px 24px", display: "flex", flexDirection: "column", alignItems: "center", textAlign: "center" }} className="px-4 sm:px-8">

          {/* Pre-order Badge */}
          <motion.div initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.4 }}>
            <span style={{
              display: "inline-block",
              fontFamily: "var(--font-space-mono)", fontSize: 10.5, fontWeight: 700,
              letterSpacing: "2.5px", textTransform: "uppercase",
              color: "#0A0A0A", border: "1.5px solid #0A0A0A",
              borderRadius: 6, padding: "5px 14px",
              background: "#FFFFFF",
              boxShadow: "2px 2px 0 #0A0A0A"
            }}>
              ✦ Now open for pre-order
            </span>
          </motion.div>

          {/* Headline */}
          <motion.h1
            initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.55, delay: 0.1 }}
            style={{
              fontFamily: "var(--font-space-grotesk)", fontWeight: 800,
              fontSize: "clamp(42px, 7vw, 72px)", lineHeight: 0.95,
              letterSpacing: "-2.5px", margin: "18px 0 0", color: "#0A0A0A",
            }}
          >
            The AI that lives on <span style={{ color: "#00C8FF" }}>your finger.</span>
          </motion.h1>

          {/* Subparagraph */}
          <motion.p
            initial={{ opacity: 0 }} animate={{ opacity: 1 }}
            transition={{ duration: 0.5, delay: 0.3 }}
            style={{ fontFamily: "var(--font-space-grotesk)", fontSize: 15.5, color: "#555550", lineHeight: 1.65, maxWidth: 500, marginTop: 14 }}
          >
            Zero is not a device. It talks, thinks, acts — all from your ring.
          </motion.p>

          {/* ═══════════════════════════════════════════════════════════
              ██  SNUG PERFECT-FIT PRODUCT CARD  ██
              ═══════════════════════════════════════════════════════════ */}
          <motion.div
            initial={{ opacity: 0, y: 15 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.5, delay: 0.35 }}
            style={{
              width: "100%", maxWidth: 410,
              marginTop: 22, marginBottom: 6,
              background: "#FFFFFF",
              border: "1.5px solid #0A0A0A",
              borderRadius: 20,
              boxShadow: "4px 4px 0 #0A0A0A",
              padding: "10px 10px 12px",
              display: "flex",
              flexDirection: "column",
              alignItems: "center",
              justifyContent: "center",
              overflow: "hidden"
            }}
          >
            {/* The Ring Image - Flush Fit */}
            <div className="float-anim" style={{ display: "flex", justifyContent: "center", width: "100%", borderRadius: 12, overflow: "hidden" }}>
              <img
                src="/zero_ring_dragonfly.png"
                alt="Zero Ring — AI-powered smart ring with transparent body, OLED display, and camera, featured with a mechanical dragonfly"
                style={{
                  width: "100%",
                  height: "auto",
                  display: "block",
                  objectFit: "contain",
                  borderRadius: 10
                }}
              />
            </div>

            {/* Inset feel caption strip at bottom */}
            <div style={{
              width: "100%",
              marginTop: 10,
              background: "#F4F3EF",
              border: "1px solid #0A0A0A",
              borderRadius: 10,
              padding: "8px 14px",
              display: "flex", justifyContent: "space-between", alignItems: "center"
            }}>
              <span style={{ fontFamily: "var(--font-space-mono)", fontSize: 10, color: "#666660", letterSpacing: "1.5px", textTransform: "uppercase", fontWeight: 700 }}>
                Zero Ring · Gen 1
              </span>
              <span style={{ fontFamily: "var(--font-space-mono)", fontSize: 10, color: "#00C8FF", fontWeight: 800 }}>
                SIZES 6–12
              </span>
            </div>
          </motion.div>

          {/* Buttons */}
          <motion.div
            initial={{ opacity: 0 }} animate={{ opacity: 1 }}
            transition={{ duration: 0.5, delay: 0.55 }}
            style={{ display: "flex", flexWrap: "wrap", justifyContent: "center", gap: 12, marginTop: 16 }}
          >
            <button
              id="hero-preorder-btn"
              onClick={() => setModal("regular")}
              style={{ background: "#0A0A0A", color: "#FFFFFF", border: "1.5px solid #0A0A0A", borderRadius: 9, padding: "13px 24px", fontFamily: "var(--font-space-grotesk)", fontWeight: 700, fontSize: 14.5, cursor: "pointer", boxShadow: "3px 3px 0 #00C8FF", transition: "all 150ms", minHeight: 46 }}
              onMouseEnter={e => { const b = e.currentTarget; b.style.transform = "translate(-1px,-1px)"; b.style.boxShadow = "4px 4px 0 #00C8FF" }}
              onMouseLeave={e => { const b = e.currentTarget; b.style.transform = "translate(0,0)"; b.style.boxShadow = "3px 3px 0 #00C8FF" }}
            >Pre-order — ₹14,999</button>

            <button
              id="hero-earlybird-btn"
              onClick={() => setModal("early")}
              style={{ background: "#FFFFFF", color: "#0A0A0A", border: "1.5px solid #0A0A0A", borderRadius: 9, padding: "13px 24px", fontFamily: "var(--font-space-grotesk)", fontWeight: 700, fontSize: 14.5, cursor: "pointer", transition: "all 150ms", minHeight: 46, boxShadow: "2px 2px 0 #0A0A0A" }}
              onMouseEnter={e => { const b = e.currentTarget; b.style.transform = "translate(-1px,-1px)"; b.style.boxShadow = "3px 3px 0 #0A0A0A" }}
              onMouseLeave={e => { const b = e.currentTarget; b.style.transform = "translate(0,0)"; b.style.boxShadow = "2px 2px 0 #0A0A0A" }}
            >🔥 Early bird ₹11,999 →</button>
          </motion.div>

          {/* Trust Caption */}
          <motion.p
            initial={{ opacity: 0 }} animate={{ opacity: 1 }}
            transition={{ duration: 0.4, delay: 0.65 }}
            style={{ fontFamily: "var(--font-space-mono)", fontSize: 10.5, color: "#888882", marginTop: 12, letterSpacing: "0.5px" }}
          >
            No payment now · Limited first batch
          </motion.p>

          {/* Stats Bar */}
          <motion.div
            initial={{ opacity: 0 }} animate={{ opacity: 1 }}
            transition={{ duration: 0.5, delay: 0.72 }}
            style={{ display: "flex", flexWrap: "wrap", justifyContent: "center", gap: "16px 36px", marginTop: 28, paddingTop: 20, borderTop: "1.5px solid #0A0A0A", width: "100%", maxWidth: 640 }}
          >
            {STATS.map(s => (
              <div key={s.label}>
                <div style={{ fontFamily: "var(--font-space-mono)", fontWeight: 800, fontSize: 16, color: "#00C8FF" }}>{s.val}</div>
                <div style={{ fontFamily: "var(--font-space-grotesk)", fontSize: 11.5, color: "#888882", marginTop: 2 }}>{s.label}</div>
              </div>
            ))}
          </motion.div>

        </div>

        {/* Section Divider */}
        <div style={{ height: 1.5, background: "#0A0A0A" }} />
      </section>
    </>
  )
}
