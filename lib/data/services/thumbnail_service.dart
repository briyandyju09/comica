import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'dart:io';
import 'package:pdfrx/pdfrx.dart';

class ThumbnailService {
  static ThumbnailService? _instance;
  ThumbnailService._();
  static ThumbnailService get instance {
    _instance ??= ThumbnailService._();
    return _instance!;
  }

  static const double _thumbWidth = 400;
  static const double _thumbHeight = 560;

  Future<String?> getThumbnailPath(
      String comicId, String pdfPath, String cacheDir) async {
    final thumbFile = File(p.join(cacheDir, '$comicId.png'));
    if (await thumbFile.exists()) return thumbFile.path;

    try {
      final success = await compute(
          _renderAndSaveThumb, _ThumbArgs(pdfPath, thumbFile.path));
      if (success) return thumbFile.path;
    } catch (e) {
      debugPrint('Thumbnail error for $pdfPath: $e');
    }
    return null;
  }

  static Future<bool> _renderAndSaveThumb(_ThumbArgs args) async {
    try {
      final doc = await PdfDocument.openFile(args.pdfPath);
      if (doc.pages.isEmpty) {
        await doc.dispose();
        return false;
      }
      final page = doc.pages[0];
      final image = await page.render(
        fullWidth: _thumbWidth,
        fullHeight: _thumbHeight,
        backgroundColor: const ui.Color(0xFFFFFFFF),
      );
      if (image == null) {
        await doc.dispose();
        return false;
      }
      final uiImage = await image.createImage();
      final byteData =
          await uiImage.toByteData(format: ui.ImageByteFormat.png);
      await doc.dispose();
      if (byteData == null) return false;
      final bytes = byteData.buffer.asUint8List();
      await File(args.outPath).writeAsBytes(bytes);
      return true;
    } catch (_) {
      return false;
    }
  }
}

class _ThumbArgs {
  final String pdfPath;
  final String outPath;
  const _ThumbArgs(this.pdfPath, this.outPath);
}
