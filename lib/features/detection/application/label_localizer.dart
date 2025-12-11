import 'package:flutter/widgets.dart';

import '../../../l10n/app_localizations.dart';

/// Maps raw detection labels (typically English class names from a model) to
/// localized, user-visible strings.
class LabelLocalizer {
  String localize(String rawLabel, BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final localized = localizations?.modelLabel(rawLabel);
    return localized ?? rawLabel;
  }
}
