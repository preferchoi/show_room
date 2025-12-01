# Show Room

Flutter 기반의 데모 앱으로, 감지 백엔드와 UI 흐름을 분리해 장면 이미지 위에 감지된 객체를 오버레이합니다. 기본값으로는 완전 오프라인 Mock 백엔드를 사용하며, YOLO 기반 감지 서비스로 교체할 수 있는 구조를 갖고 있습니다.

## 주요 동작 흐름
- `lib/main.dart`에서 `useMockDetection` 플래그를 통해 감지 백엔드를 선택합니다. 기본값(true)일 때는 실 모델 없이 UI를 실행할 수 있습니다.
- `SceneState`가 `DetectionRepository`를 통해 감지를 위임하고, UI(`SceneViewPage`)는 상태 변화에 맞춰 이미지를 표시하고 객체를 선택할 수 있습니다.

## 백엔드 구현체
- **MockDetectionRepository** (`lib/detection_repository.dart`)
  - 내장된 Base64 샘플 이미지를 사용하고, 고정된 3개의 바운딩 박스를 반환합니다.
  - 모델 파일이나 디바이스 성능과 무관하게 전체 UI를 테스트할 수 있습니다.
- **YOLO 감지**
  - `lib/yolo_service.dart`: YOLO11n 기반 바운딩 박스 감지를 위한 서비스 골격입니다. 입력 전처리, 출력 파싱, NMS가 포함되어 있으며 `ModelProvider`로 TFLite 인터프리터를 주입합니다. `assets/models/yolo11n.tflite`는 추후 실제 모델로 교체합니다.
  - `lib/yolo_seg_service.dart`: YOLO 세그멘테이션 모델을 위한 대안 구현입니다. 바운딩 박스와 선택적 마스크를 생성하며, 출력/마스크 차원은 실제 내보내기 스펙에 맞춰 조정 가능합니다.

## 모델 로딩
- `lib/model_provider.dart`의 `AssetModelProvider`가 `assets/models/yolo11n.tflite`를 읽어 인터프리터를 생성합니다. 플레이스홀더 파일이 남아있는 경우 명확한 오류를 던져 잘못된 바이너리 사용을 방지합니다.
- `labels.txt`는 `assets/models/labels.txt`에서 읽어들입니다. 레이블 수가 모델 클래스와 일치하지 않을 경우 예외를 발생시켜 파싱 오류를 조기에 알립니다.

## 이미지 소스
- `lib/image_source_provider.dart`에서 샘플/갤러리/카메라 소스를 제공하며, 권한 체크와 에러 메시지를 포함합니다. 샘플 이미지는 Base64로 내장되어 오프라인에서도 동작합니다.

## UI
- `lib/scene_view_page.dart`는 감지된 이미지를 `BoxFit.contain`으로 표시하고, `ObjectButton` 위젯으로 각 객체의 바운딩 박스를 오버레이합니다.
- 객체를 탭하면 하단 시트에서 ID, 위치, 크기, 검색/복사 액션을 제공합니다. 레이블은 `LabelLocalizer`를 거쳐 현지화됩니다.

## 현재 상태와 다음 단계
- 기본 플래그는 Mock 모드로 설정되어 있어 모델 파일 없이 실행 가능합니다.
- `yolo11n.tflite` 실제 바이너리는 아직 포함되어 있지 않으며, 추후 교체하면 YOLO 모드로 전환할 수 있습니다.
