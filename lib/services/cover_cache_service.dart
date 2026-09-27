import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:pdfx/pdfx.dart';

/// Renders and caches the first page of a PDF as a cover image.
class CoverCacheService {
  static const double _coverWidth = 400;
  static const double _coverHeight = 600;

  Future<String?> getCoverPath({
    required String comicId,
    required String pdfPath,
  }) async {
    try {
      final cacheDir = await _getCacheDir();
      final coverFile = File(p.join(cacheDir.path, '$comicId.png'));

      if (await coverFile.exists()) {
        return coverFile.path;
      }

      // Render first page
      final imageData = await _renderFirstPage(pdfPath);
      if (imageData == null) return null;

      await coverFile.writeAsBytes(imageData);
      return coverFile.path;
    } catch (e) {
      return null;
    }
  }

  Future<Uint8List?> _renderFirstPage(String pdfPath) async {
    PdfDocument? document;
    PdfPage? page;
    PdfPageImage? image;

    try {
      document = await PdfDocument.openFile(pdfPath);
      if (document.pagesCount == 0) return null;

      page = await document.getPage(1);
      image = await page.render(
        width: _coverWidth,
        height: _coverHeight,
        format: PdfPageImageFormat.png,
        backgroundColor: '#FFFFFF',
      );

      return image?.bytes;
    } catch (_) {
      return null;
    } finally {
      await page?.close();
      await document?.close();
    }
  }

  Future<Directory> _getCacheDir() async {
    final cacheDir = await getTemporaryDirectory();
    final coversDir = Directory(p.join(cacheDir.path, 'comica_covers'));
    if (!await coversDir.exists()) {
      await coversDir.create(recursive: true);
    }
    return coversDir;
  }

  Future<void> clearCache() async {
    try {
      final cacheDir = await _getCacheDir();
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
      }
    } catch (_) {}
  }

  Future<void> deleteCover(String comicId) async {
    try {
      final cacheDir = await _getCacheDir();
      final coverFile = File(p.join(cacheDir.path, '$comicId.png'));
      if (await coverFile.exists()) {
        await coverFile.delete();
      }
    } catch (_) {}
  }
}
