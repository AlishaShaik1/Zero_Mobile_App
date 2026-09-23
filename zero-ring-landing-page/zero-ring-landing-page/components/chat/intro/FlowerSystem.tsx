'use client'

import { useRef, useMemo } from 'react'
import { useFrame } from '@react-three/fiber'
import { Html } from '@react-three/drei'
import * as THREE from 'three'

interface FlowerSystemProps {
  phase: string
}

const FLOWER_COUNT = 6

const FLOWER_IMAGES = [
  'https://images.unsplash.com/photo-1490750967868-88cb44cb2753?w=200&h=200&fit=crop',
  'https://images.unsplash.com/photo-1468327768560-75b778cbb551?w=200&h=200&fit=crop',
  'https://images.unsplash.com/photo-1517849845537-4d257902454a?w=200&h=200&fit=crop',
  'https://images.unsplash.com/photo-1508610048659-a06b669e3321?w=200&h=200&fit=crop',
  'https://images.unsplash.com/photo-1507608616759-54f48f0af0ee?w=200&h=200&fit=crop',
  'https://images.unsplash.com/photo-1508821966282-38e21820b411?w=200&h=200&fit=crop',
]

export function FlowerSystem({ phase }: FlowerSystemProps) {
  const groupRef = useRef<THREE.Group>(null)
  
  const flowers = useMemo(() => {
    return Array.from({ length: FLOWER_COUNT }).map((_, i) => ({
      position: new THREE.Vector3(
        (Math.random() - 0.5) * 8,
        (Math.random() - 0.5) * 6,
        (Math.random() - 0.5) * 3 - 2
      ),
      scale: 0,
      targetScale: 0.8 + Math.random() * 0.5,
      seed: Math.random() * 10,
      image: FLOWER_IMAGES[i % FLOWER_IMAGES.length],
    }))
  }, [])

  useFrame((state) => {
    if (!groupRef.current) return
    const time = state.clock.getElapsedTime()
    
    groupRef.current.children.forEach((f, i) => {
      const data = flowers[i]
      
      // Blooming logic
      if (phase === 'initial') {
        data.scale = 0
      } else if (phase === 'blooming' || phase === 'butterflies' || phase === 'title' || phase === 'ready') {
        // Slow ease in
        data.scale += (data.targetScale - data.scale) * 0.02
        f.position.y += Math.sin(time + data.seed) * 0.001
      } else if (phase === 'transition') {
        // Shrink away
        data.scale += (0 - data.scale) * 0.1
      }

      f.scale.setScalar(data.scale)
    })
  })

  return (
    <group ref={groupRef}>
      {flowers.map((data, i) => (
        <group key={i} position={data.position}>
          <Html transform center>
            <div 
              style={{
                width: '100px',
                height: '100px',
                borderRadius: '50%',
                overflow: 'hidden',
                boxShadow: '0 10px 30px rgba(0,0,0,0.1)',
                border: '4px solid white'
              }}
            >
              <img 
                src={data.image} 
                alt="flower" 
                style={{ width: '100%', height: '100%', objectFit: 'cover' }}
                draggable={false}
              />
            </div>
          </Html>
        </group>
      ))}
    </group>
  )
}
