'use client'

import { useRef, useMemo } from 'react'
import { useFrame } from '@react-three/fiber'
import { Text } from '@react-three/drei'
import * as THREE from 'three'

const PARTICLE_COUNT = 60
const EMOJIS = ['✨', '🌸', '🦋', '💖', '💫']

export function ParticleSystem() {
  const groupRef = useRef<THREE.Group>(null)

  const particles = useMemo(() => {
    return Array.from({ length: PARTICLE_COUNT }).map(() => {
      // Spawn in a wide circle
      const angle = Math.random() * Math.PI * 2
      const radius = Math.random() * 3
      
      const position = new THREE.Vector3(
        Math.cos(angle) * radius,
        Math.sin(angle) * radius,
        (Math.random() - 0.5) * 4
      )
      
      // Drift gently outward in all directions, no gravity
      const velocity = new THREE.Vector3(
        Math.cos(angle) * (Math.random() * 0.05 + 0.02),
        Math.sin(angle) * (Math.random() * 0.05 + 0.02),
        (Math.random() - 0.5) * 0.02
      )
      
      return {
        position,
        velocity,
        scale: Math.random() * 0.6 + 0.4,
        rotationSpeed: (Math.random() - 0.5) * 0.02,
        opacity: 1,
        fadeSpeed: Math.random() * 0.002 + 0.002, // Slower fade (takes ~3-4 seconds)
        emoji: EMOJIS[Math.floor(Math.random() * EMOJIS.length)]
      }
    })
  }, [])

  useFrame(() => {
    if (!groupRef.current) return
    
    groupRef.current.children.forEach((p, i) => {
      const data = particles[i]
      
      // Drift in different directions
      p.position.add(data.velocity)
      p.rotation.z += data.rotationSpeed
      
      // Slowly shrink and disappear
      if (data.scale > 0) {
        data.scale -= data.fadeSpeed
        if (data.scale < 0) data.scale = 0
      }
      
      // Apply scale (shrinking creates a beautiful disappearing effect)
      p.scale.setScalar(data.scale)
    })
  })

  return (
    <group ref={groupRef}>
      {particles.map((data, i) => (
        <group key={i} position={data.position}>
           <Text
             fontSize={1}
             anchorX="center"
             anchorY="middle"
             scale={[data.scale, data.scale, data.scale]}
             fillOpacity={1}
           >
             {data.emoji}
           </Text>
        </group>
      ))}
    </group>
  )
}
