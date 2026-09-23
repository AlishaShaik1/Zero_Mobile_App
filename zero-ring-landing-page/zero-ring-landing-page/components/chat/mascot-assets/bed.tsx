'use client'

import React from 'react'
import { motion } from 'framer-motion'

export default function MascotBed() {
  // Ultra-realistic 3D Luxury Bed (Base, Headboard, Mattress & Indented Pillow)
  // Mascot lies comfortably on top, layered beneath MascotBlanket!

  return (
    <motion.g
      initial={{ opacity: 0, y: 15 }}
      animate={{ opacity: 1, y: 0 }}
      exit={{ opacity: 0 }}
      transition={{ duration: 0.8, ease: 'easeOut' }}
    >
      <defs>
        {/* Rich Walnut Wood Headboard */}
        <linearGradient id="headboardGrad" x1="0" y1="0" x2="1" y2="0">
          <stop offset="0%" stopColor="#2A1B14" />
          <stop offset="30%" stopColor="#452A1E" />
          <stop offset="70%" stopColor="#5C3828" />
          <stop offset="100%" stopColor="#2A1B14" />
        </linearGradient>

        {/* Headboard Wood Slat Accent */}
        <linearGradient id="woodSlatGrad" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stopColor="#6D4330" />
          <stop offset="100%" stopColor="#3B2216" />
        </linearGradient>

        {/* Deep Plush Mattress Gradient */}
        <linearGradient id="mattressPlushGrad" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stopColor="#FFFFFF" />
          <stop offset="40%" stopColor="#F1F5F9" />
          <stop offset="85%" stopColor="#CBD5E1" />
          <stop offset="100%" stopColor="#94A3B8" />
        </linearGradient>

        {/* Soft Foam Pillow Gradient */}
        <radialGradient id="pillowSoftGrad" cx="50%" cy="40%" r="60%">
          <stop offset="0%" stopColor="#FFFFFF" />
          <stop offset="60%" stopColor="#F8FAFC" />
          <stop offset="90%" stopColor="#E2E8F0" />
          <stop offset="100%" stopColor="#CBD5E1" />
        </radialGradient>

        {/* Soft Shadow Filter */}
        <filter id="bedDepthShadow" x="-30%" y="-20%" width="160%" height="160%">
          <feDropShadow dx="0" dy="8" stdDeviation="6" floodColor="#000000" floodOpacity="0.4" />
        </filter>
      </defs>

      {/* Floor Contact Shadow */}
      <ellipse cx="140" cy="248" rx="115" ry="12" fill="#000000" opacity="0.3" filter="blur(6px)" />

      {/* ── HEADBOARD (BEHIND MASCOT HEAD) ── */}
      {/* Headboard Main Panel */}
      <rect
        x="18"
        y="85"
        width="22"
        height="155"
        rx="8"
        fill="url(#headboardGrad)"
        filter="url(#bedDepthShadow)"
      />
      {/* Decorative vertical bevel slots */}
      <rect x="23" y="95" width="4" height="120" rx="2" fill="url(#woodSlatGrad)" />
      <rect x="31" y="95" width="3" height="120" rx="1.5" fill="url(#woodSlatGrad)" />

      {/* Warm Ambient Nightlight Glow behind Headboard */}
      <circle cx="28" cy="115" r="28" fill="#FEF08A" opacity="0.08" filter="blur(10px)" />

      {/* Bed Base Wooden Side Rails */}
      <rect x="25" y="222" width="225" height="20" rx="5" fill="#3B2216" />
      {/* Wooden Legs */}
      <rect x="35" y="240" width="12" height="14" rx="3" fill="#2A1B14" />
      <rect x="235" y="240" width="12" height="14" rx="3" fill="#2A1B14" />

      {/* ── PLUSH MATTRESS ── */}
      <rect
        x="28"
        y="196"
        width="224"
        height="28"
        rx="9"
        fill="url(#mattressPlushGrad)"
        filter="url(#bedDepthShadow)"
      />
      {/* Mattress Top Piping Seam */}
      <line x1="32" y1="198" x2="248" y2="198" stroke="#FFFFFF" strokeWidth="2.5" strokeLinecap="round" opacity="0.9" />
      <line x1="32" y1="222" x2="248" y2="222" stroke="#94A3B8" strokeWidth="1.5" strokeLinecap="round" opacity="0.6" />

      {/* ── INDENTED SOFT PILLOW ── */}
      {/* Pillow Back & Cushion with curved depression where mascot head rests */}
      <path
        d="M 38 182 C 38 164, 55 160, 75 165 C 95 170, 115 162, 122 178 L 124 198 L 38 198 Z"
        fill="url(#pillowSoftGrad)"
        filter="url(#bedDepthShadow)"
      />
      {/* Soft indent shadow line for head sink */}
      <path
        d="M 60 174 Q 85 180 110 174"
        stroke="#CBD5E1"
        strokeWidth="2.5"
        fill="none"
        strokeLinecap="round"
        opacity="0.8"
      />
      {/* Pillow White Fabric Sheen */}
      <path
        d="M 44 176 Q 60 166 85 169"
        stroke="#FFFFFF"
        strokeWidth="2"
        fill="none"
        strokeLinecap="round"
        opacity="0.9"
      />
    </motion.g>
  )
}

export function MascotBlanket() {
  // Ultra-realistic Stitched Quilted Duvet / Blanket (Front Layer Over Mascot)
  return (
    <motion.g
      initial={{ opacity: 0, y: 15 }}
      animate={{ opacity: 1, y: 0 }}
      exit={{ opacity: 0 }}
      transition={{ duration: 0.9, delay: 0.15, ease: 'easeOut' }}
    >
      <defs>
        {/* Luxury Midnight Navy Quilt Gradient */}
        <linearGradient id="duvetNavyGrad" x1="0" y1="0" x2="1" y2="1">
          <stop offset="0%" stopColor="#1E293B" />
          <stop offset="35%" stopColor="#0F172A" />
          <stop offset="85%" stopColor="#020617" />
          <stop offset="100%" stopColor="#0B132B" />
        </linearGradient>

        {/* Folded Top Hem Accent Gradient */}
        <linearGradient id="hemSilverGrad" x1="0" y1="0" x2="1" y2="0">
          <stop offset="0%" stopColor="#64748B" />
          <stop offset="40%" stopColor="#94A3B8" />
          <stop offset="70%" stopColor="#CBD5E1" />
          <stop offset="100%" stopColor="#64748B" />
        </linearGradient>

        {/* Deep Blanket Shadow */}
        <filter id="duvetShadow" x="-30%" y="-20%" width="160%" height="160%">
          <feDropShadow dx="0" dy="10" stdDeviation="8" floodColor="#000000" floodOpacity="0.5" />
        </filter>
      </defs>

      {/* Main Quilted Duvet Body covering mascot's torso & legs */}
      <path
        d="M 86 172 C 92 154, 125 148, 155 160 C 185 172, 222 158, 246 175 L 250 226 L 82 226 Z"
        fill="url(#duvetNavyGrad)"
        filter="url(#duvetShadow)"
      />

      {/* Diagonal Diamond Quilt Stitching Lines */}
      <g stroke="#334155" strokeWidth="1.2" strokeDasharray="3 2" opacity="0.6" fill="none">
        <line x1="105" y1="170" x2="145" y2="225" />
        <line x1="135" y1="165" x2="185" y2="225" />
        <line x1="165" y1="168" x2="220" y2="225" />
        <line x1="195" y1="172" x2="245" y2="225" />

        <line x1="145" y1="168" x2="95" y2="225" />
        <line x1="180" y1="166" x2="130" y2="225" />
        <line x1="215" y1="168" x2="165" y2="225" />
        <line x1="245" y1="176" x2="200" y2="225" />
      </g>

      {/* Plush Fabric Drape Ripple Highlights */}
      <path
        d="M 84 172 C 92 154, 125 148, 155 160 C 185 172, 222 158, 246 175"
        stroke="url(#hemSilverGrad)"
        strokeWidth="6.5"
        fill="none"
        strokeLinecap="round"
      />
      {/* Fine Satin Top Hemline */}
      <path
        d="M 86 174 C 95 158, 126 152, 155 163 C 185 174, 220 162, 244 177"
        stroke="#E2E8F0"
        strokeWidth="1.8"
        fill="none"
        strokeLinecap="round"
        opacity="0.95"
      />

      {/* Cozy Starlight Rim Reflection on Duvet */}
      <path
        d="M 120 156 Q 160 168 210 164"
        stroke="#38BDF8"
        strokeWidth="1.2"
        fill="none"
        strokeLinecap="round"
        opacity="0.4"
      />
    </motion.g>
  )
}
