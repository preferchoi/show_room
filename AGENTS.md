# AGENTS

이 문서는 본 프로젝트에서 사용되는 AI 에이전트(Agents)의 역할, 책임, 제한사항을 정의한다.  
Codex, MCP 기반 개발 흐름에서 에이전트들이 **일관된 책임 분리** 아래 코드를 생성할 수 있도록 돕는 목적을 가진다.

---

# 1. detection_repository_agent

## 역할
- UI가 사용 가능한 **일관된 감지 인터페이스(DetectionRepository)** 구현을 담당한다.
- 실제 백엔드(YoloService) 또는 Mock 백엔드를 연결하는 **중간 추상화 계층** 역할을 한다.

## 책임
- `DetectionRepository` 인터페이스 생성
- `MockDetectionRepository` 구현
- `YoloDetectionRepository` 구현
- mock/real 전환 플래그 구성 (`useMockDetection`)

## 제한
- 이미지 처리 로직 직접 작성 금지 (YOLO 전처리/후처리는 yolo_service_agent 담당)
- UI 생성 금지
- 모델 파일 다운로드 로직 수행 금지 (model_provider_agent 담당)

## 출력
- `detection_repository.dart`
- `SceneState`에서 사용되는 백엔드 바인딩 코드

---

# 2. yolo_service_agent

## 역할
- TFLite 기반 YOLO 모델을 로드하고, 전처리 → 추론 → 후처리(박스 스케일링, NMS)까지 수행하는 핵심 감지 엔진.
- bbox-only 모드 우선 구현.
- mask/segmentation 관련 기능은 구조만 마련하고 TODO로 남겨둔다.

## 책임
- `YoloService` 클래스 작성/보완
- 모델 로딩(`ModelProvider`로부터 Interpreter 획득)
- input normalization
- output tensor 파싱
- NMS 수행
- `SceneDetectionResult` 반환

## 제한
- UI 코드 생성 금지
- SceneState 직접 수정 금지
- ImageSourceProvider와 무관 (이미지 바이트만 입력받음)
- i18n 라벨 처리 금지 (label_localizer_agent 담당)

## 출력
- `yolo_service.dart`
- 모델 출력 구조에 대한 TODO 문서화

---

# 3. model_provider_agent

## 역할
- YOLO 모델 파일을 어떤 경로에서 공급받는지 결정하는 계층.
- 현재는 **AssetModelProvider**만 구현.
- 향후 “서버에서 다운받아 교체하는 모델 업데이트” 기능은 여기에 추가됨.

## 책임
- `ModelProvider` 인터페이스 정의
- `AssetModelProvider` 구현
- (TODO) `DownloadedModelProvider` 골격 정의

## 제한
- UI 접근 금지
- DetectionRepository 직접 생성 금지
- YOLO 전처리/후처리 로직 작성 금지 (yolo_service_agent 담당)

## 출력
- `model_provider.dart`

---

# 4. image_source_agent

## 역할
- 앱이 사용할 입력 이미지를 가져오는 통로를 담당한다.
- 현재는 샘플 이미지만 반환하도록 하고, gallery/camera는 TODO로 남긴다.

## 책임
- `ImageSourceType` enum 정의
- `ImageSourceProvider` 인터페이스 구현
- `SampleImageSourceProvider` 구현

## 제한
- YOLO 실행 금지
- UI 렌더링 금지
- 모델 로딩 금지

## 출력
- `image_source_provider.dart`

---

# 5. label_localizer_agent

## 역할
- YOLO가 반환하는 영어 레이블을 UI에서 다국어로 표시할 때 매핑하는 계층.
- 현재는 영어 그대로 반환.

## 책임
- `LabelLocalizer` 클래스 생성
- UI에서 레이블 출력 시 이 로직만 통과시키게 함

## 제한
- YOLO 전처리/후처리 금지
- 이미지 처리 금지
- 감지 백엔드 구현 금지

## 출력
- `label_localizer.dart`

---

# 6. ui_agent

## 역할
- Flutter UI 구성 요소 작성 담당.
- UI는 DetectionRepository를 통해서만 감지 기능을 사용.
- YOLO 서비스 / 모델 로딩 / 이미지 로딩에 직접 접근 금지.

## 책임
- SceneViewPage, ObjectButton, overlay UI, BottomSheet 등 생성
- SceneState 값 변화에 따라 UI 업데이트
- dark mode 대응 UI 구성

## 제한
- 핵심 감지 로직 작성 금지 (detection_repository_agent / yolo_service_agent 담당)
- 모델 파일 직접 읽기 금지
- 이미지 전처리 금지

## 출력
- UI 관련 .dart 파일들 (SceneView, ObjectButton, MainApp 등)

---

# 7. mock_agent

## 역할
- 현재 개발 단계에서 YOLO 서비스가 완전하지 않기 때문에,  
  UI 개발을 끊기지 않게 하기 위해 **항상 정상적인 SceneDetectionResult를 돌려주는 mock 구현**을 제공한다.

## 책임
- 가짜 이미지 반환
- 가짜 bounding box 2~4개 생성
- 항상 stable 정보 반환

## 제한
- YOLO 모델 사용 금지
- 실전 전처리/후처리 금지

## 출력
- `MockDetectionRepository` 구현 내용

---

# 8. integration_rules (중요)

1. **UI는 오직 DetectionRepository만 사용한다.**  
   - YoloService, ModelProvider, ImageSourceProvider에 직접 접근하면 안 된다.

2. **감지 로직(YOLO)은 detection_repository_agent → yolo_service_agent → model_provider_agent** 순으로 흐른다.

3. **Image 입력은 UI → image_source_agent**를 통해 얻는다.

4. **레이블 번역은 UI → label_localizer_agent**를 통해 처리한다.

5. **mock 흐름은 절대 깨지지 않아야 한다.**  
   - useMockDetection=true일 때, 앱은 모델 파일 없이 100% 동작해야 한다.

6. **새 기능(카메라, 다운로드 모델, segmentation)은 반드시 전용 Agent가 담당해야 하며, 기존 흐름을 수정하지 말고 “대체 구현체”로 추가한다.**

---

# 9. 개발 플래그

- `useMockDetection = true/false`
- `useDownloadedModel = true/false` (미래 확장)
- `enableSegmentation = true/false` (미래 확장)
- `imageSourceType = ImageSourceType.sample/gallery/camera`

이 플래그들로 **기능을 바꾸되, 구조는 그대로 유지**한다.

---

# 10. 파일 구조 예시

lib/
agents/
detection_repository.dart
yolo_detection_repository.dart
mock_detection_repository.dart

yolo_service.dart
model_provider.dart
image_source_provider.dart
label_localizer.dart
state/
scene_state.dart

ui/
scene_view_page.dart
object_button.dart

models/
models.dart

AGENTS.md

---

# 11. 요약

이 AGENTS.md는:

- Codex가 “누가 어떤 역할을 해야 하는지” 혼동하지 않게 해주고  
- UI 개발과 YOLO 개발을 **각각 독립적으로 진행 가능한 구조**를 제공하며  
- 미래 기능 확장(카메라, 다국어, segmentation, 다운로드 모델)을 방해하지 않도록 설계되었다.
