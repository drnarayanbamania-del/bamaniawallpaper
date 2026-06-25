# 📱 YBT Wallpaper

[![Flutter](https://img.shields.io/badge/Flutter-%2302569B.svg?style=flat&logo=Flutter&logoColor=white)](#-flutter-app-setup)
[![Node.js](https://img.shields.io/badge/Node.js-6DB33F?style=flat&logo=node.js&logoColor=white)](#-backend-setup)
[![SQLite](https://img.shields.io/badge/SQLite-07405E?style=flat&logo=sqlite&logoColor=white)](#-backend-setup)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A complete, production-ready wallpaper platform consisting of a lightweight **Node.js + SQLite backend**, a responsive vanilla **HTML5 Admin Dashboard**, and a modern, high-performance **Flutter client app** for Android and iOS. Built with a clean, flat-design philosophy.

---

## 🌟 Key Features

*   **⚡ Node.js Backend & API:** High-performance, lightweight JSON API built with Express and SQLite.
*   **🛡️ Secure JWT Authentication:** Robust user registration and login with JWT-based session security.
*   **📊 Vanilla Admin Dashboard:** An elegant, responsive, single-file administrative panel to manage wallpapers, categories, users, storage, and server health.
*   **📱 Modern Flutter App:** Clean, minimal UX featuring infinite-scroll wallpaper grids, search filtering, category tabs, and interactive bottom-sheet actions.
*   **🌗 Adaptive Dark & Light Modes:** Seamlessly toggles themes across both the mobile application and admin panel.
*   **📦 Easy cPanel Deployment:** Optimized for shared hosting with no complex build steps required.

---

## 📂 Repository Structure

```text
├── Backend/                 # Node.js + Express Backend
│   ├── storage/             # User-uploaded wallpaper files (automatically created)
│   ├── auth.js              # JWT registration & login logic
│   ├── categories.js        # Category CRUD API
│   ├── config.js            # Unified backend configurations
│   ├── db.js                # SQLite connection & DB initialization
│   ├── health.js            # Server metrics & DB status API
│   ├── index.html           # Full-featured Admin Dashboard (Vanilla JS/CSS)
│   ├── index.js             # Main server entry & routing
│   ├── package.json         # NPM packages and scripts
│   ├── storage.js           # Storage analytics & cleanup API
│   ├── users.js             # User administration API
│   └── wallpapers.js        # Wallpaper upload, pagination, & download APIs
│
├── ybt_wallpaper/           # Flutter Mobile Application
│   ├── lib/
│   │   ├── api.dart         # Direct API service integration
│   │   ├── auth_screen.dart # Splash, login, and registration screen
│   │   ├── config.dart      # Application environment configurations
│   │   ├── home_screen.dart # Discover grid & search UI
│   │   ├── main.dart        # Flutter application launcher
│   │   ├── theme.dart       # App styling & dark/light theme definitions
│   │   └── ...              # Screens and helpers
│   └── pubspec.yaml         # Flutter dependencies
│
└── prd.md                   # Original Product Requirement Document
```

---

## ⚙️ Config Philosophy

This platform implements a **mirrored config design** to simplify setup and maintenance. Instead of using complex `.env` files, settings are controlled in one file per project:

*   **Backend:** Configured via `Backend/config.js`
*   **Flutter App:** Configured via `ybt_wallpaper/lib/config.dart`

To switch between development (localhost) and production, simply update the `baseUrl` in these two files.

---

## 🚀 Backend Setup

The backend utilizes **Node.js**, **Express**, and **SQLite**. Database tables are auto-initialized on the first run.

### 1. Prerequisites
Ensure you have [Node.js](https://nodejs.org/) installed (v16.x or higher recommended).

### 2. Configure Settings
Open `Backend/config.js` and update configuration properties as needed:
```javascript
module.exports = {
  baseUrl: 'http://localhost:3000', // Update to your domain in production
  port: 3000,
  dbPath: './ybt_wallpaper.db',
  storagePath: './storage',
  jwtSecret: 'your-very-secure-jwt-secret-key', // Change this to a secure random string
  jwtExpiry: '7d',
  adminEmail: 'admin@yourdomain.com',
  adminPassword: 'securepassword', // Initial password used to seed admin account on first run
  appName: 'YBT Wallpaper',
  supportEmail: 'support@yourdomain.com'
};
```

### 3. Installation & Local Development
Run the following commands in the `Backend` directory:
```bash
# Navigate to the Backend folder
cd Backend

# Install dependencies
npm install

# Start the server (runs on port 3000 by default)
npm start
```

### 4. Admin Panel Access
*   Once running locally, open `http://localhost:3000/admin` (or `/` depending on your Express routes) in a web browser.
*   Log in using the `adminEmail` and `adminPassword` defined in your config file.
*   *Note: Express automatically registers the admin static panel to `/admin` or coordinates index routes.*

### 5. Deployment on cPanel Shared Hosting
1.  Upload the entire `/Backend` directory to your cPanel directory (e.g., `public_html` or a custom application root).
2.  Set up a **Node.js App** through your cPanel Node.js Application Manager:
    *   **Application Startup File:** Set to `index.js` (or `server.js` if applicable).
    *   **Application entry point:** `index.js`.
3.  Ensure the `/storage` directory has write permissions (`chmod 755` or `777`).
4.  Run `NPM Install` via the cPanel App interface.
5.  Start the Node.js application.

---

## 📱 Flutter App Setup

The Flutter application provides a smooth, native experience for both iOS and Android.

### 1. Prerequisites
Ensure you have [Flutter SDK](https://docs.flutter.dev/get-started/install) installed and configured on your machine.

### 2. Configure API Endpoint
Open `ybt_wallpaper/lib/config.dart` and modify the API base URL to match your backend:
```dart
class Config {
  static const String baseUrl = 'http://localhost:3000'; // For local testing
  // static const String baseUrl = 'https://your-production-domain.com'; // For production
  static const String appName = 'YBT Wallpaper';
  static const String supportEmail = 'support@yourdomain.com';
  static const int paginationLimit = 20;
  static const String defaultTheme = 'light'; // 'light' or 'dark'
}
```
> [!NOTE]
> If testing on an Android Emulator, use `http://10.0.2.2:3000` instead of `localhost` to connect to your host machine's backend.

### 3. Running the App
Execute the following commands in the `ybt_wallpaper` directory:
```bash
# Navigate to the Flutter directory
cd ybt_wallpaper

# Fetch Flutter packages
flutter pub get

# Run the app in debug mode on a connected emulator or device
flutter run
```

### 4. Production Build
To generate release builds:
```bash
# For Android APK
flutter build apk --release

# For iOS archive
flutter build ipa --release
```

---

## 🌐 API Reference

### 🔐 Authentication (`auth.js`)
*   `POST /api/register` — Register a new user (receives JWT).
*   `POST /api/login` — Login user (returns JWT token).
*   `GET /api/me` — Retrieve credentials of current user (Requires Authorization header).

### 🖼️ Wallpapers (`wallpapers.js`)
*   `GET /api/wallpapers` — Fetch paginated list of wallpapers (supports category query & search search).
*   `GET /api/wallpapers/:id` — Retrieve details for a single wallpaper.
*   `POST /api/wallpapers` — Upload new wallpaper (Admin only, multipart form).
*   `DELETE /api/wallpapers/:id` — Soft-delete wallpaper (Admin only).
*   `POST /api/wallpapers/:id/download` — Increment download count tracker.

### 🗂️ Categories (`categories.js`)
*   `GET /api/categories` — Get all active categories.
*   `POST /api/categories` — Create category (Admin only).
*   `DELETE /api/categories/:id` — Delete category (Admin only).

### 👤 Users (`users.js`)
*   `GET /api/users` — List all registered users (Admin only).
*   `PATCH /api/users/:id/toggle` — Toggle user activation status (Admin only).
*   `DELETE /api/users/:id` — Delete user account (Admin only).

---

## 🎨 UI & UX Guidelines
*   **Colors:** Minimalist palette featuring Sky Blue (`#38BDF8`), pure White (`#FFFFFF`), Slate (`#0F172A`/`#1E293B` for dark mode surfaces), and crisp Black.
*   **Interactivity:** Smooth bottom-sheet drawer slides for previewing, download details, and user registration.
*   **Media Handling:** Wallpaper images are loaded asynchronously using cached network image streams, using elegant shimmers to improve the user experience.

---

## Connect with Us

[![YouTube](https://img.shields.io/badge/YouTube-FF0000?style=for-the-badge&logo=youtube&logoColor=white)](https://youtube.com/@You_B_Tech)
[![GitHub](https://img.shields.io/badge/GitHub-181717?style=for-the-badge&logo=github&logoColor=white)](https://github.com/YouBTech01)
[![Instagram](https://img.shields.io/badge/Instagram-E4405F?style=for-the-badge&logo=instagram&logoColor=white)](https://instagram.com/you_b_tech)
[![Telegram](https://img.shields.io/badge/Telegram-26A69A?style=for-the-badge&logo=telegram&logoColor=white)](https://t.me/You_B_Tech)
[![Blog](https://img.shields.io/badge/Blog-ybtshop.com-blue?style=for-the-badge&logo=google-chrome&logoColor=white)](https://ybtshop.com)

