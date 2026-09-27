import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:path/path.dart' as p;
import '../models/comic.dart';

/// Scans a root directory and builds a list of Comic objects.
/// Supports PDF files inside subfolders or direct PDFs.
class LibraryService {
  static const List<String> _supportedExtensions = ['.pdf', '.cbz', '.cbr'];

  /// Scan root directory and return sorted list of comics.
  Future<List<Comic>> scanLibrary(String rootPath) async {
    final dir = Directory(rootPath);
    if (!await dir.exists()) return [];

    final comics = <Comic>[];
    final entities = await dir.list(recursive: false).toList();

    for (final entity in entities) {
      if (entity is Directory) {
        final comic = await _processFolder(entity);
        if (comic != null) comics.add(comic);
      } else if (entity is File) {
        final ext = p.extension(entity.path).toLowerCase();
        if (_supportedExtensions.contains(ext)) {
          final comic = _createComicFromFile(entity);
          comics.add(comic);
        }
      }
    }

    // Sort comics: by sortNumber first, then alphabetically
    comics.sort((a, b) {
      if (a.sortNumber >= 0 && b.sortNumber >= 0) {
        return a.sortNumber.compareTo(b.sortNumber);
      } else if (a.sortNumber >= 0) {
        return -1;
      } else if (b.sortNumber >= 0) {
        return 1;
      }
      return a.title.compareTo(b.title);
    });

    return comics;
  }

  Future<Comic?> _processFolder(Directory dir) async {
    final folderName = p.basename(dir.path);
    final files = <String>[];

    await for (final entity in dir.list(recursive: false)) {
      if (entity is File) {
        final ext = p.extension(entity.path).toLowerCase();
        if (_supportedExtensions.contains(ext)) {
          files.add(entity.path);
        }
      }
    }

    if (files.isEmpty) return null;

    // Sort files within folder
    files.sort(_naturalFileSort);

    final sortNumber = Comic.parseSortNumber(folderName);
    final title = Comic.parseTitle(folderName);
    final seriesName = Comic.parseSeriesName(title);
    final id = _generateId(dir.path);

    return Comic(
      id: id,
      title: title,
      folderPath: dir.path,
      filePaths: files,
      sortNumber: sortNumber,
      seriesName: seriesName,
    );
  }

  Comic _createComicFromFile(File file) {
    final fileName = p.basenameWithoutExtension(file.path);
    final sortNumber = Comic.parseSortNumber(fileName);
    final title = Comic.parseTitle(fileName);
    final seriesName = Comic.parseSeriesName(title);
    final id = _generateId(file.path);

    return Comic(
      id: id,
      title: title,
      folderPath: p.dirname(file.path),
      filePaths: [file.path],
      sortNumber: sortNumber,
      seriesName: seriesName,
    );
  }

  String _generateId(String path) {
    // Simple stable ID from path bytes
    final bytes = utf8.encode(path);
    int hash = 5381;
    for (final b in bytes) {
      hash = ((hash << 5) + hash) ^ b;
      hash &= 0x7FFFFFFF; // keep positive
    }
    return '${hash.toRadixString(16)}_${p.basename(path).hashCode.abs().toRadixString(16)}';
  }

  int _naturalFileSort(String a, String b) {
    final nameA = p.basename(a).toLowerCase();
    final nameB = p.basename(b).toLowerCase();

    // Extract numbers for natural sort
    final numRegex = RegExp(r'\d+');
    final matchA = numRegex.firstMatch(nameA);
    final matchB = numRegex.firstMatch(nameB);

    if (matchA != null && matchB != null) {
      final numA = int.tryParse(matchA.group(0)!);
      final numB = int.tryParse(matchB.group(0)!);
      if (numA != null && numB != null) {
        return numA.compareTo(numB);
      }
    }
    return nameA.compareTo(nameB);
  }

  /// Detect new / removed comics by comparing stored paths to filesystem.
  Future<LibrarySyncResult> syncLibrary({
    required String rootPath,
    required List<Comic> storedComics,
  }) async {
    final freshComics = await scanLibrary(rootPath);
    final freshIds = freshComics.map((c) => c.id).toSet();
    final storedIds = storedComics.map((c) => c.id).toSet();

    final newComics = freshComics.where((c) => !storedIds.contains(c.id)).toList();
    final removedIds = storedIds.difference(freshIds).toList();

    return LibrarySyncResult(
      newComics: newComics,
      removedIds: removedIds,
      allComics: freshComics,
    );
  }
}

class LibrarySyncResult {
  final List<Comic> newComics;
  final List<String> removedIds;
  final List<Comic> allComics;

  const LibrarySyncResult({
    required this.newComics,
    required this.removedIds,
    required this.allComics,
  });
}
