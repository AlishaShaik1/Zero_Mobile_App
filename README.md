# 💍 Zero Ring & Zero Mobile App Ecosystem

An open, high-performance ambient AI wearable hardware & software platform. 

This repository contains:
1. **`mobile-app/`**: The complete **Flutter & Android Kotlin** companion application source code.
2. **`firmware/` & `.ino` files**: The **ESP32 NimBLE C++** firmware for the Zero Ring wearable.
3. **`zero-ring-landing-page/`**: The **Next.js 14** web application & developer hub.
4. **`PROJECT_BLUEPRINT.md`**: The comprehensive architectural guide, file map, and workflow document.

---

## 🚀 How to Build & Extract the Mobile App APK

If you are cloning this repository to build and install the mobile app on your Android phone, follow these steps:

### 1. Prerequisites
* [Flutter SDK](https://docs.flutter.dev/get-started/install) (`v3.22.0` or newer)
* [Java JDK 17](https://www.oracle.com/java/technologies/javase/jdk17-archive-downloads.html)
* Android SDK (API 34 / 35, Build-tools 34.0.0+)

### 2. Quick Build Commands
```bash
# Clone the repository
git clone https://github.com/AlishaShaik1/Zero_Mobile_App.git
cd Zero_Mobile_App

# Navigate to the mobile app folder
cd mobile-app

# Install dependencies
flutter pub get

# Build the release APK
flutter build apk --release
```

### 3. Locate Built APK
Once compilation completes, the APK is located at:
```
mobile-app/build/app/outputs/flutter-apk/app-release.apk
```

### 4. Transfer & Install
* **Via USB (ADB)**:
  ```bash
  adb install -r build/app/outputs/flutter-apk/app-release.apk
  ```
* **Via Phone File Transfer**:
  Copy `app-release.apk` to your phone via USB cable, Google Drive, or WhatsApp, tap the file in your phone's file manager, and install.

---

## 📖 Complete Documentation & Architecture

For a complete breakdown of:
* The end-to-end voice workflow (Ring I2S Mic $\rightarrow$ BLE $\rightarrow$ Deepgram STT $\rightarrow$ Agentic Router $\rightarrow$ YouTube/WhatsApp/Camera execution $\rightarrow$ Ring OLED display update)
* Every file's purpose and relationship
* Critical BLE & Android gotchas
* Firmware pinouts and specifications

👉 **Read [PROJECT_BLUEPRINT.md](PROJECT_BLUEPRINT.md)**
