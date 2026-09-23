'use client'

import React from 'react'
import { motion } from 'framer-motion'

export default function MascotUmbrella() {
  // Ultra-clear, bold, prominent umbrella with rich dark grip handle clutched in left hand
  // Canopy centered at cx: 150, shaft connects directly into hand at (80, 122)
  return (
    <motion.g
      initial={{ scaleY: 0, opacity: 0 }}
      animate={{ scaleY: 1, opacity: 1 }}
      exit={{ scaleY: 0, opacity: 0 }}
      transition={{ duration: 0.4, ease: 'easeOut' }}
      style={{ transformOrigin: '80px 122px' }}
    >
      <defs>
        {/* Deep Vibrant Cyan Canopy Gradient */}
        <radialGradient id="canopyLustreGrad" cx="50%" cy="30%" r="70%">
          <stop offset="0%" stopColor="#38BDF8" />
          <stop offset="45%" stopColor="#0284C7" />
          <stop offset="85%" stopColor="#0369A1" />
          <stop offset="100%" stopColor="#082F49" />
        </radialGradient>

        {/* Polished Chrome Shaft Gradient */}
        <linearGradient id="chromeShaftGrad" x1="0" y1="0" x2="1" y2="0">
          <stop offset="0%" stopColor="#334155" />
          <stop offset="35%" stopColor="#CBD5E1" />
          <stop offset="60%" stopColor="#FFFFFF" />
          <stop offset="100%" stopColor="#1E293B" />
        </linearGradient>

        {/* Luxury Ebony Black Handle Gradient */}
        <linearGradient id="ebonyHandleGrad" x1="0" y1="0" x2="1" y2="0">
          <stop offset="0%" stopColor="#0F172A" />
          <stop offset="40%" stopColor="#334155" />
          <stop offset="70%" stopColor="#1E293B" />
          <stop offset="100%" stopColor="#020617" />
        </linearGradient>

        {/* Canopy Drop Shadow */}
        <filter id="umbrellaCanopyShadow" x="-30%" y="-20%" width="160%" height="160%">
          <feDropShadow dx="0" dy="8" stdDeviation="6" floodColor="#000000" floodOpacity="0.35" />
        </filter>

        {/* Handle Shadow */}
        <filter id="handleShadow" x="-30%" y="-20%" width="160%" height="160%">
          <feDropShadow dx="-1" dy="2" stdDeviation="2" floodColor="#000000" floodOpacity="0.3" />
        </filter>
      </defs>

      {/* ── BOLD METALLIC SHAFT / ROD ── */}
      {/* Shaft from hand (x: 80, y: 120) up into canopy center (x: 150, y: 70) */}
      <line
        x1="80"
        y1="120"
        x2="150"
        y2="70"
        stroke="#111111"
        strokeWidth="7"
        strokeLinecap="round"
      />
      <line
        x1="80"
        y1="120"
        x2="150"
        y2="70"
        stroke="url(#chromeShaftGrad)"
        strokeWidth="4.5"
        strokeLinecap="round"
      />

      {/* ── PROMINENT LUXURY J-HOOK HANDLE CLUTCHED IN HAND ── */}
      <g filter="url(#handleShadow)">
        {/* Handle Collar Ring (Gold Accent right above the hand) */}
        <ellipse cx="80" cy="118" rx="4" ry="2.5" fill="#F59E0B" stroke="#B45309" strokeWidth="1" />

        {/* J-Hook Handle Outer Outline */}
        <path
          d="M 80 118 V 140 C 80 152, 62 152, 62 138 V 132"
          stroke="#111111"
          strokeWidth="8"
          fill="none"
          strokeLinecap="round"
          strokeLinejoin="round"
        />

        {/* J-Hook Handle Ebony/Leather Core */}
        <path
          d="M 80 118 V 140 C 80 152, 62 152, 62 138 V 132"
          stroke="url(#ebonyHandleGrad)"
          strokeWidth="5"
          fill="none"
          strokeLinecap="round"
          strokeLinejoin="round"
        />

        {/* Handle Bottom Chrome End-Cap */}
        <circle cx="62" cy="132" r="3.2" fill="#E2E8F0" stroke="#0F172A" strokeWidth="1" />
      </g>

      {/* ── WIDE PROTECTIVE CANOPY OVER MASCOT HEAD (Span: x 60 to 240) ── */}
      {/* Canopy Dark Underside */}
      <path
        d="M 62 82 Q 150 70 238 82 Q 242 76 150 28 Q 58 76 62 82 Z"
        fill="#082F49"
      />

      {/* Canopy Outer Dome */}
      <path
        d="M 58 82 Q 100 95 150 84 Q 200 95 242 82 Q 238 28 150 28 Q 62 28 58 82 Z"
        fill="url(#canopyLustreGrad)"
        filter="url(#umbrellaCanopyShadow)"
      />

      {/* Structural Canopy Rib Highlights */}
      <path d="M 150 28 Q 105 55 68 82" stroke="#FFFFFF" strokeWidth="1.2" fill="none" opacity="0.35" />
      <path d="M 150 28 Q 128 56 112 84" stroke="#FFFFFF" strokeWidth="1.2" fill="none" opacity="0.4" />
      <path d="M 150 28 Q 150 58 150 84" stroke="#FFFFFF" strokeWidth="1.6" fill="none" opacity="0.6" />
      <path d="M 150 28 Q 172 56 188 84" stroke="#FFFFFF" strokeWidth="1.2" fill="none" opacity="0.4" />
      <path d="M 150 28 Q 195 55 232 82" stroke="#FFFFFF" strokeWidth="1.2" fill="none" opacity="0.35" />

      {/* Top Cap / Ferrule */}
      <circle cx="150" cy="28" r="4" fill="#1E293B" />
      <rect x="148.5" y="20" width="3" height="9" rx="1.5" fill="url(#chromeShaftGrad)" stroke="#111" strokeWidth="0.8" />

      {/* Bouncing Rain Splashes off Canopy */}
      <motion.circle
        cx="100"
        cy="72"
        r="1.8"
        fill="#E0F2FE"
        opacity={0.8}
        animate={{ y: [-4, -12], x: [-2, -6], opacity: [0.9, 0] }}
        transition={{ duration: 0.45, repeat: Infinity, ease: 'easeOut' }}
      />
      <motion.circle
        cx="200"
        cy="74"
        r="1.8"
        fill="#E0F2FE"
        opacity={0.8}
        animate={{ y: [-4, -12], x: [2, 6], opacity: [0.9, 0] }}
        transition={{ duration: 0.5, repeat: Infinity, ease: 'easeOut', delay: 0.2 }}
      />
      <motion.circle
        cx="150"
        cy="58"
        r="1.6"
        fill="#FFFFFF"
        opacity={0.7}
        animate={{ y: [-3, -10], opacity: [0.8, 0] }}
        transition={{ duration: 0.4, repeat: Infinity, ease: 'easeOut', delay: 0.1 }}
      />
    </motion.g>
  )
}
