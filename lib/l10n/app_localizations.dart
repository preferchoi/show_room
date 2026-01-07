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
  String objectIdLabel(String id) => _format('objectIdLabel', {'id': id});
  String get objectBoundingBoxTitle => _stringFor('objectBoundingBoxTitle');
  String objectBoundingBoxPosition(String x, String y) =>
      _format('objectBoundingBoxPosition', {'x': x, 'y': y});
  String objectBoundingBoxSize(String width, String height) =>
      _format('objectBoundingBoxSize', {'width': width, 'height': height});
  String get objectActionsTitle => _stringFor('objectActionsTitle');
  String objectDescription(String label) =>
      _format('objectDescription', {'label': label});
  String get objectSearchAction => _stringFor('objectSearchAction');
  String get objectCopyAction => _stringFor('objectCopyAction');
  String get objectCopySuccess => _stringFor('objectCopySuccess');
  String get objectSearchError => _stringFor('objectSearchError');

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

  String _format(String key, Map<String, String> replacements) {
    final template = _stringFor(key);
    return replacements.entries.fold(
      template,
      (value, entry) => value.replaceAll('{${entry.key}}', entry.value),
    );
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
      'objectIdLabel': 'ID: {id}',
      'objectBoundingBoxTitle': 'Bounding box',
      'objectBoundingBoxPosition': 'Position: ({x}, {y})',
      'objectBoundingBoxSize': 'Size: {width} × {height}',
      'objectActionsTitle': 'Next actions',
      'objectDescription': 'Detected as {label}. Explore or share more details.',
      'objectSearchAction': 'Search on the web',
      'objectCopyAction': 'Copy object summary',
      'objectCopySuccess': 'Copied object info to the clipboard',
      'objectSearchError': "Couldn't open search link",
    },
    'ko': {
      'appTitle': '장면 오버레이 데모',
      'sceneViewerTitle': '장면 뷰어',
      'noSceneLoaded': '아직 장면이 로드되지 않았어요',
      'objectIdLabel': 'ID: {id}',
      'objectBoundingBoxTitle': '바운딩 박스',
      'objectBoundingBoxPosition': '위치: ({x}, {y})',
      'objectBoundingBoxSize': '크기: {width} × {height}',
      'objectActionsTitle': '다음 작업',
      'objectDescription': '{label}로 감지했어요. 더 알아보거나 공유해보세요.',
      'objectSearchAction': '웹에서 검색',
      'objectCopyAction': '객체 요약 복사',
      'objectCopySuccess': '객체 정보를 클립보드에 복사했어요',
      'objectSearchError': '검색 링크를 열 수 없어요',
    },
  };

  static const Map<String, Map<String, String>> _modelLabels = {
    'en': {
      'helmet': 'Helmet',
      'gloves': 'Gloves',
      'vest': 'Vest',
      'boots': 'Boots',
      'goggles': 'Goggles',
      'none': 'None',
      'person': 'Person',
      'no_helmet': 'No helmet',
      'no_goggle': 'No goggles',
      'no_gloves': 'No gloves',
      'no_boots': 'No boots',
    },
    'ko': {
      'helmet': '헬멧',
      'gloves': '장갑',
      'vest': '조끼',
      'boots': '안전화',
      'goggles': '고글',
      'none': '없음',
      'person': '사람',
      'no_helmet': '헬멧 없음',
      'no_goggle': '고글 없음',
      'no_gloves': '장갑 없음',
      'no_boots': '안전화 없음',
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
