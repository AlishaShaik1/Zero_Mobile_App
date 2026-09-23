'use client'

import { useRef, useMemo } from 'react'
import { useFrame } from '@react-three/fiber'
import { Text } from '@react-three/drei'
import * as THREE from 'three'

interface ButterflySystemProps {
  phase: string
}

const BUTTERFLY_COUNT = 15

export function ButterflySystem({ phase }: ButterflySystemProps) {
  const groupRef = useRef<THREE.Group>(null)
  
  const butterflies = useMemo(() => {
    return Array.from({ length: BUTTERFLY_COUNT }).map(() => ({
      position: new THREE.Vector3(
        (Math.random() - 0.5) * 10,
        (Math.random() - 0.5) * 8,
        (Math.random() - 0.5) * 4
      ),
      velocity: new THREE.Vector3(),
      scale: 0.5 + Math.random() * 0.5,
      seed: Math.random() * 100,
    }))
  }, [])

  useFrame((state) => {
    if (!groupRef.current) return
    const time = state.clock.getElapsedTime()

    groupRef.current.children.forEach((b, i) => {
      const data = butterflies[i]
      
      const isResting = phase === 'initial' || phase === 'blooming' || phase === 'title' || phase === 'ready'
      
      // Flapping motion (scaling X to simulate wing flap for a 2D emoji)
      const flapSpeed = isResting ? 5 : 20
      const flapAmount = isResting ? 0.2 : 0.8
      b.scale.x = data.scale * (1 - Math.abs(Math.sin(time * flapSpeed + data.seed)) * flapAmount)

      // Hover / Fly logic
      if (!isResting && phase === 'transition') {
        // Fly away
        data.velocity.x += (Math.random() - 0.5) * 0.01
        data.velocity.y += (Math.random() - 0.5) * 0.01 + 0.01 // drift up fast
        data.velocity.z += (Math.random() - 0.5) * 0.01
        
        b.position.add(data.velocity)
        b.rotation.z = Math.sin(time * 5 + data.seed) * 0.2
      } else {
        // Resting subtle hover
        if (phase !== 'initial' && phase !== 'blooming') {
           b.position.y += Math.sin(time * 2 + data.seed) * 0.002
           b.position.x += Math.sin(time * 1.5 + data.seed) * 0.001
        }
      }
    })
  })

  return (
    <group ref={groupRef} visible={phase !== 'initial' && phase !== 'blooming'}>
      {butterflies.map((data, i) => (
        <group key={i} position={data.position}>
          <Text
            fontSize={1}
            anchorX="center"
            anchorY="middle"
            scale={[data.scale, data.scale, data.scale]}
          >
            🦋
          </Text>
        </group>
      ))}
    </group>
  )
}
