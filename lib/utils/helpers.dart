import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

class HapticUtils {
  static void light() => HapticFeedback.lightImpact();
  static void medium() => HapticFeedback.mediumImpact();
  static void heavy() => HapticFeedback.heavyImpact();
  static void selection() => HapticFeedback.selectionClick();
}

class FileUtils {
  static const List<String> supportedExtensions = ['.pdf', '.cbz', '.cbr'];

  static bool isSupported(String path) {
    final ext = p.extension(path).toLowerCase();
    return supportedExtensions.contains(ext);
  }

  static bool isPdf(String path) =>
      p.extension(path).toLowerCase() == '.pdf';

  static bool isCbz(String path) =>
      p.extension(path).toLowerCase() == '.cbz';

  static bool isCbr(String path) =>
      p.extension(path).toLowerCase() == '.cbr';

  static String formatFileName(String path) =>
      p.basenameWithoutExtension(path);
}

class StringUtils {
  /// Truncate with ellipsis
  static String ellipsis(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength - 1)}…';
  }

  /// Format a page range as "Page X of Y"
  static String pageLabel(int current, int total) =>
      'Page ${current + 1} of $total';

  /// Progress percentage string
  static String progressLabel(double progress) =>
      '${(progress * 100).round()}%';
}
