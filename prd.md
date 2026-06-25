# PRD — YBT Wallpaper

---

## 1. Project Overview

| Field | Detail |
|---|---|
| App Name | YBT Wallpaper |
| Frontend | Flutter (iOS + Android) |
| Backend | Node.js + Express + SQLite |
| Admin Panel | Plain HTML/CSS/JS (index.html) |
| Auth | Email + Password (JWT, no OTP) |
| Deployment | cPanel shared hosting (no build step needed) |
| Theme | Sky Blue + White + Black, Light/Dark mode |

---

## 2. Config Philosophy

### `config.dart` (Flutter)
```
- baseUrl (localhost for dev, production domain for prod)
- appName
- supportEmail
- defaultTheme
- paginationLimit
```

### `config.js` (Backend)
```
- baseUrl
- port
- dbPath
- storagePath
- jwtSecret
- jwtExpiry
- adminEmail
- adminPassword (first run only)
- appName
- supportEmail
```

**Rule:** Both files mirror each other. No `.env` file. All values hardcoded in config. Switch between localhost and production by changing one `baseUrl` value in each config file. Future settings (e.g., new feature flags, limits) added in both config files together.

---

## 3. Backend — File Structure

```
/backend
  config.js          ← all config here
  index.js           ← server entry, all routes registered here
  db.js              ← SQLite connection + schema init
  auth.js            ← register, login, JWT middleware
  users.js           ← user CRUD for admin
  wallpapers.js      ← wallpaper upload, list, delete
  categories.js      ← category CRUD
  health.js          ← server health endpoint
  storage.js         ← storage stats + file cleanup
  /storage           ← uploaded wallpaper files live here
  index.html         ← admin panel (single file)
  package.json
```

**One file per feature. No subfolders inside backend.**

---

## 4. Database Schema (SQLite)

### users
| Column | Type | Notes |
|---|---|---|
| id | INTEGER PK | auto |
| name | TEXT | |
| email | TEXT | unique |
| password | TEXT | bcrypt |
| role | TEXT | 'user' or 'admin' |
| created_at | DATETIME | |
| is_active | BOOLEAN | default true |

### categories
| Column | Type | Notes |
|---|---|---|
| id | INTEGER PK | |
| name | TEXT | unique |
| created_at | DATETIME | |

### wallpapers
| Column | Type | Notes |
|---|---|---|
| id | INTEGER PK | |
| title | TEXT | |
| file_name | TEXT | stored in /storage |
| category_id | INTEGER | FK → categories |
| uploaded_by | INTEGER | FK → users (admin) |
| downloads | INTEGER | default 0 |
| created_at | DATETIME | |
| is_active | BOOLEAN | default true |

---

## 5. Backend API Endpoints

### Auth (`auth.js`)
| Method | Route | Description |
|---|---|---|
| POST | /api/register | name, email, password, confirm_password |
| POST | /api/login | email, password → returns JWT |
| GET | /api/me | returns logged-in user info |

### Wallpapers (`wallpapers.js`)
| Method | Route | Description |
|---|---|---|
| GET | /api/wallpapers | list all (with pagination, category filter) |
| GET | /api/wallpapers/:id | single wallpaper |
| POST | /api/wallpapers | admin: upload wallpaper + metadata |
| DELETE | /api/wallpapers/:id | admin: soft delete |
| POST | /api/wallpapers/:id/download | increment download count |
| GET | /storage/:filename | serve image file |

### Categories (`categories.js`)
| Method | Route | Description |
|---|---|---|
| GET | /api/categories | list all |
| POST | /api/categories | admin: create |
| DELETE | /api/categories/:id | admin: delete |

### Users (`users.js`) — Admin only
| Method | Route | Description |
|---|---|---|
| GET | /api/users | list all users |
| PATCH | /api/users/:id/toggle | activate/deactivate user |
| DELETE | /api/users/:id | delete user |

### Health (`health.js`)
| Method | Route | Description |
|---|---|---|
| GET | /api/health | uptime, db status, storage size, version |

### Storage (`storage.js`) — Admin only
| Method | Route | Description |
|---|---|---|
| GET | /api/storage/stats | total files, used MB, free MB |
| DELETE | /api/storage/cleanup | delete orphan files not in DB |

---

## 6. Admin Panel — `index.html`

Single HTML file. No framework. Vanilla JS fetch calls to the API.

### Sections (sidebar nav)
1. **Dashboard** — total users, wallpapers, categories, storage used
2. **Wallpapers** — table list, upload form (title + category + file), delete button
3. **Categories** — table list, add form, delete button
4. **Users** — table list, activate/deactivate toggle, delete button
5. **Storage** — storage stats card, cleanup button
6. **Health** — server uptime, DB status badge (green/red)

### Design Rules
- White background, black text, sky blue accent (`#38BDF8`)
- No CSS framework — raw CSS only
- Sidebar left, content right
- Tables with minimal borders
- Admin logs in with email + password on page load (full-page login form)
- JWT stored in `localStorage`

---

## 7. Flutter App

### Config (`config.dart`)
```dart
class Config {
  static const String baseUrl = 'http://localhost:3000'; // change for prod
  static const String appName = 'YBT Wallpaper';
  static const String supportEmail = 'support@yourdomain.com';
  static const int paginationLimit = 20;
  static const String defaultTheme = 'light'; // 'light' or 'dark'
}
```

### App Structure
```
/lib
  config.dart
  main.dart
  theme.dart           ← light + dark ThemeData
  api.dart             ← all API calls in one file
  auth_screen.dart     ← splash + login + register (bottom sheet slide)
  home_screen.dart     ← wallpaper explore
  category_screen.dart ← category list + filtered wallpapers
  profile_screen.dart  ← profile + settings
  wallpaper_detail.dart ← full screen view + download (bottom sheet)
```

**One file per screen. No subfolders.**

---

## 8. Flutter Screens

### Screen 1 — Auth (`auth_screen.dart`)
- **Splash:** App logo centered, sky blue background, 2s delay → auto navigate to login if no token, else home
- **Login form:** Email + Password + Login button + "Register" text link
- **Register:** Opens as bottom sheet slide-up (not a new screen, not a popup)
  - Fields: Name, Email, Password, Confirm Password
  - Submit → closes sheet → logs in automatically

### Screen 2 — Home (`home_screen.dart`)
- Top bar: App name left, dark/light toggle right
- Search bar below top bar (filters wallpapers by title)
- Wallpaper grid (2 columns, infinite scroll)
- Tapping a wallpaper → bottom sheet slide-up with full preview + Download button
- Download increments count on backend, saves to gallery

### Screen 3 — Category (`category_screen.dart`)
- Horizontal scrollable category chips at top
- Selecting a category filters the wallpaper grid below
- Same grid + bottom sheet behavior as Home

### Screen 4 — Profile + Settings (`profile_screen.dart`)
- Shows: Name, Email, Join date
- Settings list items:
  - Dark / Light mode toggle
  - App version
  - Support email (tappable → mailto)
  - Logout (clears token, goes to auth screen)

### Bottom Nav Bar
- 3 tabs: Home, Category, Profile
- Sky blue active icon, black inactive
- No labels, just icons

---

## 9. UI/UX Rules

| Rule | Detail |
|---|---|
| No gradients | Flat color only |
| No popups/dialogs | Use bottom sheets everywhere |
| Color palette | `#38BDF8` sky blue, `#FFFFFF` white, `#000000` black |
| Dark mode colors | `#0F172A` background, `#1E293B` surface, `#38BDF8` accent, `#FFFFFF` text |
| Typography | System font, clean weight hierarchy |
| Spacing | Consistent 16px padding, 8px gap |
| Images | Cached network images with shimmer placeholder |
| Animations | Subtle: bottom sheet slide, image fade-in only |

---

## 10. Authentication Flow

```
Register → POST /api/register → receive JWT → store in SharedPreferences → go to Home

Login → POST /api/login → receive JWT → store in SharedPreferences → go to Home

Logout → clear SharedPreferences → go to Auth screen

All API calls → attach JWT in Authorization: Bearer <token> header

Token expired → catch 401 → auto logout + redirect to Auth
```

---

## 11. Deployment on cPanel

### Backend
- Upload entire `/backend` folder via cPanel File Manager or FTP
- Run `npm install` once via cPanel Terminal
- Start server using cPanel Node.js App manager (entry: `index.js`)
- `/storage` folder must have write permissions (`chmod 755`)
- SQLite DB file auto-created on first run in `dbPath` from `config.js`
- Admin account auto-created on first run using `adminEmail` + `adminPassword` from `config.js`
- `index.html` served at `/admin` route by Express static or dedicated route

### Flutter
- Change `baseUrl` in `config.dart` to production domain
- Build APK: `flutter build apk --release`
- Distribute APK directly (no Play Store required for internal use)

---

## 12. Feature Checklist

- [ ] Register (name, email, password, confirm password)
- [ ] Login (email + password, JWT)
- [ ] Splash screen with auto-auth check
- [ ] Wallpaper grid with pagination
- [ ] Category filter
- [ ] Wallpaper download to gallery + count tracking
- [ ] Dark / Light mode toggle (persisted)
- [ ] Profile screen
- [ ] Admin: wallpaper upload + delete
- [ ] Admin: category add + delete
- [ ] Admin: user list + activate/deactivate + delete
- [ ] Admin: storage stats + orphan file cleanup
- [ ] Admin: health check (uptime, DB status)
- [ ] Config-driven (one file each side, no .env)
- [ ] cPanel deploy ready (no build step on server)

---

## 13. Future Extension Points

All future additions require changes in only 2 places: `config.dart` and `config.js`.

| Future Feature | Config Key to Add |
|---|---|
| Push notifications | fcmKey, notificationEnabled |
| Premium wallpapers | premiumEnabled, razorpayKey |
| Watermark on download | watermarkEnabled, watermarkText |
| Rate limiting | rateLimitWindow, rateLimitMax |
| CDN for images | cdnEnabled, cdnBaseUrl |
| Analytics | analyticsEnabled, analyticsKey |

---

*PRD Version 1.0 — YBT Wallpaper*