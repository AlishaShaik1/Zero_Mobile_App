export default function StructuredData() {
  const jsonLd = {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "Product",
        "name": "Zero Ring",
        "image": [
          "https://zero-ring-ai.vercel.app/zero_ring_dragonfly.png"
        ],
        "description": "Zero is not a device. Zero is your AI companion. It talks, thinks, acts — all from your ring. The ultimate wearable AI technology.",
        "brand": {
          "@type": "Brand",
          "name": "Zero"
        },
        "offers": {
          "@type": "Offer",
          "url": "https://zero-ring-ai.vercel.app",
          "priceCurrency": "USD",
          "price": "199.00",
          "itemCondition": "https://schema.org/NewCondition",
          "availability": "https://schema.org/PreOrder",
          "seller": {
            "@type": "Organization",
            "name": "Zero Technologies"
          }
        }
      },
      {
        "@type": "Organization",
        "name": "Zero",
        "url": "https://zero-ring-ai.vercel.app",
        "logo": "https://zero-ring-ai.vercel.app/zero_ring_dragonfly.png",
        "sameAs": [
          "https://twitter.com/ZeroRing",
          "https://instagram.com/ZeroRingAI"
        ]
      },
      {
        "@type": "FAQPage",
        "mainEntity": [
          {
            "@type": "Question",
            "name": "What is the Zero Ring?",
            "acceptedAnswer": {
              "@type": "Answer",
              "text": "The Zero Ring is an AI-powered smart ring that acts as your personal voice assistant. It allows you to speak to an advanced AI directly from your finger."
            }
          },
          {
            "@type": "Question",
            "name": "When does the Zero Ring ship?",
            "acceptedAnswer": {
              "@type": "Answer",
              "text": "The Zero Ring is currently available for pre-order and will begin shipping in Q3 2026."
            }
          }
        ]
      }
    ]
  }

  return (
    <script
      type="application/ld+json"
      dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }}
    />
  )
}
