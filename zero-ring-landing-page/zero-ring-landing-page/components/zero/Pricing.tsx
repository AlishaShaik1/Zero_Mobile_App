"use client"

import { motion } from "framer-motion"
import { useRef, useState, useEffect } from "react"
import PreorderModal from "./PreorderModal"

const features = [
  "Zero Ring hardware",
  "Zero Android app — lifetime",
  "All AI models included",
  "Free updates forever",
  "Zero Charge dock included",
  "Priority support",
]

const plans = [
  { tag: "EARLY BIRD", price: "₹11,999", subtext: "First 100 orders only.", highlight: true, modal: "early" as const },
  { tag: "STANDARD", price: "₹14,999", subtext: "Regular pre-order price.", highlight: false, modal: "regular" as const },
  { tag: "GLOBAL", price: "$199", subtext: "Kickstarter international.", highlight: false, modal: "global" as const },
]

export default function Pricing() {
  const scrollRef = useRef<HTMLDivElement>(null)
  const [modal, setModal] = useState<false | "early" | "regular" | "global">(false)
  const [activeSlide, setActiveSlide] = useState(0)

  // Track active slide on mobile scroll
  const handleScroll = () => {
    if (!scrollRef.current) return
    const { scrollLeft, clientWidth } = scrollRef.current
    const index = Math.round(scrollLeft / (clientWidth * 0.8))
    setActiveSlide(Math.min(Math.max(index, 0), plans.length - 1))
  }

  const scrollToIndex = (index: number) => {
    if (!scrollRef.current) return
    const cardWidth = 320 + 16
    scrollRef.current.scrollTo({
      left: index * cardWidth,
      behavior: "smooth"
    })
    setActiveSlide(index)
  }

  return (
    <>
      <PreorderModal isOpen={!!modal} onClose={() => setModal(false)} plan={modal || "early"} />

      <motion.section
        id="pricing"
        initial={{ opacity: 0, y: 30 }}
        whileInView={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.6, ease: "easeOut" }}
        viewport={{ once: true, margin: "-50px" }}
        style={{ background: "#F4F3EF", padding: "64px 0", overflow: "hidden", width: "100%" }}
      >
        {/* Header */}
        <div style={{ padding: "0 20px" }} className="max-w-[800px] mx-auto text-center flex flex-col items-center mb-10">
          <p style={{ fontFamily: "var(--font-space-mono)", fontSize: 11, letterSpacing: "3px", textTransform: "uppercase", color: "#00C8FF", fontWeight: 700, marginBottom: 10 }}>
            PRICING TIERS
          </p>
          <h2 style={{ fontFamily: "var(--font-space-grotesk)", fontWeight: 800, fontSize: "clamp(36px, 6vw, 54px)", letterSpacing: "-2px", color: "#0A0A0A", margin: "0 0 8px", lineHeight: 1 }}>
            Simple. Transparent.
          </h2>
          <p style={{ fontFamily: "var(--font-space-grotesk)", fontSize: 16, color: "#777770", margin: 0 }}>
            Ships Q3 2026. Zero monthly subscriptions.
          </p>
        </div>

        {/* Responsive Pricing Grid / Mobile Slider */}
        <div className="max-w-[1160px] mx-auto px-4 sm:px-6">
          <div
            ref={scrollRef}
            onScroll={handleScroll}
            style={{
              display: "flex",
              flexDirection: "row",
              gap: 20,
              overflowX: "auto",
              paddingLeft: 12,
              paddingRight: 12,
              paddingBottom: 16,
              scrollSnapType: "x mandatory",
              WebkitOverflowScrolling: "touch",
              scrollbarWidth: "none",
            }}
            className="md:justify-center md:overflow-x-visible md:p-0"
          >
            {plans.map((plan, idx) => (
              <motion.div
                key={plan.price}
                initial={{ opacity: 0, y: 20 }}
                whileInView={{ opacity: 1, y: 0 }}
                viewport={{ once: true }}
                transition={{ duration: 0.5, delay: idx * 0.1 }}
                style={{
                  flex: "0 0 300px",
                  border: "2px solid #0A0A0A",
                  borderRadius: 22,
                  background: "#FFFFFF",
                  padding: "30px 24px 26px",
                  boxShadow: plan.highlight ? "6px 6px 0 #00C8FF" : "6px 6px 0 #0A0A0A",
                  scrollSnapAlign: "center",
                  display: "flex",
                  flexDirection: "column",
                  justifyContent: "space-between",
                  transition: "all 200ms ease",
                }}
                className="sm:min-w-[320px] md:flex-1 md:max-w-[350px]"
              >
                <div>
                  {/* Badge */}
                  <div className="flex items-center justify-between mb-4">
                    <span
                      style={{
                        display: "inline-block",
                        background: plan.highlight ? "#E8F8FF" : "#F4F3EF",
                        border: `1.5px solid ${plan.highlight ? "#00C8FF" : "#0A0A0A"}`,
                        color: plan.highlight ? "#00C8FF" : "#0A0A0A",
                        borderRadius: 6,
                        padding: "4px 12px",
                        fontFamily: "var(--font-space-mono)",
                        fontSize: 10.5,
                        fontWeight: 700,
                        letterSpacing: "1px",
                        textTransform: "uppercase"
                      }}
                    >
                      {plan.tag}
                    </span>
                    {plan.highlight && (
                      <span className="text-xs font-bold text-[#00C8FF] font-mono">
                        POPULAR
                      </span>
                    )}
                  </div>

                  {/* Price */}
                  <p style={{ fontFamily: "var(--font-space-mono)", fontSize: 44, fontWeight: 800, color: "#0A0A0A", letterSpacing: "-2px", margin: 0, lineHeight: 1 }}>
                    {plan.price}
                  </p>
                  <p style={{ fontFamily: "var(--font-space-grotesk)", fontSize: 14, color: "#666660", marginTop: 8, marginBottom: 20 }}>
                    {plan.subtext}
                  </p>

                  <div style={{ height: 1.5, background: "rgba(10,10,10,0.08)", marginBottom: 20 }} />

                  {/* Features List */}
                  <ul style={{ listStyle: "none", padding: 0, margin: 0, display: "flex", flexDirection: "column", gap: 11 }}>
                    {features.map(f => (
                      <li key={f} style={{ display: "flex", alignItems: "center", gap: 10 }}>
                        <span style={{ width: 16, height: 16, minWidth: 16, borderRadius: "50%", background: "#00C8FF", display: "inline-flex", alignItems: "center", justifyContent: "center" }} aria-hidden>
                          <svg width="9" height="9" viewBox="0 0 8 8" fill="none"><path d="M1 4l2 2 4-4" stroke="#fff" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" /></svg>
                        </span>
                        <span style={{ fontFamily: "var(--font-space-grotesk)", fontSize: 13.5, color: "#111111", fontWeight: 500 }}>{f}</span>
                      </li>
                    ))}
                  </ul>
                </div>

                {/* CTA Button */}
                <button
                  onClick={() => setModal(plan.modal)}
                  style={{
                    display: "block",
                    width: "100%",
                    marginTop: 26,
                    background: "#0A0A0A",
                    color: "#FFFFFF",
                    border: "2px solid #0A0A0A",
                    borderRadius: 10,
                    padding: "14px 16px",
                    fontFamily: "var(--font-space-grotesk)",
                    fontWeight: 700,
                    fontSize: 14.5,
                    cursor: "pointer",
                    boxShadow: plan.highlight ? "4px 4px 0 #00C8FF" : "4px 4px 0 #888880",
                    transition: "all 150ms",
                    minHeight: 48,
                  }}
                  onMouseEnter={e => {
                    const b = e.currentTarget as HTMLButtonElement
                    b.style.transform = "translate(-2px,-2px)"
                    b.style.boxShadow = plan.highlight ? "6px 6px 0 #00C8FF" : "6px 6px 0 #333"
                  }}
                  onMouseLeave={e => {
                    const b = e.currentTarget as HTMLButtonElement
                    b.style.transform = "translate(0,0)"
                    b.style.boxShadow = plan.highlight ? "4px 4px 0 #00C8FF" : "4px 4px 0 #888880"
                  }}
                >
                  {plan.tag === "EARLY BIRD" ? "Reserve Early Bird →" : plan.tag === "GLOBAL" ? "Join Global Waitlist →" : "Pre-order Standard →"}
                </button>
              </motion.div>
            ))}
          </div>

          {/* Mobile Interactive Carousel Pagination Dots (Hidden on Desktop) */}
          <div className="flex md:hidden justify-center items-center gap-2 mt-6">
            {plans.map((_, i) => (
              <button
                key={i}
                onClick={() => scrollToIndex(i)}
                aria-label={`Go to slide ${i + 1}`}
                style={{
                  width: activeSlide === i ? 24 : 8,
                  height: 8,
                  borderRadius: 4,
                  background: activeSlide === i ? "#00C8FF" : "rgba(10,10,10,0.2)",
                  border: "none",
                  padding: 0,
                  cursor: "pointer",
                  transition: "all 250ms ease",
                }}
              />
            ))}
          </div>
        </div>
      </motion.section>
    </>
  )
}
