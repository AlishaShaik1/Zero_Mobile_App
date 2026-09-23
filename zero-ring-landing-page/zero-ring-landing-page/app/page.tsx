import Nav from "@/components/zero/Nav"
import Hero from "@/components/zero/Hero"
import Companion from "@/components/zero/Companion"
import AirMouse from "@/components/zero/AirMouse"
import FeaturesGrid from "@/components/zero/FeaturesGrid"
import Specs from "@/components/zero/Specs"
import Pricing from "@/components/zero/Pricing"
import FinalCTA from "@/components/zero/FinalCTA"
import Footer from "@/components/zero/Footer"

export default function ZeroRingPage() {
  return (
    <main>
      <Nav />
      <Hero />
      <Companion />
      <AirMouse />
      <FeaturesGrid />
      <Specs />
      <Pricing />
      <FinalCTA />
      <Footer />
    </main>
  )
}
