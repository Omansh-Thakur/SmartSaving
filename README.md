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

---

<!-- comment -->

## ✨ Features

✅ **User Authentication**

- Email/password signup and login
- Persistent session management
- Secure logout

✅ **Product Search & Listing**

- Real-time product search
- Price comparison across platforms
- Beautiful product cards with ratings
- One-tap tracking

✅ **Price Comparison**

- Side-by-side Amazon vs Flipkart prices
- Automatic best price highlighting
- Savings calculation

✅ **Price History & Analytics**

- Interactive price trend charts
- Historical price snapshots
- 7-day, 30-day, 90-day views

✅ **Price Prediction**

- AI-powered price trend analysis
- "Best time to buy" recommendations
- Confidence scores

✅ **Price Alerts**

- Set target prices for tracked products
- Local notifications on price drops
- Real-time alert triggering

✅ **Tracked Products Dashboard**

- Personalized product watchlist
- Quick price updates
- One-tap access to price history

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

Just use this sample accounts:

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
- **Android SDK** - API 21+ (for Android)
- **Xcode** - 14+ (for iOS)
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

## Key Components

### Authentication Flow

```
LoginScreen → AuthService → StorageService → Home
```

### Product Search Flow

```
SearchInput → ProductProvider → AmazonService/FlipkartService → ProductCards
```

### Price Tracking Flow

```
Track Button → TrackedProductsNotifier → StorageService → Dashboard
```

### Price History Flow

```
Track Product → PriceHistory Updates → PricePrediction → Charts
```
---

## 🛠️Tech Stack
```
- **Framework**: Flutter 3.10+
- **Language**: Dart
- **State Management**: Riverpod 2.4.0
- **Local Storage**: Shared Preferences
- **Charts**: FL Chart
- **Notifications**: Flutter Local Notifications
- **Architecture**: Clean Architecture with MVVM pattern
```
---

## 📁 Folder Structure

```
lib/
├── main.dart (101 lines)
├── models/ (4 files)
│   ├── user.dart
│   ├── product.dart
│   ├── tracked_product.dart
│   └── price_alert.dart
├── services/ (7 files)
│   ├── auth_service.dart
│   ├── storage_service.dart
│   ├── amazon_service.dart
│   ├── flipkart_service.dart
│   ├── price_comparison_service.dart
│   ├── price_prediction_service.dart
│   └── notification_service.dart
├── providers/ (4 files)
│   ├── auth_provider.dart
│   ├── product_provider.dart
│   ├── tracked_products_provider.dart
│   └── price_prediction_provider.dart
├── screens/ (6 files)
│   ├── splash_screen.dart
│   ├── login_screen.dart
│   ├── register_screen.dart
│   ├── home_screen.dart
│   ├── product_detail_screen.dart
│   └── price_history_screen.dart
├── widgets/ (4 files)
│   ├── product_card.dart
│   ├── price_comparison_card.dart
│   ├── loading_skeleton.dart
│   └── app_bar.dart
└── utils/ (3 files)
    ├── constants.dart
    ├── currency_formatter.dart
    └── date_formatter.dart
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

do whatever you want with it (credit us though! 😊)

---

## 👥 Our Team

| Name                | What we did                       |
| ------------------- | --------------------------------- |
| **Omansh Thakur**   | Full Stack Development & Services |
| **Sanchit Agrawal** | Backend & Authentication          |
| **Noman Siddique**  | UI & Widgets                      |

---

## 📞 Contact

- **Email**: [omanshthakur9211@gmail.com](mailto:omanshthakur9211@gmail.com)
- **GitHub**: [SmartSaving Issues](https://github.com/Omansh-Thakur/SmartSaving/issues)

---

**Made with ❤️ by NIT Delhi students in 2026**

_Version 1.0.0 | Last updated: April 2026_
