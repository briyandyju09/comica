import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/comic.dart';
import '../services/database_service.dart';
import '../services/thumbnail_service.dart';

class ComicRepository {
  static const _rootDirKey = 'root_directory';

  final DatabaseService _db = DatabaseService.instance;
  final ThumbnailService _thumb = ThumbnailService.instance;

  // ── Root directory ────────────────────────────────────────
  Future<String?> getRootDirectory() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_rootDirKey);
  }

  Future<void> saveRootDirectory(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_rootDirKey, path);
  }

  Future<void> clearRootDirectory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_rootDirKey);
  }

  // ── Library scan ──────────────────────────────────────────
  Future<List<Comic>> scanAndSyncLibrary(String rootPath) async {
    final rootDir = Directory(rootPath);
    if (!await rootDir.exists()) {
      throw Exception('Selected directory does not exist or is not accessible: $rootPath');
    }

    final List<Comic> found = [];

    try {
      // Recursive list to find PDFs at any depth
      // We use followLinks: false to avoid infinite loops and speed up scanning
      await for (final entity in rootDir.list(recursive: true, followLinks: false)) {
        if (entity is File && _isPdf(entity.path)) {
          // Get relative path to determine folder structure
          final relativePath = p.relative(entity.path, from: rootPath);
          final parentDir = p.dirname(relativePath);
          
          // Determine folder name (immediate parent folder)
          String folderName = '';
          if (parentDir != '.') {
            folderName = p.basename(parentDir);
          }
          
          final comic = _buildComic(entity.path, folderName);
          found.add(comic);
        }
      }
    } catch (e) {
      debugPrint('Error scanning library: $e');
      if (e is FileSystemException && (e.message.contains('Permission denied') || e.osError?.errorCode == 13)) {
        throw Exception('Access denied. Please ensure the app has "All Files Access" permission in system settings for Android 11+.');
      }
      rethrow;
    }

    // Sync with DB
    final existingIds = (await _db.getAllComicIds()).toSet();
    final foundIds = found.map((c) => c.id).toSet();

    final toDelete = existingIds.difference(foundIds).toList();
    final newComics = found.where((c) => !existingIds.contains(c.id)).toList();

    if (toDelete.isNotEmpty) await _db.deleteComicsByIds(toDelete);

    if (newComics.isNotEmpty) {
      final withPages = await compute(_attachPageCountsIsolate, newComics);
      await _db.bulkInsertComics(withPages);
    }

    return getLibrary();
  }

  static Future<List<Comic>> _attachPageCountsIsolate(List<Comic> comics) async {
    final result = <Comic>[];
    for (final comic in comics) {
      try {
        final doc = await PdfDocument.openFile(comic.path);
        final count = doc.pages.length;
        await doc.dispose();
        result.add(comic.copyWith(totalPages: count));
      } catch (e) {
        debugPrint('Error getting page count for ${comic.path}: $e');
        result.add(comic);
      }
    }
    return result;
  }

  Comic _buildComic(String filePath, String parentFolder) {
    final fileName = p.basenameWithoutExtension(filePath);
    final nameToCheck = parentFolder.isNotEmpty ? parentFolder : fileName;
    final sortNumber =
        _extractSortNumber(nameToCheck) ?? _extractSortNumber(fileName);
    final title = _cleanTitle(fileName);
    final id = _generateId(filePath);

    return Comic(
      id: id,
      path: filePath,
      title: title,
      folderName: parentFolder,
      sortNumber: sortNumber,
      addedAt: DateTime.now(),
    );
  }

  String _generateId(String path) {
    final bytes = utf8.encode(path);
    return md5.convert(bytes).toString();
  }

  int? _extractSortNumber(String name) {
    final r = RegExp(r'^\((\d+)\)');
    final m = r.firstMatch(name.trim());
    if (m == null) return null;
    return int.tryParse(m.group(1)!);
  }

  String _cleanTitle(String name) {
    var cleaned = name.replaceFirst(RegExp(r'^\(\d+\)\s*'), '').trim();
    cleaned = cleaned.replaceAll('_', ' ').replaceAll('-', ' ').trim();
    if (cleaned.isEmpty) return name;
    // Title case first letter
    return cleaned[0].toUpperCase() + cleaned.substring(1);
  }

  bool _isPdf(String path) => path.toLowerCase().endsWith('.pdf');

  // ── Read library ──────────────────────────────────────────
  Future<List<Comic>> getLibrary() async {
    final comics = await _db.getAllComics();
    return _sortComics(comics);
  }

  Future<Comic?> getComic(String id) => _db.getComic(id);

  List<Comic> _sortComics(List<Comic> comics) {
    final withNum = comics.where((c) => c.sortNumber != null).toList()
      ..sort((a, b) {
        final cmp = a.sortNumber!.compareTo(b.sortNumber!);
        if (cmp != 0) return cmp;
        return a.title.compareTo(b.title);
      });
    final withoutNum = comics.where((c) => c.sortNumber == null).toList()
      ..sort((a, b) => a.title.compareTo(b.title));
    return [...withNum, ...withoutNum];
  }

  // ── Thumbnails ────────────────────────────────────────────
  Future<String?> ensureThumbnail(Comic comic) async {
    if (comic.thumbnailPath != null &&
        File(comic.thumbnailPath!).existsSync()) {
      return comic.thumbnailPath;
    }
    final cacheDir = (await getApplicationCacheDirectory()).path;
    final path =
        await _thumb.getThumbnailPath(comic.id, comic.path, cacheDir);
    if (path != null) {
      await _db.updateThumbnailPath(comic.id, path);
    }
    return path;
  }

  // ── Favorites ────────────────────────────────────────────
  Future<void> toggleFavorite(String id) async {
    final comic = await _db.getComic(id);
    if (comic == null) return;
    await _db.setFavorite(id, !comic.isFavorite);
  }
}
