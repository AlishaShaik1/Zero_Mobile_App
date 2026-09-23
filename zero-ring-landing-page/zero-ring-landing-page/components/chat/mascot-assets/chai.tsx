'use client'

import React from 'react'
import { motion } from 'framer-motion'

export default function MascotChai() {
  // Ultra-realistic Cutting Chai in traditional grooved cutting glass with brass saucer
  // Positioned directly in the mascot's right hand (translate 160, 116)
  return (
    <motion.g
      initial={{ opacity: 0, scale: 0.6, y: 10 }}
      animate={{ opacity: 1, scale: 1, y: 0 }}
      exit={{ opacity: 0, scale: 0.5 }}
      transition={{ duration: 0.45, type: 'spring', bounce: 0.3 }}
      transform="translate(160, 116)"
    >
      <defs>
        {/* Rich Masala Chai Tea Liquid */}
        <linearGradient id="masalaChaiGrad" x1="0" y1="0" x2="1" y2="0">
          <stop offset="0%" stopColor="#A0522D" />
          <stop offset="35%" stopColor="#C87A38" />
          <stop offset="70%" stopColor="#E29A56" />
          <stop offset="100%" stopColor="#873E12" />
        </linearGradient>

        {/* Chai Froth / Malai Top Cream */}
        <radialGradient id="chaiFrothGrad" cx="50%" cy="50%" r="50%">
          <stop offset="0%" stopColor="#FFF1E0" />
          <stop offset="60%" stopColor="#F5D0A9" />
          <stop offset="100%" stopColor="#D99B66" />
        </radialGradient>

        {/* Brass Traditional Saucer Gradient */}
        <radialGradient id="brassSaucerGrad" cx="50%" cy="50%" r="50%">
          <stop offset="0%" stopColor="#FDE68A" />
          <stop offset="50%" stopColor="#D97706" />
          <stop offset="90%" stopColor="#92400E" />
          <stop offset="100%" stopColor="#451A03" />
        </radialGradient>

        {/* Translucent Heavy Fluted Glass Body */}
        <linearGradient id="flutedGlassGrad" x1="0" y1="0" x2="1" y2="0">
          <stop offset="0%" stopColor="#FFFFFF" stopOpacity="0.5" />
          <stop offset="20%" stopColor="#E0F2FE" stopOpacity="0.15" />
          <stop offset="80%" stopColor="#BAE6FD" stopOpacity="0.1" />
          <stop offset="100%" stopColor="#FFFFFF" stopOpacity="0.45" />
        </linearGradient>

        <filter id="chaiSaucerShadow" x="-30%" y="-20%" width="160%" height="160%">
          <feDropShadow dx="0" dy="6" stdDeviation="4" floodColor="#000000" floodOpacity="0.25" />
        </filter>
      </defs>

      {/* Swirling Aromatic Steam */}
      <motion.path
        d="M 20 6 Q 14 -6 24 -16 T 18 -28"
        stroke="#FFFFFF"
        strokeWidth="2.2"
        fill="none"
        strokeLinecap="round"
        opacity={0.5}
        animate={{
          y: [-2, -12],
          opacity: [0, 0.65, 0],
          pathLength: [0, 1],
        }}
        transition={{ duration: 1.8, repeat: Infinity, ease: 'easeOut' }}
      />
      <motion.path
        d="M 32 10 Q 38 -2 28 -12 T 36 -24"
        stroke="#FFFFFF"
        strokeWidth="2"
        fill="none"
        strokeLinecap="round"
        opacity={0.4}
        animate={{
          y: [-2, -10],
          opacity: [0, 0.5, 0],
          pathLength: [0, 1],
        }}
        transition={{ duration: 1.5, repeat: Infinity, ease: 'easeOut', delay: 0.6 }}
      />

      {/* ── SAUCER ── */}
      <ellipse cx="25" cy="65" rx="27" ry="7" fill="#000" opacity="0.2" filter="blur(3px)" />
      <ellipse cx="25" cy="64" rx="26" ry="6.5" fill="url(#brassSaucerGrad)" filter="url(#chaiSaucerShadow)" />
      <ellipse cx="25" cy="63" rx="21" ry="4.5" fill="#B45309" />
      <ellipse cx="25" cy="62.5" rx="19" ry="3.5" fill="#F59E0B" opacity="0.7" />

      {/* ── CUTTING CHAI GLASS ── */}
      {/* Glass Back Interior */}
      <ellipse cx="25" cy="18" rx="19" ry="4.5" fill="#FFF8F0" opacity="0.6" />

      {/* Hot Spiced Tea Liquid */}
      <path d="M 8 23 C 8 50 12 59 25 59 C 38 59 42 50 42 23 Z" fill="url(#masalaChaiGrad)" />

      {/* Froth & Micro Cardamom Bubbles */}
      <ellipse cx="25" cy="23" rx="17" ry="4" fill="url(#chaiFrothGrad)" />
      <circle cx="21" cy="23" r="1.2" fill="#78350F" opacity="0.8" />
      <circle cx="27" cy="22" r="0.9" fill="#78350F" opacity="0.7" />
      <circle cx="31" cy="24" r="1" fill="#78350F" opacity="0.8" />
      <circle cx="17" cy="24" r="0.8" fill="#FFF" />

      {/* Translucent Glass Exterior with Cutting Glass Vertical Grooves */}
      <path d="M 6 18 C 6 52 11 62 25 62 C 39 62 44 52 44 18 Z" fill="url(#flutedGlassGrad)" />

      {/* Vertical Glass Cutting Facets / Grooves */}
      <line x1="12" y1="26" x2="15" y2="56" stroke="#FFFFFF" strokeWidth="1.2" strokeLinecap="round" opacity="0.6" />
      <line x1="18" y1="28" x2="20" y2="58" stroke="#FFFFFF" strokeWidth="1" strokeLinecap="round" opacity="0.4" />
      <line x1="32" y1="28" x2="30" y2="58" stroke="#FFFFFF" strokeWidth="1" strokeLinecap="round" opacity="0.4" />
      <line x1="38" y1="26" x2="35" y2="56" stroke="#FFFFFF" strokeWidth="1.2" strokeLinecap="round" opacity="0.6" />

      {/* Bright Primary Specular Reflection on Front Glass */}
      <path d="M 9 20 C 9 44 12 54 18 59" stroke="#FFFFFF" strokeWidth="2.2" fill="none" opacity="0.8" strokeLinecap="round" />

      {/* Top Glass Rim */}
      <ellipse cx="25" cy="18" rx="19" ry="4.5" fill="none" stroke="#FFFFFF" strokeWidth="1.8" opacity="0.9" />
    </motion.g>
  )
}
