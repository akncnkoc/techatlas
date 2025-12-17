# TechAtlas

TechAtlas is a comprehensive Smart Board application developed with Flutter for Windows. It provides seamless access to educational resources, focusing on PDF book viewing, Google Drive integration, and interactive drawing capabilities.

## Features

-   **Smart PDF Viewer**:
    -   High-performance PDF rendering.
    -   Zoom and pan capabilities.
    -   Support for "cropped" questions/sections (using `.book` format).
    -   Tabbed interface for opening multiple books.
-   **Google Drive Integration**:
    -   Browsing files and folders directly within the app.
    -   Access Code system for secure folder access.
    -   Service Account authentication (encrypted).
-   **Drawing Tools**:
    -   Integrated "Drawing Pen" (Cizim Kalemi) mode.
    -   Toggle between drawing and mouse interaction.
-   **Local Library**:
    -   "My Books" section for downloaded content.
    -   Recent files history.
-   **Security**:
    -   Service account credentials are **encrypted** (`assets/service_account.enc`) and decrypted at runtime.
    -   Plaintext keys are excluded from the codebase and builds.

## Setup & Development

### Prerequisites

-   [Flutter SDK](https://flutter.dev/docs/get-started/install/windows) (Stable channel)
-   Visual Studio with C++ workload (for Windows development)
-   Dart SDK

### Dependencies

Install dependencies:

```bash
flutter pub get
```

### Credentials

The application requires Google Cloud Service Account credentials.
These are stored in `assets/service_account.enc` (encrypted).

If you need to update the credentials:
1.  Place the new `service_account.json` in the project root.
2.  Run the encryption script:
    ```bash
    flutter pub run tool/encrypt_sa.dart
    ```
3.  This will update `assets/service_account.enc`.
4.  **Do not commit** the plaintext `service_account.json`.

## Building for Windows

To create a release build:

```bash
flutter build windows --release
```

The output will be in `build\windows\x64\runner\Release`.

## Packaging for GitHub Release

To create a distributable ZIP file (which includes the app, assets, and launcher scripts):

```powershell
.\package_for_github.ps1
```

This will generate `techatlas.zip` in the project root, ready for upload.

## Installer

The project includes a custom bootstrap installer (`TechAtlas_Setup.exe`) built from `Installer_Bootstrap.cs`.
To compile the installer:

```powershell
.\build_installer.ps1
```

## Architecture

-   **Frontend**: Flutter (Material Design 3)
-   **State Management**: `setState` & simple local state (planned migration to Provider/Riverpod if complexity grows).
-   **Storage**:
    -   `shared_preferences` for settings.
    -   Local file system for downloaded books.
    -   Google Drive API for cloud content.
-   **Windows Integration**: `window_manager` for window control, fullscreen, and always-on-top behaviors.
