# Decisions

## Phase 0

### Project location

The app lives in `D:\Hekal`, not `C:\dev\garage_erp`. The path is plain ASCII with no spaces. Flutter Windows builds break or lock when the path contains Arabic characters or the folder is synced by OneDrive. Confirm this drive is not a OneDrive/Desktop synced folder before relying on daily builds.

### Flutter SDK location

Flutter is installed at `C:\dev\flutter` (stable 3.47.8, Dart 3.13.7). The SDK is kept outside the app repo so upgrades do not mix with project history.

### Visual Studio vs Build Tools

The machine had no Visual Studio. Phase 0 installed **Visual Studio 2022 Build Tools 17.14.42** with the `VCTools` workload, MSVC 14.44, CMake, and Windows 11 SDK 10.0.26100. That is enough for Flutter Windows. The full Community IDE is not required. Android SDK was not installed on purpose.

### No database in Phase 0

There was no attached `database.dart`. The Drift schema, `garage.sqlite`, repositories, and seed data are authored in **Phase 2** from the master prompt data model. Phase 0 only reserves `lib/core/db/`.

### Packages

Only packages listed in the master prompt are used. `cupertino_icons` from `flutter create` was removed. Versions are the latest compatible with Flutter 3.47 / Dart 3.13 at the time of bootstrap.

### Fonts

Google currently ships Cairo as one variable TTF (`Cairo[slnt,wght].ttf` from `google/fonts`). Static Regular/SemiBold/Bold files are not published on that tree. The variable file is copied to `assets/fonts/Cairo-Regular.ttf`, `Cairo-SemiBold.ttf`, and `Cairo-Bold.ttf` and registered at weights 400, 600, and 700 so the UI and later PDFs stay offline. Phase 1 will confirm joining and mixed Arabic/English in print.

### Offline rule

The app does not call the network, load Google Fonts at runtime, or send telemetry.
