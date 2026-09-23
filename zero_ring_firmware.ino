// ============================================================================
// ZeroRing.ino — AI smart ring firmware — SINGLE FILE BUILD
// Board: Seeed XIAO ESP32S3 Sense (bare board — no SD card, direct-to-phone)
//
// Push-to-talk only: no wake word, no TFLite, no MPU6050. Hold the button
// on the Home screen to stream mic audio over BLE; release to stop.
//
// Libraries required (Library Manager, Arduino IDE 2.x desktop / cloud):
//   - Adafruit GFX Library
//   - Adafruit SSD1306
//   - Adafruit BusIO            (SSD1306 dependency)
//   - NimBLE-Arduino (2.x)
//   - driver/i2s.h and esp_camera ship with the ESP32 Arduino core — no install
//
// No MPU6050 / Adafruit_Sensor in this build — that library's `sensor_t`
// typedef collided with the one in the ESP32 camera driver headers, and
// there's no motion sensor on this build anyway.
//
// Custom partition scheme required: Tools -> Partition Scheme -> "Huge APP
// (3MB No OTA/1MB SPIFFS)". Camera + BLE will not fit the default table.
//
// BUTTON PIN: D1 on the XIAO ESP32S3 = GPIO2. Confirmed via Seeed's own
// pinout docs — GPIO2 carries no boot-strap/system role, and confirmed
// working on real hardware via a standalone diagnostic sketch (clean
// DOWN/UP transitions, hold duration reported correctly past 1000ms).
//
// BUTTON MAP (single button, D1 = GPIO2):
//   OFF, hold ~1s              -> boot up
//   ASLEEP, single tap         -> wake to Home
//   Home, single tap           -> next screen
//   Home, double tap           -> go to sleep
//   Home, hold past 2s         -> LATCH into audio streaming; keeps
//                                  streaming for as long as you hold,
//                                  no matter how long that is. Release
//                                  to stop. No other timing check runs
//                                  once this latches, so a long
//                                  conversation can never be
//                                  misread as anything else.
//   Settings screen, hold 2s   -> "Power Off?" confirm screen
//   Power-off confirm, tap     -> cancel, back to Settings
//   Power-off confirm, dbltap  -> actually shuts down (deep sleep;
//                                  needs the ~1s boot-hold to wake again)
//   Power-off confirm, 4s idle -> auto-cancel
// ============================================================================

#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
#include <NimBLEDevice.h>
#include <driver/i2s.h>   // legacy IDF I2S driver — present on every ESP32 core
                          // (ESP_I2S.h is new-core-only and isn't available
                          // on Arduino Cloud Editor's pinned core, hence this)
#define I2S_PORT_SPK I2S_NUM_0
#define I2S_PORT_MIC I2S_NUM_1
#include "esp_camera.h"
#include "esp_sleep.h"
#include <WiFi.h>
#include <WebServer.h>
#include <SPIFFS.h>

// ============================================================================
// SECTION 1 — HARDWARE MAP  (was config.h)
// ============================================================================
#ifdef D5
  #define PIN_I2C_SDA D5  // D5 on XIAO ESP32S3 (GPIO 6)
#else
  #define PIN_I2C_SDA 6
#endif

#ifdef D6
  #define PIN_I2C_SCL D6  // D6 on XIAO ESP32S3 (GPIO 43)
#else
  #define PIN_I2C_SCL 43
#endif

#ifdef D1
  #define PIN_BUTTON  D1  // D1 on XIAO ESP32S3 (GPIO 1 / GPIO 2)
#else
  #define PIN_BUTTON  2   // D1 fallback
#endif

#define PIN_I2S_BCLK  7   // D8  -> MAX98357A speaker out
#define PIN_I2S_LRC   8   // D9
#define PIN_I2S_DOUT  9   // D10

#define PIN_MIC_CLK   42  // onboard PDM mic (Sense board), fixed pins
#define PIN_MIC_DATA  41  // onboard PDM mic (Sense board), fixed pins

#define OLED_W 64
#define OLED_H 32
#define OLED_ADDR 0x3C

#define BTN_DEBOUNCE_MS      30
#define BTN_DOUBLE_GAP_MS    600   // 600ms window for double-tap (easier to hit on a ring)
#define BTN_LONG_BOOT_MS     1000   // OFF -> boot
#define AUDIO_HOLD_START_MS  2000   // Home: hold past this -> start streaming
#define POWEROFF_HOLD_MS     2000   // Settings: hold past this -> confirm screen
#define POWEROFF_CONFIRM_TIMEOUT_MS 4000

#define IDLE_TIMEOUT_MS        15000UL
#define VAD_POLL_INTERVAL_MS   200

#define BLE_DEVICE_NAME        "Zero"

// ---- WiFi Hotspot -----------------------------------------------------------
#define WIFI_AP_SSID  "Zero-Ring"
#define WIFI_AP_PASS  "zero1234"
#define WIFI_AP_CHAN  1
#define WIFI_AP_MAX  2       // max simultaneous clients
#define SVC_UUID_MAIN           "6e400001-0000-1000-8000-00805f9b34fb"
#define CHR_UUID_AUDIO_UP        "6e400002-0000-1000-8000-00805f9b34fb" // ring -> phone (mic)
#define CHR_UUID_AUDIO_DOWN      "6e400003-0000-1000-8000-00805f9b34fb" // phone -> ring (AI speech)
#define CHR_UUID_COMMAND         "6e400004-0000-1000-8000-00805f9b34fb" // phone -> ring
#define CHR_UUID_CAPTION         "6e400005-0000-1000-8000-00805f9b34fb" // phone -> ring
#define CHR_UUID_MEDIA           "6e400006-0000-1000-8000-00805f9b34fb" // ring -> phone
#define CHR_UUID_MOUSE            "6e400007-0000-1000-8000-00805f9b34fb" // ring -> phone/PC
// ^ placeholders — match these to your phone app's exact BLE UUIDs before flashing.

// ============================================================================
// SECTION 2 — CAMERA PIN MAP  (was camera_pins.h)
// ============================================================================
#define PWDN_GPIO_NUM     -1
#define RESET_GPIO_NUM    -1
#define XCLK_GPIO_NUM     10
#define SIOD_GPIO_NUM     40
#define SIOC_GPIO_NUM     39
#define Y9_GPIO_NUM       48
#define Y8_GPIO_NUM       11
#define Y7_GPIO_NUM       12
#define Y6_GPIO_NUM       14
#define Y5_GPIO_NUM       16
#define Y4_GPIO_NUM       18
#define Y3_GPIO_NUM       17
#define Y2_GPIO_NUM       15
#define VSYNC_GPIO_NUM    38
#define HREF_GPIO_NUM     47
#define PCLK_GPIO_NUM     13

// ============================================================================
// SECTION 3 — MASCOT BITMAPS
// ============================================================================
#define ZERO_MASCOT_W 40
#define ZERO_MASCOT_H 32


static const uint8_t zero_idle_open[] PROGMEM = {
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x3F,
  0xFF, 0xFF, 0x00, 0x00, 0x3F, 0xFF, 0xFF, 0x00, 0x00, 0xF0, 0x00, 0x03,
  0x80, 0x00, 0x60, 0x00, 0x01, 0x80, 0x00, 0xE0, 0x00, 0x01, 0x80, 0x78,
  0xE0, 0x00, 0x01, 0x80, 0xFC, 0xE0, 0x00, 0x01, 0x80, 0xDC, 0xE0, 0x00,
  0x01, 0x80, 0xCC, 0xE0, 0x40, 0x41, 0x80, 0xDC, 0xE1, 0xF3, 0xE1, 0x80,
  0xDF, 0xE1, 0xF3, 0xE1, 0x80, 0xE0, 0xE1, 0xF3, 0xE1, 0x80, 0x70, 0xE1,
  0xF3, 0xE1, 0x80, 0x3F, 0xE1, 0xF3, 0xE1, 0x80, 0x1F, 0xE0, 0x00, 0x01,
  0x80, 0x00, 0xE0, 0x00, 0x01, 0xE0, 0x00, 0xE0, 0x00, 0x01, 0xF0, 0x00,
  0xE0, 0x00, 0x01, 0xD8, 0x00, 0xE0, 0x00, 0x01, 0xCC, 0x00, 0xF0, 0x03,
  0x83, 0xE4, 0x00, 0x3F, 0xFF, 0xFF, 0xE4, 0x00, 0x3F, 0xFF, 0xFF, 0xC4,
  0x00, 0x1F, 0x80, 0x3E, 0xFC, 0x00, 0x19, 0x80, 0x26, 0xFC, 0x00, 0x39,
  0xC0, 0x67, 0x78, 0x00, 0x79, 0xC0, 0xCB, 0x00, 0x00, 0x70, 0xC0, 0xE3,
  0x00, 0x03, 0xFF, 0xFF, 0xFF, 0xF0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00,
};

static const uint8_t zero_idle_closed[] PROGMEM = {
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x3F,
  0xFF, 0xFF, 0x00, 0x00, 0x3F, 0xFF, 0xFF, 0x00, 0x00, 0xF0, 0x00, 0x03,
  0x80, 0x00, 0x60, 0x00, 0x01, 0x80, 0x00, 0xE0, 0x00, 0x01, 0x80, 0x78,
  0xE0, 0x00, 0x01, 0x80, 0xFC, 0xE0, 0x00, 0x01, 0x80, 0xDC, 0xE0, 0x00,
  0x01, 0x80, 0xCC, 0xE0, 0x40, 0x41, 0x80, 0xDC, 0xE0, 0x00, 0x01, 0x80,
  0xDF, 0xE0, 0x00, 0x01, 0x80, 0xE0, 0xE0, 0x00, 0x01, 0x80, 0x70, 0xE0,
  0x10, 0x01, 0x80, 0x3F, 0xE0, 0x12, 0x01, 0x80, 0x1F, 0xE0, 0x00, 0x01,
  0x80, 0x00, 0xE0, 0x00, 0x01, 0xE0, 0x00, 0xE0, 0x00, 0x01, 0xF0, 0x00,
  0xE0, 0x00, 0x01, 0xD8, 0x00, 0xE0, 0x00, 0x01, 0xCC, 0x00, 0xF0, 0x03,
  0x83, 0xE4, 0x00, 0x3F, 0xFF, 0xFF, 0xE4, 0x00, 0x3F, 0xFF, 0xFF, 0xC4,
  0x00, 0x1F, 0x80, 0x3E, 0xFC, 0x00, 0x19, 0x80, 0x26, 0xFC, 0x00, 0x39,
  0xC0, 0x67, 0x78, 0x00, 0x79, 0xC0, 0xCB, 0x00, 0x00, 0x70, 0xC0, 0xE3,
  0x00, 0x03, 0xFF, 0xFF, 0xFF, 0xF0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00,
};

#define ZERO_BOOT_FRAMES 13

static const uint8_t zero_boot_0[] PROGMEM = {
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x3F,
  0xFF, 0xFF, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00,
};

static const uint8_t zero_boot_1[] PROGMEM = {
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x3F,
  0xFF, 0xFF, 0x00, 0x00, 0x3F, 0xFF, 0xFF, 0x00, 0x00, 0xF0, 0x00, 0x03,
  0x80, 0x00, 0x60, 0x00, 0x01, 0x80, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00,
};

static const uint8_t zero_boot_2[] PROGMEM = {
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x3F,
  0xFF, 0xFF, 0x00, 0x00, 0x3F, 0xFF, 0xFF, 0x00, 0x00, 0xF0, 0x00, 0x03,
  0x80, 0x00, 0x60, 0x00, 0x01, 0x80, 0x00, 0xE0, 0x00, 0x01, 0x80, 0x78,
  0xE0, 0x00, 0x01, 0x80, 0xFC, 0xE0, 0x00, 0x01, 0x80, 0xDC, 0xE0, 0x00,
  0x01, 0x80, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00,
};

static const uint8_t zero_boot_3[] PROGMEM = {
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x3F,
  0xFF, 0xFF, 0x00, 0x00, 0x3F, 0xFF, 0xFF, 0x00, 0x00, 0xF0, 0x00, 0x03,
  0x80, 0x00, 0x60, 0x00, 0x01, 0x80, 0x00, 0xE0, 0x00, 0x01, 0x80, 0x78,
  0xE0, 0x00, 0x01, 0x80, 0xFC, 0xE0, 0x00, 0x01, 0x80, 0xDC, 0xE0, 0x00,
  0x01, 0x80, 0xCC, 0xE0, 0x40, 0x41, 0x80, 0xDC, 0xE1, 0xF3, 0xE1, 0x80,
  0xDF, 0xE1, 0xF3, 0xE1, 0x80, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00,
};

static const uint8_t zero_boot_4[] PROGMEM = {
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x3F,
  0xFF, 0xFF, 0x00, 0x00, 0x3F, 0xFF, 0xFF, 0x00, 0x00, 0xF0, 0x00, 0x03,
  0x80, 0x00, 0x60, 0x00, 0x01, 0x80, 0x00, 0xE0, 0x00, 0x01, 0x80, 0x78,
  0xE0, 0x00, 0x01, 0x80, 0xFC, 0xE0, 0x00, 0x01, 0x80, 0xDC, 0xE0, 0x00,
  0x01, 0x80, 0xCC, 0xE0, 0x40, 0x41, 0x80, 0xDC, 0xE1, 0xF3, 0xE1, 0x80,
  0xDF, 0xE1, 0xF3, 0xE1, 0x80, 0xE0, 0xE1, 0xF3, 0xE1, 0x80, 0x70, 0xE1,
  0xF3, 0xE1, 0x80, 0x3F, 0xE1, 0xF3, 0xE1, 0x80, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00,
};

static const uint8_t zero_boot_5[] PROGMEM = {
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x3F,
  0xFF, 0xFF, 0x00, 0x00, 0x3F, 0xFF, 0xFF, 0x00, 0x00, 0xF0, 0x00, 0x03,
  0x80, 0x00, 0x60, 0x00, 0x01, 0x80, 0x00, 0xE0, 0x00, 0x01, 0x80, 0x78,
  0xE0, 0x00, 0x01, 0x80, 0xFC, 0xE0, 0x00, 0x01, 0x80, 0xDC, 0xE0, 0x00,
  0x01, 0x80, 0xCC, 0xE0, 0x40, 0x41, 0x80, 0xDC, 0xE1, 0xF3, 0xE1, 0x80,
  0xDF, 0xE1, 0xF3, 0xE1, 0x80, 0xE0, 0xE1, 0xF3, 0xE1, 0x80, 0x70, 0xE1,
  0xF3, 0xE1, 0x80, 0x3F, 0xE1, 0xF3, 0xE1, 0x80, 0x1F, 0xE0, 0x00, 0x01,
  0x80, 0x00, 0xE0, 0x00, 0x01, 0xE0, 0x00, 0xE0, 0x00, 0x01, 0xF0, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00,
};

static const uint8_t zero_boot_6[] PROGMEM = {
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x3F,
  0xFF, 0xFF, 0x00, 0x00, 0x3F, 0xFF, 0xFF, 0x00, 0x00, 0xF0, 0x00, 0x03,
  0x80, 0x00, 0x60, 0x00, 0x01, 0x80, 0x00, 0xE0, 0x00, 0x01, 0x80, 0x78,
  0xE0, 0x00, 0x01, 0x80, 0xFC, 0xE0, 0x00, 0x01, 0x80, 0xDC, 0xE0, 0x00,
  0x01, 0x80, 0xCC, 0xE0, 0x40, 0x41, 0x80, 0xDC, 0xE1, 0xF3, 0xE1, 0x80,
  0xDF, 0xE1, 0xF3, 0xE1, 0x80, 0xE0, 0xE1, 0xF3, 0xE1, 0x80, 0x70, 0xE1,
  0xF3, 0xE1, 0x80, 0x3F, 0xE1, 0xF3, 0xE1, 0x80, 0x1F, 0xE0, 0x00, 0x01,
  0x80, 0x00, 0xE0, 0x00, 0x01, 0xE0, 0x00, 0xE0, 0x00, 0x01, 0xF0, 0x00,
  0xE0, 0x00, 0x01, 0xD8, 0x00, 0xE0, 0x00, 0x01, 0xCC, 0x00, 0xF0, 0x03,
  0x83, 0xE4, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00,
};

static const uint8_t zero_boot_7[] PROGMEM = {
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x3F,
  0xFF, 0xFF, 0x00, 0x00, 0x3F, 0xFF, 0xFF, 0x00, 0x00, 0xF0, 0x00, 0x03,
  0x80, 0x00, 0x60, 0x00, 0x01, 0x80, 0x00, 0xE0, 0x00, 0x01, 0x80, 0x78,
  0xE0, 0x00, 0x01, 0x80, 0xFC, 0xE0, 0x00, 0x01, 0x80, 0xDC, 0xE0, 0x00,
  0x01, 0x80, 0xCC, 0xE0, 0x40, 0x41, 0x80, 0xDC, 0xE1, 0xF3, 0xE1, 0x80,
  0xDF, 0xE1, 0xF3, 0xE1, 0x80, 0xE0, 0xE1, 0xF3, 0xE1, 0x80, 0x70, 0xE1,
  0xF3, 0xE1, 0x80, 0x3F, 0xE1, 0xF3, 0xE1, 0x80, 0x1F, 0xE0, 0x00, 0x01,
  0x80, 0x00, 0xE0, 0x00, 0x01, 0xE0, 0x00, 0xE0, 0x00, 0x01, 0xF0, 0x00,
  0xE0, 0x00, 0x01, 0xD8, 0x00, 0xE0, 0x00, 0x01, 0xCC, 0x00, 0xF0, 0x03,
  0x83, 0xE4, 0x00, 0x3F, 0xFF, 0xFF, 0xE4, 0x00, 0x3F, 0xFF, 0xFF, 0xC4,
  0x00, 0x1F, 0x80, 0x3E, 0xFC, 0x00, 0x19, 0x80, 0x26, 0xFC, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00,
};

static const uint8_t zero_boot_8[] PROGMEM = {
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x3F,
  0xFF, 0xFF, 0x00, 0x00, 0x3F, 0xFF, 0xFF, 0x00, 0x00, 0xF0, 0x00, 0x03,
  0x80, 0x00, 0x60, 0x00, 0x01, 0x80, 0x00, 0xE0, 0x00, 0x01, 0x80, 0x78,
  0xE0, 0x00, 0x01, 0x80, 0xFC, 0xE0, 0x00, 0x01, 0x80, 0xDC, 0xE0, 0x00,
  0x01, 0x80, 0xCC, 0xE0, 0x40, 0x41, 0x80, 0xDC, 0xE1, 0xF3, 0xE1, 0x80,
  0xDF, 0xE1, 0xF3, 0xE1, 0x80, 0xE0, 0xE1, 0xF3, 0xE1, 0x80, 0x70, 0xE1,
  0xF3, 0xE1, 0x80, 0x3F, 0xE1, 0xF3, 0xE1, 0x80, 0x1F, 0xE0, 0x00, 0x01,
  0x80, 0x00, 0xE0, 0x00, 0x01, 0xE0, 0x00, 0xE0, 0x00, 0x01, 0xF0, 0x00,
  0xE0, 0x00, 0x01, 0xD8, 0x00, 0xE0, 0x00, 0x01, 0xCC, 0x00, 0xF0, 0x03,
  0x83, 0xE4, 0x00, 0x3F, 0xFF, 0xFF, 0xE4, 0x00, 0x3F, 0xFF, 0xFF, 0xC4,
  0x00, 0x1F, 0x80, 0x3E, 0xFC, 0x00, 0x19, 0x80, 0x26, 0xFC, 0x00, 0x39,
  0xC0, 0x67, 0x78, 0x00, 0x79, 0xC0, 0xCB, 0x00, 0x00, 0x70, 0xC0, 0xE3,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00,
};

static const uint8_t zero_boot_9[] PROGMEM = {
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x3F,
  0xFF, 0xFF, 0x00, 0x00, 0x3F, 0xFF, 0xFF, 0x00, 0x00, 0xF0, 0x00, 0x03,
  0x80, 0x00, 0x60, 0x00, 0x01, 0x80, 0x00, 0xE0, 0x00, 0x01, 0x80, 0x78,
  0xE0, 0x00, 0x01, 0x80, 0xFC, 0xE0, 0x00, 0x01, 0x80, 0xDC, 0xE0, 0x00,
  0x01, 0x80, 0xCC, 0xE0, 0x40, 0x41, 0x80, 0xDC, 0xE1, 0xF3, 0xE1, 0x80,
  0xDF, 0xE1, 0xF3, 0xE1, 0x80, 0xE0, 0xE1, 0xF3, 0xE1, 0x80, 0x70, 0xE1,
  0xF3, 0xE1, 0x80, 0x3F, 0xE1, 0xF3, 0xE1, 0x80, 0x1F, 0xE0, 0x00, 0x01,
  0x80, 0x00, 0xE0, 0x00, 0x01, 0xE0, 0x00, 0xE0, 0x00, 0x01, 0xF0, 0x00,
  0xE0, 0x00, 0x01, 0xD8, 0x00, 0xE0, 0x00, 0x01, 0xCC, 0x00, 0xF0, 0x03,
  0x83, 0xE4, 0x00, 0x3F, 0xFF, 0xFF, 0xE4, 0x00, 0x3F, 0xFF, 0xFF, 0xC4,
  0x00, 0x1F, 0x80, 0x3E, 0xFC, 0x00, 0x19, 0x80, 0x26, 0xFC, 0x00, 0x39,
  0xC0, 0x67, 0x78, 0x00, 0x79, 0xC0, 0xCB, 0x00, 0x00, 0x70, 0xC0, 0xE3,
  0x00, 0x03, 0xFF, 0xFF, 0xFF, 0xF0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00,
};

static const uint8_t zero_boot_10[] PROGMEM = {
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x3F,
  0xFF, 0xFF, 0x00, 0x00, 0x3F, 0xFF, 0xFF, 0x00, 0x00, 0xF0, 0x00, 0x03,
  0x80, 0x00, 0x60, 0x00, 0x01, 0x80, 0x00, 0xE0, 0x00, 0x01, 0x80, 0x78,
  0xE0, 0x00, 0x01, 0x80, 0xFC, 0xE0, 0x00, 0x01, 0x80, 0xDC, 0xE0, 0x00,
  0x01, 0x80, 0xCC, 0xE0, 0x40, 0x41, 0x80, 0xDC, 0xE1, 0xF3, 0xE1, 0x80,
  0xDF, 0xE1, 0xF3, 0xE1, 0x80, 0xE0, 0xE1, 0xF3, 0xE1, 0x80, 0x70, 0xE1,
  0xF3, 0xE1, 0x80, 0x3F, 0xE1, 0xF3, 0xE1, 0x80, 0x1F, 0xE0, 0x00, 0x01,
  0x80, 0x00, 0xE0, 0x00, 0x01, 0xE0, 0x00, 0xE0, 0x00, 0x01, 0xF0, 0x00,
  0xE0, 0x00, 0x01, 0xD8, 0x00, 0xE0, 0x00, 0x01, 0xCC, 0x00, 0xF0, 0x03,
  0x83, 0xE4, 0x00, 0x3F, 0xFF, 0xFF, 0xE4, 0x00, 0x3F, 0xFF, 0xFF, 0xC4,
  0x00, 0x1F, 0x80, 0x3E, 0xFC, 0x00, 0x19, 0x80, 0x26, 0xFC, 0x00, 0x39,
  0xC0, 0x67, 0x78, 0x00, 0x79, 0xC0, 0xCB, 0x00, 0x00, 0x70, 0xC0, 0xE3,
  0x00, 0x03, 0xFF, 0xFF, 0xFF, 0xF0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00,
};

static const uint8_t zero_boot_11[] PROGMEM = {
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x3F,
  0xFF, 0xFF, 0x00, 0x00, 0x3F, 0xFF, 0xFF, 0x00, 0x00, 0xF0, 0x00, 0x03,
  0x80, 0x00, 0x60, 0x00, 0x01, 0x80, 0x00, 0xE0, 0x00, 0x01, 0x80, 0x78,
  0xE0, 0x00, 0x01, 0x80, 0xFC, 0xE0, 0x00, 0x01, 0x80, 0xDC, 0xE0, 0x00,
  0x01, 0x80, 0xCC, 0xE0, 0x40, 0x41, 0x80, 0xDC, 0xE0, 0x00, 0x01, 0x80,
  0xDF, 0xE0, 0x00, 0x01, 0x80, 0xE0, 0xE0, 0x00, 0x01, 0x80, 0x70, 0xE0,
  0x10, 0x01, 0x80, 0x3F, 0xE0, 0x12, 0x01, 0x80, 0x1F, 0xE0, 0x00, 0x01,
  0x80, 0x00, 0xE0, 0x00, 0x01, 0xE0, 0x00, 0xE0, 0x00, 0x01, 0xF0, 0x00,
  0xE0, 0x00, 0x01, 0xD8, 0x00, 0xE0, 0x00, 0x01, 0xCC, 0x00, 0xF0, 0x03,
  0x83, 0xE4, 0x00, 0x3F, 0xFF, 0xFF, 0xE4, 0x00, 0x3F, 0xFF, 0xFF, 0xC4,
  0x00, 0x1F, 0x80, 0x3E, 0xFC, 0x00, 0x19, 0x80, 0x26, 0xFC, 0x00, 0x39,
  0xC0, 0x67, 0x78, 0x00, 0x79, 0xC0, 0xCB, 0x00, 0x00, 0x70, 0xC0, 0xE3,
  0x00, 0x03, 0xFF, 0xFF, 0xFF, 0xF0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00,
};

static const uint8_t zero_boot_12[] PROGMEM = {
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x3F,
  0xFF, 0xFF, 0x00, 0x00, 0x3F, 0xFF, 0xFF, 0x00, 0x00, 0xF0, 0x00, 0x03,
  0x80, 0x00, 0x60, 0x00, 0x01, 0x80, 0x00, 0xE0, 0x00, 0x01, 0x80, 0x78,
  0xE0, 0x00, 0x01, 0x80, 0xFC, 0xE0, 0x00, 0x01, 0x80, 0xDC, 0xE0, 0x00,
  0x01, 0x80, 0xCC, 0xE0, 0x40, 0x41, 0x80, 0xDC, 0xE1, 0xF3, 0xE1, 0x80,
  0xDF, 0xE1, 0xF3, 0xE1, 0x80, 0xE0, 0xE1, 0xF3, 0xE1, 0x80, 0x70, 0xE1,
  0xF3, 0xE1, 0x80, 0x3F, 0xE1, 0xF3, 0xE1, 0x80, 0x1F, 0xE0, 0x00, 0x01,
  0x80, 0x00, 0xE0, 0x00, 0x01, 0xE0, 0x00, 0xE0, 0x00, 0x01, 0xF0, 0x00,
  0xE0, 0x00, 0x01, 0xD8, 0x00, 0xE0, 0x00, 0x01, 0xCC, 0x00, 0xF0, 0x03,
  0x83, 0xE4, 0x00, 0x3F, 0xFF, 0xFF, 0xE4, 0x00, 0x3F, 0xFF, 0xFF, 0xC4,
  0x00, 0x1F, 0x80, 0x3E, 0xFC, 0x00, 0x19, 0x80, 0x26, 0xFC, 0x00, 0x39,
  0xC0, 0x67, 0x78, 0x00, 0x79, 0xC0, 0xCB, 0x00, 0x00, 0x70, 0xC0, 0xE3,
  0x00, 0x03, 0xFF, 0xFF, 0xFF, 0xF0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00,
};

static const uint8_t* const zero_idle_frames[2] PROGMEM = {
  zero_idle_open,
  zero_idle_closed
};

static const uint8_t* const zero_boot_frames[ZERO_BOOT_FRAMES] PROGMEM = {
  zero_boot_0,  zero_boot_1,  zero_boot_2,  zero_boot_3,
  zero_boot_4,  zero_boot_5,  zero_boot_6,  zero_boot_7,
  zero_boot_8,  zero_boot_9,  zero_boot_10, zero_boot_11,
  zero_boot_12
};

// ============================================================================
// SECTION 4 — GLOBAL STATE
// ============================================================================
Adafruit_SSD1306 display(OLED_W, OLED_H, &Wire, -1);
// Legacy driver/i2s.h is C-style (i2s_write/i2s_read on a port number),
// so no speaker/mic objects needed — just the two port IDs above.

enum PowerState { PWR_OFF, PWR_BOOTING, PWR_AWAKE, PWR_ASLEEP, PWR_SHUTTING_DOWN };
enum Screen {
  SCR_HOME,        // 0 — Clock + Mascot
  SCR_AI,          // 1 — AI Ornith status (listening / thinking / response)
  SCR_TIMER,       // 2 — Stopwatch / Countdown
  SCR_STEPS,       // 3 — Step counter / Health ring
  SCR_WEATHER,     // 4 — Weather (synced from phone)
  SCR_MUSIC,       // 5 — Now Playing / media controls
  SCR_NOTES,       // 6 — Quick voice note
  SCR_NOTIFY,      // 7 — Notification (last BLE message)
  SCR_CAMERA,      // 8 — Camera trigger
  SCR_TORCH,       // 9 — Flashlight (BLE relay to phone)
  SCR_BATTERY,     // 10 — Battery + BLE status
  SCR_WIFI,        // 11 — WiFi Hotspot status (ALWAYS ON from boot)
  SCR_SETTINGS,    // 12 — Settings + power-off
  SCR_COUNT
};
enum Expression { EXPR_IDLE, EXPR_HAPPY, EXPR_LISTENING, EXPR_THINKING, EXPR_SPEAKING, EXPR_LOWBATT };

PowerState powerState = PWR_OFF;
Screen currentScreen = SCR_HOME;
Expression currentExpr = EXPR_IDLE;

unsigned long lastActivityMs = 0;
unsigned long screenFrameTimer = 0;
uint8_t mascotFrameIdx = 0;

String aiCaption = "";
bool airMouseActive = false;

// ---- Per-screen state -------------------------------------------------------
// Timer screen
unsigned long timerStartMs = 0;
bool timerRunning = false;
unsigned long timerElapsedMs = 0; // saved elapsed when paused

// Steps screen
uint32_t stepCount = 0;
float heartRate = 72.0f; // placeholder; update via BLE caption

// Weather screen (updated via BLE caption)
char weatherLine1[16] = "Connecting...";
char weatherLine2[16] = "";

// Music screen
char musicTitle[16]  = "No track";
char musicArtist[16] = "";
bool musicPlaying = false;

// Notification screen
char notifApp[16]  = "";
char notifText[32] = "No notifications";

// Torch state
bool torchOn = false;

// Push-to-talk streaming state.
bool audioStreaming = false;

// WiFi + Camera web server state
WebServer camServer(80);
bool wifiAPEnabled = false;      // OFF by default — toggle from HOTSPOT screen
bool wifiClientConnected = false;
bool cameraReady = false;
uint32_t photoCount = 0;         // increments each capture; used for filenames

// Power-off confirmation
bool powerOffConfirmActive = false;
unsigned long powerOffConfirmAt = 0;

// BLE server + characteristic handles — declared here so screen draw
// functions (drawBatteryScreen, handleStatus) can check connection state
// without a forward reference error.
NimBLEServer*         bleServer   = nullptr;
NimBLECharacteristic* chrAudioUp  = nullptr;
NimBLECharacteristic* chrAudioDown= nullptr;
NimBLECharacteristic* chrCommand  = nullptr;
NimBLECharacteristic* chrCaption  = nullptr;
NimBLECharacteristic* chrMedia    = nullptr;
NimBLECharacteristic* chrMouse    = nullptr;

// ---- Button FSM state (non-blocking debounce version) --------------------
enum BtnPhase { BTN_IDLE, BTN_DOWN, BTN_WAIT_DOUBLE, BTN_HOLDING };
BtnPhase btnPhase = BTN_IDLE;
unsigned long btnDownAt = 0;
unsigned long btnUpAt = 0;

bool btnLastReading = HIGH;   // last raw digitalRead()
bool btnStableState = HIGH;   // debounced state actually acted on
unsigned long btnLastEdgeMs = 0;

void markActivity() { lastActivityMs = millis(); }

// Forward declarations
void handleButton();
void onSingleTap();
void onDoubleTap();
void bootFromOff();
void enterAwake();
void enterAsleep();
void enterShutdown();
void goDeepSleepUntilInterrupt();
void nextScreen();
void nextListItem();
void confirmScreen();
void drawHoldProgress(float pct);
void drawHomeScreen();
void drawAIScreen();
void drawTimerScreen();
void drawStepsScreen();
void drawWeatherScreen();
void drawMusicScreen();
void drawNotesScreen();
void drawNotifyScreen();
void drawCameraScreen();
void drawTorchScreen();
void drawBatteryScreen();
void drawWiFiScreen();
void drawSettingsScreen();
void drawGenericScreen(const char* title, const char* body);
void updateMascotAnimation();
void playBootAnimation();
void playShutdownAnimation();
// WiFi / Camera / Web server
bool initCamera();
void setupWiFiAP();
void toggleWiFiAP();
void setupWebServer();
void handleRoot();
void handleStream();
void handleCapture();
void handleGallery();
void handlePhoto();
void handleDelete();
void handleStatus();
void setupBLE();
void startAudioStreamHold();
void stopAudioStreamHold();
void streamAudioChunk();
void showPowerOffConfirm();
void cancelPowerOffConfirm();
void confirmPowerOff();
void initCameraIfNeeded();
void deinitCamera();
void captureAndSendPhoto();
void startVideoRecording();
void startAudioRecording();
void saveVoiceNote();
void airMouseLoop();

uint8_t detectedOledAddr = OLED_ADDR;

uint8_t autoDetectOLEDAddress() {
  Serial.println(F("\n=================================================="));
  Serial.println(F("🔍 XIAO ESP32S3: Scanning I2C Bus on D5(SDA) & D6(SCL)..."));
  Serial.println(F("=================================================="));
  uint8_t detected = 0x00;
  for (uint8_t addr = 1; addr < 127; addr++) {
    Wire.beginTransmission(addr);
    if (Wire.endTransmission() == 0) {
      Serial.print(F("✅ [FOUND] Device at I2C address: 0x"));
      if (addr < 16) Serial.print(F("0"));
      Serial.print(addr, HEX);
      if (addr == 0x3C || addr == 0x3D) {
        Serial.print(F("  <-- ⭐ 0.49\" OLED MATCH!"));
        if (detected == 0x00) detected = addr;
      }
      Serial.println();
    }
  }
  if (detected == 0x00) {
    detected = OLED_ADDR;
    Serial.println(F("⚠️ OLED not found in auto-scan, defaulting to 0x3C"));
  } else {
    Serial.print(F("🎉 0.49\" OLED detected at address: 0x"));
    Serial.println(detected, HEX);
  }
  Serial.println(F("==================================================\n"));
  return detected;
}

// ============================================================================
// SECTION 6 — setup / loop
// ============================================================================
void setup() {
  Serial.begin(115200);

  pinMode(PIN_BUTTON, INPUT_PULLUP);

  Wire.begin(PIN_I2C_SDA, PIN_I2C_SCL);
  Wire.setClock(400000);

  // Runtime Auto-Detect 0.49" OLED Address (0x3C or 0x3D)
  detectedOledAddr = autoDetectOLEDAddress();
  if (!display.begin(SSD1306_SWITCHCAPVCC, detectedOledAddr)) {
    uint8_t altAddr = (detectedOledAddr == 0x3C) ? 0x3D : 0x3C;
    display.begin(SSD1306_SWITCHCAPVCC, altAddr);
  }
  // CRITICAL: Clear the Adafruit splash screen that begin() draws automatically.
  // Without this you get random noise / the Adafruit logo instead of your mascot.
  display.clearDisplay();
  display.display();
  display.setTextColor(SSD1306_WHITE);
  display.setTextSize(1);
  display.cp437(true);

  // Speaker: standard I2S out to the MAX98357A
  i2s_config_t spkConfig = {
    .mode = (i2s_mode_t)(I2S_MODE_MASTER | I2S_MODE_TX),
    .sample_rate = 16000,
    .bits_per_sample = I2S_BITS_PER_SAMPLE_16BIT,
    .channel_format = I2S_CHANNEL_FMT_ONLY_LEFT,
    .communication_format = I2S_COMM_FORMAT_STAND_I2S,
    .intr_alloc_flags = ESP_INTR_FLAG_LEVEL1,
    .dma_buf_count = 4,
    .dma_buf_len = 256,
  };
  i2s_pin_config_t spkPins = {
    .bck_io_num = PIN_I2S_BCLK,
    .ws_io_num = PIN_I2S_LRC,
    .data_out_num = PIN_I2S_DOUT,
    .data_in_num = I2S_PIN_NO_CHANGE,
  };
  i2s_driver_install(I2S_PORT_SPK, &spkConfig, 0, NULL);
  i2s_set_pin(I2S_PORT_SPK, &spkPins);

  // Mic: PDM in from the onboard mic
  i2s_config_t micConfig = {
    .mode = (i2s_mode_t)(I2S_MODE_MASTER | I2S_MODE_RX | I2S_MODE_PDM),
    .sample_rate = 16000,
    .bits_per_sample = I2S_BITS_PER_SAMPLE_16BIT,
    .channel_format = I2S_CHANNEL_FMT_ONLY_LEFT,
    .communication_format = I2S_COMM_FORMAT_STAND_I2S,
    .intr_alloc_flags = ESP_INTR_FLAG_LEVEL1,
    .dma_buf_count = 4,
    .dma_buf_len = 256,
  };
  i2s_pin_config_t micPins = {
    .bck_io_num = I2S_PIN_NO_CHANGE,
    .ws_io_num = PIN_MIC_CLK,
    .data_out_num = I2S_PIN_NO_CHANGE,
    .data_in_num = PIN_MIC_DATA,
  };
  if (i2s_driver_install(I2S_PORT_MIC, &micConfig, 0, NULL) != ESP_OK ||
      i2s_set_pin(I2S_PORT_MIC, &micPins) != ESP_OK) {
    Serial.println("Mic init failed - check onboard PDM mic");
  }

  setupBLE();

  // Init SPIFFS for photo storage (always mounted — needed for BLE too)
  if (!SPIFFS.begin(true)) {
    Serial.println("SPIFFS mount failed — photos won't persist");
  } else {
    File root = SPIFFS.open("/");
    File f = root.openNextFile();
    while (f) { photoCount++; f = root.openNextFile(); }
  }

  // WiFi AP and Camera are OFF at boot — user enables from HOTSPOT screen.
  // This saves significant battery when the camera web UI isn't needed.
  WiFi.mode(WIFI_OFF);  // ensure radio off from the start
  Serial.println("WiFi OFF at boot. Go to HOTSPOT screen + double-tap to enable.");

  lastActivityMs = millis();
  bootFromOff(); // Turn on screen and play boot animation
}

void loop() {
  handleButton();

  // Web server — only runs when user has enabled WiFi from the HOTSPOT screen
  if (wifiAPEnabled) {
    wifiClientConnected = (WiFi.softAPgetStationNum() > 0);
    camServer.handleClient();
  }

  switch (powerState) {
    case PWR_OFF:
    case PWR_BOOTING:
    case PWR_SHUTTING_DOWN:
      break;

    case PWR_AWAKE: {
      updateMascotAnimation();

      if (audioStreaming) {
        streamAudioChunk();
        markActivity();
      } else if (airMouseActive) {
        airMouseLoop();
      }

      if (!powerOffConfirmActive && (millis() - lastActivityMs > IDLE_TIMEOUT_MS)) {
        enterAsleep();
      }
      break;
    }

    case PWR_ASLEEP:
      break;
  }
}

// ============================================================================
// SECTION 7 — BUTTON FSM (non-blocking debounce — no delay() calls)
// ============================================================================
void handleButton() {
  bool reading = digitalRead(PIN_BUTTON);
  unsigned long now = millis();

  // Track the raw edge time, then only commit to a new stable state once
  // it's held steady for BTN_DEBOUNCE_MS. No delay() anywhere in here —
  // this function must return every loop() tick so audio streaming,
  // BLE, and the idle timer all keep running smoothly while the button
  // is being watched.
  if (reading != btnLastReading) {
    btnLastEdgeMs = now;
    btnLastReading = reading;
  }
  bool justDebounced = false;
  if ((now - btnLastEdgeMs) > BTN_DEBOUNCE_MS && btnStableState != btnLastReading) {
    btnStableState = btnLastReading;
    justDebounced = true;
  }

  // ---- Falling edge: button just went down (debounced) ----
  if (justDebounced && btnStableState == LOW) {
    if (btnPhase == BTN_WAIT_DOUBLE && (now - btnUpAt) < BTN_DOUBLE_GAP_MS) {
      btnPhase = BTN_IDLE;
      onDoubleTap();
    } else {
      btnPhase = BTN_DOWN;
      btnDownAt = now;
    }
  }

  // ---- Held low: evaluate hold thresholds every tick while pressed ----
  if (btnStableState == LOW && (btnPhase == BTN_DOWN || btnPhase == BTN_HOLDING)) {
    unsigned long held = now - btnDownAt;

    if (powerState == PWR_OFF) {
      if (btnPhase == BTN_DOWN && held > BTN_LONG_BOOT_MS) {
        btnPhase = BTN_HOLDING;
        bootFromOff();
      }
    } else if (audioStreaming) {
      // Latched. Nothing to evaluate here — streamAudioChunk() in loop()
      // handles it every cycle for as long as the button is held.
    } else if (powerOffConfirmActive) {
      // No hold action on the confirm screen — only taps.
    } else if (currentScreen == SCR_HOME) {
      if (btnPhase == BTN_DOWN && held > AUDIO_HOLD_START_MS) {
        btnPhase = BTN_HOLDING;
        startAudioStreamHold();
      } else if (btnPhase == BTN_DOWN) {
        drawHoldProgress((float)held / (float)AUDIO_HOLD_START_MS);
      }
    } else if (currentScreen == SCR_SETTINGS) {
      if (btnPhase == BTN_DOWN && held > POWEROFF_HOLD_MS) {
        btnPhase = BTN_HOLDING;
        showPowerOffConfirm();
      } else if (btnPhase == BTN_DOWN) {
        drawHoldProgress((float)held / (float)POWEROFF_HOLD_MS);
      }
    }
  }

  // ---- Rising edge: button just released (debounced) ----
  if (justDebounced && btnStableState == HIGH) {
    if (audioStreaming) {
      stopAudioStreamHold();
      btnPhase = BTN_IDLE;
    } else if (btnPhase == BTN_DOWN) {
      btnUpAt = now;
      btnPhase = BTN_WAIT_DOUBLE;
    } else if (btnPhase == BTN_HOLDING) {
      btnPhase = BTN_IDLE;
    }
  }

  // ---- Waiting to see if a second tap arrives ----
  if (btnPhase == BTN_WAIT_DOUBLE && (now - btnUpAt) > BTN_DOUBLE_GAP_MS) {
    btnPhase = BTN_IDLE;
    onSingleTap();
  }

  if (powerOffConfirmActive && (now - powerOffConfirmAt > POWEROFF_CONFIRM_TIMEOUT_MS)) {
    cancelPowerOffConfirm();
  }
}

void onSingleTap() {
  markActivity();
  if (powerOffConfirmActive) {
    cancelPowerOffConfirm();
    return;
  }
  switch (powerState) {
    case PWR_OFF:
    case PWR_ASLEEP: enterAwake(); break;
    case PWR_AWAKE:
      // Single tap always cycles to the next screen
      nextScreen();
      break;
    default: break;
  }
}

void onDoubleTap() {
  markActivity();

  // Wake from sleep on double tap
  if (powerState == PWR_ASLEEP || powerState == PWR_OFF) {
    enterAwake();
    return;
  }
  if (powerState != PWR_AWAKE) return;

  // Power-off confirm screen: double tap = confirm shutdown
  if (powerOffConfirmActive) {
    confirmPowerOff();
    return;
  }

  // Interactive screens: double tap = ACTION (not sleep)
  // These screens have their own double-tap function.
  switch (currentScreen) {
    case SCR_TIMER:
      // Toggle stopwatch start/stop
      if (timerRunning) {
        timerElapsedMs += millis() - timerStartMs;
        timerRunning = false;
      } else {
        timerStartMs = millis();
        timerRunning = true;
      }
      return;

    case SCR_WIFI:
      // Toggle WiFi AP + camera on/off — the primary battery-save control
      toggleWiFiAP();
      return;

    case SCR_TORCH:
      torchOn = !torchOn;
      // TODO: BLE relay to phone to toggle flashlight
      return;

    case SCR_CAMERA:
      // TODO: BLE relay to phone to take photo
      return;

    case SCR_MUSIC:
      musicPlaying = !musicPlaying;
      // TODO: BLE relay to phone media command
      return;

    default:
      break;
  }

  // Default: double tap = sleep
  enterAsleep();
}

// ============================================================================
// SECTION 8 — POWER STATE TRANSITIONS
// ============================================================================
void bootFromOff() {
  powerState = PWR_BOOTING;
  display.ssd1306_command(SSD1306_DISPLAYON);
  playBootAnimation();
  powerState = PWR_AWAKE;
  currentScreen = SCR_HOME;
  currentExpr = EXPR_IDLE;
  markActivity();
}

void enterAwake() {
  powerState = PWR_AWAKE;
  currentScreen = SCR_HOME;
  currentExpr = EXPR_IDLE;
  display.ssd1306_command(SSD1306_DISPLAYON);
  markActivity();
}

void enterAsleep() {
  if (audioStreaming) stopAudioStreamHold();
  powerOffConfirmActive = false;
  powerState = PWR_ASLEEP;
  display.clearDisplay();
  display.display();
  display.ssd1306_command(SSD1306_DISPLAYOFF);
  goDeepSleepUntilInterrupt();
}

void enterShutdown() {
  powerState = PWR_SHUTTING_DOWN;
  playShutdownAnimation();
  display.clearDisplay();
  display.display();
  powerState = PWR_OFF;
  esp_sleep_enable_ext0_wakeup((gpio_num_t)PIN_BUTTON, 0);
  esp_deep_sleep_start();
}

void goDeepSleepUntilInterrupt() {
  // Wakes on button press only (no motion sensor on this build).
  esp_sleep_enable_ext0_wakeup((gpio_num_t)PIN_BUTTON, 0);
  esp_light_sleep_start();
}

// ============================================================================
// SECTION 9 — SCREENS + BOOT ANIMATION
// ============================================================================
void nextScreen() {
  // Cycle through screens (skip SCR_AI — auto-shown by mascot/BLE events)
  currentScreen = (Screen)((currentScreen + 1) % SCR_COUNT);
  markActivity();
}

void nextListItem() { markActivity(); }

void confirmScreen() {
  // Legacy — kept for compatibility. Double tap on most screens now handled in onDoubleTap().
  markActivity();
}

void drawHoldProgress(float pct) {
  display.clearDisplay();
  display.drawRect(4, OLED_H/2 - 4, OLED_W - 8, 8, SSD1306_WHITE);
  display.fillRect(4, OLED_H/2 - 4, (int)((OLED_W - 8) * pct), 8, SSD1306_WHITE);
  display.display();
}

void drawHomeScreen() {
  display.clearDisplay();
  display.setTextSize(1);
  display.setCursor(0, 0);
  display.println("12:34");
  display.println("Aug 14");

  // Safe direct pointer — no pgm_read_ptr needed since both arrays are in flash
  const uint8_t* frame = (mascotFrameIdx % 2 == 0) ? zero_idle_open : zero_idle_closed;
  display.drawBitmap(OLED_W - ZERO_MASCOT_W, 0, frame, ZERO_MASCOT_W, ZERO_MASCOT_H, SSD1306_WHITE);

  if (aiCaption.length() > 0) {
    display.setCursor(0, OLED_H - 8);
    display.print(aiCaption);
  }
  display.display();
}

void drawGenericScreen(const char* title, const char* body) {
  display.clearDisplay();
  display.setTextSize(1);
  display.setTextColor(SSD1306_WHITE);
  display.setCursor(0, 0);
  display.print(title);
  display.drawLine(0, 9, OLED_W - 1, 9, SSD1306_WHITE);
  display.setCursor(0, 13);
  display.println(body);
  display.display();
}

// ============================================================================
// RICH SCREEN IMPLEMENTATIONS (64 x 32 px)
// ============================================================================

// -- SCREEN 1: AI Ornith Status -----------------------------------------------
void drawAIScreen() {
  display.clearDisplay();
  display.setTextSize(1);

  // Title bar
  display.fillRect(0, 0, OLED_W, 9, SSD1306_WHITE);
  display.setTextColor(SSD1306_BLACK, SSD1306_WHITE);
  display.setCursor(2, 1);
  display.print("ORNITH AI");
  display.setTextColor(SSD1306_WHITE);

  // Expression state
  const char* exprLabel = "IDLE";
  if      (currentExpr == EXPR_LISTENING) exprLabel = "LISTENING";
  else if (currentExpr == EXPR_THINKING)  exprLabel = "THINKING ";
  else if (currentExpr == EXPR_SPEAKING)  exprLabel = "SPEAKING ";
  else if (currentExpr == EXPR_HAPPY)     exprLabel = "HAPPY    ";
  else if (currentExpr == EXPR_LOWBATT)   exprLabel = "LOW BATT ";
  display.setCursor(2, 12);
  display.print("State:"); display.print(exprLabel);

  // Caption (last AI reply truncated)
  display.setCursor(0, 23);
  String cap = aiCaption.length() > 0 ? aiCaption : "Hold D1 to ask...";
  if (cap.length() > 10) cap = cap.substring(0, 10);
  display.print(cap);

  // Small animated dot when streaming
  if (audioStreaming) {
    uint8_t dot = (millis() / 300) % 3;
    for (uint8_t i = 0; i < 3; i++) {
      if (i <= dot) display.fillCircle(47 + i * 6, 27, 2, SSD1306_WHITE);
      else          display.drawCircle(47 + i * 6, 27, 2, SSD1306_WHITE);
    }
  }
  display.display();
}

// -- SCREEN 2: Timer / Stopwatch ----------------------------------------------
void drawTimerScreen() {
  display.clearDisplay();
  display.setTextSize(1);

  // Title
  display.fillRect(0, 0, OLED_W, 9, SSD1306_WHITE);
  display.setTextColor(SSD1306_BLACK, SSD1306_WHITE);
  display.setCursor(4, 1);
  display.print(timerRunning ? "STOPWATCH" : "STOPWATCH");
  display.setTextColor(SSD1306_WHITE);

  // Elapsed time
  unsigned long elapsed = timerElapsedMs;
  if (timerRunning) elapsed += (millis() - timerStartMs);
  unsigned long secs = (elapsed / 1000) % 60;
  unsigned long mins = (elapsed / 60000) % 60;
  unsigned long hrs  = elapsed / 3600000;

  display.setTextSize(2);
  display.setCursor(3, 12);
  char buf[10];
  if (hrs > 0) snprintf(buf, sizeof(buf), "%02lu:%02lu", hrs, mins);
  else         snprintf(buf, sizeof(buf), "%02lu:%02lu", mins, secs);
  display.print(buf);

  // Status hint on right side (tiny)
  display.setTextSize(1);
  display.setCursor(44, 24);
  display.print(timerRunning ? "[RUN]" : "[STP]");
  display.display();
}

// -- SCREEN 3: Steps / Heart Rate ---------------------------------------------
void drawStepsScreen() {
  display.clearDisplay();
  display.setTextSize(1);

  display.fillRect(0, 0, OLED_W, 9, SSD1306_WHITE);
  display.setTextColor(SSD1306_BLACK, SSD1306_WHITE);
  display.setCursor(8, 1);
  display.print("HEALTH");
  display.setTextColor(SSD1306_WHITE);

  // Step count
  display.setCursor(0, 11);
  display.print("Steps:");
  display.print(stepCount);

  // Heart rate
  display.setCursor(0, 22);
  display.print("HR:   ");
  display.print((int)heartRate);
  display.print(" bpm");

  // Tiny heart icon (top-right)
  display.drawPixel(56, 2, SSD1306_WHITE);
  display.drawPixel(59, 2, SSD1306_WHITE);
  display.drawLine(55, 3, 60, 3, SSD1306_WHITE);
  display.drawLine(54, 4, 61, 4, SSD1306_WHITE);
  display.drawLine(55, 5, 60, 5, SSD1306_WHITE);
  display.drawLine(56, 6, 59, 6, SSD1306_WHITE);
  display.drawLine(57, 7, 58, 7, SSD1306_WHITE);
  display.display();
}

// -- SCREEN 4: Weather --------------------------------------------------------
void drawWeatherScreen() {
  display.clearDisplay();
  display.setTextSize(1);

  display.fillRect(0, 0, OLED_W, 9, SSD1306_WHITE);
  display.setTextColor(SSD1306_BLACK, SSD1306_WHITE);
  display.setCursor(6, 1);
  display.print("WEATHER");
  display.setTextColor(SSD1306_WHITE);

  display.setCursor(0, 12);
  display.print(weatherLine1);
  display.setCursor(0, 23);
  display.print(weatherLine2);

  // Sun icon (top-right corner)
  display.drawCircle(59, 5, 3, SSD1306_WHITE);
  display.drawLine(59, 0, 59, 1, SSD1306_WHITE);
  display.drawLine(63, 5, 62, 5, SSD1306_WHITE);
  display.drawLine(55, 5, 56, 5, SSD1306_WHITE);
  display.display();
}

// -- SCREEN 5: Music / Now Playing --------------------------------------------
void drawMusicScreen() {
  display.clearDisplay();
  display.setTextSize(1);

  display.fillRect(0, 0, OLED_W, 9, SSD1306_WHITE);
  display.setTextColor(SSD1306_BLACK, SSD1306_WHITE);
  display.setCursor(2, 1);
  display.print(musicPlaying ? ">> PLAYING" : "|| PAUSED ");
  display.setTextColor(SSD1306_WHITE);

  display.setCursor(0, 12);
  display.print(musicTitle);
  display.setCursor(0, 23);
  display.print(musicArtist);

  // Progress line (animated placeholder)
  display.drawRect(0, 30, OLED_W, 2, SSD1306_WHITE);
  uint8_t prog = (millis() / 500) % OLED_W;
  display.fillRect(0, 30, prog, 2, SSD1306_WHITE);
  display.display();
}

// -- SCREEN 6: Voice Notes ----------------------------------------------------
void drawNotesScreen() {
  display.clearDisplay();
  display.setTextSize(1);

  display.fillRect(0, 0, OLED_W, 9, SSD1306_WHITE);
  display.setTextColor(SSD1306_BLACK, SSD1306_WHITE);
  display.setCursor(6, 1);
  display.print("V-NOTES");
  display.setTextColor(SSD1306_WHITE);

  display.setCursor(0, 12);
  display.print("Hold to record");
  display.setCursor(0, 22);
  display.print("  [  REC  ]");

  // Mic icon
  display.drawRoundRect(28, 11, 8, 10, 2, SSD1306_WHITE);
  display.drawLine(32, 21, 32, 25, SSD1306_WHITE);
  display.drawLine(28, 25, 36, 25, SSD1306_WHITE);
  display.display();
}

// -- SCREEN 7: Notification ---------------------------------------------------
void drawNotifyScreen() {
  display.clearDisplay();
  display.setTextSize(1);

  display.fillRect(0, 0, OLED_W, 9, SSD1306_WHITE);
  display.setTextColor(SSD1306_BLACK, SSD1306_WHITE);
  display.setCursor(2, 1);
  display.print("NOTIFY");
  if (strlen(notifApp) > 0) {
    display.setCursor(36, 1);
    display.print(notifApp);
  }
  display.setTextColor(SSD1306_WHITE);

  display.setCursor(0, 12);
  // Show first 20 chars of notification
  char shortMsg[21];
  strncpy(shortMsg, notifText, 20);
  shortMsg[20] = '\0';
  display.print(shortMsg);
  if (strlen(notifText) > 20) {
    display.setCursor(0, 23);
    display.print(notifText + 20);
  }
  display.display();
}

// -- SCREEN 8: Camera Trigger -------------------------------------------------
void drawCameraScreen() {
  display.clearDisplay();
  display.setTextSize(1);

  display.fillRect(0, 0, OLED_W, 9, SSD1306_WHITE);
  display.setTextColor(SSD1306_BLACK, SSD1306_WHITE);
  display.setCursor(6, 1);
  display.print("CAMERA");
  display.setTextColor(SSD1306_WHITE);

  // Camera body icon
  display.drawRoundRect(8, 12, 36, 16, 2, SSD1306_WHITE);
  display.fillRect(15, 10, 8, 3, SSD1306_WHITE); // viewfinder bump
  display.drawCircle(26, 20, 5, SSD1306_WHITE);   // lens circle
  display.fillCircle(26, 20, 2, SSD1306_WHITE);   // lens center

  display.setCursor(48, 14);
  display.print("DBL");
  display.setCursor(48, 23);
  display.print("TAP");
  display.display();
}

// -- SCREEN 9: Torch ----------------------------------------------------------
void drawTorchScreen() {
  display.clearDisplay();
  display.setTextSize(1);

  if (torchOn) {
    // Fully lit — white background
    display.fillRect(0, 0, OLED_W, OLED_H, SSD1306_WHITE);
    display.setTextColor(SSD1306_BLACK, SSD1306_WHITE);
    display.setCursor(12, 12);
    display.print("TORCH ON");
  } else {
    display.fillRect(0, 0, OLED_W, 9, SSD1306_WHITE);
    display.setTextColor(SSD1306_BLACK, SSD1306_WHITE);
    display.setCursor(8, 1);
    display.print("TORCH");
    display.setTextColor(SSD1306_WHITE);
    // Bulb icon
    display.drawCircle(32, 20, 7, SSD1306_WHITE);
    display.drawLine(29, 27, 35, 27, SSD1306_WHITE);
    display.drawLine(30, 29, 34, 29, SSD1306_WHITE);
    display.setCursor(44, 14);
    display.print("DBL");
    display.setCursor(44, 23);
    display.print("TAP");
  }
  display.setTextColor(SSD1306_WHITE);
  display.display();
}

// -- SCREEN 10: Battery + BLE Status ------------------------------------------
void drawBatteryScreen() {
  display.clearDisplay();
  display.setTextSize(1);

  display.fillRect(0, 0, OLED_W, 9, SSD1306_WHITE);
  display.setTextColor(SSD1306_BLACK, SSD1306_WHITE);
  display.setCursor(4, 1);
  display.print("BATTERY");
  display.setTextColor(SSD1306_WHITE);

  // Battery icon
  display.drawRect(2, 12, 34, 12, SSD1306_WHITE);
  display.fillRect(36, 15, 3, 6, SSD1306_WHITE); // + terminal
  display.fillRect(4, 14, 28, 8, SSD1306_WHITE);  // ~85% full

  // Labels
  display.setCursor(42, 12);
  display.print("~85%");
  display.setCursor(0, 26);
  display.print("BLE:");
  bool bleConn = bleServer && bleServer->getConnectedCount() > 0;
  display.print(bleConn ? "Connected" : "Scanning..");
  display.display();
}

// -- SCREEN 11: WiFi Hotspot (OFF by default, double-tap to toggle) -----------
void drawWiFiScreen() {
  display.clearDisplay();
  display.setTextSize(1);

  // Title bar
  display.fillRect(0, 0, OLED_W, 9, SSD1306_WHITE);
  display.setTextColor(SSD1306_BLACK, SSD1306_WHITE);
  display.setCursor(4, 1);
  display.print("HOTSPOT");
  display.setTextColor(SSD1306_WHITE);

  if (!wifiAPEnabled) {
    // ---- OFF state — clear call to action ----
    display.setCursor(6, 12);
    display.print("WiFi is OFF");
    display.setCursor(0, 23);
    display.print("DBL TAP = turn ON");
    // Crossed-out WiFi icon
    display.drawLine(55, 7, 63, 7, SSD1306_WHITE);
    display.drawLine(57, 5, 61, 5, SSD1306_WHITE);
    display.drawLine(54, 9, 64, 1, SSD1306_WHITE); // diagonal cross
  } else {
    // ---- ON state — show connection info ----
    uint8_t clients = WiFi.softAPgetStationNum();

    // Signal arcs icon (top-right)
    display.drawCircle(59, 3, 2, SSD1306_WHITE);
    display.drawLine(57, 5, 61, 5, SSD1306_WHITE);
    display.drawLine(55, 7, 63, 7, SSD1306_WHITE);

    display.setCursor(0, 11);
    display.print(WIFI_AP_SSID);

    display.setCursor(0, 21);
    display.print("192.168.4.1");

    if (clients > 0) {
      display.fillRect(43, 20, 21, 10, SSD1306_WHITE);
      display.setTextColor(SSD1306_BLACK, SSD1306_WHITE);
      display.setCursor(45, 22);
      display.print(clients); display.print(" conn");
      display.setTextColor(SSD1306_WHITE);
    } else {
      display.setCursor(44, 21);
      display.print("no conn");
    }
  }
  display.display();
}

// -- SCREEN 12: Settings ------------------------------------------------------
void drawSettingsScreen() {
  display.clearDisplay();
  display.setTextSize(1);

  display.fillRect(0, 0, OLED_W, 9, SSD1306_WHITE);
  display.setTextColor(SSD1306_BLACK, SSD1306_WHITE);
  display.setCursor(4, 1);
  display.print("SETTINGS");
  display.setTextColor(SSD1306_WHITE);

  display.setCursor(0, 12);
  display.print("Hold 2s: OFF");
  display.setCursor(0, 22);
  display.print("DBL: sleep");

  // Gear icon (simple)
  display.drawCircle(56, 20, 5, SSD1306_WHITE);
  display.drawLine(56, 13, 56, 15, SSD1306_WHITE);
  display.drawLine(56, 25, 56, 27, SSD1306_WHITE);
  display.drawLine(49, 20, 51, 20, SSD1306_WHITE);
  display.drawLine(61, 20, 63, 20, SSD1306_WHITE);
  display.display();
}

void updateMascotAnimation() {
  static unsigned long lastBlinkChange = 0;
  unsigned long now = millis();
  if (mascotFrameIdx == 0 && now - lastBlinkChange > 2200) {
    mascotFrameIdx = 1; lastBlinkChange = now;
  } else if (mascotFrameIdx == 1 && now - lastBlinkChange > 150) {
    mascotFrameIdx = 0; lastBlinkChange = now;
  }

  static unsigned long lastDraw = 0;
  if (millis() - lastDraw < 100) return;
  lastDraw = millis();

  if (audioStreaming) {
    drawGenericScreen("Listening...", "release to send");
    return;
  }
  if (powerOffConfirmActive) {
    drawGenericScreen("Power off?", "tap=no  dbltap=yes");
    return;
  }

  switch (currentScreen) {
    case SCR_HOME:     drawHomeScreen(); break;
    case SCR_AI:       drawAIScreen(); break;
    case SCR_TIMER:    drawTimerScreen(); break;
    case SCR_STEPS:    drawStepsScreen(); break;
    case SCR_WEATHER:  drawWeatherScreen(); break;
    case SCR_MUSIC:    drawMusicScreen(); break;
    case SCR_NOTES:    drawNotesScreen(); break;
    case SCR_NOTIFY:   drawNotifyScreen(); break;
    case SCR_CAMERA:   drawCameraScreen(); break;
    case SCR_TORCH:    drawTorchScreen(); break;
    case SCR_BATTERY:  drawBatteryScreen(); break;
    case SCR_WIFI:     drawWiFiScreen(); break;
    case SCR_SETTINGS: drawSettingsScreen(); break;
    default: break;
  }
}

// Safe frame getter: avoids pgm_read_ptr unreliability on ESP32 with PROGMEM pointer arrays.
// Directly returns the compile-time pointer for each frame index.
const uint8_t* getBootFrame(int i) {
  switch (i) {
    case  0: return zero_boot_0;
    case  1: return zero_boot_1;
    case  2: return zero_boot_2;
    case  3: return zero_boot_3;
    case  4: return zero_boot_4;
    case  5: return zero_boot_5;
    case  6: return zero_boot_6;
    case  7: return zero_boot_7;
    case  8: return zero_boot_8;
    case  9: return zero_boot_9;
    case 10: return zero_boot_10;
    case 11: return zero_boot_11;
    case 12: return zero_boot_12;
    default: return zero_boot_0;
  }
}

void playBootAnimation() {
  display.clearDisplay();
  display.display();
  delay(30);
  for (int i = 0; i < ZERO_BOOT_FRAMES; i++) {
    display.clearDisplay();
    display.drawBitmap(12, 0, getBootFrame(i), ZERO_MASCOT_W, ZERO_MASCOT_H, SSD1306_WHITE);
    display.display();
    delay(70);
  }
}

void playShutdownAnimation() {
  for (int i = ZERO_BOOT_FRAMES - 1; i >= 0; i--) {
    display.clearDisplay();
    display.drawBitmap(12, 0, getBootFrame(i), ZERO_MASCOT_W, ZERO_MASCOT_H, SSD1306_WHITE);
    display.display();
    delay(50);
  }
}

// ============================================================================
// SECTION 10 — BLE
// ============================================================================
// (bleServer and characteristic pointers declared in global state above)


class CommandCallback : public NimBLECharacteristicCallbacks {
  void onWrite(NimBLECharacteristic* pCharacteristic, NimBLEConnInfo& connInfo) override {
    std::string cmd = pCharacteristic->getValue();
    if (cmd == "take_photo") captureAndSendPhoto();
    else if (cmd == "record_video") startVideoRecording();
    else if (cmd == "record_audio") startAudioRecording();
    else if (cmd == "take_note") saveVoiceNote();
  }
};

class AudioDownCallback : public NimBLECharacteristicCallbacks {
  void onWrite(NimBLECharacteristic* pCharacteristic, NimBLEConnInfo& connInfo) override {
    std::string audioChunk = pCharacteristic->getValue();
    size_t bytesWritten = 0;
    i2s_write(I2S_PORT_SPK, audioChunk.data(), audioChunk.size(), &bytesWritten, portMAX_DELAY);
    currentExpr = EXPR_SPEAKING;
  }
};

class CaptionCallback : public NimBLECharacteristicCallbacks {
  void onWrite(NimBLECharacteristic* pCharacteristic, NimBLEConnInfo& connInfo) override {
    aiCaption = String(pCharacteristic->getValue().c_str());
  }
};

void setupBLE() {
  NimBLEDevice::init(BLE_DEVICE_NAME);
  bleServer = NimBLEDevice::createServer();
  NimBLEService* svc = bleServer->createService(SVC_UUID_MAIN);

  chrAudioUp   = svc->createCharacteristic(CHR_UUID_AUDIO_UP, NIMBLE_PROPERTY::NOTIFY);
  chrAudioDown = svc->createCharacteristic(CHR_UUID_AUDIO_DOWN, NIMBLE_PROPERTY::WRITE);
  chrCommand   = svc->createCharacteristic(CHR_UUID_COMMAND, NIMBLE_PROPERTY::WRITE);
  chrCaption   = svc->createCharacteristic(CHR_UUID_CAPTION, NIMBLE_PROPERTY::WRITE);
  chrMedia     = svc->createCharacteristic(CHR_UUID_MEDIA, NIMBLE_PROPERTY::NOTIFY);
  chrMouse     = svc->createCharacteristic(CHR_UUID_MOUSE, NIMBLE_PROPERTY::NOTIFY);

  chrAudioDown->setCallbacks(new AudioDownCallback());
  chrCommand->setCallbacks(new CommandCallback());
  chrCaption->setCallbacks(new CaptionCallback());

  svc->start();
  bleServer->getAdvertising()->start();
}

// ============================================================================
// SECTION 10b — PUSH-TO-TALK AUDIO STREAMING (open-ended hold)
// ============================================================================
// SECTION 10b — PUSH-TO-TALK AUDIO STREAMING (open-ended hold)
// ============================================================================
void startAudioStreamHold() {
  audioStreaming = true;
  currentExpr = EXPR_LISTENING;
  if (chrAudioUp) {
    uint8_t startMarker = 0xFF;
    chrAudioUp->setValue(&startMarker, 1);
    chrAudioUp->notify();
  }
  markActivity();
}

void stopAudioStreamHold() {
  audioStreaming = false;
  currentExpr = EXPR_THINKING;
  if (chrAudioUp) {
    uint8_t stopMarker = 0xFE;
    chrAudioUp->setValue(&stopMarker, 1);
    chrAudioUp->notify();
  }
  markActivity();
}

void streamAudioChunk() {
  static int16_t chunk[120]; // ~7.5ms @ 16kHz mono per BLE notification
  size_t bytesRead = 0;
  i2s_read(I2S_PORT_MIC, chunk, sizeof(chunk), &bytesRead, portMAX_DELAY);
  if (chrAudioUp && bytesRead > 0) {
    chrAudioUp->setValue((uint8_t*)chunk, bytesRead);
    chrAudioUp->notify();
  }
}

// ============================================================================
// SECTION 10c — POWER-OFF CONFIRM (Settings screen only)
// ============================================================================
void showPowerOffConfirm() {
  powerOffConfirmActive = true;
  powerOffConfirmAt = millis();
  markActivity();
}

void cancelPowerOffConfirm() {
  powerOffConfirmActive = false;
  markActivity();
}

void confirmPowerOff() {
  powerOffConfirmActive = false;
  enterShutdown();
}

// ============================================================================
// ============================================================================
// SECTION 11 — CAMERA  (persistent — stays initialized for web streaming)
// ============================================================================
bool initCamera() {
  camera_config_t cfg = {};
  cfg.pin_d0 = Y2_GPIO_NUM;   cfg.pin_d1 = Y3_GPIO_NUM;
  cfg.pin_d2 = Y4_GPIO_NUM;   cfg.pin_d3 = Y5_GPIO_NUM;
  cfg.pin_d4 = Y6_GPIO_NUM;   cfg.pin_d5 = Y7_GPIO_NUM;
  cfg.pin_d6 = Y8_GPIO_NUM;   cfg.pin_d7 = Y9_GPIO_NUM;
  cfg.pin_xclk        = XCLK_GPIO_NUM;
  cfg.pin_pclk        = PCLK_GPIO_NUM;
  cfg.pin_vsync       = VSYNC_GPIO_NUM;
  cfg.pin_href        = HREF_GPIO_NUM;
  cfg.pin_sscb_sda    = SIOD_GPIO_NUM;
  cfg.pin_sscb_scl    = SIOC_GPIO_NUM;
  cfg.pin_pwdn        = PWDN_GPIO_NUM;
  cfg.pin_reset       = RESET_GPIO_NUM;
  cfg.xclk_freq_hz    = 20000000;
  cfg.pixel_format    = PIXFORMAT_JPEG;
  // Use PSRAM if available for double-buffering (smoother stream)
  if (psramFound()) {
    cfg.frame_size    = FRAMESIZE_SVGA;  // 800x600 — good quality
    cfg.jpeg_quality  = 10;
    cfg.fb_count      = 2;
  } else {
    cfg.frame_size    = FRAMESIZE_VGA;   // 640x480 fallback
    cfg.jpeg_quality  = 12;
    cfg.fb_count      = 1;
  }
  esp_err_t err = esp_camera_init(&cfg);
  if (err != ESP_OK) {
    Serial.printf("Camera init error 0x%x\n", err);
    return false;
  }
  // Flip image if camera is mounted upside-down
  sensor_t* s = esp_camera_sensor_get();
  if (s) { s->set_vflip(s, 1); s->set_hmirror(s, 1); }
  return true;
}

void initCameraIfNeeded() { if (!cameraReady) cameraReady = initCamera(); }
void deinitCamera() { esp_camera_deinit(); cameraReady = false; }

void captureAndSendPhoto() {
  initCameraIfNeeded();
  camera_fb_t* fb = esp_camera_fb_get();
  if (fb) {
    esp_camera_fb_return(fb);
  }
  currentExpr = EXPR_HAPPY;
}

void startVideoRecording() {
  initCameraIfNeeded();
}

void startAudioRecording() {}
void saveVoiceNote() {}

// ============================================================================
// SECTION 12 — AIR MOUSE (disabled: no motion sensor on this build)
// ============================================================================
void airMouseLoop() {
  // No MPU6050 to read gyro data from. Left as a no-op so the Air Mouse
  // screen doesn't crash if double-tapped; the cursor just won't move.
}

// ============================================================================
// SECTION 13 — WIFI ACCESS POINT + TOGGLE
// ============================================================================
void setupWiFiAP() {
  WiFi.mode(WIFI_AP);
  WiFi.softAP(WIFI_AP_SSID, WIFI_AP_PASS, WIFI_AP_CHAN, 0, WIFI_AP_MAX);
  delay(200);
  WiFi.softAPConfig(
    IPAddress(192, 168, 4, 1),
    IPAddress(192, 168, 4, 1),
    IPAddress(255, 255, 255, 0)
  );
  Serial.printf("WiFi AP started: SSID=%s  IP=192.168.4.1\n", WIFI_AP_SSID);
}

// Called from double-tap on the HOTSPOT screen.
// Turning ON:  starts WiFi AP + initialises camera + starts web server.
// Turning OFF: disconnects all clients, shuts down WiFi radio + deinits camera.
void toggleWiFiAP() {
  if (!wifiAPEnabled) {
    // --- TURN ON ---
    // Brief feedback on OLED
    drawGenericScreen("WiFi", "Starting...");

    // Start AP
    setupWiFiAP();

    // Init camera (only when WiFi is on — saves power otherwise)
    if (!cameraReady) {
      cameraReady = initCamera();
      if (!cameraReady) Serial.println("Camera init failed");
    }

    // Start web server routes (idempotent — safe to call each time)
    setupWebServer();

    wifiAPEnabled = true;
    markActivity();
    Serial.println("WiFi + camera ON");

    // Confirm on OLED
    drawGenericScreen("WiFi ON", "192.168.4.1");
    delay(800);

  } else {
    // --- TURN OFF ---
    drawGenericScreen("WiFi", "Stopping...");

    // Disconnect any clients and stop the AP
    camServer.stop();
    WiFi.softAPdisconnect(true);
    WiFi.mode(WIFI_OFF);

    // Power down the camera to save current
    if (cameraReady) {
      esp_camera_deinit();
      cameraReady = false;
    }

    wifiAPEnabled = false;
    wifiClientConnected = false;
    markActivity();
    Serial.println("WiFi + camera OFF");

    drawGenericScreen("WiFi OFF", "Battery saved");
    delay(800);
  }
}

// ============================================================================
// SECTION 14 — WEB SERVER + ROUTES
// ===============================
// ---- Web page served in chunks (avoids raw string + PROGMEM String issues) --
// Each chunk is a normal escaped C string stored in PROGMEM.

static const char HTML_HEAD[] PROGMEM =
  "<!DOCTYPE html><html lang='en'><head>"
  "<meta charset='UTF-8'><meta name='viewport' content='width=device-width,initial-scale=1'>"
  "<title>Zero Ring Camera</title><style>"
  ":root{--bg:#0a0a0f;--card:#12121a;--border:#2a2a3a;--accent:#6c63ff;--text:#e0e0f0;--sub:#888}"
  "*{box-sizing:border-box;margin:0;padding:0}"
  "body{background:var(--bg);color:var(--text);font-family:'Segoe UI',system-ui,sans-serif;"
  "min-height:100vh;display:flex;flex-direction:column;align-items:center}"
  "header{width:100%;padding:14px 20px;display:flex;align-items:center;gap:14px;"
  "background:rgba(18,18,26,.9);backdrop-filter:blur(12px);"
  "border-bottom:1px solid var(--border);position:sticky;top:0;z-index:99}"
  ".mascot svg{width:44px;height:44px;filter:drop-shadow(0 0 8px #6c63ff88)}"
  ".brand h1{font-size:1.15rem;font-weight:700}h1 span{color:var(--accent)}"
  ".brand p{font-size:.72rem;color:var(--sub)}"
  ".status-dot{width:8px;height:8px;border-radius:50%;background:#22c55e;"
  "box-shadow:0 0 6px #22c55e;margin-left:auto;animation:pulse 2s infinite}"
  "@keyframes pulse{0%,100%{opacity:1}50%{opacity:.4}}"
  ".badge{font-size:.68rem;padding:2px 8px;border-radius:20px;"
  "background:var(--card);border:1px solid var(--border);color:var(--sub);margin-left:6px}"
  "main{width:100%;max-width:520px;padding:16px;display:flex;flex-direction:column;gap:16px}"
  ".card{background:var(--card);border:1px solid var(--border);border-radius:16px;overflow:hidden}"
  ".stream-wrap{position:relative;aspect-ratio:4/3;background:#000;"
  "display:flex;align-items:center;justify-content:center}"
  ".stream-wrap img{width:100%;height:100%;object-fit:cover}"
  ".stream-overlay{position:absolute;top:10px;left:10px;font-size:.68rem;"
  "background:rgba(0,0,0,.6);padding:3px 8px;border-radius:8px;color:#fff;"
  "display:flex;align-items:center;gap:5px}"
  ".live-dot{width:6px;height:6px;border-radius:50%;background:#ef4444;animation:pulse 1s infinite}"
  ".no-stream{text-align:center;padding:40px 20px;color:var(--sub)}"
  ".no-stream .icon{font-size:3rem;margin-bottom:8px}"
  ".controls{padding:14px;display:flex;gap:10px;flex-wrap:wrap}"
  ".btn{flex:1;padding:11px 8px;border:none;border-radius:12px;font-size:.82rem;"
  "font-weight:600;cursor:pointer;transition:all .18s;min-width:90px}"
  ".btn-primary{background:linear-gradient(135deg,var(--accent),#9c5cff);color:#fff;"
  "box-shadow:0 4px 18px #6c63ff44}.btn-primary:active{transform:scale(.96)}"
  ".btn-secondary{background:var(--border);color:var(--text)}"
  ".btn-danger{background:linear-gradient(135deg,#e02d2d,#ff6b9d);color:#fff}"
  ".section-label{padding:12px 14px 6px;font-size:.72rem;font-weight:700;"
  "text-transform:uppercase;letter-spacing:.1em;color:var(--sub)}"
  ".gallery{padding:0 10px 12px;display:grid;"
  "grid-template-columns:repeat(auto-fill,minmax(100px,1fr));gap:8px}"
  ".photo-item{position:relative;aspect-ratio:1;border-radius:10px;"
  "overflow:hidden;background:#1a1a28;cursor:pointer}"
  ".photo-item img{width:100%;height:100%;object-fit:cover;transition:transform .2s}"
  ".photo-item:hover img{transform:scale(1.06)}"
  ".photo-actions{position:absolute;bottom:0;left:0;right:0;padding:4px;"
  "display:flex;gap:3px;background:linear-gradient(transparent,rgba(0,0,0,.8))}"
  ".photo-actions a,.photo-actions button{flex:1;padding:4px;font-size:.62rem;"
  "border:none;border-radius:5px;text-align:center;cursor:pointer;text-decoration:none}"
  ".photo-actions a{background:var(--accent);color:#fff}"
  ".photo-actions button{background:#e02d2d;color:#fff}"
  ".empty-gallery{padding:24px;text-align:center;color:var(--sub);font-size:.82rem}"
  ".status-bar{padding:10px 14px;display:flex;gap:12px;font-size:.72rem;"
  "color:var(--sub);border-top:1px solid var(--border)}"
  ".status-bar span b{color:var(--text)}"
  "#toast{position:fixed;bottom:24px;left:50%;transform:translateX(-50%);"
  "background:var(--accent);color:#fff;padding:10px 20px;border-radius:12px;"
  "font-size:.82rem;font-weight:600;opacity:0;transition:opacity .3s;"
  "pointer-events:none;z-index:999}#toast.show{opacity:1}"
  "</style></head><body>";

static const char HTML_HEADER[] PROGMEM =
  "<header>"
  "<div class='mascot'>"
  "<svg viewBox='0 0 80 80' fill='none' xmlns='http://www.w3.org/2000/svg' id='mascot-svg'>"
  "<rect x='16' y='22' width='48' height='40' rx='10' fill='#1a1a2e' stroke='#6c63ff' stroke-width='2.5'/>"
  "<rect id='eye-l' x='25' y='35' width='10' height='10' rx='3' fill='#6c63ff'/>"
  "<rect id='eye-r' x='45' y='35' width='10' height='10' rx='3' fill='#6c63ff'/>"
  "<path d='M32 52 Q40 58 48 52' stroke='#6c63ff' stroke-width='2' stroke-linecap='round' fill='none'/>"
  "<rect x='4' y='32' width='12' height='7' rx='3.5' fill='#1a1a2e' stroke='#6c63ff' stroke-width='2'/>"
  "<rect x='64' y='32' width='12' height='7' rx='3.5' fill='#1a1a2e' stroke='#6c63ff' stroke-width='2'/>"
  "<rect x='24' y='60' width='10' height='12' rx='4' fill='#1a1a2e' stroke='#6c63ff' stroke-width='2'/>"
  "<rect x='46' y='60' width='10' height='12' rx='4' fill='#1a1a2e' stroke='#6c63ff' stroke-width='2'/>"
  "<line x1='40' y1='22' x2='40' y2='12' stroke='#6c63ff' stroke-width='2'/>"
  "<circle cx='40' cy='9' r='3' fill='#ff6b9d'/>"
  "</svg></div>"
  "<div class='brand'><h1>Zero <span>Ring</span></h1><p id='hdr-status'>Connecting...</p></div>"
  "<div class='status-dot'></div>"
  "<span class='badge' id='client-badge'>0 clients</span>"
  "</header>";

static const char HTML_BODY[] PROGMEM =
  "<main>"
  "<div class='card'>"
  "<div class='stream-wrap' id='stream-wrap'>"
  "<div class='no-stream' id='no-stream-msg'>"
  "<div class='icon'>&#128247;</div>"
  "<p>Connect to <b>Zero-Ring</b> WiFi<br>then open http://192.168.4.1</p>"
  "</div>"
  "<img id='stream-img' src='' style='display:none' alt='Live stream'/>"
  "<div class='stream-overlay' id='live-badge' style='display:none'>"
  "<div class='live-dot'></div> LIVE"
  "</div></div>"
  "<div class='controls'>"
  "<button class='btn btn-primary' onclick='snapPhoto()'>&#128247; Snap</button>"
  "<button class='btn btn-secondary' onclick='toggleStream()'>&#9654; Stream</button>"
  "<button class='btn btn-danger' onclick='clearAll()'>&#128465; Clear All</button>"
  "</div></div>"
  "<div class='card'><div class='section-label'>Gallery</div>"
  "<div class='gallery' id='gallery'><div class='empty-gallery'>No photos yet. Tap Snap!</div></div>"
  "</div>"
  "<div class='card'><div class='status-bar'>"
  "<span>&#128246; BLE: <b id='s-ble'>-</b></span>"
  "<span>&#128267; WiFi: <b id='s-wifi'>-</b></span>"
  "<span>&#128190; Photos: <b id='s-storage'>-</b></span>"
  "</div></div></main>"
  "<div id='toast'></div>";

static const char HTML_SCRIPT[] PROGMEM =
  "<script>"
  "let streaming=false;"
  "function toast(m){const t=document.getElementById('toast');t.textContent=m;"
  "t.classList.add('show');setTimeout(()=>t.classList.remove('show'),2200);}"
  "function toggleStream(){"
  "const i=document.getElementById('stream-img'),"
  "b=document.getElementById('live-badge'),"
  "n=document.getElementById('no-stream-msg');"
  "if(streaming){i.src='';i.style.display='none';b.style.display='none';"
  "n.style.display='flex';streaming=false;}"
  "else{i.src='/stream?t='+Date.now();i.style.display='block';"
  "b.style.display='flex';n.style.display='none';streaming=true;}}"
  "function snapPhoto(){toast('Capturing...');"
  "fetch('/capture').then(r=>r.json()).then(d=>{"
  "if(d.file){toast('Saved: '+d.file);loadGallery();}else toast('Capture failed');"
  "}).catch(()=>toast('Error'));}"
  "function loadGallery(){fetch('/gallery').then(r=>r.json()).then(files=>{"
  "const g=document.getElementById('gallery');"
  "if(!files||!files.length){g.innerHTML='<div class=\"empty-gallery\">No photos yet.</div>';return;}"
  "g.innerHTML=files.map(f=>"
  "'<div class=\"photo-item\"><img src=\"/photo/'+f+'\" loading=\"lazy\">'"
  "+'<div class=\"photo-actions\">'"
  "+'<a href=\"/photo/'+f+'\" download=\"'+f+'\">&#8681;</a>'"
  "+'<button onclick=\"delPhoto(\\'' +f+ '\\')\">&#x2715;</button>'"
  "+'</div></div>').join('');});}"
  "function delPhoto(n){fetch('/delete/'+n).then(()=>{toast('Deleted');loadGallery();});}"
  "function clearAll(){if(!confirm('Delete all photos?'))return;"
  "fetch('/gallery').then(r=>r.json()).then(f=>"
  "Promise.all(f.map(x=>fetch('/delete/'+x))).then(()=>{toast('Cleared');loadGallery();}));}"
  "function updateStatus(){fetch('/status').then(r=>r.json()).then(d=>{"
  "document.getElementById('s-ble').textContent=d.ble?'Connected':'Scanning';"
  "document.getElementById('s-wifi').textContent=d.clients+' client'+(d.clients!==1?'s':'');"
  "document.getElementById('s-storage').textContent=d.photos+' photo'+(d.photos!==1?'s':'');"
  "document.getElementById('hdr-status').textContent='192.168.4.1 - '+d.clients+' connected';"
  "document.getElementById('client-badge').textContent=d.clients+' client'+(d.clients!==1?'s':'');"
  "}).catch(()=>{});}"
  "function blinkMascot(){"
  "const el=document.getElementById('eye-l'),er=document.getElementById('eye-r');"
  "el.setAttribute('height','2');er.setAttribute('height','2');"
  "el.setAttribute('y','40');er.setAttribute('y','40');"
  "setTimeout(()=>{"
  "el.setAttribute('height','10');er.setAttribute('height','10');"
  "el.setAttribute('y','35');er.setAttribute('y','35');},160);}"
  "setInterval(blinkMascot,2800);setInterval(updateStatus,2000);"
  "updateStatus();loadGallery();setTimeout(toggleStream,800);"
  "</script></body></html>";

// ---- HTTP route handlers ----------------------------------------------------

void handleRoot() {
  // Send HTML in 4 PROGMEM chunks — avoids large String allocation in RAM
  WiFiClient client = camServer.client();
  client.print(F("HTTP/1.1 200 OK\r\nContent-Type: text/html\r\nConnection: close\r\n\r\n"));
  client.print(FPSTR(HTML_HEAD));
  client.print(FPSTR(HTML_HEADER));
  client.print(FPSTR(HTML_BODY));
  client.print(FPSTR(HTML_SCRIPT));
}


void handleStream() {
  if (!cameraReady) {
    camServer.send(503, "text/plain", "Camera not ready");
    return;
  }
  // MJPEG multipart stream
  WiFiClient client = camServer.client();
  client.println("HTTP/1.1 200 OK");
  client.println("Content-Type: multipart/x-mixed-replace;boundary=frame");
  client.println("Connection: keep-alive");
  client.println();

  while (client.connected() && WiFi.softAPgetStationNum() > 0) {
    camera_fb_t* fb = esp_camera_fb_get();
    if (!fb) { delay(10); continue; }
    client.printf("--frame\r\nContent-Type: image/jpeg\r\nContent-Length: %u\r\n\r\n", fb->len);
    client.write(fb->buf, fb->len);
    client.println();
    esp_camera_fb_return(fb);
    delay(60);  // ~16 fps cap; lower = faster but more CPU
  }
}

void handleCapture() {
  if (!cameraReady) {
    camServer.send(503, "application/json", "{\"error\":\"Camera not ready\"}");
    return;
  }
  camera_fb_t* fb = esp_camera_fb_get();
  if (!fb) {
    camServer.send(500, "application/json", "{\"error\":\"Frame grab failed\"}");
    return;
  }
  // Save to SPIFFS
  photoCount++;
  char filename[32];
  snprintf(filename, sizeof(filename), "/photo%04lu.jpg", (unsigned long)photoCount);
  File f = SPIFFS.open(filename, FILE_WRITE);
  if (f) {
    f.write(fb->buf, fb->len);
    f.close();
    esp_camera_fb_return(fb);
    String resp = "{\"file\":\""; resp += (filename + 1); resp += "\"}"; // strip leading /
    camServer.send(200, "application/json", resp);
    // Update OLED expression
    currentExpr = EXPR_HAPPY;
  } else {
    esp_camera_fb_return(fb);
    camServer.send(500, "application/json", "{\"error\":\"SPIFFS write failed\"}");
  }
}

void handleGallery() {
  String json = "[";
  bool first = true;
  File root = SPIFFS.open("/");
  File f = root.openNextFile();
  while (f) {
    String name = String(f.name());
    // Only list jpg files
    if (name.endsWith(".jpg") || name.endsWith(".jpeg")) {
      if (!first) json += ",";
      // Strip leading slash for the JS client
      if (name.startsWith("/")) name = name.substring(1);
      json += "\"" + name + "\"";
      first = false;
    }
    f = root.openNextFile();
  }
  json += "]";
  camServer.send(200, "application/json", json);
}

void handlePhoto() {
  // URI format: /photo/<filename>
  String path = camServer.uri();
  // Map /photo/photo0001.jpg -> /photo0001.jpg in SPIFFS
  String spiffsPath = "/" + path.substring(7); // strip "/photo/"
  if (!SPIFFS.exists(spiffsPath)) {
    camServer.send(404, "text/plain", "Not found");
    return;
  }
  File f = SPIFFS.open(spiffsPath, FILE_READ);
  camServer.streamFile(f, "image/jpeg");
  f.close();
}

void handleDelete() {
  // URI format: /delete/<filename>
  String path = camServer.uri();
  String spiffsPath = "/" + path.substring(8); // strip "/delete/"
  if (SPIFFS.exists(spiffsPath)) {
    SPIFFS.remove(spiffsPath);
    if (photoCount > 0) photoCount--;
    camServer.send(200, "application/json", "{\"ok\":true}");
  } else {
    camServer.send(404, "application/json", "{\"error\":\"not found\"}");
  }
}

void handleStatus() {
  bool bleConn = bleServer && bleServer->getConnectedCount() > 0;
  uint8_t clients = WiFi.softAPgetStationNum();
  // Count photos
  uint32_t cnt = 0;
  File root = SPIFFS.open("/");
  File f = root.openNextFile();
  while (f) { cnt++; f = root.openNextFile(); }
  String json = "{";
  json += "\"ble\":" + String(bleConn ? "true" : "false") + ",";
  json += "\"clients\":" + String(clients) + ",";
  json += "\"photos\":" + String(cnt) + ",";
  json += "\"camera\":" + String(cameraReady ? "true" : "false");
  json += "}";
  camServer.send(200, "application/json", json);
}

void setupWebServer() {
  camServer.on("/",       HTTP_GET, handleRoot);
  camServer.on("/stream", HTTP_GET, handleStream);
  camServer.on("/capture",HTTP_GET, handleCapture);
  camServer.on("/gallery",HTTP_GET, handleGallery);
  camServer.on("/status", HTTP_GET, handleStatus);

  // Dynamic routes with URI prefix matching
  camServer.onNotFound([]() {
    String uri = camServer.uri();
    if (uri.startsWith("/photo/"))        handlePhoto();
    else if (uri.startsWith("/delete/"))  handleDelete();
    else camServer.send(404, "text/plain", "Not found");
  });

  // CORS headers so browser fetch() works
  camServer.enableCORS(true);
  camServer.begin();
  Serial.println("\U0001F310 Web server started at http://192.168.4.1");
}
