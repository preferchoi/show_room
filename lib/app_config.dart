import 'image_source_provider.dart';

// Toggle between the fully offline mock backend and the YOLO-backed backend.
// Keep this true while YoloService still contains TODOs (normalization,
// parsing, labels, etc.) so the UI can run safely end-to-end.
const bool useMockDetection = true;
const ImageSourceType defaultImageSource = ImageSourceType.sample;
