"use client"

import { motion, AnimatePresence } from "framer-motion"
import { useEffect, useState, useRef } from "react"

interface PreorderModalProps {
  isOpen: boolean
  onClose: () => void
  plan?: "early" | "regular" | "global"
}

const PLANS = {
  early:   { label: "Early Bird",    price: "₹11,999", note: "First 100 orders only" },
  regular: { label: "Pre-order",     price: "₹14,999", note: "Ships Q3 2026" },
  global:  { label: "Global Launch", price: "$199",    note: "Kickstarter launch" },
}

// ─── WEB3FORMS SETUP (100% RELIABLE & FREE) ─────────────────────────────────
// FormSubmit servers are currently down (Error 521) and they block iframes.
// Let's use Web3Forms, the most reliable free service for React apps.
// 1. Go to https://web3forms.com/
// 2. Enter founderzero1@gmail.com and click "Create Access Key"
// 3. Check your email for the key and paste it below:
const WEB3FORMS_KEY = "4ebb526a-c65f-4b49-9bd7-fb1589ace1e1"
// ─────────────────────────────────────────────────────────────────────────────

export default function PreorderModal({ isOpen, onClose, plan = "early" }: PreorderModalProps) {
  const selected = PLANS[plan]
  const [status, setStatus] = useState<"idle" | "loading" | "success" | "error">("idle")
  const [form, setForm] = useState({ name: "", email: "", phone: "", size: "8" })
  const firstRef = useRef<HTMLInputElement>(null)

  useEffect(() => {
    if (!isOpen) { setStatus("idle"); return }
    document.body.style.overflow = "hidden"
    const onKey = (e: KeyboardEvent) => { if (e.key === "Escape") onClose() }
    window.addEventListener("keydown", onKey)
    setTimeout(() => firstRef.current?.focus(), 80)
    return () => { window.removeEventListener("keydown", onKey); document.body.style.overflow = "" }
  }, [isOpen, onClose])

  const set = (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement>) =>
    setForm(p => ({ ...p, [e.target.name]: e.target.value }))

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!form.name || !form.email) return
    setStatus("loading")

    try {
      const res = await fetch("https://api.web3forms.com/submit", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Accept: "application/json"
        },
        body: JSON.stringify({
          access_key: WEB3FORMS_KEY,
          subject: `🔔 Zero Ring Pre-order — ${selected.label} (${selected.price})`,
          from_name: "Zero Ring Website",
          "Customer Name": form.name,
          "Customer Email": form.email,
          "Phone Number": form.phone || "—",
          "Ring Size": form.size,
          "Selected Plan": selected.label,
          "Total Price": selected.price
        })
      })

      const json = await res.json()
      if (json.success) {
        setStatus("success")
      } else {
        setStatus("error")
      }
    } catch (err) {
      setStatus("error")
    }
  }

  const inputStyle: React.CSSProperties = {
    width: "100%",
    background: "#FFFFFF",
    border: "2px solid #0A0A0A",
    borderRadius: 8,
    padding: "11px 14px",
    color: "#0A0A0A",
    fontFamily: "var(--font-space-grotesk)",
    fontSize: 14,
    outline: "none",
    transition: "box-shadow 150ms",
  }

  return (
    <AnimatePresence>
      {isOpen && (
        <motion.div
          initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }}
          transition={{ duration: 0.18 }}
          onClick={onClose}
          role="dialog" aria-modal="true" aria-label="Pre-order Zero Ring"
          style={{ position: "fixed", inset: 0, zIndex: 9999, display: "flex", alignItems: "center", justifyContent: "center", padding: "16px", background: "rgba(10,10,10,0.6)", backdropFilter: "blur(6px)" }}
        >
          <motion.div
            initial={{ opacity: 0, scale: 0.94, y: 20 }}
            animate={{ opacity: 1, scale: 1, y: 0 }}
            exit={{ opacity: 0, scale: 0.94, y: 20 }}
            transition={{ duration: 0.24, ease: [0.16, 1, 0.3, 1] }}
            onClick={e => e.stopPropagation()}
            style={{
              background: "#F4F3EF",
              border: "2px solid #0A0A0A",
              borderRadius: 16,
              boxShadow: "8px 8px 0 #0A0A0A",
              width: "100%",
              maxWidth: 460,
              maxHeight: "92vh",
              overflowY: "auto",
            }}
          >
            {/* Header */}
            <div style={{ padding: "24px 24px 0", borderBottom: "2px solid #0A0A0A" }}>
              <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start", paddingBottom: 16 }}>
                <div>
                  <span style={{ display: "inline-block", fontFamily: "var(--font-space-mono)", fontSize: 10, fontWeight: 700, letterSpacing: "2px", color: "#0A0A0A", border: "1.5px solid #0A0A0A", borderRadius: 4, padding: "4px 10px", marginBottom: 10 }}>
                    ✦ PRE-ORDER
                  </span>
                  <h2 style={{ fontFamily: "var(--font-space-grotesk)", fontWeight: 800, fontSize: 22, color: "#0A0A0A", margin: "0 0 4px", letterSpacing: "-0.5px" }}>
                    Reserve your Zero Ring
                  </h2>
                  <p style={{ fontFamily: "var(--font-space-grotesk)", fontSize: 13, color: "#666660", margin: 0 }}>
                    {selected.note} ·{" "}
                    <span style={{ color: "#00C8FF", fontWeight: 700 }}>{selected.price}</span>
                  </p>
                </div>
                <button
                  onClick={onClose} aria-label="Close"
                  style={{ background: "transparent", border: "2px solid #0A0A0A", borderRadius: 6, width: 32, height: 32, display: "flex", alignItems: "center", justifyContent: "center", cursor: "pointer", color: "#0A0A0A", fontSize: 14, flexShrink: 0, marginLeft: 12, transition: "all 150ms" }}
                  onMouseEnter={e => { const b = e.currentTarget as HTMLButtonElement; b.style.background = "#0A0A0A"; b.style.color = "#F4F3EF" }}
                  onMouseLeave={e => { const b = e.currentTarget as HTMLButtonElement; b.style.background = "transparent"; b.style.color = "#0A0A0A" }}
                >✕</button>
              </div>
            </div>

            {/* Success state */}
            {status === "success" ? (
              <motion.div initial={{ opacity: 0, y: 8 }} animate={{ opacity: 1, y: 0 }}
                style={{ padding: "32px 24px", textAlign: "center" }}>
                <div style={{ width: 56, height: 56, borderRadius: "50%", background: "#00C8FF", border: "2px solid #0A0A0A", display: "flex", alignItems: "center", justifyContent: "center", margin: "0 auto 16px", fontSize: 22, color: "#0A0A0A", fontWeight: 700 }}>✓</div>
                <h3 style={{ fontFamily: "var(--font-space-grotesk)", fontWeight: 800, fontSize: 20, color: "#0A0A0A", margin: "0 0 8px" }}>You&apos;re in! 🎉</h3>
                <p style={{ fontFamily: "var(--font-space-grotesk)", fontSize: 13, color: "#666660", lineHeight: 1.65, margin: "0 0 20px" }}>
                  Confirmation sent to <strong style={{ color: "#0A0A0A" }}>{form.email}</strong>.<br />Your Zero Ring ships Q3 2026.
                </p>
                <button onClick={onClose}
                  style={{ background: "#0A0A0A", color: "#FFFFFF", border: "2px solid #0A0A0A", borderRadius: 8, padding: "11px 28px", fontFamily: "var(--font-space-grotesk)", fontWeight: 700, fontSize: 14, cursor: "pointer", boxShadow: "3px 3px 0 #00C8FF" }}>
                  Done
                </button>
              </motion.div>
            ) : (
              <form onSubmit={handleSubmit} style={{ padding: "20px 24px 24px" }}>
                <div style={{ display: "flex", flexDirection: "column", gap: 14 }}>
                  {/* Name */}
                  <div>
                    <label style={{ fontFamily: "var(--font-space-mono)", fontSize: 10, fontWeight: 700, color: "#666660", letterSpacing: "1.5px", display: "block", marginBottom: 6, textTransform: "uppercase" }}>Full Name *</label>
                    <input ref={firstRef} name="name" value={form.name} onChange={set} placeholder="Aryan Kapoor" required style={inputStyle}
                      onFocus={e => { e.currentTarget.style.boxShadow = "3px 3px 0 #00C8FF" }}
                      onBlur={e => { e.currentTarget.style.boxShadow = "none" }} />
                  </div>

                  {/* Email */}
                  <div>
                    <label style={{ fontFamily: "var(--font-space-mono)", fontSize: 10, fontWeight: 700, color: "#666660", letterSpacing: "1.5px", display: "block", marginBottom: 6, textTransform: "uppercase" }}>Email Address *</label>
                    <input name="email" type="email" value={form.email} onChange={set} placeholder="you@email.com" required style={inputStyle}
                      onFocus={e => { e.currentTarget.style.boxShadow = "3px 3px 0 #00C8FF" }}
                      onBlur={e => { e.currentTarget.style.boxShadow = "none" }} />
                  </div>

                  {/* Phone + Size row */}
                  <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 12 }}>
                    <div>
                      <label style={{ fontFamily: "var(--font-space-mono)", fontSize: 10, fontWeight: 700, color: "#666660", letterSpacing: "1.5px", display: "block", marginBottom: 6, textTransform: "uppercase" }}>Phone</label>
                      <input name="phone" type="tel" value={form.phone} onChange={set} placeholder="+91 98765..." style={inputStyle}
                        onFocus={e => { e.currentTarget.style.boxShadow = "3px 3px 0 #00C8FF" }}
                        onBlur={e => { e.currentTarget.style.boxShadow = "none" }} />
                    </div>
                    <div>
                      <label style={{ fontFamily: "var(--font-space-mono)", fontSize: 10, fontWeight: 700, color: "#666660", letterSpacing: "1.5px", display: "block", marginBottom: 6, textTransform: "uppercase" }}>Ring Size</label>
                      <select name="size" value={form.size} onChange={set} style={{ ...inputStyle, cursor: "pointer" }}>
                        {["6","7","8","9","10","11","12"].map(s => <option key={s} value={s}>Size {s}</option>)}
                      </select>
                    </div>
                  </div>

                  {/* Plan card */}
                  <div style={{ background: "#FFFFFF", border: "2px solid #0A0A0A", borderRadius: 10, padding: "12px 16px", display: "flex", justifyContent: "space-between", alignItems: "center", boxShadow: "3px 3px 0 #0A0A0A" }}>
                    <div>
                      <p style={{ fontFamily: "var(--font-space-mono)", fontSize: 10, fontWeight: 700, color: "#00C8FF", letterSpacing: "1.5px", margin: 0, textTransform: "uppercase" }}>Selected Plan</p>
                      <p style={{ fontFamily: "var(--font-space-grotesk)", fontWeight: 700, fontSize: 14, color: "#0A0A0A", margin: "3px 0 0" }}>{selected.label}</p>
                    </div>
                    <span style={{ fontFamily: "var(--font-space-mono)", fontWeight: 700, fontSize: 22, color: "#0A0A0A" }}>{selected.price}</span>
                  </div>

                  {/* Error State */}
                  {status === "error" && (
                    <p style={{ fontFamily: "var(--font-space-grotesk)", fontSize: 13, color: "#C0392B", background: "#FEF2F2", border: "2px solid #FECACA", borderRadius: 8, padding: "10px 14px", margin: 0 }}>
                      Something went wrong. Please check your access key or connection.
                    </p>
                  )}

                  {/* Submit */}
                  <button
                    type="submit" disabled={status === "loading"}
                    style={{ width: "100%", background: status === "loading" ? "#888" : "#0A0A0A", color: "#FFFFFF", border: "2px solid #0A0A0A", borderRadius: 10, padding: "14px 24px", fontFamily: "var(--font-space-grotesk)", fontWeight: 800, fontSize: 15, cursor: status === "loading" ? "not-allowed" : "pointer", boxShadow: status === "loading" ? "none" : "4px 4px 0 #00C8FF", transition: "all 150ms", minHeight: 50 }}
                    onMouseEnter={e => { if (status !== "loading") { const b = e.currentTarget as HTMLButtonElement; b.style.transform = "translate(-2px,-2px)"; b.style.boxShadow = "6px 6px 0 #00C8FF" } }}
                    onMouseLeave={e => { const b = e.currentTarget as HTMLButtonElement; b.style.transform = "translate(0,0)"; b.style.boxShadow = status === "loading" ? "none" : "4px 4px 0 #00C8FF" }}
                  >
                    {status === "loading" ? "Reserving your spot…" : `Reserve Now — ${selected.price} →`}
                  </button>

                  <p style={{ fontFamily: "var(--font-space-mono)", fontSize: 10, color: "#888882", textAlign: "center", letterSpacing: "0.5px", margin: 0 }}>
                    No payment now · Confirmation sent to your email · Cancel anytime
                  </p>
                </div>
              </form>
            )}
          </motion.div>
        </motion.div>
      )}
    </AnimatePresence>
  )
}
