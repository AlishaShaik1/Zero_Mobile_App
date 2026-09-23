"use client"

import { motion, useScroll, useTransform } from "framer-motion"
import { useState } from "react"
import ZeroLogo from "./ZeroLogo"
import PreorderModal from "./PreorderModal"
import { Menu } from "lucide-react"
import { PageNav } from "@/components/chat/nav/PageNav"

export default function Nav() {
  const [open, setOpen] = useState(false)
  const [menuOpen, setMenuOpen] = useState(false)
  const { scrollY } = useScroll()
  const borderOpacity = useTransform(scrollY, [0, 40], [0.3, 1])

  return (
    <>
      <PreorderModal isOpen={open} onClose={() => setOpen(false)} plan="early" />

      <motion.nav
        style={{
          position: "sticky", top: 0, zIndex: 100, height: 72,
          background: "rgba(244,243,239,0.95)",
          backdropFilter: "blur(16px)",
          WebkitBackdropFilter: "blur(16px)",
          borderBottom: "2px solid #0A0A0A",
        }}
      >
        <div
          style={{ height: "100%", maxWidth: 1100, margin: "0 auto", display: "flex", alignItems: "center", justifyContent: "space-between", padding: "0 20px", width: "100%" }}
          className="md:px-6"
        >
          {/* Logo */}
          <a href="/" aria-label="Zero Ring home" style={{ display: "flex", alignItems: "center", textDecoration: "none" }}>
            <ZeroLogo size={0.28} color="#0A0A0A" />
          </a>

          {/* Desktop links */}
          <nav aria-label="Main navigation" className="hidden md:flex" style={{ gap: 28, alignItems: "center" }}>
            {[["Features", "/#features"], ["Specs", "/#specs"], ["Pricing", "/#pricing"]].map(([label, href]) => (
              <a
                key={label} href={href}
                style={{ fontFamily: "var(--font-space-grotesk)", fontSize: 13, fontWeight: 600, color: "#555550", textDecoration: "none", transition: "color 150ms" }}
                onMouseEnter={e => { (e.currentTarget as HTMLAnchorElement).style.color = "#0A0A0A" }}
                onMouseLeave={e => { (e.currentTarget as HTMLAnchorElement).style.color = "#555550" }}
              >{label}</a>
            ))}
          </nav>

          <div style={{ display: "flex", alignItems: "center", gap: 16 }}>
            {/* CTA */}
            <button
              id="nav-preorder-btn"
              onClick={() => setOpen(true)}
              style={{ background: "#0A0A0A", color: "#FFFFFF", border: "2px solid #0A0A0A", borderRadius: 7, padding: "8px 16px", fontFamily: "var(--font-space-grotesk)", fontWeight: 700, fontSize: 13, cursor: "pointer", boxShadow: "3px 3px 0 #00C8FF", transition: "all 150ms", whiteSpace: "nowrap" }}
              onMouseEnter={e => { const b = e.currentTarget as HTMLButtonElement; b.style.transform = "translate(-1px,-1px)"; b.style.boxShadow = "4px 4px 0 #00C8FF" }}
              onMouseLeave={e => { const b = e.currentTarget as HTMLButtonElement; b.style.transform = "translate(0,0)"; b.style.boxShadow = "3px 3px 0 #00C8FF" }}
            >
              Pre-order ₹14,999
            </button>
            
            {/* Hamburger Button */}
            <button
              onClick={() => setMenuOpen(true)}
              style={{ background: "transparent", border: "none", cursor: "pointer", color: "#0A0A0A", padding: 4 }}
              aria-label="Open Menu"
            >
              <Menu size={28} strokeWidth={2.5} />
            </button>
          </div>
        </div>
      </motion.nav>

      {/* Sleek Side Drawer with 4 Sections */}
      <PageNav open={menuOpen} onClose={() => setMenuOpen(false)} />
    </>
  )
}
