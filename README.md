```text
  ███╗   ███╗ ██████╗ ███╗   ██╗███████╗██╗   ██╗
  ████╗ ████║██╔═══██╗████╗  ██║██╔════╝╚██╗ ██╔╝
  ██╔████╔██║██║   ██║██╔██╗ ██║█████╗   ╚████╔╝ 
  ██║╚██╔╝██║██║   ██║██║╚██╗██║██╔══╝    ╚██╔╝  
  ██║ ╚═╝ ██║╚██████╔╝██║ ╚████║███████╗   ██║   
  ╚═╝     ╚═╝ ╚═════╝ ╚═╝  ╚═══╝╚══════╝   ╚═╝   
  ████████╗██████╗  █████╗  ██████╗██╗  ██╗███████╗██████╗ 
  ╚══██╔══╝██╔══██╗██╔══██╗██╔════╝██║ ██╔╝██╔════╝██╔══██╗
     ██║   ██████╔╝███████║██║     █████╔╝ █████╗  ██████╔╝
     ██║   ██╔══██╗██╔══██║██║     ██╔═██╗ ██╔══╝  ██╔══██╗
     ██║   ██║  ██║██║  ██║╚██████╗██║  ██╗███████╗██║  ██║
     ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝
```

# 💰 Money Tracker - Income Timeline Manager

### *A Smart, Secure, and Elegant Income Tracking Solution built with Flutter*

> **A beautifully designed mobile application to forecast, track, and manage your upcoming and received income.**
> Featuring recurring projections, local database management, robust security via PIN, and a dynamic dashboard for complete financial visibility!

[![Made by](https://img.shields.io/badge/Made%20by-Naimur%20Rashid-0e76a8?style=flat-square)](#)
[![Year](https://img.shields.io/badge/Year-2026-0e76a8?style=flat-square)](#)
[![License](https://img.shields.io/badge/License-MIT-green?style=flat-square)](#)
[![Dart](https://img.shields.io/badge/Dart-3.0+-blue?style=flat-square)](#)
[![Framework](https://img.shields.io/badge/Framework-Flutter-02569B?style=flat-square)](#)

<br/>

[![Download APK](https://img.shields.io/badge/Download-APK-2ea44f?style=for-the-badge&logo=android)](https://github.com/naimurhamim/income-timeline-tracker-app/releases/latest)



## 📌 Project Overview

Money Tracker is a feature-rich financial application focused exclusively on tracking **Income**. It allows users to manage fixed deposits, savings, DPS, bonds, and other recurring or one-time income sources. 

The system provides a clear timeline of upcoming receivables, automatically projecting future dates for recurring entries (Monthly, Quarterly, Half-Yearly, Yearly) up to a defined expiry date. With local persistence, no data ever leaves the user's device, ensuring maximum privacy and security.

**Core Objectives:**
- Provide a clear, timeline-based forecast of expected income (Next 3 months, Yearly, etc.).
- Ensure a premium, butter-smooth UI/UX using `flutter_animate` and glassmorphism design principles.
- Deliver cross-platform support (Android).
- Keep data 100% offline and secure with local SQLite and PIN lock authentication.

---

## ✨ Features

| Feature | Description |
|---|---|
| 🔄 **Smart Recurring Projections** | Automatically calculates future dates and totals for recurring income until a set expiry date. |
| 📊 **Dynamic Analytics** | Provides estimated yearly totals, next 3 months projections, and categorical breakdowns. |
| 🔒 **PIN Lock Security** | Secures financial data with a custom in-app PIN lock system. |
| 🔔 **Local Notifications** | Sends automated background reminders (7 days before, 3 days before, and on the exact day) for upcoming income. |
| 🎨 **Premium UI & Dark Mode** | Built with an aesthetically pleasing gradient-rich design, smooth bouncy tap interactions, and seamless dark mode support. |
| 💱 **Multi-Currency Support** | Switch between BDT, USD, EUR, and more globally used currencies seamlessly. |

---

## 🛠️ Tech Stack

| Component | Technology |
|---|---|
| **Framework** | Flutter |
| **Language** | Dart |
| **State Management** | Provider |
| **Local Database** | SQLite (`sqflite`) |
| **Animations** | `flutter_animate`, Custom Route Transitions |
| **Local Notifications** | `flutter_local_notifications` |

---

## 🚀 Getting Started

### 1. Prerequisites
- Flutter SDK (stable channel)
- Dart SDK
- Android Studio / VS Code
- Visual Studio (for Windows Desktop builds)

### 2. Installation
```powershell
# Clone the repository
git clone <repository_url>
cd MoneyTracker

# Get dependencies
flutter pub get

# Run the app
flutter run
```

### 3. Building for Production
```powershell
# Build Android APK
flutter build apk --release
```

---

## 📁 Repository Structure
```text
MoneyTracker/
│
├── android/                # Android native project files
├── assets/                 # Images, Fonts, Icons
├── lib/                    # Source Code
│   ├── database/           # SQLite database helpers and migrations
│   ├── models/             # Data classes (Entry, Category)
│   ├── providers/          # State management (EntryProvider, ThemeProvider, etc.)
│   ├── screens/            # UI Screens (Dashboard, Entries, Summary, Settings)
│   ├── services/           # Background services (Notifications, Auth)
│   ├── theme/              # Colors, TextStyles, Dark/Light mode definitions
│   └── widgets/            # Reusable UI components (Cards, Tiles, Animations)
│
├── pubspec.yaml            # Flutter dependencies and assets configuration
└── README.md               # Project documentation
```

---

## 👨‍💻 Author

**MD Naimur Rashid (Hamim)**
- 🌐 **Website:** [naimurrashid.dev](https://naimurrashid.dev/)
- 💼 **LinkedIn:** [md-naimur-rashid](https://www.linkedin.com/in/md-naimur-rashid/)
- 🐙 **GitHub:** [@naimurhamim](https://github.com/naimurhamim)

---
*Built as a showcase for Advanced Mobile App Development, combining clean architecture, premium UI/UX, and robust local data management.*
