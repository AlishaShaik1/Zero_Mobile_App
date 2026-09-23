'use client'

import React from 'react'
import { motion } from 'framer-motion'

interface MascotNoodlesProps {
  isSlurping?: boolean
}

export default function MascotNoodles({ isSlurping = true }: MascotNoodlesProps) {
  // Ramen Bowl positioned right by the mascot's right hand (x: 165, y: 115)
  // Chopsticks lift noodles, and animated flowing strands curve smoothly into the mouth (x: 150, y: 145)
  return (
    <motion.g
      initial={{ opacity: 0, scale: 0.6, y: 10 }}
      animate={{ opacity: 1, scale: 1, y: 0 }}
      exit={{ opacity: 0, scale: 0.5 }}
      transition={{ duration: 0.45, type: 'spring', bounce: 0.3 }}
      transform="translate(165, 112)"
    >
      <defs>
        {/* Ceramic Ramen Bowl Glaze */}
        <radialGradient id="ramenBowlGrad" cx="50%" cy="80%" r="65%">
          <stop offset="0%" stopColor="#FFFFFF" />
          <stop offset="45%" stopColor="#E2E8F0" />
          <stop offset="85%" stopColor="#94A3B8" />
          <stop offset="100%" stopColor="#475569" />
        </radialGradient>

        {/* Rich Tonkotsu/Shoyu Ramen Broth */}
        <radialGradient id="ramenBrothGrad" cx="45%" cy="45%" r="60%">
          <stop offset="0%" stopColor="#F59E0B" />
          <stop offset="35%" stopColor="#D97706" />
          <stop offset="75%" stopColor="#B45309" />
          <stop offset="100%" stopColor="#78350F" />
        </radialGradient>

        {/* Bamboo Chopsticks */}
        <linearGradient id="chopstickGrad" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stopColor="#FDE68A" />
          <stop offset="40%" stopColor="#D97706" />
          <stop offset="100%" stopColor="#92400E" />
        </linearGradient>

        {/* Soft Boiled Egg Yolk */}
        <radialGradient id="eggYolkGrad" cx="40%" cy="40%" r="50%">
          <stop offset="0%" stopColor="#FEF08A" />
          <stop offset="40%" stopColor="#F59E0B" />
          <stop offset="100%" stopColor="#EA580C" />
        </radialGradient>

        {/* Bowl Drop Shadow */}
        <filter id="bowlDropShadow" x="-30%" y="-20%" width="160%" height="160%">
          <feDropShadow dx="0" dy="8" stdDeviation="5" floodColor="#000000" floodOpacity="0.3" />
        </filter>
      </defs>

      {/* Steaming Hot Broth Vapor */}
      <motion.path
        d="M 36 12 Q 30 2 40 -8 T 32 -20"
        stroke="#FFFFFF"
        strokeWidth="2.2"
        fill="none"
        strokeLinecap="round"
        opacity={0.5}
        animate={{
          y: [-2, -10],
          opacity: [0, 0.6, 0],
          pathLength: [0, 1],
        }}
        transition={{ duration: 1.6, repeat: Infinity, ease: 'easeOut' }}
      />

      {/* ── BOWL BASE & SHADOW ── */}
      <ellipse cx="40" cy="58" rx="22" ry="5" fill="#000" opacity="0.22" filter="blur(3px)" />

      {/* Ceramic Outer Bowl Body */}
      <path
        d="M 12 24 C 12 56 68 56 68 24 Z"
        fill="url(#ramenBowlGrad)"
        filter="url(#bowlDropShadow)"
      />

      {/* Traditional Crimson Red Rim Ring Pattern */}
      <path
        d="M 14 30 C 20 44 60 44 66 30"
        fill="none"
        stroke="#DC2626"
        strokeWidth="2.8"
        strokeLinecap="round"
        opacity={0.85}
      />

      {/* Broth Liquid Surface */}
      <ellipse cx="40" cy="24" rx="28" ry="8" fill="url(#ramenBrothGrad)" />

      {/* Glistening Broth Oil Droplets */}
      <ellipse cx="34" cy="22" rx="4" ry="1.5" fill="#FEF08A" opacity={0.6} />
      <ellipse cx="48" cy="26" rx="3.5" ry="1.2" fill="#FEF08A" opacity={0.5} />

      {/* Crisp Nori Sheet */}
      <path
        d="M 14 10 L 24 20 L 18 28 L 8 18 Z"
        fill="#14261C"
        stroke="#052E16"
        strokeWidth="0.8"
      />

      {/* Soft-Boiled Ramen Egg Half */}
      <g transform="translate(22, 18) rotate(-15)">
        <ellipse cx="6" cy="4" rx="6" ry="4.2" fill="#FFFFFF" />
        <ellipse cx="6" cy="4" rx="3.5" ry="2.6" fill="url(#eggYolkGrad)" />
        <circle cx="5" cy="3" r="0.8" fill="#FFFFFF" opacity={0.8} />
      </g>

      {/* Narutomaki Fish Cake with Pink Swirl */}
      <g transform="translate(48, 20) rotate(12)">
        <circle cx="5" cy="5" r="5" fill="#FFFFFF" stroke="#E2E8F0" strokeWidth="0.6" />
        <path
          d="M 5 2.5 C 6.5 2.5 7.5 3.8 7.5 5 C 7.5 6.2 6.2 7 5 7 C 3.8 7 3.5 5.8 3.8 5"
          fill="none"
          stroke="#EC4899"
          strokeWidth="1.2"
          strokeLinecap="round"
        />
      </g>

      {/* Chopped Green Chives */}
      <circle cx="42" cy="27" r="1.6" fill="#22C55E" />
      <circle cx="38" cy="29" r="1.4" fill="#16A34A" />
      <circle cx="46" cy="29" r="1.3" fill="#22C55E" />

      {/* Wavy Ramen Noodles in Bowl */}
      <path d="M 20 25 Q 28 18 38 25 T 56 24" fill="none" stroke="#FCD34D" strokeWidth="2.6" strokeLinecap="round" />
      <path d="M 24 23 Q 32 15 42 22 T 58 20" fill="none" stroke="#FBBF24" strokeWidth="2.2" strokeLinecap="round" />

      {/* ── CHOPSTICKS LIFTING NOODLES ── */}
      <g transform="translate(18, -12)">
        {/* Back Chopstick */}
        <rect
          x="28"
          y="-6"
          width="3.5"
          height="52"
          rx="1.5"
          fill="url(#chopstickGrad)"
          transform="rotate(25, 28, -6)"
          filter="drop-shadow(1px 2px 2px rgba(0,0,0,0.3))"
        />
        {/* Front Chopstick */}
        <rect
          x="35"
          y="-10"
          width="3.5"
          height="52"
          rx="1.5"
          fill="url(#chopstickGrad)"
          transform="rotate(20, 35, -10)"
          filter="drop-shadow(1px 2px 2px rgba(0,0,0,0.25))"
        />

        {/* Noodle cluster gripped by chopsticks */}
        <path d="M 20 18 Q 25 10 32 10 Q 38 10 42 18" fill="none" stroke="#FDE68A" strokeWidth="2.8" strokeLinecap="round" />
        <path d="M 22 20 Q 27 12 34 12 Q 40 12 44 20" fill="none" stroke="#F59E0B" strokeWidth="2.2" strokeLinecap="round" />
      </g>

      {/* ── ANIMATED FLOWING NOODLE STRANDS INTO MOUTH ── */}
      {/* From chopsticks (x: 42, y: 6) curving into mouth at (x: -15, y: 33) */}
      <g>
        {/* Main Flowing Strand 1 */}
        <motion.path
          d="M 42 6 C 24 4, 0 16, -15 33"
          fill="none"
          stroke="#FCD34D"
          strokeWidth="3.2"
          strokeLinecap="round"
          strokeDasharray="10 3"
          animate={
            isSlurping
              ? {
                  strokeDashoffset: [0, -26],
                  d: [
                    'M 42 6 C 24 4, 0 16, -15 33',
                    'M 42 6 C 26 2, -2 18, -15 33',
                    'M 42 6 C 24 4, 0 16, -15 33',
                  ],
                }
              : {}
          }
          transition={{ duration: 0.5, repeat: Infinity, ease: 'linear' }}
          filter="drop-shadow(1px 1px 1px rgba(0,0,0,0.25))"
        />

        {/* Secondary Flowing Strand 2 */}
        <motion.path
          d="M 44 10 C 26 8, 2 20, -13 36"
          fill="none"
          stroke="#FBBF24"
          strokeWidth="2.5"
          strokeLinecap="round"
          strokeDasharray="8 3"
          animate={
            isSlurping
              ? {
                  strokeDashoffset: [0, -22],
                }
              : {}
          }
          transition={{ duration: 0.45, repeat: Infinity, ease: 'linear' }}
        />

        {/* Golden Highlight Strand 3 */}
        <motion.path
          d="M 40 8 C 22 6, -2 18, -16 32"
          fill="none"
          stroke="#FEF08A"
          strokeWidth="1.8"
          strokeLinecap="round"
          strokeDasharray="6 2"
          animate={
            isSlurping
              ? {
                  strokeDashoffset: [0, -16],
                }
              : {}
          }
          transition={{ duration: 0.4, repeat: Infinity, ease: 'linear' }}
        />

        {/* Slurp Droplet micro-particles at mouth entry */}
        {isSlurping && (
          <motion.g>
            <motion.circle
              cx="-14"
              cy="31"
              r="1.4"
              fill="#F59E0B"
              animate={{
                y: [-2, -6, 2],
                x: [0, 3, 5],
                opacity: [1, 0.8, 0],
              }}
              transition={{ duration: 0.45, repeat: Infinity, ease: 'easeOut' }}
            />
            <motion.circle
              cx="-16"
              cy="35"
              r="1.1"
              fill="#FEF08A"
              animate={{
                y: [0, -4, 2],
                x: [0, -2, -4],
                opacity: [1, 0.7, 0],
              }}
              transition={{ duration: 0.4, repeat: Infinity, ease: 'easeOut', delay: 0.15 }}
            />
          </motion.g>
        )}
      </g>

      {/* Front Bowl Ceramic Lip */}
      <path
        d="M 12 24 C 12 32 68 32 68 24"
        fill="none"
        stroke="#F1F5F9"
        strokeWidth="2.2"
        strokeLinecap="round"
      />
    </motion.g>
  )
}
