import 'package:hive_flutter/hive_flutter.dart';
import '../models/comic.dart';

class StorageService {
  static const String _comicsBoxName = 'comics';
  static const String _settingsBoxName = 'settings';
  static const String _settingsKey = 'app_settings';

  late Box<Comic> _comicsBox;
  late Box<dynamic> _settingsBox;

  Future<void> init() async {
    await Hive.initFlutter();

    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(ComicAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(AppSettingsAdapter());
    }

    _comicsBox = await Hive.openBox<Comic>(_comicsBoxName);
    _settingsBox = await Hive.openBox(_settingsBoxName);
  }

  // ── Comics ────────────────────────────────────────────────────────────────

  List<Comic> getAllComics() => _comicsBox.values.toList();

  Comic? getComic(String id) => _comicsBox.get(id);

  Future<void> saveComic(Comic comic) async {
    await _comicsBox.put(comic.id, comic);
  }

  Future<void> saveAllComics(List<Comic> comics) async {
    final map = {for (final c in comics) c.id: c};
    await _comicsBox.putAll(map);
  }

  Future<void> deleteComic(String id) async {
    await _comicsBox.delete(id);
  }

  Future<void> deleteComics(List<String> ids) async {
    await _comicsBox.deleteAll(ids);
  }

  Future<void> updateReadProgress(String comicId, int page) async {
    final comic = _comicsBox.get(comicId);
    if (comic != null) {
      comic.lastReadPage = page;
      comic.lastOpenedAt = DateTime.now();
      await comic.save();
    }
  }

  Future<void> toggleFavorite(String comicId) async {
    final comic = _comicsBox.get(comicId);
    if (comic != null) {
      comic.isFavorite = !comic.isFavorite;
      await comic.save();
    }
  }

  Future<void> toggleBookmark(String comicId, int page) async {
    final comic = _comicsBox.get(comicId);
    if (comic != null) {
      if (comic.bookmarkedPages.contains(page)) {
        comic.bookmarkedPages.remove(page);
      } else {
        comic.bookmarkedPages.add(page);
        comic.bookmarkedPages.sort();
      }
      await comic.save();
    }
  }

  Future<void> updateCoverPath(String comicId, String coverPath) async {
    final comic = _comicsBox.get(comicId);
    if (comic != null) {
      comic.coverImagePath = coverPath;
      await comic.save();
    }
  }

  List<Comic> getRecentlyRead({int limit = 10}) {
    final all = _comicsBox.values
        .where((c) => c.lastOpenedAt != null)
        .toList()
      ..sort((a, b) => b.lastOpenedAt!.compareTo(a.lastOpenedAt!));
    return all.take(limit).toList();
  }

  List<Comic> getFavorites() =>
      _comicsBox.values.where((c) => c.isFavorite).toList();

  // ── Settings ──────────────────────────────────────────────────────────────

  AppSettings getSettings() {
    return _settingsBox.get(_settingsKey) as AppSettings? ?? AppSettings();
  }

  Future<void> saveSettings(AppSettings settings) async {
    await _settingsBox.put(_settingsKey, settings);
  }

  Future<void> setRootDirectory(String path) async {
    final settings = getSettings();
    settings.rootDirectoryPath = path;
    await saveSettings(settings);
  }

  Future<void> setLastOpenedComic(String comicId) async {
    final settings = getSettings();
    settings.lastOpenedComicId = comicId;
    await saveSettings(settings);
  }

  Future<void> clearLibrary() async {
    await _comicsBox.clear();
  }

  // ── Streams ───────────────────────────────────────────────────────────────

  Stream<BoxEvent> get comicsStream => _comicsBox.watch();
}
