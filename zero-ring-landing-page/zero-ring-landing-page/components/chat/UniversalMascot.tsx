'use client'

import { motion, useAnimation, AnimatePresence } from 'framer-motion'
import React, {
  forwardRef,
  useEffect,
  useImperativeHandle,
  useMemo,
  useRef,
  useState,
  useCallback,
} from 'react'
import { createPortal } from 'react-dom'

// ── Asset imports ──
import MascotUmbrella from './mascot-assets/umbrella'
import MascotNoodles from './mascot-assets/noodles'
import MascotSamosa from './mascot-assets/samosa'
import MascotMilk from './mascot-assets/milk'
import MascotChai from './mascot-assets/chai'
import MascotBed, { MascotBlanket } from './mascot-assets/bed'
import MascotLaptop from './mascot-assets/laptop'

/* ────────────────────────────── Types ────────────────────────────── */

export type TimeOfDay = 'morning' | 'afternoon' | 'evening' | 'night'
export type Weather = 'normal' | 'rain' | 'sunny'

export type MascotMood = TimeOfDay | Weather | 'happy' | 'sad' | 'excited' | 'hungry'

export interface MascotHandle {
  setMood: (mood: MascotMood, durationMs?: number) => void
  reactToMessage: (text: string) => void
  celebrate: () => void
  wave: () => void
  runLap: () => void
  eatSamosa: () => Promise<void>
  eatNoodles: () => Promise<void>
  drinkMilk: () => Promise<void>
  drinkChai: () => Promise<void>
  forceAsset: (asset: string | null) => void
}

export interface Rect { x: number; y: number; width: number; height: number }

export interface UniversalMascotProps {
  containerRef?: React.RefObject<HTMLElement | null>
  avoidRect?: Rect | (() => Rect | null)
  walk?: boolean
  mode?: 'inline' | 'roam'
  size?: number
  autoTimeOfDay?: boolean
  weather?: Weather | null
  onInteract?: (mood: MascotMood) => void
  enableDebugPanel?: boolean
  showFloatingToggle?: boolean
}

/* ──────────────────────────── Constants ──────────────────────────── */

const ZZZ_ITEMS = ['z', 'z', 'Z'] as const

// ViewBox standard trace
const VW = 300
const VH = 300

const wait = (ms: number) => new Promise<void>(r => setTimeout(r, ms))

/* ──────────────────────────── Helpers ────────────────────────────── */

// Resilient weather detection with localStorage/sessionStorage caching
async function detectWeather(signal?: AbortSignal): Promise<Weather> {
  if (typeof window === 'undefined') return 'normal'

  // Check cache first (15-min TTL)
  try {
    const cached = sessionStorage.getItem('zero_mascot_weather')
    if (cached) {
      const parsed = JSON.parse(cached)
      if (Date.now() - parsed.ts < 15 * 60 * 1000) {
        return parsed.weather
      }
    }
  } catch {
    // Ignore storage issues
  }

  let lat: number | null = null
  let lon: number | null = null

  // 1. Try browser geolocation if already granted
  if (navigator.geolocation && (navigator as any).permissions) {
    try {
      const status = await (navigator as any).permissions.query({ name: 'geolocation' })
      if (status.state === 'granted') {
        const pos = await new Promise<GeolocationPosition>((resolve, reject) => {
          navigator.geolocation.getCurrentPosition(resolve, reject, { timeout: 3000 })
        })
        lat = pos.coords.latitude
        lon = pos.coords.longitude
      }
    } catch {
      // Permission not granted or query unsupported
    }
  }

  // 2. IP Fallback 1: ipapi.co
  if (lat === null || lon === null) {
    try {
      const res = await fetch('https://ipapi.co/json/', { signal })
      if (res.ok) {
        const data = await res.json()
        if (typeof data?.latitude === 'number' && typeof data?.longitude === 'number') {
          lat = data.latitude
          lon = data.longitude
        }
      }
    } catch {
      // Try secondary IP lookup
    }
  }

  // 3. IP Fallback 2: ipwho.is
  if (lat === null || lon === null) {
    try {
      const res = await fetch('https://ipwho.is/', { signal })
      if (res.ok) {
        const data = await res.json()
        if (data?.success && typeof data?.latitude === 'number' && typeof data?.longitude === 'number') {
          lat = data.latitude
          lon = data.longitude
        }
      }
    } catch {
      // Default coordinates
    }
  }

  if (lat === null || lon === null) {
    return 'normal'
  }

  // Fetch forecast from Open-Meteo
  try {
    const url = `https://api.open-meteo.com/v1/forecast?latitude=${lat}&longitude=${lon}&current_weather=true&hourly=cloudcover&forecast_days=1`
    const resp = await fetch(url, { signal })
    if (!resp.ok) return 'normal'
    const data = await resp.json()
    const code: number = data?.current_weather?.weathercode ?? 0
    const cloudcover: number = data?.hourly?.cloudcover?.[new Date().getHours()] ?? 100

    let result: Weather = 'normal'
    // WMO Weather codes: 51-67, 80-82, 95-99 = rain / drizzle / thunderstorm
    if ((code >= 51 && code <= 67) || (code >= 80 && code <= 82) || (code >= 95 && code <= 99)) {
      result = 'rain'
    } else if (code < 3 && cloudcover < 40) {
      result = 'sunny'
    }

    // Save to cache
    try {
      sessionStorage.setItem('zero_mascot_weather', JSON.stringify({ weather: result, ts: Date.now() }))
    } catch {
      // Ignore
    }

    return result
  } catch {
    return 'normal'
  }
}

function getTimeOfDay(): TimeOfDay {
  const h = new Date().getHours()
  if (h >= 5 && h < 12) return 'morning'
  if (h >= 12 && h < 17) return 'afternoon'
  if (h >= 17 && h < 21) return 'evening'
  return 'night'
}

function usePrefersReducedMotion(): boolean {
  const [reduced, setReduced] = useState(false)
  useEffect(() => {
    if (typeof window === 'undefined' || !window.matchMedia) return
    const mq = window.matchMedia('(prefers-reduced-motion: reduce)')
    setReduced(mq.matches)
    const onChange = () => setReduced(mq.matches)
    mq.addEventListener('change', onChange)
    return () => mq.removeEventListener('change', onChange)
  }, [])
  return reduced
}

/* ─────────────────────────── Component ───────────────────────────── */

const UniversalMascot = forwardRef<MascotHandle, UniversalMascotProps>(
  function UniversalMascot(
    {
      size = 110,
      autoTimeOfDay = true,
      weather: externalWeather = null,
      onInteract,
      enableDebugPanel = false,
      showFloatingToggle = true,
    },
    ref,
  ) {
    const mascotRef = useRef<HTMLDivElement>(null)
    const reducedMotion = usePrefersReducedMotion()

    // Animation controllers
    const bodyControls = useAnimation()
    const blinkControls = useAnimation()
    const leftArmCtrl = useAnimation()
    const rightArmCtrl = useAnimation()
    const mouthCtrl = useAnimation()
    const eyeCtrl = useAnimation()
    const bedRotateCtrl = useAnimation()
    const lapCtrl = useAnimation()

    const [mounted, setMounted] = useState(false)
    const mountedRef = useRef(false)
    useEffect(() => {
      setMounted(true)
      mountedRef.current = true
      return () => { mountedRef.current = false }
    }, [])

    const safeStart = useCallback(async (ctrl: any, target: any) => {
      if (!mountedRef.current) return
      try {
        await ctrl.start(target)
      } catch (e) {
        // Component unmounted safely
      }
    }, [])

    // Time and Weather state
    const [timeOfDay, setTimeOfDay] = useState<TimeOfDay>('morning')
    const [weatherState, setWeather] = useState<Weather>('normal')

    // Facial expression modes
    const [mouthMode, setMouthMode] = useState<'idle' | 'yawn' | 'chew' | 'slurp' | 'drink' | 'happy'>('idle')
    const [eyeMode, setEyeMode] = useState<'normal' | 'happy' | 'slurp' | 'surprised' | 'sleep' | 'wink'>('normal')
    const [showBlush, setShowBlush] = useState(false)
    const [showMilkMustache, setShowMilkMustache] = useState(false)
    const [showSparkle, setShowSparkle] = useState(false)

    // Interactive asset visibility
    const [showUmbrella, setShowUmbrella] = useState(false)
    const [showSamosa, setShowSamosa] = useState(false)
    const [samosaBite, setSamosaBite] = useState(0)
    const [showChai, setShowChai] = useState(false)
    const [showNoodles, setShowNoodles] = useState(false)
    const [showMilk, setShowMilk] = useState(false)
    const [milkStage, setMilkStage] = useState(0)
    const [showBed, setShowBed] = useState(false)
    const [showLaptop, setShowLaptop] = useState(false)

    // Secondary indicators
    const [zzzKey, setZzzKey] = useState(0)
    const [showZzz, setShowZzz] = useState(false)
    const [rainActive, setRainActive] = useState(false)
    const [typingFrame, setTypingFrame] = useState<0 | 1>(0)

    // Floating Tester Panel state
    const [isStudioOpen, setIsStudioOpen] = useState(false)
    const [forcedAsset, setForcedAsset] = useState<string | null>(null)
    const [floatNonce, setFloatNonce] = useState(0)
    const [anchorEl, setAnchorEl] = useState<Element | null>(null)

    const appliedWeather = externalWeather ?? weatherState

    // Randomized raindrops
    const rainDrops = useMemo(
      () =>
        Array.from({ length: 18 }, (_, i) => ({
          id: i,
          x: i * 16 + 8,
          delay: Math.random() * 1.5,
        })),
      [],
    )

    /* ── Time clock and weather bootstrap ── */
    useEffect(() => {
      if (!autoTimeOfDay) return
      setTimeOfDay(getTimeOfDay())

      // Auto update clock every 30s
      const interval = setInterval(() => {
        setTimeOfDay(getTimeOfDay())
      }, 30000)

      const controller = new AbortController()
      const timeout = setTimeout(() => controller.abort(), 7000)
      detectWeather(controller.signal)
        .then(w => setWeather(w))
        .finally(() => clearTimeout(timeout))

      return () => {
        clearInterval(interval)
        clearTimeout(timeout)
        controller.abort()
      }
    }, [autoTimeOfDay])

    /* ── Anchor inspection ── */
    useEffect(() => {
      if (typeof document === 'undefined') return
      const checkAnchor = () =>
        setAnchorEl(prev => {
          const next = document.getElementById('mascot-anchor')
          return prev === next ? prev : next
        })
      checkAnchor()
      const observer = new MutationObserver(checkAnchor)
      observer.observe(document.body, { childList: true, subtree: true })
      window.addEventListener('resize', checkAnchor)
      return () => {
        observer.disconnect()
        window.removeEventListener('resize', checkAnchor)
      }
    }, [])

    /* ── Idle Float Routine ── */
    useEffect(() => {
      if (reducedMotion || timeOfDay === 'night' || forcedAsset === 'bed') {
        safeStart(bodyControls, { y: 0, transition: { duration: 1 } })
        return
      }
      const isLap = showLaptop || forcedAsset === 'laptop'
      const dur = isLap ? 4.0 : 2.2
      safeStart(bodyControls, {
        y: [0, isLap ? -2 : -6, 0],
        transition: { duration: dur, repeat: Infinity, ease: 'easeInOut' },
      })
    }, [bodyControls, timeOfDay, showLaptop, forcedAsset, reducedMotion, floatNonce, safeStart])

    /* ── Natural Blinking ── */
    useEffect(() => {
      if (reducedMotion || eyeMode !== 'normal') return
      let active = true
      const blink = async () => {
        while (active && mountedRef.current) {
          await wait(2800 + Math.random() * 2500)
          if (!active || !mountedRef.current) break
          await safeStart(blinkControls, { scaleY: 0.1, transition: { duration: 0.05 } })
          await safeStart(blinkControls, { scaleY: 1, transition: { duration: 0.08 } })
        }
      }
      blink()
      return () => { active = false }
    }, [blinkControls, reducedMotion, eyeMode, safeStart])

    /* ── Reset Routine ── */
    const resetPose = useCallback(async () => {
      setShowLaptop(false)
      setShowBed(false)
      setShowUmbrella(false)
      setShowSamosa(false)
      setShowChai(false)
      setShowNoodles(false)
      setShowMilk(false)
      setShowMilkMustache(false)
      setShowSparkle(false)
      setShowBlush(false)
      setMouthMode('idle')
      setEyeMode('normal')
      setSamosaBite(0)
      setMilkStage(0)

      await Promise.all([
        safeStart(rightArmCtrl, { x: 0, y: 0, rotate: 0, transition: { duration: 0.4 } }),
        safeStart(leftArmCtrl, { x: 0, y: 0, rotate: 0, transition: { duration: 0.4 } }),
        safeStart(eyeCtrl, { y: 0, scaleY: 1, rotate: 0, transition: { duration: 0.4 } }),
        safeStart(bedRotateCtrl, { rotate: 0, x: 0, y: 0, transition: { duration: 0.4 } }),
        safeStart(mouthCtrl, { scaleY: 0, opacity: 0, transition: { duration: 0.3 } }),
      ])
    }, [rightArmCtrl, leftArmCtrl, eyeCtrl, bedRotateCtrl, mouthCtrl, safeStart])

    /* ── Action: Samosa Eating Sequence ── */
    const eatSamosaSequence = useCallback(async () => {
      if (!mountedRef.current) return
      setShowSamosa(true)
      setSamosaBite(0)
      await wait(300)
      if (!mountedRef.current) return

      // Move samosa directly to mouth
      await safeStart(rightArmCtrl, { x: -14, y: -10, rotate: -4, transition: { duration: 0.45 } })

      // Bite 1
      setMouthMode('chew')
      setEyeMode('happy')
      setShowBlush(true)
      setSamosaBite(1)
      await wait(1200)
      if (!mountedRef.current) return

      // Bite 2
      setSamosaBite(2)
      await safeStart(rightArmCtrl, { x: -12, y: -10, rotate: -2, transition: { duration: 0.3 } })
      await wait(1400)
      if (!mountedRef.current) return

      // Bite 3 (Final bite)
      setSamosaBite(3)
      await wait(1500)
      if (!mountedRef.current) return

      // Finished! Savoring expression
      setSamosaBite(4)
      setMouthMode('happy')
      setShowSparkle(true)
      await wait(1000)
      if (!mountedRef.current) return

      // Return arm
      setShowSparkle(false)
      setShowBlush(false)
      setMouthMode('idle')
      setEyeMode('normal')
      setShowSamosa(false)
      await safeStart(rightArmCtrl, { x: 0, y: 0, transition: { duration: 0.5 } })
    }, [rightArmCtrl, safeStart])

    /* ── Action: Noodle Slurp Sequence ── */
    const eatNoodlesSequence = useCallback(async () => {
      if (!mountedRef.current) return
      setShowNoodles(true)
      await safeStart(rightArmCtrl, { x: -10, y: -6, transition: { duration: 0.5 } })

      // Open slurping mouth and squint happily
      setMouthMode('slurp')
      setEyeMode('slurp')
      setShowBlush(true)

      await wait(4200) // Slurping duration
      if (!mountedRef.current) return

      // Satisfied swallow
      setMouthMode('happy')
      setEyeMode('happy')
      setShowSparkle(true)
      await wait(1200)
      if (!mountedRef.current) return

      setShowSparkle(false)
      setShowBlush(false)
      setMouthMode('idle')
      setEyeMode('normal')
      setShowNoodles(false)
      await safeStart(rightArmCtrl, { x: 0, y: 0, transition: { duration: 0.5 } })
    }, [rightArmCtrl, safeStart])

    /* ── Action: Milk Drinking & Hand Swipe Mustache Wipe ── */
    const drinkMilkSequence = useCallback(async () => {
      if (!mountedRef.current) return
      setShowMilk(true)
      setMilkStage(0)
      await wait(300)
      if (!mountedRef.current) return

      // Raise milk jar to mouth
      await safeStart(rightArmCtrl, { x: -16, y: -8, rotate: 12, transition: { duration: 0.45 } })

      // Drink Stage 1 (half)
      setMouthMode('drink')
      setMilkStage(1)
      await wait(1200)
      if (!mountedRef.current) return

      // Drink Stage 2 (low)
      setMilkStage(2)
      await wait(1400)
      if (!mountedRef.current) return

      // Lower glass — Milk mustache appears!
      setMilkStage(3)
      setShowMilkMustache(true)
      setMouthMode('idle')
      setEyeMode('surprised')
      await safeStart(rightArmCtrl, { x: -20, y: 0, transition: { duration: 0.4 } })
      setShowMilk(false)
      await wait(800)
      if (!mountedRef.current) return

      // Hand Swipe Wipe across mouth
      await safeStart(rightArmCtrl, { x: -65, y: -18, rotate: -25, transition: { duration: 0.35 } })
      await safeStart(rightArmCtrl, { x: 15, y: -18, rotate: 10, transition: { duration: 0.45, ease: 'easeInOut' } })
      if (!mountedRef.current) return

      // As hand wipes across, clear mustache into squeaky sparkle and happy blush!
      setShowMilkMustache(false)
      setShowSparkle(true)
      setShowBlush(true)
      setMouthMode('happy')
      setEyeMode('happy')

      await safeStart(rightArmCtrl, { x: 0, y: 0, rotate: 0, transition: { duration: 0.4 } })
      await wait(1400)
      if (!mountedRef.current) return

      setShowSparkle(false)
      setShowBlush(false)
      setMouthMode('idle')
      setEyeMode('normal')
    }, [rightArmCtrl, safeStart])

    /* ── Action: Chai Drinking Sequence ── */
    const drinkChaiSequence = useCallback(async () => {
      if (!mountedRef.current) return
      setShowChai(true)
      await wait(300)
      if (!mountedRef.current) return

      // Raise steaming cutting chai to mouth
      await safeStart(rightArmCtrl, { x: -16, y: -10, transition: { duration: 0.5 } })

      // Savoring tea
      setMouthMode('drink')
      setEyeMode('happy')
      setShowBlush(true)

      await wait(3200)
      if (!mountedRef.current) return

      // Lower saucer & glass
      setMouthMode('happy')
      setShowSparkle(true)
      await safeStart(rightArmCtrl, { x: 0, y: 0, transition: { duration: 0.5 } })
      await wait(1000)
      if (!mountedRef.current) return

      setShowSparkle(false)
      setShowBlush(false)
      setMouthMode('idle')
      setEyeMode('normal')
      setShowChai(false)
    }, [rightArmCtrl, safeStart])

    /* ── Master Ambient Routine ── */
    useEffect(() => {
      if (forcedAsset || reducedMotion) return
      let active = true

      const routine = async () => {
        while (active && mountedRef.current) {
          await wait(6000 + Math.random() * 4000)
          if (!active || !mountedRef.current) break

          if (timeOfDay === 'morning' && appliedWeather !== 'rain') {
            const rand = Math.random()
            if (rand < 0.4) {
              // Yawn & Morning Stretch
              setEyeMode('sleep')
              setMouthMode('yawn')
              await safeStart(leftArmCtrl, { x: -10, y: -30, rotate: -15, transition: { duration: 0.6 } })
              await safeStart(rightArmCtrl, { x: 10, y: -30, rotate: 15, transition: { duration: 0.6 } })
              await wait(1500)
              if (!active || !mountedRef.current) break
              await Promise.all([
                safeStart(leftArmCtrl, { x: 0, y: 0, rotate: 0, transition: { duration: 0.4 } }),
                safeStart(rightArmCtrl, { x: 0, y: 0, rotate: 0, transition: { duration: 0.4 } }),
              ])
              setMouthMode('idle')
              setEyeMode('normal')
            } else {
              // Drink fresh cold milk & wipe
              await drinkMilkSequence()
            }
          } else if (timeOfDay === 'afternoon' && appliedWeather !== 'rain') {
            const rand = Math.random()
            if (rand < 0.5) {
              // Typing on Desk Laptop
              setShowLaptop(true)
              await safeStart(eyeCtrl, { y: 6, transition: { duration: 0.3 } })
              await Promise.all([
                safeStart(leftArmCtrl, { x: 12, y: 34, transition: { duration: 0.3 } }),
                safeStart(rightArmCtrl, { x: -12, y: 34, transition: { duration: 0.3 } }),
              ])
              const typingEnd = Date.now() + 6500
              while (active && mountedRef.current && Date.now() < typingEnd) {
                setTypingFrame(0)
                await wait(180)
                setTypingFrame(1)
                await wait(180)
              }
              if (!active || !mountedRef.current) break
              await Promise.all([
                safeStart(leftArmCtrl, { x: 0, y: 0, transition: { duration: 0.3 } }),
                safeStart(rightArmCtrl, { x: 0, y: 0, transition: { duration: 0.3 } }),
                safeStart(eyeCtrl, { y: 0, transition: { duration: 0.3 } }),
              ])
              setShowLaptop(false)
            } else {
              // Eat Flowing Ramen Noodles
              await eatNoodlesSequence()
            }
          } else if (timeOfDay === 'evening' && appliedWeather !== 'rain') {
            const rand = Math.random()
            if (rand < 0.5) {
              // Steaming Cutting Chai
              await drinkChaiSequence()
            } else {
              // Crispy Samosa Crunch
              await eatSamosaSequence()
            }
          }
        }
      }
      routine()
      return () => { active = false }
    }, [
      timeOfDay,
      appliedWeather,
      forcedAsset,
      reducedMotion,
      leftArmCtrl,
      rightArmCtrl,
      eyeCtrl,
      mouthCtrl,
      eatSamosaSequence,
      eatNoodlesSequence,
      drinkMilkSequence,
      drinkChaiSequence,
      safeStart,
    ])

    /* ── Forced Asset / Manual Override ── */
    useEffect(() => {
      if (!forcedAsset) return
      resetPose()

      const apply = async () => {
        if (!mountedRef.current) return
        if (forcedAsset === 'laptop') {
          setShowLaptop(true)
          await safeStart(eyeCtrl, { y: 6 })
          safeStart(leftArmCtrl, { x: 12, y: 34 })
          safeStart(rightArmCtrl, { x: -12, y: 34 })
        } else if (forcedAsset === 'samosa') {
          eatSamosaSequence()
        } else if (forcedAsset === 'noodles') {
          eatNoodlesSequence()
        } else if (forcedAsset === 'milk') {
          drinkMilkSequence()
        } else if (forcedAsset === 'chai') {
          drinkChaiSequence()
        } else if (forcedAsset === 'umbrella') {
          setShowUmbrella(true)
          safeStart(leftArmCtrl, { x: 0, y: -6 })
        } else if (forcedAsset === 'bed') {
          setShowBed(true)
          setEyeMode('sleep')
          safeStart(bedRotateCtrl, { rotate: -90, x: -20, y: 0 })
        }
      }
      apply()
    }, [forcedAsset, resetPose, eyeCtrl, rightArmCtrl, leftArmCtrl, bedRotateCtrl, eatSamosaSequence, eatNoodlesSequence, drinkMilkSequence, drinkChaiSequence, safeStart])

    /* ── Night Mode (Window & Bed) ── */
    useEffect(() => {
      if (forcedAsset || timeOfDay !== 'night' || appliedWeather === 'rain') return
      let active = true
      safeStart(bedRotateCtrl, { rotate: -90, x: -20, y: 0, transition: { duration: 0.8, ease: 'easeInOut' } })
      setEyeMode('sleep')
      setShowBed(true)

      if (!reducedMotion) {
        const sleep = async () => {
          while (active && mountedRef.current) {
            await wait(3500 + Math.random() * 2000)
            if (!active || !mountedRef.current) break
            setShowZzz(true)
            setZzzKey(k => k + 1)
            await wait(2600)
            if (!active || !mountedRef.current) break
            setShowZzz(false)
          }
        }
        sleep()
      }
      return () => {
        active = false
        setShowBed(false)
        setShowZzz(false)
      }
    }, [timeOfDay, appliedWeather, forcedAsset, reducedMotion, bedRotateCtrl, safeStart])

    /* ── Rain Routine ── */
    useEffect(() => {
      if (forcedAsset || appliedWeather !== 'rain') {
        if (!forcedAsset) {
          setShowUmbrella(false)
          setRainActive(false)
        }
        return
      }
      let active = true
      setRainActive(true)

      const rainSeq = async () => {
        await wait(600)
        if (!active || !mountedRef.current) return
        await safeStart(leftArmCtrl, { x: 0, y: -6, transition: { duration: 0.6 } })
        if (!active || !mountedRef.current) return
        setShowUmbrella(true)
      }
      rainSeq()
      return () => {
        active = false
      }
    }, [appliedWeather, forcedAsset, leftArmCtrl, safeStart])

    /* ── Imperative API ── */
    useImperativeHandle(ref, () => ({
      setMood: (mood, durationMs) => {
        if (!mountedRef.current) return
        const dur = (durationMs ?? 1800) / 1000
        if (mood === 'morning' || mood === 'afternoon' || mood === 'evening' || mood === 'night') {
          setTimeOfDay(mood)
        } else if (mood === 'rain' || mood === 'sunny' || mood === 'normal') {
          setWeather(mood)
        } else if (mood === 'happy' || mood === 'excited') {
          setShowBlush(true)
          setMouthMode('happy')
          setEyeMode('happy')
          safeStart(bodyControls, { y: [0, -14, 0, -8, 0], transition: { duration: 0.7, ease: 'easeOut' } })
            .then(() => setFloatNonce(n => n + 1))
          setTimeout(() => {
            if (!mountedRef.current) return
            setShowBlush(false)
            setMouthMode('idle')
            setEyeMode('normal')
          }, dur * 1000)
        } else if (mood === 'sad') {
          safeStart(eyeCtrl, { y: 6, scaleY: 0.7, transition: { duration: 0.5 } })
          setTimeout(() => {
            if (!mountedRef.current) return
            safeStart(eyeCtrl, { y: 0, scaleY: 1, transition: { duration: 0.5 } })
          }, dur * 1000)
        } else if (mood === 'hungry') {
          drinkMilkSequence()
        }
        onInteract?.(mood)
      },

      reactToMessage: text => {
        if (!mountedRef.current) return
        const t = text.toLowerCase()
        if (['good', 'yes', 'great', 'awesome', 'nice', 'love', 'perfect', 'amazing'].some(w => t.includes(w))) {
          setShowBlush(true)
          setEyeMode('happy')
          setMouthMode('happy')
          setTimeout(() => {
            if (!mountedRef.current) return
            setShowBlush(false)
            setEyeMode('normal')
            setMouthMode('idle')
          }, 2500)
        } else if (['milk', 'drink'].some(w => t.includes(w))) {
          drinkMilkSequence()
        } else if (['samosa', 'snack', 'crispy'].some(w => t.includes(w))) {
          eatSamosaSequence()
        } else if (['noodles', 'ramen', 'eat', 'hungry'].some(w => t.includes(w))) {
          eatNoodlesSequence()
        }
      },

      celebrate: async () => {
        if (!mountedRef.current) return
        setShowBlush(true)
        setShowSparkle(true)
        setEyeMode('happy')
        setMouthMode('happy')
        await safeStart(bodyControls, { y: [0, -20, 0, -12, 0], transition: { duration: 0.9, ease: 'easeOut' } })
        await Promise.all([
          safeStart(leftArmCtrl, { y: -30, x: -10, rotate: -20, transition: { duration: 0.25 } }),
          safeStart(rightArmCtrl, { y: -30, x: 10, rotate: 20, transition: { duration: 0.25 } }),
        ])
        await Promise.all([
          safeStart(leftArmCtrl, { y: 0, x: 0, rotate: 0, transition: { duration: 0.4 } }),
          safeStart(rightArmCtrl, { y: 0, x: 0, rotate: 0, transition: { duration: 0.4 } }),
        ])
        setShowSparkle(false)
        setShowBlush(false)
        setEyeMode('normal')
        setMouthMode('idle')
        setFloatNonce(n => n + 1)
      },

      wave: async () => {
        setEyeMode('happy')
        await leftArmCtrl.start({ y: -12, rotate: -15, transition: { duration: 0.15 } })
        for (let i = 0; i < 3; i++) {
          await leftArmCtrl.start({ rotate: 12, transition: { duration: 0.15 } })
          await leftArmCtrl.start({ rotate: -20, transition: { duration: 0.15 } })
        }
        await leftArmCtrl.start({ rotate: 0, y: 0, transition: { duration: 0.2 } })
        setEyeMode('normal')
      },

      runLap: async () => {
        await lapCtrl.start({ x: 170, transition: { duration: 0.45, ease: 'easeIn' } })
        lapCtrl.set({ x: -170 })
        await lapCtrl.start({ x: 0, transition: { duration: 0.45, ease: 'easeOut' } })
      },

      eatSamosa: eatSamosaSequence,
      eatNoodles: eatNoodlesSequence,
      drinkMilk: drinkMilkSequence,
      drinkChai: drinkChaiSequence,
      forceAsset: a => setForcedAsset(a),
    }), [bodyControls, leftArmCtrl, rightArmCtrl, eyeCtrl, lapCtrl, onInteract, eatSamosaSequence, eatNoodlesSequence, drinkMilkSequence, drinkChaiSequence])

    /* ── Derived Flags ── */
    const isNight = timeOfDay === 'night' || forcedAsset === 'bed'
    const isLapActive = showLaptop || forcedAsset === 'laptop'
    const isBedActive = showBed || forcedAsset === 'bed'

    /* ── The Mascot SVG Canvas ── */
    const mascotBody = (
      <div
        style={{
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
          position: anchorEl ? 'absolute' : 'relative',
          left: anchorEl ? '50%' : 'auto',
          top: anchorEl ? '50%' : 'auto',
          transform: anchorEl ? 'translate(-50%, -50%)' : 'none',
        }}
      >
        <motion.div
          ref={mascotRef}
          animate={bodyControls}
          style={{
            position: 'relative',
            width: size,
            height: size,
            zIndex: 100,
            cursor: 'pointer',
          }}
          onClick={() => {
            // Interactive click: celebrate or wave!
            if (Math.random() > 0.5) {
              ref && (ref as any).current?.wave?.()
            } else {
              setShowBlush(true)
              setTimeout(() => setShowBlush(false), 1800)
            }
          }}
        >
          <svg
            width="100%"
            height="100%"
            viewBox={`0 0 ${VW} ${VH}`}
            fill="none"
            style={{ overflow: 'visible' }}
            role="img"
            aria-label="Zero AI Robot Mascot"
          >
            <defs>
              {/* Deep Celestial Night Sky Gradient */}
              <linearGradient id="nightSkyGrad" x1="0" y1="0" x2="0" y2="1">
                <stop offset="0%" stopColor="#020617" />
                <stop offset="50%" stopColor="#0B132B" />
                <stop offset="100%" stopColor="#1C2541" />
              </linearGradient>

              {/* Luminous Moon Gradient */}
              <radialGradient id="moonLuminousGrad" cx="40%" cy="35%" r="65%">
                <stop offset="0%" stopColor="#FFFDF0" />
                <stop offset="60%" stopColor="#FEF08A" />
                <stop offset="90%" stopColor="#FDE047" />
                <stop offset="100%" stopColor="#EAB308" />
              </radialGradient>

              {/* Moon Glow Filter */}
              <filter id="moonGlow" x="-50%" y="-50%" width="200%" height="200%">
                <feGaussianBlur in="SourceGraphic" stdDeviation="6" result="blur" />
                <feMerge>
                  <feMergeNode in="blur" />
                  <feMergeNode in="SourceGraphic" />
                </feMerge>
              </filter>
            </defs>

            <motion.g animate={lapCtrl}>
              {/* ── BIGGER REALISTIC PANORAMIC NIGHT WINDOW (MOON & STARS) ── */}
              {isNight && (
                <motion.g
                  initial={{ opacity: 0, scale: 0.95 }}
                  animate={{ opacity: 1, scale: 1 }}
                  transition={{ duration: 1.2, ease: 'easeOut' }}
                >
                  {/* Window Architectural Outer Frame (Bigger & Panoramic) */}
                  <rect
                    x="165"
                    y="14"
                    width="125"
                    height="136"
                    rx="18"
                    fill="#1E293B"
                    stroke="#334155"
                    strokeWidth="3"
                  />

                  {/* Window Glass Pane / Deep Cosmic Night Sky */}
                  <rect
                    x="170"
                    y="18"
                    width="115"
                    height="128"
                    rx="14"
                    fill="url(#nightSkyGrad)"
                  />

                  {/* ── LUMINOUS DETAILED MOON ── */}
                  <g filter="url(#moonGlow)">
                    {/* Moon Outer Halo */}
                    <circle cx="252" cy="46" r="18" fill="#FEF08A" opacity="0.15" />
                    {/* Glowing Moon Sphere */}
                    <circle cx="252" cy="46" r="13" fill="url(#moonLuminousGrad)" />

                    {/* Soft Lunar Craters */}
                    <circle cx="248" cy="43" r="2.2" fill="#CA8A04" opacity="0.45" />
                    <circle cx="255" cy="51" r="2.6" fill="#CA8A04" opacity="0.4" />
                    <circle cx="257" cy="42" r="1.5" fill="#CA8A04" opacity="0.35" />
                  </g>

                  {/* ── TWINKLING STARS & STARBURSTS ── */}
                  {/* Star 1 (Pulsing Starburst) */}
                  <motion.g
                    animate={{ scale: [0.8, 1.4, 0.8], opacity: [0.5, 1, 0.5] }}
                    transition={{ duration: 2.2, repeat: Infinity, ease: 'easeInOut' }}
                    style={{ transformOrigin: '190px 38px' }}
                  >
                    <polygon
                      points="190,33 191.5,37 195,38 191.5,39 190,43 188.5,39 185,38 188.5,37"
                      fill="#FFFFFF"
                    />
                  </motion.g>

                  {/* Star 2 */}
                  <motion.circle
                    cx="218"
                    cy="28"
                    r="1.8"
                    fill="#BAE6FD"
                    animate={{ opacity: [0.3, 1, 0.3], scale: [0.7, 1.2, 0.7] }}
                    transition={{ duration: 1.8, repeat: Infinity, ease: 'easeInOut', delay: 0.5 }}
                  />

                  {/* Star 3 (Golden) */}
                  <motion.circle
                    cx="182"
                    cy="85"
                    r="2.2"
                    fill="#FEF08A"
                    animate={{ opacity: [0.4, 1, 0.4] }}
                    transition={{ duration: 2.5, repeat: Infinity, ease: 'easeInOut', delay: 1 }}
                  />

                  {/* Star 4 */}
                  <motion.circle
                    cx="210"
                    cy="95"
                    r="1.5"
                    fill="#FFFFFF"
                    animate={{ opacity: [0.2, 0.9, 0.2] }}
                    transition={{ duration: 2, repeat: Infinity, ease: 'easeInOut', delay: 0.7 }}
                  />

                  {/* Star 5 */}
                  <motion.circle
                    cx="270"
                    cy="90"
                    r="1.6"
                    fill="#E0F2FE"
                    animate={{ opacity: [0.4, 1, 0.4] }}
                    transition={{ duration: 2.1, repeat: Infinity, ease: 'easeInOut', delay: 1.3 }}
                  />

                  {/* Shooting Star Streak */}
                  <motion.line
                    x1="260"
                    y1="25"
                    x2="230"
                    y2="55"
                    stroke="#FFFFFF"
                    strokeWidth="1.5"
                    strokeLinecap="round"
                    initial={{ pathLength: 0, opacity: 0 }}
                    animate={{
                      pathLength: [0, 1, 0],
                      opacity: [0, 0.9, 0],
                      x: [0, -20],
                      y: [0, 20],
                    }}
                    transition={{ duration: 1.2, repeat: Infinity, repeatDelay: 4, ease: 'easeOut' }}
                  />

                  {/* Window Grid Mullions */}
                  <line x1="228" y1="18" x2="228" y2="146" stroke="#334155" strokeWidth="2.5" />
                  <line x1="170" y1="82" x2="285" y2="82" stroke="#334155" strokeWidth="2.5" />
                </motion.g>
              )}

              {/* ── RAINDROPS ── */}
              {appliedWeather === 'rain' && rainActive && rainDrops.map(drop => (
                <motion.rect
                  key={drop.id}
                  x={drop.x}
                  y={-40}
                  width={2.2}
                  height={16}
                  rx={1}
                  fill="#38BDF8"
                  animate={{ y: [0, 360] }}
                  transition={{ duration: 0.7, repeat: Infinity, delay: drop.delay, ease: 'linear' }}
                />
              ))}

              {/* ── BED BASE LAYER ── */}
              {isBedActive && <MascotBed />}

              {/* ── SLEEPING ROTATION WRAPPER ── */}
              <motion.g
                animate={bedRotateCtrl}
                style={{ transformOrigin: '150px 150px' } as React.CSSProperties}
              >
                {/* LEGS */}
                <path d="M 124 186 V 202 H 116" stroke="#222" strokeWidth="8" fill="none" strokeLinejoin="round" strokeLinecap="round" />
                <path d="M 124 186 V 202 H 116" stroke="#FFF" strokeWidth="4" fill="none" strokeLinejoin="round" strokeLinecap="round" />
                <path d="M 176 186 V 202 H 184" stroke="#222" strokeWidth="8" fill="none" strokeLinejoin="round" strokeLinecap="round" />
                <path d="M 176 186 V 202 H 184" stroke="#FFF" strokeWidth="4" fill="none" strokeLinejoin="round" strokeLinecap="round" />

                {/* MAIN BODY */}
                <rect x="100" y="100" width="100" height="86" rx="8" fill="#FFF" stroke="#222" strokeWidth="4" />

                {/* LEFT ARM */}
                <motion.g
                  animate={leftArmCtrl}
                  style={{ transformOrigin: '100px 142px' } as React.CSSProperties}
                >
                  {(showUmbrella || forcedAsset === 'umbrella') && <MascotUmbrella />}
                  <path d="M 100 142 H 88 C 82 142 80 138 80 132 V 122" stroke="#222" strokeWidth="8" fill="none" strokeLinejoin="round" strokeLinecap="round" />
                  <path d="M 100 142 H 88 C 82 142 80 138 80 132 V 122" stroke="#FFF" strokeWidth="4" fill="none" strokeLinejoin="round" strokeLinecap="round" />
                </motion.g>

                {/* RIGHT ARM */}
                <motion.g
                  animate={rightArmCtrl}
                  style={{ transformOrigin: '200px 142px' } as React.CSSProperties}
                >
                  <path d="M 200 142 H 208 C 214 142 216 146 216 150 V 162 C 216 166 212 168 208 168 H 202" stroke="#222" strokeWidth="8" fill="none" strokeLinejoin="round" strokeLinecap="round" />
                  <path d="M 200 142 H 208 C 214 142 216 146 216 150 V 162 C 216 166 212 168 208 168 H 202" stroke="#FFF" strokeWidth="4" fill="none" strokeLinejoin="round" strokeLinecap="round" />

                  {/* Hand-Held Food & Drink Assets */}
                  {(showNoodles || forcedAsset === 'noodles') && <MascotNoodles isSlurping={mouthMode === 'slurp'} />}
                  {(showSamosa || forcedAsset === 'samosa') && <MascotSamosa biteStage={samosaBite} />}
                  {(showMilk || forcedAsset === 'milk') && <MascotMilk stage={milkStage} />}
                  {(showChai || forcedAsset === 'chai') && <MascotChai />}
                </motion.g>

                {/* ── EYES & FACIAL EXPRESSIONS ── */}
                <motion.g
                  animate={eyeCtrl}
                  style={{ transformOrigin: '150px 141px' } as React.CSSProperties}
                >
                  {/* Mode: Normal Eyes */}
                  {eyeMode === 'normal' && (
                    <>
                      {/* Left Eye */}
                      <motion.rect x="125" y="136" width="10" height="10" rx="1.5" fill="#00A2FF" stroke="#0A5B94" strokeWidth="2" animate={blinkControls} style={{ transformOrigin: '130px 141px' }} />
                      <motion.rect x="127" y="138" width="3" height="3" rx="0.5" fill="#FFFFFF" animate={blinkControls} style={{ transformOrigin: '130px 141px' }} />

                      {/* Right Eye */}
                      <motion.rect x="165" y="136" width="10" height="10" rx="1.5" fill="#00A2FF" stroke="#0A5B94" strokeWidth="2" animate={blinkControls} style={{ transformOrigin: '170px 141px' }} />
                      <motion.rect x="167" y="138" width="3" height="3" rx="0.5" fill="#FFFFFF" animate={blinkControls} style={{ transformOrigin: '170px 141px' }} />
                    </>
                  )}

                  {/* Mode: Happy Eyes (^ ^) */}
                  {eyeMode === 'happy' && (
                    <>
                      <path d="M 124 142 Q 130 134 136 142" stroke="#0A5B94" strokeWidth="3" fill="none" strokeLinecap="round" />
                      <path d="M 164 142 Q 170 134 176 142" stroke="#0A5B94" strokeWidth="3" fill="none" strokeLinecap="round" />
                    </>
                  )}

                  {/* Mode: Slurp / Squeezed Joy Eyes (> <) */}
                  {eyeMode === 'slurp' && (
                    <>
                      <path d="M 124 137 L 134 141 L 124 145" stroke="#0A5B94" strokeWidth="3" fill="none" strokeLinecap="round" strokeLinejoin="round" />
                      <path d="M 176 137 L 166 141 L 176 145" stroke="#0A5B94" strokeWidth="3" fill="none" strokeLinecap="round" strokeLinejoin="round" />
                    </>
                  )}

                  {/* Mode: Surprised Eyes (O O) */}
                  {eyeMode === 'surprised' && (
                    <>
                      <circle cx="130" cy="141" r="6" fill="#00A2FF" stroke="#0A5B94" strokeWidth="2" />
                      <circle cx="131" cy="139" r="2" fill="#FFFFFF" />
                      <circle cx="170" cy="141" r="6" fill="#00A2FF" stroke="#0A5B94" strokeWidth="2" />
                      <circle cx="171" cy="139" r="2" fill="#FFFFFF" />
                    </>
                  )}

                  {/* Mode: Sleep Eyes (- -) */}
                  {eyeMode === 'sleep' && (
                    <>
                      <line x1="124" y1="141" x2="136" y2="141" stroke="#0A5B94" strokeWidth="3" strokeLinecap="round" />
                      <line x1="164" y1="141" x2="176" y2="141" stroke="#0A5B94" strokeWidth="3" strokeLinecap="round" />
                    </>
                  )}

                  {/* Blushing Cheeks */}
                  {showBlush && (
                    <motion.g initial={{ opacity: 0 }} animate={{ opacity: 1 }}>
                      <path d="M 116 144 L 122 150 M 120 144 L 126 150" stroke="#FF527B" strokeWidth="2.5" strokeLinecap="round" />
                      <path d="M 174 144 L 180 150 M 178 144 L 184 150" stroke="#FF527B" strokeWidth="2.5" strokeLinecap="round" />
                    </motion.g>
                  )}

                  {/* ── MOUTH EXPRESSIONS ── */}
                  {/* Yawn Mouth */}
                  {mouthMode === 'yawn' && (
                    <motion.path
                      d="M 138 143 C 138 162 162 162 162 143 Z"
                      fill="#111"
                      initial={{ scaleY: 0 }}
                      animate={{ scaleY: 1 }}
                      transition={{ duration: 0.3 }}
                      style={{ transformOrigin: '150px 145px' }}
                    />
                  )}

                  {/* Samosa Chew Mouth (cycles open/close) */}
                  {mouthMode === 'chew' && (
                    <motion.path
                      d="M 142 144 Q 150 156 158 144 Z"
                      fill="#111"
                      animate={{ scaleY: [0.3, 1.2, 0.3] }}
                      transition={{ duration: 0.4, repeat: Infinity, ease: 'easeInOut' }}
                      style={{ transformOrigin: '150px 145px' }}
                    />
                  )}

                  {/* Noodle Slurp Mouth (O shape) */}
                  {mouthMode === 'slurp' && (
                    <motion.ellipse
                      cx="150"
                      cy="146"
                      rx="6.5"
                      ry="8"
                      fill="#111"
                      animate={{ scale: [0.9, 1.1, 0.9] }}
                      transition={{ duration: 0.5, repeat: Infinity, ease: 'easeInOut' }}
                    />
                  )}

                  {/* Milk Drinking Mouth */}
                  {mouthMode === 'drink' && (
                    <ellipse cx="150" cy="146" rx="5" ry="4" fill="#111" />
                  )}

                  {/* Happy Smile Mouth */}
                  {mouthMode === 'happy' && (
                    <path d="M 142 144 Q 150 154 158 144" stroke="#111" strokeWidth="3" fill="none" strokeLinecap="round" />
                  )}

                  {/* ── CREAMY MILK MUSTACHE ── */}
                  {showMilkMustache && (
                    <motion.g
                      initial={{ opacity: 0, scale: 0.6 }}
                      animate={{ opacity: 1, scale: 1 }}
                      exit={{ opacity: 0, scale: 0.5 }}
                      transition={{ duration: 0.25 }}
                    >
                      {/* Creamy white foam mustache over mouth */}
                      <path
                        d="M 136 142 C 142 138 148 144 150 141 C 152 144 158 138 164 142 C 160 148 140 148 136 142 Z"
                        fill="#FFFFFF"
                        stroke="#E2E8F0"
                        strokeWidth="0.8"
                        filter="drop-shadow(0px 1px 2px rgba(0,0,0,0.15))"
                      />
                      {/* Milk drop hanging */}
                      <circle cx="150" cy="147" r="1.5" fill="#FFFFFF" />
                      <circle cx="144" cy="145" r="1" fill="#FFFFFF" />
                      <circle cx="156" cy="145" r="1" fill="#FFFFFF" />
                    </motion.g>
                  )}

                  {/* ── SPARKLE SHINE (✨) ON WIPED CLEAN / CELEBRATE ── */}
                  {showSparkle && (
                    <motion.g
                      initial={{ scale: 0, opacity: 0 }}
                      animate={{ scale: [0, 1.3, 1], opacity: [0, 1, 0] }}
                      transition={{ duration: 0.9, ease: 'easeOut' }}
                    >
                      {/* Sparkle 1 */}
                      <polygon points="166,132 168,136 172,138 168,140 166,144 164,140 160,138 164,136" fill="#FDE047" stroke="#CA8A04" strokeWidth="0.5" />
                      {/* Sparkle 2 */}
                      <polygon points="132,134 133.5,137 137,138.5 133.5,140 132,143 130.5,140 127,138.5 130.5,137" fill="#38BDF8" />
                    </motion.g>
                  )}
                </motion.g>
              </motion.g>

              {/* ── GROUND SHADOW ── */}
              <ellipse cx="150" cy="209" rx="42" ry="2" fill="#222" opacity="0.3" />
              <line x1="102" y1="209" x2="198" y2="209" stroke="#222" strokeWidth="2.5" strokeLinecap="round" />

              {/* ── BED BLANKET (OVER MASCOT) ── */}
              {isBedActive && <MascotBlanket />}

              {/* ── 3/4 ISOMETRIC SIDE LAPTOP (FRONT) ── */}
              {isLapActive && (
                <motion.g
                  initial={{ opacity: 0, y: 30 }}
                  animate={{ opacity: 1, y: 0 }}
                  transition={{ duration: 0.5, ease: 'easeOut' }}
                >
                  <MascotLaptop typingFrame={typingFrame} />
                </motion.g>
              )}

              {/* ── FLOATING ZZZ SLEEP PARTICLES ── */}
              {showZzz && ZZZ_ITEMS.map((z, i) => (
                <motion.text
                  key={`${zzzKey}-${i}`}
                  x={215 + i * 14}
                  y={95}
                  fontSize={16 + i * 6}
                  fontWeight="bold"
                  fill="#60A5FA"
                  initial={{ opacity: 0, y: 0 }}
                  animate={{ opacity: [0, 1, 0], y: -30 - i * 15, x: [0, 6, 12] }}
                  transition={{ duration: 2.2, delay: i * 0.6, repeat: Infinity, ease: 'easeOut' }}
                >
                  {z}
                </motion.text>
              ))}
            </motion.g>
          </svg>
        </motion.div>
      </div>
    )

    return (
      <>
        {mounted && anchorEl ? createPortal(mascotBody, anchorEl) : mascotBody}

        {/* ── SLEEK FLOATING TESTER TOGGLE / MASCOT STUDIO DOCK ── */}
        {mounted && showFloatingToggle && typeof document !== 'undefined'
          ? createPortal(
            <div
              style={{
                position: 'fixed',
                bottom: 24,
                right: 24,
                zIndex: 99999,
                fontFamily: 'var(--font-space-grotesk), sans-serif',
              }}
            >
              {/* Collapsed Pill Button */}
              {!isStudioOpen ? (
                <motion.button
                  whileHover={{ scale: 1.05 }}
                  whileTap={{ scale: 0.95 }}
                  onClick={() => setIsStudioOpen(true)}
                  style={{
                    display: 'flex',
                    alignItems: 'center',
                    gap: 8,
                    padding: '10px 16px',
                    borderRadius: 999,
                    background: 'rgba(17, 17, 17, 0.9)',
                    color: '#FFF',
                    backdropFilter: 'blur(16px)',
                    border: '1px solid rgba(255, 255, 255, 0.15)',
                    boxShadow: '0 8px 32px rgba(0,0,0,0.2)',
                    fontSize: 12,
                    fontWeight: 600,
                    cursor: 'pointer',
                    letterSpacing: '0.02em',
                  }}
                >
                  <span style={{ fontSize: 15 }}>🤖</span>
                  <span>Mascot Studio</span>
                  <span
                    style={{
                      fontSize: 10,
                      background: '#22C8FF',
                      color: '#000',
                      padding: '2px 6px',
                      borderRadius: 99,
                      fontWeight: 700,
                    }}
                  >
                    TEST
                  </span>
                </motion.button>
              ) : (
                /* Expanded Control Panel */
                <motion.div
                  initial={{ opacity: 0, scale: 0.9, y: 20 }}
                  animate={{ opacity: 1, scale: 1, y: 0 }}
                  exit={{ opacity: 0, scale: 0.9, y: 20 }}
                  transition={{ duration: 0.2 }}
                  style={{
                    width: 340,
                    background: 'rgba(255, 255, 255, 0.96)',
                    backdropFilter: 'blur(20px)',
                    borderRadius: 24,
                    border: '1px solid rgba(0, 0, 0, 0.1)',
                    boxShadow: '0 16px 48px rgba(0,0,0,0.18)',
                    padding: 16,
                    color: '#111',
                    fontSize: 12,
                  }}
                >
                  {/* Header */}
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 12, paddingBottom: 8, borderBottom: '1px solid #EEE' }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
                      <span style={{ fontSize: 16 }}>🤖</span>
                      <strong style={{ fontSize: 14 }}>Zero Mascot Studio</strong>
                    </div>
                    <button
                      onClick={() => setIsStudioOpen(false)}
                      style={{
                        background: '#F1F5F9',
                        border: 'none',
                        borderRadius: 99,
                        width: 24,
                        height: 24,
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'center',
                        cursor: 'pointer',
                        fontWeight: 'bold',
                        color: '#64748B',
                      }}
                    >
                      ✕
                    </button>
                  </div>

                  {/* Current Active Status Badge */}
                  <div style={{ display: 'flex', gap: 6, marginBottom: 12, flexWrap: 'wrap' }}>
                    <span style={{ background: '#F0F9FF', border: '1px solid #BAE6FD', color: '#0369A1', padding: '3px 8px', borderRadius: 6, fontSize: 11, fontWeight: 600 }}>
                      🕒 {timeOfDay}
                    </span>
                    <span style={{ background: '#F0FDF4', border: '1px solid #BBF7D0', color: '#15803D', padding: '3px 8px', borderRadius: 6, fontSize: 11, fontWeight: 600 }}>
                      ⛅ {appliedWeather}
                    </span>
                    {forcedAsset && (
                      <span style={{ background: '#FEF3C7', border: '1px solid #FDE68A', color: '#B45309', padding: '3px 8px', borderRadius: 6, fontSize: 11, fontWeight: 600 }}>
                        ⚡ {forcedAsset}
                      </span>
                    )}
                  </div>

                  {/* Actions / Foods */}
                  <div style={{ marginBottom: 12 }}>
                    <span style={{ fontWeight: 700, display: 'block', marginBottom: 6, color: '#64748B', fontSize: 11, textTransform: 'uppercase', letterSpacing: '0.05em' }}>
                      Snacks & Drinks
                    </span>
                    <div style={{ display: 'grid', gridTemplateColumns: 'repeat(2, 1fr)', gap: 6 }}>
                      <button
                        onClick={eatSamosaSequence}
                        style={{ padding: '8px 10px', borderRadius: 10, border: '1px solid #E2E8F0', background: '#FFF', cursor: 'pointer', fontSize: 11, fontWeight: 600, display: 'flex', alignItems: 'center', gap: 6 }}
                      >
                        <span>🥟</span> Samosa Crunch
                      </button>
                      <button
                        onClick={eatNoodlesSequence}
                        style={{ padding: '8px 10px', borderRadius: 10, border: '1px solid #E2E8F0', background: '#FFF', cursor: 'pointer', fontSize: 11, fontWeight: 600, display: 'flex', alignItems: 'center', gap: 6 }}
                      >
                        <span>🍜</span> Noodle Slurp
                      </button>
                      <button
                        onClick={drinkMilkSequence}
                        style={{ padding: '8px 10px', borderRadius: 10, border: '1px solid #E2E8F0', background: '#FFF', cursor: 'pointer', fontSize: 11, fontWeight: 600, display: 'flex', alignItems: 'center', gap: 6 }}
                      >
                        <span>🥛</span> Milk & Wipe
                      </button>
                      <button
                        onClick={drinkChaiSequence}
                        style={{ padding: '8px 10px', borderRadius: 10, border: '1px solid #E2E8F0', background: '#FFF', cursor: 'pointer', fontSize: 11, fontWeight: 600, display: 'flex', alignItems: 'center', gap: 6 }}
                      >
                        <span>☕</span> Chai Sip
                      </button>
                    </div>
                  </div>

                  {/* Time Override */}
                  <div style={{ marginBottom: 12 }}>
                    <span style={{ fontWeight: 700, display: 'block', marginBottom: 6, color: '#64748B', fontSize: 11, textTransform: 'uppercase', letterSpacing: '0.05em' }}>
                      Time of Day
                    </span>
                    <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 4 }}>
                      {(['morning', 'afternoon', 'evening', 'night'] as const).map(t => (
                        <button
                          key={t}
                          onClick={() => { setTimeOfDay(t); setForcedAsset(null) }}
                          style={{
                            padding: '6px 4px',
                            borderRadius: 8,
                            border: timeOfDay === t && !forcedAsset ? '1px solid #22C8FF' : '1px solid #E2E8F0',
                            background: timeOfDay === t && !forcedAsset ? '#E0F2FE' : '#FFF',
                            color: timeOfDay === t && !forcedAsset ? '#0369A1' : '#334155',
                            cursor: 'pointer',
                            fontSize: 10,
                            fontWeight: 600,
                            textTransform: 'capitalize',
                          }}
                        >
                          {t === 'morning' ? '🌅 M' : t === 'afternoon' ? '☀️ A' : t === 'evening' ? '🌆 E' : '🌙 N'}
                        </button>
                      ))}
                    </div>
                  </div>

                  {/* Actions & Scenes */}
                  <div style={{ marginBottom: 12 }}>
                    <span style={{ fontWeight: 700, display: 'block', marginBottom: 6, color: '#64748B', fontSize: 11, textTransform: 'uppercase', letterSpacing: '0.05em' }}>
                      Scenes & Actions
                    </span>
                    <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 6 }}>
                      <button
                        onClick={() => setForcedAsset('laptop')}
                        style={{ padding: '6px 8px', borderRadius: 8, border: '1px solid #E2E8F0', background: '#FFF', cursor: 'pointer', fontSize: 11, fontWeight: 600 }}
                      >
                        💻 Laptop
                      </button>
                      <button
                        onClick={() => { setTimeOfDay('night'); setForcedAsset('bed') }}
                        style={{ padding: '6px 8px', borderRadius: 8, border: '1px solid #E2E8F0', background: '#FFF', cursor: 'pointer', fontSize: 11, fontWeight: 600 }}
                      >
                        🛌 Bed Night
                      </button>
                      <button
                        onClick={() => { setWeather('rain'); setForcedAsset('umbrella') }}
                        style={{ padding: '6px 8px', borderRadius: 8, border: '1px solid #E2E8F0', background: '#FFF', cursor: 'pointer', fontSize: 11, fontWeight: 600 }}
                      >
                        ☂️ Rain
                      </button>
                    </div>
                  </div>

                  {/* Reset to Auto */}
                  <button
                    onClick={() => {
                      setForcedAsset(null)
                      setTimeOfDay(getTimeOfDay())
                      resetPose()
                    }}
                    style={{
                      width: '100%',
                      padding: '8px',
                      borderRadius: 10,
                      background: '#F1F5F9',
                      border: '1px solid #CBD5E1',
                      color: '#475569',
                      fontSize: 11,
                      fontWeight: 700,
                      cursor: 'pointer',
                    }}
                  >
                    ↺ Reset to Live System Clock
                  </button>
                </motion.div>
              )}
            </div>,
            document.body,
          )
          : null}
      </>
    )
  },
)

export default UniversalMascot
