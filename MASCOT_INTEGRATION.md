# Mascot integration guide

Companion doc to `UniversalMascot.tsx`. This file has no code logic in it —
it's the wiring instructions: what to call, when, and with what data, so the
mascot actually reacts to time, weather, and what's happening in the chat
box. Hand both files to the coding agent together.

---

## 1. Time of day

Handled automatically inside the component — nothing to wire up.

`getTimeOfDayMood()` reads the local system clock and maps it to a mood
whenever nothing else (weather, sentiment, manual override) is active:

| Hours       | Mood        |
|-------------|-------------|
| 05:00–07:59 | `dawn`      |
| 08:00–11:59 | `morning`   |
| 12:00–16:59 | `afternoon` |
| 17:00–19:59 | `evening`   |
| 20:00–04:59 | `night`     |

To turn this off (e.g. you want to drive mood entirely yourself), pass
`autoTimeOfDay={false}` on `<UniversalMascot />`.

**Do not** call `setMood()` on a timer to simulate this — the component
already re-resolves ambient mood on its own. Only call `setMood()` for
things the component can't know by itself (weather, sentiment, custom
triggers).

---

## 2. Weather

The mascot has **no built-in weather fetching** — it only knows `rain`,
`hot`, or `clear` as an input. Wherever your app already knows (or fetches)
the weather, translate it and pass it in.

### Option A — prop-driven (recommended for weather that changes rarely)

```tsx
<UniversalMascot
  containerRef={chatBoxRef}
  weather={weatherState}   // "clear" | "rain" | "hot" | null
/>
```

`weather` overrides time-of-day for as long as it's set. Set it back to
`null` to return to the normal day/night cycle.

### Option B — imperative (recommended if weather comes from a polling hook)

```tsx
useEffect(() => {
  if (!weatherFromApi) return;
  if (weatherFromApi.condition === "rain") {
    mascotRef.current?.setMood("rain");
  } else if (weatherFromApi.tempC >= 32) {
    mascotRef.current?.setMood("hot");
  }
}, [weatherFromApi]);
```

### Suggested mapping from a typical weather API

| API condition (example)              | Mascot mood |
|---------------------------------------|-------------|
| `rain`, `drizzle`, `thunderstorm`     | `rain`      |
| temperature ≥ ~32°C / 90°F            | `hot`       |
| anything else                         | leave unset — falls back to time of day |

Don't map every condition (snow, fog, wind) to a mood — the mascot only has
rain/hot accessories today. Unmapped conditions should simply not call
`setMood`, so time-of-day keeps showing.

---

## 3. Chat-box interactivity

This is the "other factors" layer — things that happen *in the
conversation*, not in the outside world.

| Chat event                              | Call                                              | Notes |
|------------------------------------------|----------------------------------------------------|-------|
| New AI or user message rendered          | `mascotRef.current?.reactToMessage(text)`          | Runs sentiment detection; only overrides mood if happy/sad is detected, otherwise no-op. Prefer your model's own sentiment tag over the built-in keyword matcher if you have one — swap the call for `setMood('happy', 3500)` directly. |
| AI reply is explicitly positive/celebratory (thumbs up, task completed, milestone) | `mascotRef.current?.celebrate()` | Happy mood + sparkle + one quick lap around the box. |
| User taps or clicks the mascot           | handled internally, plus fires `onInteract(mood)`  | Use `onInteract` to trigger a sound effect, a toast, or `wave()` from your own click handler if you want a custom response instead of the default bounce. |
| New chat / empty conversation starts     | `mascotRef.current?.wave()`                        | A short greeting animation, no mood change. |
| It's snack/juice/tea time in your product (e.g. a scheduled break reminder, or just for delight at a fixed time) | `mascotRef.current?.setMood('juice' \| 'snack', 8000)` | These are your product's own idea of "activity," not something the engine infers — pick the trigger condition. |
| User goes idle for a while / away        | `mascotRef.current?.setMood('sleep')`              | Clear with `setMood(ambientMood)` or just let it fall back naturally once you stop forcing it — pass no duration and clear manually on the next real interaction. |
| Error / failed message                   | not handled today                                   | If you want a mood for this, add a `"confused"` or reuse `"sad"` — see "Extending" below. |

### Composer avoidance

Every walking frame checks `avoidRect` and refuses to place the mascot
there. Recompute it live rather than hardcoding coordinates, since the
composer resizes (multi-line input, attachments, etc.):

```tsx
avoidRect={() => {
  const composer = document.getElementById("composer");
  if (!composer || !chatBoxRef.current) return null;
  const c = composer.getBoundingClientRect();
  const box = chatBoxRef.current.getBoundingClientRect();
  return { x: c.left - box.left, y: c.top - box.top, width: c.width, height: c.height };
}}
```

If you have other no-walk zones (e.g. a pinned banner), extend this
function to check multiple rects and return whichever one the mascot is
currently closest to violating — `avoidRect` only accepts one rect at a
time today.

---

## 4. Priority order (what wins when multiple things are true)

1. Manual `setMood(mood, duration)` call — always wins while its timer is active.
2. `weather` prop (`rain` / `hot`).
3. Time of day (`dawn` / `morning` / `afternoon` / `evening` / `night`).
4. `idle` fallback if `autoTimeOfDay` is off and nothing else is set.

Sentiment reactions (`reactToMessage`) and `celebrate()` are just
timed calls to `setMood()` under the hood — they follow rule 1, then expire
back to whatever rule 2–4 currently resolves to.

---

## 5. Extending

To add a new mood (e.g. `"confused"` for errors, or `"excited"` for a
special event):

1. Add it to the `MascotMood` union type.
2. Add an entry to `MOOD_ACCENT` (antenna color).
3. Add an eye shape in `Eyes()`.
4. Optionally add an accessory component and register it in `Accessory()`.
5. Trigger it the same way as any other mood: `setMood('confused', 3000)`.

No other part of the walking/interaction engine needs to change — moods are
additive.
