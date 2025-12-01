import 'package:flutter/widgets.dart';

/// Maps raw detection labels (typically English class names from a model) to
/// localized, user-visible strings.
class LabelLocalizer {
  String localize(String rawLabel, BuildContext context) {
    // TODO: Integrate with AppLocalizations / Intl once translations exist.
    // Keeping the raw label ensures the UI remains stable even without
    // localization resources available.
    return rawLabel;
  }
}
