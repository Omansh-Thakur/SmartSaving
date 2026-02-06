# 💰 SmartSaving

A Flutter app that helps you track and compare product prices across Amazon and Flipkart. Stop manually checking prices every time you want to buy something!

## 📋 What's Inside?

- [What is this?](#what-is-this)
- [Features](#features)
- [Quick Start](#quick-start)
- [Project Setup](#project-setup)
- [How it works](#how-it-works)
- [What we used](#what-we-used)
- [Folder Structure](#folder-structure)
- [Development](#development)
- [Build & Run](#build--run)
- [Issues & Help](#issues--help)
- [Our Team](#our-team)
- [License](#license)

---

## 🎯 What is this?

Ever found yourself comparing prices on Amazon and Flipkart endlessly? SmartSaving does that for you automatically!

It's an app where you can:

- Search for products you want to buy
- See price differences between Amazon and Flipkart instantly
- Track how prices change over time with nice charts
- Get notifications when prices drop
- Get predictions on when's the best time to buy

We built this as a student project to solve a real problem we face every day.

**Made by**: 3 students who were tired of comparing prices manually 😅

---

## ✨ Features

### 🔐 User Accounts

- Create an account with email and password
- Your data stays logged in even after you close the app
- Personalized profile

### 🔍 Search Products

- Search for anything across 8+ categories
- See all the products available
- Filter by price if you want

### 💳 Compare Prices

- See Amazon and Flipkart prices side by side
- Instantly know which is cheaper
- Click to buy directly from the app

### 📈 Price History

- Beautiful charts showing are price trends
- See if prices are going up or down
- Track for weeks, months

### 🤖 Smart Predictions

- We predict when prices will drop
- Shows you "best time to buy"
- Based on patterns we found in data

### 🔔 Price Alerts

- Get a notification when price drops
- Set your target price
- Never miss a deal

### ❤️ Save Products

- One click to save products
- Track multiple items at once
- Easy access later

### 💵 For Indians

- All prices in ₹ (Indian Rupees)
- Proper formatting with commas
- Ready for Hindi later

---

## 🚀 Quick Start

### What you need

- Flutter 3.10+
- Dart 3.10+
- Android emulator or iOS simulator (or a real phone)

### Get it running (5 minutes)

```bash
# Clone
git clone https://github.com/Omansh-Thakur/SmartSaving.git
cd SmartSaving

# Install dependencies
flutter pub get

# Run it!
flutter run
```

### Login Details (for testing)

Just use these fake accounts:

```
Email: test@example.com
Password: password123
```

Or make your own account!

---

## 📦 Project Setup

### Prerequisites

Make sure you have:

- **Flutter** - 3.10+
- **Dart** - 3.10+
- **Android SDK** - API 21+ (if testing on Android)
- **Xcode** - 14+ (if testing on iOS)
- **Git** - to clone the repo

### Installation

1. **Clone the repo**

   ```bash
   git clone https://github.com/Omansh-Thakur/SmartSaving.git
   cd SmartSaving
   ```

2. **Get dependencies**

   ```bash
   flutter pub get
   ```

3. **Run the app**
   ```bash
   flutter run
   ```

### Run on specific device

```bash
# See available devices
flutter devices

# Run on specific device
flutter run -d <device_id>
```

---

## 🏗️ How it works

```
UI (Screens)
    ↓
State Management (Riverpod)
    ↓
Business Logic (Providers)
    ↓
Services (Amazon, Flipkart, Auth)
    ↓
Local Storage (Shared Preferences)
```

We used **Riverpod** for state management because it's clean and easy to test. **Shared Preferences** stores everything locally so the app works even without internet (with cached data).

---

## 🛠️ What we used

| What                   | Why                                            |
| ---------------------- | ---------------------------------------------- |
| **Flutter**            | Cross-platform (Android + iOS in one codebase) |
| **Riverpod**           | State management is easier                     |
| **Material Design 3**  | Looks modern and professional                  |
| **FL Chart**           | Price history charts look beautiful            |
| **Shared Preferences** | Store data locally, simple & reliable          |

---

## 📁 Folder Structure

```
lib/
├── main.dart                  # App starts here
├── models/                    # Data structures
│   ├── user.dart
│   ├── product.dart
│   ├── tracked_product.dart
│   └── price_alert.dart
├── services/                  # Talking to APIs & Auth
│   ├── auth_service.dart      # Login/Register (mock)
│   ├── amazon_service.dart    # Amazon prices (mock)
│   ├── flipkart_service.dart  # Flipkart prices (mock)
│   └── notification_service.dart
├── providers/                 # State management
│   ├── auth_provider.dart
│   ├── product_provider.dart
│   ├── tracked_products_provider.dart
│   └── price_prediction_provider.dart
├── screens/                   # App pages
│   ├── splash_screen.dart
│   ├── login_screen.dart
│   ├── register_screen.dart
│   ├── home_screen.dart
│   ├── product_detail_screen.dart
│   └── price_history_screen.dart
├── widgets/                   # Reusable UI pieces
│   ├── product_card.dart
│   ├── price_comparison_widget.dart
│   └── custom_app_bar.dart
└── utils/
    ├── constants.dart
    ├── validators.dart
    └── theme.dart
```

---

## 👨‍💻 Development

### Formatting & Linting

```bash
# Format code (recommended before committing)
flutter format lib/

# Check for issues
flutter analyze
```

### Running Tests

```bash
# Run all tests
flutter test

# Run specific test
flutter test test/widget_test.dart
```

### Useful commands

```bash
# Clean everything (sometimes fixes random issues)
flutter clean

# See verbose output (helps debugging)
flutter run -v

# Generate code if needed
flutter pub run build_runner build
```

---

## 📦 Build & Run

### For Android

```bash
# Test build
flutter build apk --debug

# For Google Play Store
flutter build appbundle --release

# Just APK (release)
flutter build apk --release
```

### For iOS

```bash
# Debug
flutter build ios --debug

# Release
flutter build ios --release
```

### Before Publishing

- [ ] Update version in `pubspec.yaml`
- [ ] All tests pass: `flutter test`
- [ ] No warnings: `flutter analyze`
- [ ] Tested on real device
- [ ] Updated CHANGELOG.md
- [ ] Created git tag: `git tag v1.0.0`

---

## 🔧 Issues & Help

### Common Problems

| Problem             | Fix                                           |
| ------------------- | --------------------------------------------- |
| App won't run       | Try `flutter clean` then `flutter pub get`    |
| Can't find emulator | Run `flutter devices` to see what's available |
| Gradle errors       | Same as above - run `flutter clean`           |
| iOS pod issues      | Go to `ios/` folder and run `pod install`     |
| App is slow         | Use a real phone instead of emulator          |

### Getting Help

- Check the error message carefully - it usually tells you what's wrong
- Google the error (seriously, that works!)
- Check out [Flutter docs](https://flutter.dev)
- Create an issue on GitHub

---

## 🤝 Want to help?

If you wanna add features or fix bugs:

1. Fork the project
2. Make a branch: `git checkout -b feature/cool-stuff`
3. Make changes
4. Commit: `git commit -m 'Added cool stuff'`
5. Push: `git push origin feature/cool-stuff`
6. Open a Pull Request

---

## 📄 License

MIT License - do whatever you want with it (credit us though! 😊)

---

## 👥 Our Team

| Name                | What we did                       |
| ------------------- | --------------------------------- |
| **Omansh Thakur**   | Full Stack Development & Services |
| **Sanchit Agarwal** | Backend & Authentication          |
| **Noman Siddique**  | UI & Widgets                      |

---

## 📞 Contact

- **Email**: [omanshthakur9211@gmail.com](mailto:omanshthakur9211@gmail.com)
- **GitHub**: [SmartSaving Issues](https://github.com/Omansh-Thakur/SmartSaving/issues)

---

## 🙏 Thanks

- Flutter team for making this framework
- Google for Material Design
- Everyone who tested and gave feedback

---

**Made with ❤️ by NIT Delhi students in 2026**

_Version 1.0.0 | Last updated: February 2026_
