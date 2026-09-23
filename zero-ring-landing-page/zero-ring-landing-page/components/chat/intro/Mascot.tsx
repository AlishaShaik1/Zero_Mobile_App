'use client'

import { motion, useAnimation } from 'framer-motion'
import { useEffect, useRef, useState } from 'react'

type TimeOfDay = 'morning' | 'afternoon' | 'evening' | 'night'
type Weather = 'rain' | 'sunny' | 'normal'

function getTimeOfDay(): TimeOfDay {
  const h = new Date().getHours()
  if (h >= 5  && h < 12) return 'morning'
  if (h >= 12 && h < 17) return 'afternoon'
  if (h >= 17 && h < 21) return 'evening'
  return 'night'
}

async function detectWeather(): Promise<Weather> {
  try {
    const pos = await new Promise<GeolocationPosition>((res, rej) =>
      navigator.geolocation.getCurrentPosition(res, rej, { timeout: 5000 })
    )
    const { latitude: lat, longitude: lon } = pos.coords
    const url = `https://api.open-meteo.com/v1/forecast?latitude=${lat}&longitude=${lon}&current_weather=true&hourly=cloudcover&forecast_days=1`
    const resp = await fetch(url)
    const data = await resp.json()
    const code: number = data.current_weather?.weathercode ?? 0
    const cloudcover: number = data.hourly?.cloudcover?.[new Date().getHours()] ?? 100
    if (code >= 51) return 'rain'
    if (code < 3 && cloudcover < 35) return 'sunny'
    return 'normal'
  } catch {
    return 'normal'
  }
}

const RAIN_DROPS = Array.from({ length: 14 }, (_, i) => ({
  id: i,
  x: 30 + i * 17,
  delay: (i * 0.13) % 1.1,
}))

const ZZZ_ITEMS = ['z', 'z', 'Z']

export function Mascot({ size = 140 }: { size?: number }) {
  const bodyControls      = useAnimation()
  const blinkControls     = useAnimation()
  const leftArmCtrl       = useAnimation()
  const leftArmPathCtrl   = useAnimation()
  const leftFistCtrl      = useAnimation()
  const rightArmCtrl      = useAnimation()
  const mouthCtrl     = useAnimation()
  const eyeCtrl       = useAnimation()

  const [timeOfDay, setTimeOfDay]       = useState<TimeOfDay>('morning')
  const [weather, setWeather]           = useState<Weather>('normal')
  const [showMouth, setShowMouth]       = useState(false)
  const [showUmbrella, setShowUmbrella] = useState(false)
  const [showSun, setShowSun]           = useState(false)
  const [showSamosa, setShowSamosa]     = useState(false)
  const [showTeaCup, setShowTeaCup]     = useState(false)
  const [zzzKey, setZzzKey]             = useState(0)
  const [showZzz, setShowZzz]           = useState(false)
  const [rainActive, setRainActive]     = useState(false)
  const [umbrellaUp, setUmbrellaUp]     = useState(false)

  const OL = 16
  const FL = 6

  useEffect(() => {
    setTimeOfDay(getTimeOfDay())
    detectWeather().then(w => setWeather(w))
  }, [])

  // Gentle body float
  useEffect(() => {
    const dur = timeOfDay === 'night' ? 3.5 : 2.2
    bodyControls.start({
      y: [0, -6, 0],
      transition: { duration: dur, repeat: Infinity, ease: 'easeInOut' },
    })
  }, [bodyControls, timeOfDay])

  // Blink
  useEffect(() => {
    let active = true
    const blink = async () => {
      while (active) {
        await new Promise(r => setTimeout(r, 2600 + Math.random() * 1800))
        if (!active) break
        await blinkControls.start({ scaleY: 0.06, transition: { duration: 0.07 } })
        await blinkControls.start({ scaleY: 1,    transition: { duration: 0.09 } })
      }
    }
    blink()
    return () => { active = false }
  }, [blinkControls])

  // ── Morning: Yawn ──
  useEffect(() => {
    if (timeOfDay !== 'morning' || weather === 'rain') return
    let active = true
    const yawn = async () => {
      try {
        while (active) {
          await new Promise(r => setTimeout(r, 7000 + Math.random() * 4000))
          if (!active) break
          await eyeCtrl.start({ scaleY: 0.3, transition: { duration: 0.4 } })
          setShowMouth(true)
          await mouthCtrl.start({ scaleY: 1, opacity: 1, transition: { duration: 0.5, ease: 'easeOut' } })
          await leftArmCtrl.start({ rotate: -75, x: 32, y: -28, transition: { duration: 0.5, ease: 'easeOut' } })
          await new Promise(r => setTimeout(r, 1200))
          await leftArmCtrl.start({ rotate: 0, x: 0, y: 0, transition: { duration: 0.4 } })
          await mouthCtrl.start({ scaleY: 0, opacity: 0, transition: { duration: 0.35 } })
          setShowMouth(false)
          await eyeCtrl.start({ scaleY: 1, transition: { duration: 0.2 } })
        }
      } catch (e) {}
    }
    yawn()
    return () => { active = false }
  }, [timeOfDay, weather, leftArmCtrl, mouthCtrl, eyeCtrl])

  // ── Afternoon: Stomach rub ──
  useEffect(() => {
    if (timeOfDay !== 'afternoon' || weather === 'rain') return
    let active = true
    const rub = async () => {
      try {
        while (active) {
          await new Promise(r => setTimeout(r, 5000 + Math.random() * 3000))
          if (!active) break
          for (let i = 0; i < 3; i++) {
            await rightArmCtrl.start({ x: -18, y: -14, rotate: -20, transition: { duration: 0.35, ease: 'easeInOut' } })
            await rightArmCtrl.start({ x: -8,  y: -22, rotate:   0, transition: { duration: 0.35, ease: 'easeInOut' } })
            await rightArmCtrl.start({ x:  6,  y: -12, rotate:  15, transition: { duration: 0.35, ease: 'easeInOut' } })
            await rightArmCtrl.start({ x:  0,  y:   0, rotate:   0, transition: { duration: 0.3  } })
          }
        }
      } catch (e) {}
    }
    rub()
    return () => { active = false }
  }, [timeOfDay, weather, rightArmCtrl])

  // ── Evening: Eat samosa + drink tea ──
  useEffect(() => {
    if (timeOfDay !== 'evening' || weather === 'rain') return
    let active = true
    let cycle = 0
    const eat = async () => {
      try {
        while (active) {
          await new Promise(r => setTimeout(r, 5000 + Math.random() * 2000))
          if (!active) break
          const isSamosa = cycle % 2 === 0
          cycle++
          if (isSamosa) {
            setShowSamosa(true)
            await new Promise(r => setTimeout(r, 400))
            await rightArmCtrl.start({ x: -40, y: -50, rotate: -35, transition: { duration: 0.6, ease: 'easeOut' } })
            await new Promise(r => setTimeout(r, 600))
            setShowSamosa(false)
            await rightArmCtrl.start({ x: 0, y: 0, rotate: 0, transition: { duration: 0.5 } })
          } else {
            setShowTeaCup(true)
            await new Promise(r => setTimeout(r, 400))
            await rightArmCtrl.start({ x: -45, y: -55, rotate: -40, transition: { duration: 0.6, ease: 'easeOut' } })
            await new Promise(r => setTimeout(r, 800))
            setShowTeaCup(false)
            await rightArmCtrl.start({ x: 0, y: 0, rotate: 0, transition: { duration: 0.5 } })
          }
        }
      } catch (e) {}
    }
    eat()
    return () => { active = false }
  }, [timeOfDay, weather, rightArmCtrl])

  // ── Night: Sleepy + Zzz ──
  useEffect(() => {
    if (timeOfDay !== 'night' || weather === 'rain') return
    let active = true
    eyeCtrl.start({ scaleY: 0.5, transition: { duration: 0.8 } })
    const sleep = async () => {
      try {
        while (active) {
          await new Promise(r => setTimeout(r, 4000 + Math.random() * 3000))
          if (!active) break
          setShowZzz(true)
          setZzzKey(k => k + 1)
          await new Promise(r => setTimeout(r, 2500))
          setShowZzz(false)
        }
      } catch (e) {}
    }
    sleep()
    return () => { active = false }
  }, [timeOfDay, weather, eyeCtrl])

  // ── Rain sequence ──
  useEffect(() => {
    if (weather !== 'rain') {
      setShowUmbrella(false)
      setRainActive(false)
      setUmbrellaUp(false)
      leftArmCtrl.start({ rotate: 0, x: 0, y: 0 })
      leftArmPathCtrl.start({ d: "M 80 84 C 68 80, 54 72, 40 60", transition: { duration: 0.3 } })
      leftFistCtrl.start({ cx: 40, cy: 56, transition: { duration: 0.3 } })
      return
    }
    let active = true
    const rainSeq = async () => {
      try {
        setUmbrellaUp(false)
        setShowUmbrella(false)
        setRainActive(true)
        await new Promise(r => setTimeout(r, 1500))
        if (!active) return
        await eyeCtrl.start({ y: -8, transition: { duration: 0.4 } })
        await new Promise(r => setTimeout(r, 800))
        await eyeCtrl.start({ y: 0, transition: { duration: 0.3 } })
        if (!active) return
        await Promise.all([
          leftArmPathCtrl.start({ d: "M 80 84 C 80 110, 65 110, 50 110", transition: { duration: 0.7, ease: 'easeOut' } }),
          leftFistCtrl.start({ cx: 50, cy: 110, transition: { duration: 0.7, ease: 'easeOut' } })
        ])
        if (!active) return
        setShowUmbrella(true)
        setUmbrellaUp(true)
      } catch (e) {}
    }
    rainSeq()
    return () => { active = false }
  }, [weather, eyeCtrl, leftArmCtrl, leftArmPathCtrl, leftFistCtrl])

  // ── Sunny sequence ──
  useEffect(() => {
    if (weather !== 'sunny') {
      setShowSun(false)
      leftArmCtrl.start({ rotate: 0, x: 0, y: 0 })
      return
    }
    let active = true
    const sunnySeq = async () => {
      try {
        setShowSun(true)
        await new Promise(r => setTimeout(r, 1000))
        while (active) {
          await new Promise(r => setTimeout(r, 3000 + Math.random() * 2000))
          if (!active) break
          await leftArmCtrl.start({ rotate: -55, x: 28, y: -35, transition: { duration: 0.5, ease: 'easeOut' } })
          await new Promise(r => setTimeout(r, 1500))
          await leftArmCtrl.start({ rotate: 0, x: 0, y: 0, transition: { duration: 0.4 } })
        }
      } catch (e) {}
    }
    sunnySeq()
    return () => { active = false }
  }, [weather, leftArmCtrl])

  return (
    <>
      <motion.div animate={bodyControls} style={{ display: 'inline-block', lineHeight: 0 }}>
        <svg
          width={size}
          height={Math.round(size * 1.18)}
          viewBox="0 0 280 280"
          fill="none"
          xmlns="http://www.w3.org/2000/svg"
        >
          {/* ══ SUN ══ */}
          {showSun && (
            <motion.g
              initial={{ scale: 0, opacity: 0 }}
              animate={{ scale: 1, opacity: 1 }}
              transition={{ duration: 0.8, type: 'spring', bounce: 0.4 }}
              style={{ transformOrigin: '38px 15px' } as React.CSSProperties}
            >
              <motion.circle cx="38" cy="15" r="16" fill="#FFD700" opacity="0.9"
                animate={{ scale: [1, 1.08, 1] }}
                transition={{ duration: 2, repeat: Infinity, ease: 'easeInOut' }}
              />
              {[0,45,90,135,180,225,270,315].map((deg, i) => {
                const rad = (deg * Math.PI) / 180
                return (
                  <motion.line key={i}
                    x1={38 + Math.cos(rad) * 20} y1={15 + Math.sin(rad) * 20}
                    x2={38 + Math.cos(rad) * 28} y2={15 + Math.sin(rad) * 28}
                    stroke="#FFD700" strokeWidth="3" strokeLinecap="round"
                    animate={{ opacity: [0.6, 1, 0.6] }}
                    transition={{ duration: 1.5, repeat: Infinity, delay: i * 0.18 }}
                  />
                )
              })}
            </motion.g>
          )}

          {/* ══ RAIN DROPS ══ */}
          {weather === 'rain' && rainActive && RAIN_DROPS.map(drop => {
            const blocked = umbrellaUp && drop.x > 10 && drop.x < 200
            return (
              <motion.line
                key={drop.id}
                x1={drop.x} y1={-20}
                x2={drop.x} y2={-4}
                stroke="#22C8FF" strokeWidth="2" strokeLinecap="round" opacity="0.75"
                animate={blocked ? {
                  y: [0, 65, 50, 35, 20],
                  opacity: [0.8, 0.7, 0.4, 0.1, 0],
                } : {
                  y: [0, 270],
                  opacity: [0.85, 0.1],
                }}
                transition={{
                  duration: blocked ? 0.7 : 0.95,
                  repeat: Infinity,
                  delay: drop.delay,
                  ease: blocked ? 'easeOut' : 'linear',
                }}
              />
            )
          })}

          {/* ══ SHADOW ══ */}
          <ellipse cx="149" cy="230" rx="58" ry="5.5" fill="rgba(0,0,0,0.12)" />

          {/* ════ LEGS ════ */}
          <rect x="106" y="176" width="22" height="28" fill="#FFF" stroke="#111" strokeWidth="7" strokeLinejoin="miter" />
          <rect x="98"  y="197" width="32" height="16" fill="#FFF" stroke="#111" strokeWidth="7" strokeLinejoin="miter" />
          <rect x="162" y="176" width="22" height="28" fill="#FFF" stroke="#111" strokeWidth="7" strokeLinejoin="miter" />
          <rect x="160" y="197" width="32" height="16" fill="#FFF" stroke="#111" strokeWidth="7" strokeLinejoin="miter" />

          {/* ════ RIGHT ARM — curved arm + round fist ════ */}
          <motion.g
            animate={rightArmCtrl}
            style={{ transformBox: 'view-box', transformOrigin: '218px 126px' } as React.CSSProperties}
          >
            {showSamosa && (
              <motion.polygon
                points="256,130 272,152 240,152"
                fill="#FF9933" stroke="#111" strokeWidth="3"
                initial={{ scale: 0, opacity: 0 }}
                animate={{ scale: 1, opacity: 1 }}
                style={{ transformOrigin: '256px 144px' } as React.CSSProperties}
              />
            )}
            {showTeaCup && (
              <motion.g
                initial={{ scale: 0, opacity: 0 }}
                animate={{ scale: 1, opacity: 1 }}
                style={{ transformOrigin: '258px 134px' } as React.CSSProperties}
              >
                <rect x="244" y="124" width="22" height="18" rx="3" fill="#FDEBD0" stroke="#111" strokeWidth="2.5" />
                <path d="M 266 128 Q 274 133 266 138" fill="none" stroke="#111" strokeWidth="2.5" strokeLinecap="round" />
                <motion.path d="M 252 122 Q 254 116 252 110" fill="none" stroke="#aaa" strokeWidth="1.5" strokeLinecap="round"
                  animate={{ opacity: [0, 1, 0], y: [-3, -6, -3] }}
                  transition={{ duration: 1.2, repeat: Infinity }}
                />
              </motion.g>
            )}
            {/* Upper arm: shoulder(218,122) → curves out to fist center(258,148) */}
            {/* Black outline */}
            <path d="M 218 126 C 230 130, 248 138, 258 148"
              fill="none" stroke="#111111" strokeWidth={OL} strokeLinecap="round" />
            {/* White inner */}
            <path d="M 218 126 C 230 130, 248 138, 258 148"
              fill="none" stroke="#FFFFFF" strokeWidth={FL} strokeLinecap="round" />
            {/* Round fist — filled circle */}
            <circle cx="258" cy="150" r="13" fill="#FFFFFF" stroke="#111111" strokeWidth="7" />
          </motion.g>

          {/* ════ BODY ════ */}
          <path
            d="M 96 52 L 202 52 L 218 68 L 218 162 L 202 178 L 96 178 L 80 162 L 80 68 Z"
            fill="#FFFFFF" stroke="#111111" strokeWidth="7" strokeLinejoin="miter"
          />

          {/* ════ MOUTH (yawn) ════ */}
          {showMouth && (
            <motion.ellipse
              cx="149" cy="158" rx="16" ry="10"
              fill="#111111"
              initial={{ scaleY: 0, opacity: 0 }}
              animate={mouthCtrl}
              style={{ transformOrigin: '149px 158px' } as React.CSSProperties}
            />
          )}

          {/* ════ EYES ════ */}
          <motion.g animate={blinkControls} style={{ transformOrigin: '149px 115px' } as React.CSSProperties}>
            <motion.g animate={eyeCtrl} style={{ transformOrigin: '149px 115px' } as React.CSSProperties}>
              <rect x="116" y="103" width="26" height="24" rx="1" fill="#00C8FF" />
              <rect x="156" y="103" width="26" height="24" rx="1" fill="#00C8FF" />
              <rect x="126" y="112" width="7" height="7" rx="0" fill="white" opacity="0.85" />
              <rect x="166" y="112" width="7" height="7" rx="0" fill="white" opacity="0.85" />
              {/* Night droopy eyelid overlay */}
              {timeOfDay === 'night' && (
                <>
                  <motion.rect x="116" y="103" width="26" height="12" rx="1" fill="#111111" opacity="0.5"
                    animate={{ height: [10, 14, 10] }}
                    transition={{ duration: 3, repeat: Infinity, ease: 'easeInOut' }}
                  />
                  <motion.rect x="156" y="103" width="26" height="12" rx="1" fill="#111111" opacity="0.5"
                    animate={{ height: [10, 14, 10] }}
                    transition={{ duration: 3, repeat: Infinity, ease: 'easeInOut', delay: 0.2 }}
                  />
                </>
              )}
            </motion.g>
          </motion.g>

          {/* ════ LEFT ARM ════ */}
          <motion.g
            animate={leftArmCtrl}
            style={{ transformBox: 'view-box', transformOrigin: '80px 84px' } as React.CSSProperties}
          >
            <motion.path
              animate={leftArmPathCtrl}
              d="M 80 84 C 68 80, 54 72, 40 60"
              fill="none" stroke="#111111" strokeWidth={OL} strokeLinecap="round"
            />
            <motion.path
              animate={leftArmPathCtrl}
              d="M 80 84 C 68 80, 54 72, 40 60"
              fill="none" stroke="#FFFFFF" strokeWidth={FL} strokeLinecap="round"
            />
            <motion.circle
              animate={leftFistCtrl}
              cx="40" cy="56" r="13"
              fill="#FFFFFF" stroke="#111111" strokeWidth="7"
            />
          </motion.g>

          {/* ════ UMBRELLA — positioned relative to the L-shaped arm fist (50, 110) ════ */}
          {showUmbrella && (
            <motion.g
              initial={{ scaleY: 0, opacity: 0 }}
              animate={{ scaleY: 1, opacity: 1 }}
              transition={{ duration: 0.5, type: 'spring', bounce: 0.5 }}
              style={{ transformBox: 'view-box', transformOrigin: '50px 110px' } as React.CSSProperties}
            >
              {/* Handle — slanted pole from canopy (85, 35) down to the fist (50, 110), clearing the body */}
              <path
                d="M 85 35 L 48 115 Q 47 122 37 122"
                fill="none" stroke="#111111" strokeWidth="4.5" strokeLinecap="round"
              />
              {/* Canopy — base moved up to Y=35 to increase gap above head (Y=52) */}
              <path
                d="M 50 35 Q 155 -25 260 35 Z"
                fill="#22C8FF" stroke="#111111" strokeWidth="3.5"
              />
              {/* Ribs radiating from the symmetric peak (155, 5) */}
              <line x1="155" y1="5" x2="50"  y2="35" stroke="#0099cc" strokeWidth="1.8" opacity="0.6" />
              <line x1="155" y1="5" x2="102" y2="35" stroke="#0099cc" strokeWidth="1.8" opacity="0.6" />
              <line x1="155" y1="5" x2="155" y2="35" stroke="#0099cc" strokeWidth="1.8" opacity="0.6" />
              <line x1="155" y1="5" x2="208" y2="35" stroke="#0099cc" strokeWidth="1.8" opacity="0.6" />
              <line x1="155" y1="5" x2="260" y2="35" stroke="#0099cc" strokeWidth="1.8" opacity="0.6" />
            </motion.g>
          )}

          {/* ════ ZZZ particles (night) ════ */}
          {showZzz && ZZZ_ITEMS.map((z, i) => (
            <motion.text
              key={`${zzzKey}-${i}`}
              x={208 + i * 10}
              y={88}
              fontSize={10 + i * 4}
              fontWeight="900"
              fill="#111111"
              fontFamily="monospace"
              initial={{ opacity: 0, y: 0 }}
              animate={{ opacity: [0, 0.85, 0], y: -40 - i * 10 }}
              transition={{ duration: 1.8, delay: i * 0.45, ease: 'easeOut' }}
            >
              {z}
            </motion.text>
          ))}
        </svg>
      </motion.div>

      {/* ── TEMPORARY TESTING UI ── */}
      <div 
        style={{ 
          position: 'fixed', 
          bottom: 20, 
          left: 20, 
          zIndex: 9999, 
          background: 'white', 
          border: '1px solid #E0E0E0',
          padding: '12px', 
          borderRadius: '12px', 
          boxShadow: '0 4px 20px rgba(0,0,0,0.1)',
          display: 'flex', 
          flexDirection: 'column', 
          gap: '8px', 
          color: '#111', 
          fontFamily: 'var(--font-space-grotesk), sans-serif', 
          fontSize: '12px' 
        }}
      >
        <div className="font-bold border-b pb-1 mb-1">Mascot Animation Tester</div>
        <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
          <strong>Time:</strong>
          {['morning', 'afternoon', 'evening', 'night'].map((t) => (
            <button 
              key={t}
              onClick={() => setTimeOfDay(t as TimeOfDay)} 
              style={{ 
                padding: '4px 8px', 
                borderRadius: '4px',
                background: timeOfDay === t ? '#111' : '#F0F0F0',
                color: timeOfDay === t ? 'white' : '#111',
                textTransform: 'capitalize'
              }}
            >
              {t}
            </button>
          ))}
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
          <strong>Weather:</strong>
          {['normal', 'rain', 'sunny'].map((w) => (
            <button 
              key={w}
              onClick={() => setWeather(w as Weather)} 
              style={{ 
                padding: '4px 8px', 
                borderRadius: '4px',
                background: weather === w ? '#22C8FF' : '#F0F0F0',
                color: weather === w ? 'white' : '#111',
                textTransform: 'capitalize'
              }}
            >
              {w}
            </button>
          ))}
        </div>
      </div>
    </>
  )
}
