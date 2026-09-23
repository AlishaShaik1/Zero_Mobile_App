interface ZeroLogoProps {
  size?: number
  color?: string
}

export default function ZeroLogo({ size = 1, color = "#0A0A0A" }: ZeroLogoProps) {
  // We use the new custom logo image instead of the old SVG.
  // We keep the size prop working to scale the height appropriately.
  // Increased base height multiplier to make the logo larger and more visible
  const h = Math.round(240 * size)

  return (
    <img 
      src="/logo.png?v=2" 
      alt="Zero AI Logo" 
      style={{ 
        height: `${h}px`, 
        width: 'auto', 
        objectFit: 'contain',
        objectPosition: 'left',
        // Optional: If the logo is dark and the footer is dark, CSS filters could be used,
        // but typically a transparent logo looks good. We apply brightness if color is white.
        filter: color === "#FFFFFF" ? 'brightness(0) invert(1)' : 'none'
      }}
      draggable="false"
    />
  )
}

