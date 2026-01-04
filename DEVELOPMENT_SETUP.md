# Hamorah - Development Environment Setup Guide

This guide walks through setting up the complete development environment for Hamorah on Windows. The process is similar for macOS and Linux with platform-specific variations.

---

## Prerequisites

- Windows 10/11 (64-bit)
- At least 10GB free disk space
- Internet connection
- Administrator access (for some installations)

---

## Step 1: Install Flutter SDK

### Option A: Using Chocolatey (Recommended)
```powershell
# Install Chocolatey if not already installed
Set-ExecutionPolicy Bypass -Scope Process -Force
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

# Install Flutter
choco install flutter -y
```

### Option B: Manual Installation
1. Download Flutter SDK from: https://docs.flutter.dev/get-started/install/windows
2. Extract to `C:\flutter` (or your preferred location)
3. Add `C:\flutter\bin` to your PATH environment variable

### Verify Installation
```powershell
flutter --version
```

---

## Step 2: Install Android Studio

Android Studio provides the Android SDK and emulator, even if you're targeting desktop.

1. Download from: https://developer.android.com/studio
2. Run the installer
3. During setup, ensure these are selected:
   - Android SDK
   - Android SDK Command-line Tools
   - Android SDK Build-Tools
   - Android SDK Platform-Tools

### Post-Installation

1. Open Android Studio
2. Go to **Settings > Languages & Frameworks > Android SDK**
3. In the **SDK Tools** tab, install:
   - Android SDK Command-line Tools (latest)
   - Android Emulator (if you want to test on Android)

### Set ANDROID_HOME Environment Variable

```powershell
# Check if Android SDK is installed
dir "$env:LOCALAPPDATA\Android\Sdk"

# Set ANDROID_HOME (run as Administrator or set in System Properties)
[Environment]::SetEnvironmentVariable("ANDROID_HOME", "$env:LOCALAPPDATA\Android\Sdk", "User")

# Add to PATH
$currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
[Environment]::SetEnvironmentVariable("Path", "$currentPath;$env:LOCALAPPDATA\Android\Sdk\cmdline-tools\latest\bin;$env:LOCALAPPDATA\Android\Sdk\platform-tools", "User")
```

**Restart your terminal after setting environment variables.**

---

## Step 3: Install Visual Studio Build Tools (Windows Desktop)

For Windows desktop development, you need the Visual Studio C++ build tools.

### Option A: Visual Studio Community (Full IDE)
1. Download from: https://visualstudio.microsoft.com/
2. During installation, select:
   - **Desktop development with C++**
   - Windows 10/11 SDK

### Option B: Build Tools Only
1. Download Build Tools from: https://visualstudio.microsoft.com/visual-studio-cpp-build-tools/
2. Install with **Desktop development with C++** workload

---

## Step 4: Configure Flutter

### Accept Android Licenses
```powershell
flutter doctor --android-licenses
# Press 'y' to accept all licenses
```

### Enable Desktop Support
```powershell
flutter config --enable-windows-desktop
flutter config --enable-macos-desktop
flutter config --enable-linux-desktop
```

### Verify Everything
```powershell
flutter doctor -v
```

You should see checkmarks for:
- Flutter
- Windows development
- Android toolchain
- Android Studio
- VS Code (if installed)

---

## Step 5: Install VS Code (Recommended IDE)

1. Download from: https://code.visualstudio.com/
2. Install these extensions:
   - **Flutter** (by Dart Code)
   - **Dart** (by Dart Code)
   - **GitLens** (optional, for git integration)

---

## Step 6: Clone and Setup Project

```powershell
# Navigate to your projects folder
cd C:\Claude  # or your preferred location

# Clone the repository
git clone https://github.com/gnoobs75/Hamorah.git
cd Hamorah

# Get dependencies
flutter pub get
```

---

## Step 7: Run the Application

### Windows Desktop
```powershell
flutter run -d windows
```

### Android Emulator
```powershell
# List available devices
flutter devices

# Run on Android
flutter run -d <device-id>
```

### Web (for quick testing)
```powershell
flutter run -d chrome
```

---

## Troubleshooting Common Issues

### Issue: `flutter` command not found
**Solution**: Ensure Flutter is in your PATH
```powershell
# Check if Flutter is in PATH
where flutter

# If not, add it
$env:Path += ";C:\flutter\bin"
```

### Issue: Android SDK not found
**Solution**: Set ANDROID_HOME
```powershell
[Environment]::SetEnvironmentVariable("ANDROID_HOME", "$env:LOCALAPPDATA\Android\Sdk", "User")
```

### Issue: `cmdline-tools` component missing
**Solution**: Install via Android Studio
1. Open Android Studio
2. Settings > Languages & Frameworks > Android SDK
3. SDK Tools tab
4. Check "Android SDK Command-line Tools (latest)"
5. Click Apply

### Issue: SQLite errors on Windows
**Solution**: The app uses `sqflite_common_ffi` for desktop. This is already configured in `main.dart`:
```dart
if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
}
```

### Issue: Hive "Cannot create file" error
**Solution**: The app uses Application Support directory instead of Documents. This is configured in `initialization_service.dart`.

### Issue: Visual Studio not detected
**Solution**: Ensure you have the C++ workload installed:
```powershell
# Check Visual Studio installations
& "C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe" -latest -property displayName
```

---

## Environment Variables Summary

| Variable | Value | Purpose |
|----------|-------|---------|
| `ANDROID_HOME` | `%LOCALAPPDATA%\Android\Sdk` | Android SDK location |
| `PATH` additions | Flutter bin, Android cmdline-tools, platform-tools | CLI access |

---

## Project-Specific Setup

### Grok API Key
1. Get an API key from: https://console.x.ai
2. Run the app
3. Go to Settings > Grok API Key
4. Enter your key (stored securely on device)

### Bible Data
- On first run, click "Download Now" or "Use Sample Data"
- Sample data includes: Genesis 1, Psalm 23, John 1, John 3

---

## Build Commands

### Debug Build
```powershell
flutter run -d windows
```

### Release Build
```powershell
flutter build windows --release
```

### Clean Build
```powershell
flutter clean
flutter pub get
flutter run -d windows
```

---

## Useful Commands

```powershell
# Check Flutter setup
flutter doctor -v

# List connected devices
flutter devices

# Get dependencies
flutter pub get

# Upgrade dependencies
flutter pub upgrade

# Run tests
flutter test

# Analyze code
flutter analyze

# Format code
dart format .
```

---

## IDE Setup (VS Code)

### Recommended settings (`.vscode/settings.json`):
```json
{
  "dart.flutterSdkPath": "C:\\flutter",
  "editor.formatOnSave": true,
  "editor.codeActionsOnSave": {
    "source.fixAll": true
  },
  "[dart]": {
    "editor.defaultFormatter": "Dart-Code.dart-code",
    "editor.rulers": [80]
  }
}
```

### Launch configuration (`.vscode/launch.json`):
```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Hamorah (Windows)",
      "request": "launch",
      "type": "dart",
      "deviceId": "windows"
    },
    {
      "name": "Hamorah (Debug)",
      "request": "launch",
      "type": "dart"
    }
  ]
}
```

---

## Next Steps

1. Run `flutter doctor` to verify setup
2. Run the app with `flutter run -d windows`
3. Add your Grok API key in Settings
4. Start chatting with Hamorah!

---

## Support

For issues with:
- **Flutter**: https://docs.flutter.dev/
- **Android Studio**: https://developer.android.com/studio/intro
- **This project**: Create an issue on GitHub
