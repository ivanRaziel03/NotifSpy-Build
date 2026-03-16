# NotifSpy - Notification Tracker & Recovery

A sleek Android notification spy app built with Flutter. Captures all incoming notifications, detects deleted/dismissed ones, and lets you filter by app or contact. Especially useful for recovering deleted WhatsApp messages.

![Flutter](https://img.shields.io/badge/Flutter-3.9+-02569B?logo=flutter)
![Dart](https://img.shields.io/badge/Dart-3.9+-0175C2?logo=dart)
![Android](https://img.shields.io/badge/Android-NotificationListenerService-3DDC84?logo=android)
![License](https://img.shields.io/badge/License-Private-red)

## Features

### Notification Capture
- Intercepts all incoming notifications via Android's `NotificationListenerService`
- Stores full notification content locally (title, text, big text, sub text, category, conversation)
- Detects when notifications are removed/dismissed and marks them as deleted
- Skips group summaries and self-notifications to keep the feed clean

### Filtering & Search
- **Quick Filters:** All, WhatsApp, Messaging, Deleted
- **App Browser:** See all tracked apps with notification counts and deleted counts
- **Contact Filter:** Within any app, filter by sender/contact name
- **Full-text Search:** Search across title, text, and app name

### WhatsApp Focus
- Dedicated WhatsApp filter for quick access
- Per-contact filtering within WhatsApp notifications
- Deleted message recovery (if the notification was captured before deletion)
- Support for both WhatsApp and WhatsApp Business

### Privacy & Security
- All data is stored locally on-device using Hive
- No server, no cloud, no analytics, no tracking
- No internet permission required for core functionality
- Only requires `BIND_NOTIFICATION_LISTENER_SERVICE` permission

### UI/UX
- Dark-first design with a purple/cyan accent palette
- Light mode available via settings
- Date-grouped notification feed with relative timestamps
- Swipe-to-delete on individual notifications
- Stats bar showing total captured, deleted count, and tracked apps
- Clean detail screen with metadata, timestamps, and copy-to-clipboard

## Tech Stack

| Layer | Technology |
|-------|-----------|
| UI | Flutter 3.9+, Material Design 3 |
| State | Provider |
| Storage | Hive (local NoSQL) |
| Native | Kotlin, `NotificationListenerService` |
| Platform Channel | `MethodChannel` + `EventChannel` |

## Project Structure

```
lib/
├── main.dart                          # Entry point, permission check, routing
├── models/
│   └── captured_notification.dart     # Hive model for captured notifications
├── screens/
│   ├── home_screen.dart               # Main feed with filters and search
│   ├── permission_screen.dart         # Onboarding: grant notification access
│   ├── notification_detail_screen.dart # Full notification detail view
│   ├── app_filter_screen.dart         # Browse by app
│   ├── app_notifications_screen.dart  # Notifications for a specific app
│   └── settings_screen.dart           # Theme, data management, status
├── services/
│   ├── hive_service.dart              # Hive initialization and adapters
│   ├── theme_service.dart             # Dark/light mode persistence
│   └── notification_listener_service.dart  # Platform channel bridge
├── theme/
│   └── app_theme.dart                 # Dark/light themes, app colors
└── widgets/
    ├── notification_tile.dart         # Reusable notification list item
    └── empty_state.dart               # Empty state placeholder

android/app/src/main/kotlin/com/example/samapp/
├── MainActivity.kt                    # Platform channel setup
└── NotifSpyListenerService.kt         # Native notification listener
```

## Installation

### Prerequisites
- Flutter SDK 3.9+
- Android device (notification listener is Android-only)
- USB debugging enabled

### Steps

```bash
git clone <repo-url>
cd SamandariApp
flutter pub get
dart run build_runner build
flutter run
```

On first launch, the app will ask for Notification Access permission. Grant it in Android Settings to start capturing.

## How It Works

1. **Native Layer:** `NotifSpyListenerService` extends Android's `NotificationListenerService`. It receives callbacks for every posted and removed notification system-wide.

2. **Platform Channel:** `MainActivity` bridges native events to Flutter via an `EventChannel`. Notifications are streamed in real-time to the Dart side.

3. **Storage:** Each notification is saved as a `CapturedNotification` in a Hive box. When a notification is removed, matching entries are marked as `isRemoved = true`.

4. **UI:** The home screen displays a live feed of all captured notifications, grouped by date. Filters, search, and per-app views let you find what you need.

## Permissions

| Permission | Purpose |
|-----------|---------|
| `BIND_NOTIFICATION_LISTENER_SERVICE` | Core: intercept notifications |
| `INTERNET` | Optional: future features |
| `POST_NOTIFICATIONS` | Show local notifications if needed |
| `WAKE_LOCK` | Keep listener alive in background |

## Author

**Samandari**

---

*All data stays on your device. No cloud. No tracking. Your notifications, your control.*
