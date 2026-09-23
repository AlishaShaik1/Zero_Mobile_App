'use client'

import React, { useEffect, useState } from 'react'
import { motion } from 'framer-motion'

interface MascotMilkProps {
  stage?: number // 0 = full, 1 = half, 2 = low, 3 = empty/mustache
}

export default function MascotMilk({ stage }: MascotMilkProps) {
  const [internalStage, setInternalStage] = useState(0)
  const currentStage = stage !== undefined ? stage : internalStage

  useEffect(() => {
    if (stage !== undefined) return
    const t1 = setTimeout(() => setInternalStage(1), 1000)
    const t2 = setTimeout(() => setInternalStage(2), 2200)
    const t3 = setTimeout(() => setInternalStage(3), 3200)
    return () => {
      clearTimeout(t1)
      clearTimeout(t2)
      clearTimeout(t3)
    }
  }, [stage])

  // Milk height inside the jar/bottle: 0=full, 1=half, 2=low, 3=empty
  const milkHeight = currentStage === 0 ? 36 : currentStage === 1 ? 22 : currentStage === 2 ? 10 : 3
  const milkY = currentStage === 0 ? 20 : currentStage === 1 ? 34 : currentStage === 2 ? 46 : 53

  return (
    <motion.g
      initial={{ opacity: 0, scale: 0.6, y: 10 }}
      animate={{ opacity: 1, scale: 1, y: 0 }}
      exit={{ opacity: 0, scale: 0.5 }}
      transition={{ duration: 0.45, type: 'spring', bounce: 0.3 }}
      transform="translate(158, 114)"
    >
      <defs>
        {/* Rich Creamy White Milk Gradient */}
        <linearGradient id="jarMilkGrad" x1="0" y1="0" x2="1" y2="0">
          <stop offset="0%" stopColor="#FFFFFF" />
          <stop offset="35%" stopColor="#F8FAFC" />
          <stop offset="80%" stopColor="#E2E8F0" />
          <stop offset="100%" stopColor="#CBD5E1" />
        </linearGradient>

        {/* Milk Top Cream Meniscus */}
        <radialGradient id="jarMilkSurface" cx="50%" cy="50%" r="50%">
          <stop offset="0%" stopColor="#FFFFFF" />
          <stop offset="70%" stopColor="#F1F5F9" />
          <stop offset="100%" stopColor="#E2E8F0" />
        </radialGradient>

        {/* Heavy Crystal Glass Refraction */}
        <linearGradient id="jarGlassWall" x1="0" y1="0" x2="1" y2="0">
          <stop offset="0%" stopColor="#FFFFFF" stopOpacity="0.6" />
          <stop offset="15%" stopColor="#E0F2FE" stopOpacity="0.2" />
          <stop offset="85%" stopColor="#BAE6FD" stopOpacity="0.1" />
          <stop offset="100%" stopColor="#FFFFFF" stopOpacity="0.65" />
        </linearGradient>

        {/* Thick Glass Base */}
        <linearGradient id="jarBaseGrad" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stopColor="#BAE6FD" stopOpacity="0.3" />
          <stop offset="100%" stopColor="#38BDF8" stopOpacity="0.7" />
        </linearGradient>

        {/* Shadow */}
        <filter id="milkJarShadow" x="-30%" y="-20%" width="160%" height="160%">
          <feDropShadow dx="0" dy="6" stdDeviation="4" floodColor="#000000" floodOpacity="0.28" />
        </filter>

        {/* Jar Interior Clip Path (Vintage Milk Bottle Profile) */}
        <clipPath id="jarInnerClip">
          <path d="M 17 14 L 17 22 C 17 26 12 28 12 34 L 12 52 C 12 56 36 56 36 52 L 36 34 C 36 28 31 26 31 22 L 31 14 Z" />
        </clipPath>
      </defs>

      {/* Ground Contact Shadow */}
      <ellipse cx="24" cy="59" rx="15" ry="4" fill="#000" opacity="0.22" filter="blur(3px)" />

      {/* Thick Glass Bottle Base */}
      <path d="M 12 50 L 12 54 C 12 58 36 58 36 54 L 36 50 Z" fill="url(#jarBaseGrad)" />

      {/* Glass Back Interior */}
      <ellipse cx="24" cy="14" rx="7.5" ry="2.5" fill="#F0F9FF" opacity="0.8" />

      {/* ── MILK LIQUID INSIDE BOTTLE (CLIPPED) ── */}
      <g clipPath="url(#jarInnerClip)">
        <motion.rect
          x="10"
          y={milkY}
          width="28"
          height={milkHeight + 10}
          fill="url(#jarMilkGrad)"
          animate={{ y: milkY, height: milkHeight + 10 }}
          transition={{ duration: 0.5, ease: 'easeInOut' }}
        />

        {/* Milk Meniscus / Surface */}
        <motion.ellipse
          cx="24"
          cy={milkY}
          rx={milkY < 26 ? 7 : 11}
          ry={2.5}
          fill="url(#jarMilkSurface)"
          stroke="#E2E8F0"
          strokeWidth="0.8"
          animate={{ cy: milkY, rx: milkY < 26 ? 7 : 11 }}
          transition={{ duration: 0.5, ease: 'easeInOut' }}
        />

        {/* Micro-cream bubbles on surface */}
        <motion.g animate={{ cy: milkY }}>
          <circle cx="20" cy={milkY - 0.5} r="1" fill="#FFF" />
          <circle cx="27" cy={milkY + 0.5} r="1.2" fill="#FFF" />
        </motion.g>
      </g>

      {/* ── CLEAR CRYSTAL GLASS BOTTLE BODY & NECK ── */}
      <path
        d="M 16 12 L 16 22 C 16 26 10 28 10 34 L 10 52 C 10 57 38 57 38 52 L 38 34 C 38 28 32 26 32 22 L 32 12 Z"
        fill="url(#jarGlassWall)"
        filter="url(#milkJarShadow)"
        stroke="#FFFFFF"
        strokeWidth="1.2"
        strokeLinejoin="round"
      />

      {/* Vintage Embossed Ring / Neck Flange on Milk Bottle */}
      <ellipse cx="24" cy="18" rx="8.5" ry="2.2" fill="none" stroke="#FFFFFF" strokeWidth="1.2" opacity="0.85" />

      {/* Specular Glare Highlights on Left Flank */}
      <path
        d="M 12 34 L 12 50"
        stroke="#FFFFFF"
        strokeWidth="2.4"
        strokeLinecap="round"
        opacity="0.9"
      />
      <path
        d="M 14.5 32 L 14.5 48"
        stroke="#FFFFFF"
        strokeWidth="1.2"
        strokeLinecap="round"
        opacity="0.5"
      />

      {/* Right Edge Reflection */}
      <path
        d="M 36 34 L 36 50"
        stroke="#FFFFFF"
        strokeWidth="1.4"
        strokeLinecap="round"
        opacity="0.6"
      />

      {/* Bottle Mouth Lip / Rolled Rim */}
      <ellipse
        cx="24"
        cy="12"
        rx="8"
        ry="2.8"
        fill="none"
        stroke="#FFFFFF"
        strokeWidth="2"
        opacity="0.95"
      />

      {/* Condensation Cold Water Droplets on Jar Exterior */}
      <circle cx="13" cy="38" r="1.1" fill="#FFFFFF" opacity="0.9" />
      <circle cx="13" cy="46" r="1.3" fill="#FFFFFF" opacity="0.95" />
      <circle cx="35" cy="42" r="1" fill="#FFFFFF" opacity="0.8" />
      <circle cx="34" cy="49" r="1.2" fill="#FFFFFF" opacity="0.85" />
    </motion.g>
  )
}
