# show_room

A Flutter app that uses a camera + YOLO TFLite model to detect objects in a room, draw overlays, and show detection history.

## Features
- Real-time camera preview
- Object detection using a YOLO TFLite model
- Bounding-box overlay with labels/confidence
- Detection history list (recently detected items)
- Future: item detail view, settings screen

## Tech stack
- Flutter, Dart
- (Planned) TFLite / YOLO11 model on-device

## Project structure
- `lib/`
  - `core/`: shared configuration, theme, and utilities
  - `features/`
    - `camera/`: camera preview screen, overlay widgets, and controller
    - `detection/`: detection domain models, services, and state
    - `history/`: detection history models, repository, and screen
    - `settings/`: settings UI
  - `main.dart`: app entrypoint

## Getting started
### Requirements
- Flutter SDK
- Android Studio or an Android emulator/device

### Basic commands
```bash
flutter pub get
flutter run
```

## Roadmap / TODO
- Implement YOLO inference service
- Implement detection history storage
- Settings screen for thresholds/model configs

## License
License: TBD
