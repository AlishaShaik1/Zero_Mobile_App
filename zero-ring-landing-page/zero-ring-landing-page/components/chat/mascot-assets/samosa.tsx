'use client'

import React, { useEffect, useState } from 'react'
import { motion, AnimatePresence } from 'framer-motion'

interface MascotSamosaProps {
  biteStage?: number // 0 = whole, 1 = first bite, 2 = half eaten, 3 = last chunk, 4 = finished
}

export default function MascotSamosa({ biteStage }: MascotSamosaProps) {
  const [internalBites, setInternalBites] = useState(0)
  const bites = biteStage !== undefined ? biteStage : internalBites

  useEffect(() => {
    if (biteStage !== undefined) return
    const t1 = setTimeout(() => setInternalBites(1), 1000)
    const t2 = setTimeout(() => setInternalBites(2), 2000)
    const t3 = setTimeout(() => setInternalBites(3), 3000)
    const t4 = setTimeout(() => setInternalBites(4), 4000)
    return () => {
      clearTimeout(t1)
      clearTimeout(t2)
      clearTimeout(t3)
      clearTimeout(t4)
    }
  }, [biteStage])

  // Falling crumbs state whenever bite increments
  const [crumbKey, setCrumbKey] = useState(0)
  useEffect(() => {
    if (bites > 0) {
      setCrumbKey(k => k + 1)
    }
  }, [bites])

  return (
    <g transform="translate(152, 108)">
      <motion.g
        initial={{ opacity: 0, scale: 0.3, rotate: -20 }}
        animate={{
          opacity: bites >= 4 ? 0 : 1,
          scale: Math.max(0, 1.28 - bites * 0.22),
          rotate: 0,
        }}
        transition={{ duration: 0.45, type: 'spring', bounce: 0.3 }}
        style={{ transformOrigin: '40px 45px' }}
      >
        <defs>
          {/* Crispy Golden Fried Samosa Crust Gradient */}
          <radialGradient id="samosaGoldGrad" cx="45%" cy="40%" r="65%" fx="35%" fy="30%">
            <stop offset="0%" stopColor="#FED786" />
            <stop offset="25%" stopColor="#F5B041" />
            <stop offset="65%" stopColor="#D67417" />
            <stop offset="90%" stopColor="#9C3D04" />
            <stop offset="100%" stopColor="#6E2802" />
          </radialGradient>

          {/* Steamy Spiced Potato & Masala Stuffing */}
          <radialGradient id="alooMasalaGrad" cx="50%" cy="50%" r="55%">
            <stop offset="0%" stopColor="#FFE082" />
            <stop offset="40%" stopColor="#E5A93C" />
            <stop offset="80%" stopColor="#B36B15" />
            <stop offset="100%" stopColor="#78350F" />
          </radialGradient>

          {/* Crispy Bottom Edge / Seam */}
          <linearGradient id="crispSeamGrad" x1="0" y1="0" x2="1" y2="0">
            <stop offset="0%" stopColor="#5E2300" />
            <stop offset="30%" stopColor="#B45309" />
            <stop offset="70%" stopColor="#F59E0B" />
            <stop offset="100%" stopColor="#5E2300" />
          </linearGradient>

          {/* Drop Shadow */}
          <filter id="samosaDropShadow" x="-30%" y="-20%" width="160%" height="160%">
            <feDropShadow dx="-2" dy="8" stdDeviation="6" floodColor="#000000" floodOpacity="0.35" />
          </filter>

          {/* Multi-tier Bite Masks */}
          <clipPath id="samosaBiteClip1">
            <path d="M -15 26 Q 8 16 24 28 Q 42 12 60 26 Q 78 18 95 32 L 95 110 L -15 110 Z" />
          </clipPath>
          <clipPath id="samosaBiteClip2">
            <path d="M -15 48 Q 12 36 28 50 Q 48 34 68 48 Q 85 40 95 56 L 95 110 L -15 110 Z" />
          </clipPath>
          <clipPath id="samosaBiteClip3">
            <path d="M -15 68 Q 15 58 35 70 Q 55 56 75 68 Q 88 62 95 76 L 95 110 L -15 110 Z" />
          </clipPath>
        </defs>

        {/* Rising Piping Hot Steam Wisps */}
        <AnimatePresence>
          {bites < 3 && (
            <motion.g
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
            >
              <motion.path
                d="M 38 -4 Q 30 -16 42 -28 T 32 -44"
                stroke="#FFFFFF"
                strokeWidth="2.5"
                fill="none"
                strokeLinecap="round"
                opacity={0.6}
                animate={{
                  y: [-2, -12],
                  opacity: [0, 0.7, 0],
                  pathLength: [0, 1],
                }}
                transition={{ duration: 1.6, repeat: Infinity, ease: 'easeOut' }}
              />
              <motion.path
                d="M 48 2 Q 56 -10 44 -22 T 54 -36"
                stroke="#FFFFFF"
                strokeWidth="2"
                fill="none"
                strokeLinecap="round"
                opacity={0.5}
                animate={{
                  y: [-2, -10],
                  opacity: [0, 0.5, 0],
                  pathLength: [0, 1],
                }}
                transition={{ duration: 1.3, repeat: Infinity, ease: 'easeOut', delay: 0.4 }}
              />
            </motion.g>
          )}
        </AnimatePresence>

        {/* Falling Crispy Flake & Crumb Particles on Bite */}
        {bites > 0 && bites < 4 && (
          <motion.g key={`crumbs-${crumbKey}`}>
            {[
              { id: 1, x: 22, y: bites * 18, vx: -14, vy: 28, r: 1.8 },
              { id: 2, x: 38, y: bites * 18 - 4, vx: -3, vy: 34, r: 2.4 },
              { id: 3, x: 52, y: bites * 18 + 2, vx: 16, vy: 30, r: 2.0 },
              { id: 4, x: 30, y: bites * 18 + 6, vx: -9, vy: 24, r: 1.5 },
              { id: 5, x: 62, y: bites * 18 - 2, vx: 20, vy: 36, r: 1.8 },
            ].map(c => (
              <motion.circle
                key={c.id}
                cx={c.x}
                cy={c.y}
                r={c.r}
                fill="#F59E0B"
                stroke="#92400E"
                strokeWidth="0.6"
                initial={{ opacity: 1, scale: 1, x: 0, y: 0 }}
                animate={{
                  opacity: [1, 0.8, 0],
                  x: c.vx,
                  y: c.vy,
                  scale: [1, 0.8, 0.3],
                }}
                transition={{ duration: 0.7, ease: 'easeIn' }}
              />
            ))}
          </motion.g>
        )}

        <motion.g animate={{ y: bites > 0 ? 4 : 0 }}>
          {/* Visible Spiced Aloo/Pea Interior when Bitten */}
          {bites > 0 && (
            <g>
              <path
                d="M 12 20 L 68 20 L 72 72 L 8 72 Z"
                fill="url(#alooMasalaGrad)"
              />
              {/* Vibrant Green Tender Peas */}
              <circle cx="28" cy="38" r="3.6" fill="#65A30D" stroke="#365314" strokeWidth="0.8" />
              <circle cx="27" cy="37" r="1.2" fill="#BEF264" />
              <circle cx="50" cy="34" r="3.8" fill="#4D7C0F" stroke="#1A2E05" strokeWidth="0.8" />
              <circle cx="49" cy="33" r="1.2" fill="#A3E635" />
              <circle cx="44" cy="54" r="4" fill="#65A30D" stroke="#365314" strokeWidth="0.8" />
              <circle cx="43" cy="53" r="1.3" fill="#BEF264" />
              <circle cx="62" cy="62" r="3" fill="#4D7C0F" />
              <circle cx="22" cy="52" r="2.8" fill="#65A30D" />

              {/* Potato chunk textures */}
              <rect x="34" y="42" width="7" height="6" rx="2" fill="#FDE047" opacity="0.9" />
              <rect x="52" y="48" width="8" height="7" rx="2.5" fill="#FACC15" opacity="0.85" />
              <circle cx="38" cy="32" r="1" fill="#14532D" />
              <circle cx="48" cy="44" r="1.2" fill="#14532D" />
              <circle cx="32" cy="58" r="1" fill="#14532D" />
              <circle cx="58" cy="38" r="1.3" fill="#713F12" />
            </g>
          )}

          {/* Main Samosa Pastry Shell (Clipped by bite progress) */}
          <g
            clipPath={
              bites === 1
                ? 'url(#samosaBiteClip1)'
                : bites === 2
                ? 'url(#samosaBiteClip2)'
                : bites === 3
                ? 'url(#samosaBiteClip3)'
                : 'none'
            }
          >
            {/* Pyramid 3D Triangular Body */}
            <path
              d="M 40 4 C 46 4 52 14 58 24 C 68 44 78 62 72 72 C 66 82 14 82 8 72 C 2 62 12 44 22 24 C 28 14 34 4 40 4 Z"
              fill="url(#samosaGoldGrad)"
              filter="url(#samosaDropShadow)"
            />

            {/* Crispy Fried Blisters / Micro-bubbles */}
            <circle cx="32" cy="24" r="2.4" fill="#FEF08A" opacity="0.6" />
            <circle cx="48" cy="20" r="2" fill="#FEF08A" opacity="0.7" />
            <circle cx="22" cy="42" r="2.8" fill="#FEF08A" opacity="0.5" />
            <circle cx="58" cy="44" r="3.2" fill="#FEF08A" opacity="0.65" />
            <circle cx="38" cy="52" r="3" fill="#FEF08A" opacity="0.55" />
            <circle cx="50" cy="62" r="2.4" fill="#FEF08A" opacity="0.6" />

            {/* Roasted Cumin / Ajwain Seeds */}
            <ellipse cx="36" cy="34" rx="2" ry="0.9" fill="#3D1A04" transform="rotate(30, 36, 34)" />
            <ellipse cx="26" cy="54" rx="2.2" ry="1" fill="#3D1A04" transform="rotate(-25, 26, 54)" />
            <ellipse cx="52" cy="46" rx="2.4" ry="1.1" fill="#3D1A04" transform="rotate(45, 52, 46)" />
            <ellipse cx="44" cy="66" rx="2" ry="0.9" fill="#3D1A04" transform="rotate(-15, 44, 66)" />
            <ellipse cx="18" cy="64" rx="1.8" ry="0.8" fill="#3D1A04" transform="rotate(10, 18, 64)" />

            {/* Flaky Center Seam Fold */}
            <path
              d="M 40 5 Q 47 28 49 68"
              stroke="#78350F"
              strokeWidth="4"
              fill="none"
              strokeLinecap="round"
              opacity="0.85"
            />
            <path
              d="M 38 6 Q 44 28 46 68"
              stroke="#FDE68A"
              strokeWidth="2"
              fill="none"
              strokeLinecap="round"
              opacity="0.75"
            />

            {/* Hand-Crimped Bottom Crust Rim */}
            <path
              d="M 10 72 Q 40 86 70 72"
              stroke="url(#crispSeamGrad)"
              strokeWidth="8"
              fill="none"
              strokeLinecap="round"
            />
            {/* Crimping ridges */}
            <path
              d="M 16 75 L 18 79 M 26 77 L 28 82 M 36 78 L 38 83 M 46 78 L 48 83 M 56 77 L 58 82 M 64 75 L 66 79"
              stroke="#451A03"
              strokeWidth="2.2"
              strokeLinecap="round"
            />
          </g>
        </motion.g>
      </motion.g>
    </g>
  )
}
