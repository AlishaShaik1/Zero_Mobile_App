'use client'

import React from 'react'
import { motion } from 'framer-motion'

export default function MascotLaptop({ typingFrame = 0 }: { typingFrame?: 0 | 1 }) {
  // Ultra-realistic Desk Laptop with Active Keyboard Key-Pressing
  // Positioned cleanly on desk below eye line so both eyes & face are fully visible.
  // Keys visibly depress & glow when tapped by the mascot's hands!

  return (
    <motion.g
      initial={{ opacity: 0, scale: 0.85, y: 15 }}
      animate={{ opacity: 1, scale: 1, y: 0 }}
      exit={{ opacity: 0, scale: 0.85, y: 15 }}
      transition={{ duration: 0.45, type: 'spring', bounce: 0.25 }}
    >
      <defs>
        {/* Sleek Aluminum Unibody Top Deck */}
        <linearGradient id="laptopDeckGrad" x1="0" y1="0" x2="1" y2="1">
          <stop offset="0%" stopColor="#F8FAFC" />
          <stop offset="35%" stopColor="#E2E8F0" />
          <stop offset="80%" stopColor="#94A3B8" />
          <stop offset="100%" stopColor="#64748B" />
        </linearGradient>

        {/* Chassis Base Side Thickness */}
        <linearGradient id="chassisEdgeDarkGrad" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stopColor="#475569" />
          <stop offset="100%" stopColor="#0F172A" />
        </linearGradient>

        {/* Screen Bezel */}
        <linearGradient id="laptopBezelGrad" x1="0" y1="0" x2="1" y2="1">
          <stop offset="0%" stopColor="#1E293B" />
          <stop offset="100%" stopColor="#020617" />
        </linearGradient>

        {/* OLED Glass Screen Background */}
        <linearGradient id="laptopOledGrad" x1="0" y1="0" x2="1" y2="1">
          <stop offset="0%" stopColor="#020617" />
          <stop offset="50%" stopColor="#082F49" />
          <stop offset="100%" stopColor="#0C4A6E" />
        </linearGradient>

        {/* Cyber Screen Ambient Glow Filter */}
        <filter id="laptopScreenAmbientGlow" x="-50%" y="-50%" width="200%" height="200%">
          <feDropShadow dx="0" dy="-4" stdDeviation="10" floodColor="#22C8FF" floodOpacity="0.45" />
        </filter>

        {/* Idle Key Gradient */}
        <linearGradient id="idleKeyGrad" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stopColor="#334155" />
          <stop offset="100%" stopColor="#0F172A" />
        </linearGradient>

        {/* Pressed Key Cyan Glow */}
        <linearGradient id="pressedKeyGrad" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stopColor="#38BDF8" />
          <stop offset="100%" stopColor="#0284C7" />
        </linearGradient>
      </defs>

      {/* ── DESK SURFACE / PAD SHADOW ── */}
      <polygon
        points="95,198 205,186 235,214 110,224"
        fill="#000000"
        opacity="0.25"
        filter="blur(5px)"
      />

      {/* Floating Cyber Desk Pad under Laptop */}
      <polygon
        points="98,198 202,188 230,212 112,222"
        fill="#1E293B"
        stroke="#334155"
        strokeWidth="1"
        opacity="0.8"
      />

      {/* Ambient Upward Light Glow reflecting onto mascot face */}
      <ellipse
        cx="160"
        cy="150"
        rx="45"
        ry="20"
        fill="#22C8FF"
        opacity="0.12"
        filter="blur(12px)"
      />

      {/* ── SCREEN DISPLAY (ANGLED BELOW EYE-LINE: y 148 to 188) ── */}
      <g filter="url(#laptopScreenAmbientGlow)">
        {/* Screen Outer Aluminum Shell / Bezel */}
        <polygon
          points="114,186 196,177 188,144 106,153"
          fill="url(#laptopBezelGrad)"
          stroke="#475569"
          strokeWidth="1.2"
          strokeLinejoin="round"
        />

        {/* Active OLED Glass Screen */}
        <polygon
          points="116,183 193,175 186,147 109,155"
          fill="url(#laptopOledGrad)"
        />

        {/* Screen Code Lines & Terminal */}
        <g opacity="0.95">
          {/* Header Bar */}
          <line x1="111" y1="158" x2="184" y2="150" stroke="#22C8FF" strokeWidth="0.8" opacity="0.5" />

          {/* Glowing Code Lines */}
          <line x1="114" y1="163" x2="148" y2="159" stroke="#22C8FF" strokeWidth="1.4" strokeLinecap="round" />
          <line x1="115" y1="168" x2="175" y2="162" stroke="#38BDF8" strokeWidth="1.3" strokeLinecap="round" opacity="0.85" />
          <line x1="116" y1="173" x2="155" y2="169" stroke="#7DD3FC" strokeWidth="1.1" strokeLinecap="round" opacity="0.75" />
          <line x1="117" y1="178" x2="182" y2="171" stroke="#22C8FF" strokeWidth="1.3" strokeLinecap="round" opacity="0.9" />

          {/* Mini Waveform in corner */}
          <motion.path
            d="M 148 178 Q 158 172 165 176 T 178 173"
            fill="none"
            stroke="#22C8FF"
            strokeWidth="1.4"
            strokeLinecap="round"
            animate={{
              d: [
                'M 148 178 Q 158 172 165 176 T 178 173',
                'M 148 178 Q 158 180 165 173 T 178 173',
                'M 148 178 Q 158 172 165 176 T 178 173',
              ],
            }}
            transition={{ duration: 1, repeat: Infinity, ease: 'easeInOut' }}
          />

          {/* Minimal Zero Logo */}
          <circle cx="178" cy="151" r="2.2" fill="none" stroke="#22C8FF" strokeWidth="0.8" />
          <circle cx="178" cy="151" r="0.8" fill="#22C8FF" />
        </g>

        {/* Diagonal Screen Reflection */}
        <polygon
          points="109,155 138,152 130,181 116,183"
          fill="#FFFFFF"
          opacity="0.08"
        />
      </g>

      {/* Screen Hinge */}
      <polygon
        points="114,186 196,177 198,180 116,189"
        fill="#0F172A"
      />

      {/* ── KEYBOARD DECK (ISOMETRIC BASE IN FRONT) ── */}
      {/* Base Chassis Side Edge */}
      <polygon
        points="116,189 116,193 135,214 220,201 220,197 198,180"
        fill="url(#chassisEdgeDarkGrad)"
        stroke="#334155"
        strokeWidth="0.8"
      />

      {/* Base Top Surface (Keyboard Deck) */}
      <polygon
        points="116,189 198,180 220,197 135,214"
        fill="url(#laptopDeckGrad)"
        stroke="#E2E8F0"
        strokeWidth="0.8"
        strokeLinejoin="round"
      />

      {/* Chamfered Metallic Edge Light */}
      <line x1="135" y1="214" x2="220" y2="197" stroke="#FFFFFF" strokeWidth="1.2" strokeLinecap="round" opacity="0.9" />

      {/* Keyboard Inset */}
      <polygon
        points="122,190 194,182 210,195 136,206"
        fill="#0F172A"
        opacity="0.85"
      />

      {/* ── INDIVIDUAL MECHANICAL KEY ROWS WITH ACTIVE PRESS STATES ── */}
      {/* Row 1 */}
      <polygon points="124,191 192,183 194,185 126,193" fill="url(#idleKeyGrad)" />

      {/* Row 2 (With active key press under left hand) */}
      <polygon points="127,194 150,191 152,193 129,196" fill={typingFrame === 0 ? 'url(#pressedKeyGrad)' : 'url(#idleKeyGrad)'} />
      <polygon points="154,190 195,186 197,188 156,192" fill="url(#idleKeyGrad)" />

      {/* Row 3 (With active key press under right hand) */}
      <polygon points="130,197 165,193 167,195 132,199" fill="url(#idleKeyGrad)" />
      <polygon points="169,192 198,189 201,191 172,194" fill={typingFrame === 1 ? 'url(#pressedKeyGrad)' : 'url(#idleKeyGrad)'} />

      {/* Row 4 (Spacebar row) */}
      <polygon points="133,200 202,192 206,195 135,203" fill="url(#idleKeyGrad)" />

      {/* Trackpad */}
      <polygon
        points="152,204 176,201 180,208 156,211"
        fill="#94A3B8"
        stroke="#CBD5E1"
        strokeWidth="0.5"
        opacity="0.8"
      />

      {/* ── MASCOT TYPING HANDS (ACTIVELY PRESSING KEYS) ── */}
      {/* Left Hand Pressing Key */}
      <motion.g
        animate={{
          x: typingFrame === 0 ? 0 : 2,
          y: typingFrame === 0 ? 3 : 0,
        }}
        transition={{ duration: 0.1 }}
      >
        <ellipse cx="145" cy="195" rx="5.5" ry="3.8" fill="#FFFFFF" stroke="#222" strokeWidth="2.5" />
      </motion.g>

      {/* Right Hand Pressing Key */}
      <motion.g
        animate={{
          x: typingFrame === 1 ? 0 : -2,
          y: typingFrame === 1 ? 3 : 0,
        }}
        transition={{ duration: 0.1 }}
      >
        <ellipse cx="178" cy="191" rx="5.5" ry="3.8" fill="#FFFFFF" stroke="#222" strokeWidth="2.5" />
      </motion.g>
    </motion.g>
  )
}
