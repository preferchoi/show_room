import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

/// Lightweight localization loader backed by in-memory maps.
class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static const List<Locale> supportedLocales = [Locale('en'), Locale('ko')];

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  String get appTitle => _stringFor('appTitle');
  String get sceneViewerTitle => _stringFor('sceneViewerTitle');
  String get noSceneLoaded => _stringFor('noSceneLoaded');

  /// Returns a localized label for the model class name, or null if none is
  /// available for the current locale.
  String? modelLabel(String rawLabel) {
    final key = rawLabel.trim().toLowerCase();
    return _modelLabelLookup(_localeCode, key) ?? _modelLabelLookup('en', key);
  }

  String _stringFor(String key) {
    return _stringResources[_localeCode]?[key] ??
        _stringResources['en']![key] ??
        key;
  }

  String get _localeCode {
    final canonicalized = Intl.canonicalizedLocale(locale.toString());
    return canonicalized.split('_').first;
  }

  static const Map<String, Map<String, String>> _stringResources = {
    'en': {
      'appTitle': 'Scene Overlay Demo',
      'sceneViewerTitle': 'Scene viewer',
      'noSceneLoaded': 'No scene loaded yet',
    },
    'ko': {
      'appTitle': '장면 오버레이 데모',
      'sceneViewerTitle': '장면 뷰어',
      'noSceneLoaded': '아직 장면이 로드되지 않았어요',
    },
  };

  static const Map<String, Map<String, String>> _modelLabels = {
    'en': {
      'person': 'Person',
      'bicycle': 'Bicycle',
      'car': 'Car',
      'motorcycle': 'Motorcycle',
      'airplane': 'Airplane',
      'bus': 'Bus',
      'train': 'Train',
      'truck': 'Truck',
      'boat': 'Boat',
      'traffic light': 'Traffic light',
      'fire hydrant': 'Fire hydrant',
      'stop sign': 'Stop sign',
      'parking meter': 'Parking meter',
      'bench': 'Bench',
      'bird': 'Bird',
      'cat': 'Cat',
      'dog': 'Dog',
      'horse': 'Horse',
      'sheep': 'Sheep',
      'cow': 'Cow',
      'elephant': 'Elephant',
      'bear': 'Bear',
      'zebra': 'Zebra',
      'giraffe': 'Giraffe',
      'backpack': 'Backpack',
      'umbrella': 'Umbrella',
      'handbag': 'Handbag',
      'tie': 'Tie',
      'suitcase': 'Suitcase',
      'frisbee': 'Frisbee',
      'skis': 'Skis',
      'snowboard': 'Snowboard',
      'sports ball': 'Sports ball',
      'kite': 'Kite',
      'baseball bat': 'Baseball bat',
      'baseball glove': 'Baseball glove',
      'skateboard': 'Skateboard',
      'surfboard': 'Surfboard',
      'tennis racket': 'Tennis racket',
      'bottle': 'Bottle',
      'wine glass': 'Wine glass',
      'cup': 'Cup',
      'fork': 'Fork',
      'knife': 'Knife',
      'spoon': 'Spoon',
      'bowl': 'Bowl',
      'banana': 'Banana',
      'apple': 'Apple',
      'sandwich': 'Sandwich',
      'orange': 'Orange',
      'broccoli': 'Broccoli',
      'carrot': 'Carrot',
      'hot dog': 'Hot dog',
      'pizza': 'Pizza',
      'donut': 'Donut',
      'cake': 'Cake',
      'chair': 'Chair',
      'couch': 'Couch',
      'potted plant': 'Potted plant',
      'bed': 'Bed',
      'dining table': 'Dining table',
      'toilet': 'Toilet',
      'tv': 'TV',
      'laptop': 'Laptop',
      'mouse': 'Mouse',
      'remote': 'Remote',
      'keyboard': 'Keyboard',
      'cell phone': 'Cell phone',
      'microwave oven': 'Microwave oven',
      'toaster': 'Toaster',
      'sink': 'Sink',
      'refrigerator': 'Refrigerator',
      'book': 'Book',
      'clock': 'Clock',
      'vase': 'Vase',
      'scissors': 'Scissors',
      'teddy bear': 'Teddy bear',
      'hair dryer': 'Hair dryer',
      'toothbrush': 'Toothbrush',
    },
    'ko': {
      'person': '사람',
      'bicycle': '자전거',
      'car': '자동차',
      'motorcycle': '오토바이',
      'airplane': '비행기',
      'bus': '버스',
      'train': '기차',
      'truck': '트럭',
      'boat': '보트',
      'traffic light': '신호등',
      'fire hydrant': '소화전',
      'stop sign': '정지 표지판',
      'parking meter': '주차 요금기',
      'bench': '벤치',
      'bird': '새',
      'cat': '고양이',
      'dog': '개',
      'horse': '말',
      'sheep': '양',
      'cow': '소',
      'elephant': '코끼리',
      'bear': '곰',
      'zebra': '얼룩말',
      'giraffe': '기린',
      'backpack': '배낭',
      'umbrella': '우산',
      'handbag': '핸드백',
      'tie': '넥타이',
      'suitcase': '여행가방',
      'frisbee': '프리스비',
      'skis': '스키',
      'snowboard': '스노보드',
      'sports ball': '스포츠공',
      'kite': '연',
      'baseball bat': '야구 방망이',
      'baseball glove': '야구 글러브',
      'skateboard': '스케이트보드',
      'surfboard': '서핑보드',
      'tennis racket': '테니스 라켓',
      'bottle': '병',
      'wine glass': '와인잔',
      'cup': '컵',
      'fork': '포크',
      'knife': '칼',
      'spoon': '숟가락',
      'bowl': '그릇',
      'banana': '바나나',
      'apple': '사과',
      'sandwich': '샌드위치',
      'orange': '오렌지',
      'broccoli': '브로콜리',
      'carrot': '당근',
      'hot dog': '핫도그',
      'pizza': '피자',
      'donut': '도넛',
      'cake': '케이크',
      'chair': '의자',
      'couch': '소파',
      'potted plant': '화분',
      'bed': '침대',
      'dining table': '식탁',
      'toilet': '변기',
      'tv': '텔레비전',
      'laptop': '노트북',
      'mouse': '마우스',
      'remote': '리모컨',
      'keyboard': '키보드',
      'cell phone': '휴대전화',
      'microwave oven': '전자레인지',
      'toaster': '토스터',
      'sink': '싱크대',
      'refrigerator': '냉장고',
      'book': '책',
      'clock': '시계',
      'vase': '꽃병',
      'scissors': '가위',
      'teddy bear': '곰인형',
      'hair dryer': '드라이어',
      'toothbrush': '칫솔',
    },
  };

  static String? _modelLabelLookup(String localeCode, String key) {
    return _modelLabels[localeCode]?[key];
  }
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['en', 'ko'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(AppLocalizations(locale));
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
