/* =========================================================================================
 * 0.49" OLED I2C ADDRESS SCANNER & TESTER FOR SEEED STUDIO XIAO ESP32S3 (SENSE)
 * Wiring:
 *   - OLED SDA -> D5 (GPIO 6)
 *   - OLED SCK / SCL -> D6 (GPIO 43)
 *   - OLED VCC -> 3V3
 *   - OLED GND -> GND
 *   - Button -> D1 (GPIO 1 / GPIO 2)
 * =========================================================================================
 */

#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>

#ifdef D5
  #define PIN_SDA D5  // GPIO 6 on XIAO ESP32S3
#else
  #define PIN_SDA 6
#endif

#ifdef D6
  #define PIN_SCL D6  // GPIO 43 on XIAO ESP32S3
#else
  #define PIN_SCL 43
#endif

#ifdef D1
  #define PIN_BTN D1  // D1 on XIAO ESP32S3
#else
  #define PIN_BTN 2
#endif

#define SCREEN_WIDTH 64  // 0.49" OLED is 64x32
#define SCREEN_HEIGHT 32
#define OLED_RESET -1

Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, OLED_RESET);

void setup() {
  Serial.begin(115200);
  unsigned long start = millis();
  while (!Serial && millis() - start < 2500); // Wait for USB Serial

  Serial.println("\n-----------------------------------------------------------");
  Serial.println("🔎 SEEED XIAO ESP32S3: 0.49\" OLED I2C Scanner (D5-SDA / D6-SCK)");
  Serial.println("-----------------------------------------------------------");

  pinMode(PIN_BTN, INPUT_PULLUP);

  // Start I2C on your connected pins: D5 (SDA) and D6 (SCK/SCL)
  Wire.begin(PIN_SDA, PIN_SCL);
  Wire.setClock(400000);
  Serial.println("🔌 I2C initialized on SDA -> D5 (GPIO 6) and SCK/SCL -> D6 (GPIO 43)");

  uint8_t foundAddress = 0;
  int nDevices = 0;

  Serial.println("Scanning I2C bus (0x01 to 0x7E)...");
  for (uint8_t address = 1; address < 127; address++) {
    Wire.beginTransmission(address);
    uint8_t error = Wire.endTransmission();

    if (error == 0) {
      Serial.print("✅ [FOUND] Device at I2C address: 0x");
      if (address < 16) Serial.print("0");
      Serial.print(address, HEX);

      if (address == 0x3C || address == 0x3D) {
        Serial.print("  <-- ⭐ This is your 0.49\" OLED display address!");
        foundAddress = address;
      }
      Serial.println();
      nDevices++;
    }
  }

  if (nDevices == 0) {
    Serial.println("❌ No I2C devices found on D5/D6. Check wiring:");
    Serial.println("   VCC -> 3V3, GND -> GND, SDA -> D5, SCK -> D6");
    return;
  }

  if (foundAddress == 0) foundAddress = 0x3C;

  Serial.print("\nTesting OLED initialization at 0x");
  Serial.print(foundAddress, HEX);
  Serial.println("...");

  if (!display.begin(SSD1306_SWITCHCAPVCC, foundAddress)) {
    Serial.println("❌ SSD1306 allocation failed. Trying 0x3D...");
    display.begin(SSD1306_SWITCHCAPVCC, 0x3D);
  }

  display.clearDisplay();
  display.setTextSize(1);
  display.setTextColor(SSD1306_WHITE);
  display.setCursor(0, 0);
  display.println("XIAO S3");
  display.setCursor(0, 14);
  display.print("0x");
  display.print(foundAddress, HEX);
  display.print(" OK");
  display.drawRect(0, 24, 64, 8, SSD1306_WHITE);
  display.fillRect(2, 26, 60, 4, SSD1306_WHITE);
  display.display();

  Serial.println("🎉 OLED Initialized! Press button on D1 to test input.");
}

void loop() {
  if (digitalRead(PIN_BTN) == LOW) {
    Serial.println("🔘 D1 Button PRESSED!");
    delay(150);
  }
  delay(20);
}
