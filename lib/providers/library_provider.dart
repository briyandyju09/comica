import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/comic.dart';
import '../services/library_service.dart';
import '../services/storage_service.dart';
import '../services/cover_cache_service.dart';

// ── Service Providers ─────────────────────────────────────────────────────

final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService();
});

final libraryServiceProvider = Provider<LibraryService>((ref) {
  return LibraryService();
});

final coverCacheServiceProvider = Provider<CoverCacheService>((ref) {
  return CoverCacheService();
});

// ── App Settings Provider ─────────────────────────────────────────────────

final appSettingsProvider = StateNotifierProvider<AppSettingsNotifier, AppSettings>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return AppSettingsNotifier(storage);
});

class AppSettingsNotifier extends StateNotifier<AppSettings> {
  final StorageService _storage;

  AppSettingsNotifier(this._storage) : super(_storage.getSettings());

  Future<void> setRootDirectory(String path) async {
    state = AppSettings(
      rootDirectoryPath: path,
      isDarkMode: state.isDarkMode,
      useVerticalScroll: state.useVerticalScroll,
      lastOpenedComicId: state.lastOpenedComicId,
    );
    await _storage.saveSettings(state);
  }

  Future<void> setScrollMode(bool vertical) async {
    state = AppSettings(
      rootDirectoryPath: state.rootDirectoryPath,
      isDarkMode: state.isDarkMode,
      useVerticalScroll: vertical,
      lastOpenedComicId: state.lastOpenedComicId,
    );
    await _storage.saveSettings(state);
  }

  Future<void> setLastOpenedComic(String comicId) async {
    state = AppSettings(
      rootDirectoryPath: state.rootDirectoryPath,
      isDarkMode: state.isDarkMode,
      useVerticalScroll: state.useVerticalScroll,
      lastOpenedComicId: comicId,
    );
    await _storage.saveSettings(state);
  }
}

// ── Library State ─────────────────────────────────────────────────────────

enum LibraryStatus { initial, scanning, ready, error }

class LibraryState {
  final LibraryStatus status;
  final List<Comic> comics;
  final String? errorMessage;
  final bool isSyncing;
  final String searchQuery;
  final LibraryFilter filter;

  const LibraryState({
    this.status = LibraryStatus.initial,
    this.comics = const [],
    this.errorMessage,
    this.isSyncing = false,
    this.searchQuery = '',
    this.filter = LibraryFilter.all,
  });

  List<Comic> get filteredComics {
    var result = comics;

    // Apply filter
    switch (filter) {
      case LibraryFilter.favorites:
        result = result.where((c) => c.isFavorite).toList();
        break;
      case LibraryFilter.inProgress:
        result = result.where((c) => c.isRead && c.lastReadPage >= 0).toList();
        break;
      case LibraryFilter.all:
        break;
    }

    // Apply search
    if (searchQuery.isNotEmpty) {
      final q = searchQuery.toLowerCase();
      result = result.where((c) => c.title.toLowerCase().contains(q)).toList();
    }

    return result;
  }

  LibraryState copyWith({
    LibraryStatus? status,
    List<Comic>? comics,
    String? errorMessage,
    bool? isSyncing,
    String? searchQuery,
    LibraryFilter? filter,
  }) {
    return LibraryState(
      status: status ?? this.status,
      comics: comics ?? this.comics,
      errorMessage: errorMessage,
      isSyncing: isSyncing ?? this.isSyncing,
      searchQuery: searchQuery ?? this.searchQuery,
      filter: filter ?? this.filter,
    );
  }
}

enum LibraryFilter { all, favorites, inProgress }

// ── Library Notifier ──────────────────────────────────────────────────────

final libraryProvider = StateNotifierProvider<LibraryNotifier, LibraryState>((ref) {
  final storage = ref.watch(storageServiceProvider);
  final libraryService = ref.watch(libraryServiceProvider);
  final coverCache = ref.watch(coverCacheServiceProvider);
  return LibraryNotifier(storage, libraryService, coverCache, ref);
});

class LibraryNotifier extends StateNotifier<LibraryState> {
  final StorageService _storage;
  final LibraryService _libraryService;
  final CoverCacheService _coverCache;
  final Ref _ref;

  LibraryNotifier(
    this._storage,
    this._libraryService,
    this._coverCache,
    this._ref,
  ) : super(const LibraryState());

  Future<void> loadLibrary() async {
    final settings = _ref.read(appSettingsProvider);
    if (settings.rootDirectoryPath == null) {
      state = state.copyWith(status: LibraryStatus.ready);
      return;
    }

    final stored = _storage.getAllComics();
    if (stored.isNotEmpty) {
      // Sort stored comics
      stored.sort((a, b) {
        if (a.sortNumber >= 0 && b.sortNumber >= 0) {
          return a.sortNumber.compareTo(b.sortNumber);
        } else if (a.sortNumber >= 0) return -1;
        else if (b.sortNumber >= 0) return 1;
        return a.title.compareTo(b.title);
      });
      state = state.copyWith(status: LibraryStatus.ready, comics: stored);
      // Background sync
      _syncLibrary(settings.rootDirectoryPath!);
    } else {
      await scanLibrary(settings.rootDirectoryPath!);
    }
  }

  Future<void> scanLibrary(String rootPath) async {
    state = state.copyWith(status: LibraryStatus.scanning);

    try {
      final comics = await _libraryService.scanLibrary(rootPath);
      await _storage.saveAllComics(comics);
      state = state.copyWith(status: LibraryStatus.ready, comics: comics);
      // Generate covers in background
      _generateCovers(comics);
    } catch (e) {
      state = state.copyWith(
        status: LibraryStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> _syncLibrary(String rootPath) async {
    if (state.isSyncing) return;
    state = state.copyWith(isSyncing: true);

    try {
      final result = await _libraryService.syncLibrary(
        rootPath: rootPath,
        storedComics: state.comics,
      );

      if (result.newComics.isNotEmpty || result.removedIds.isNotEmpty) {
        if (result.newComics.isNotEmpty) {
          await _storage.saveAllComics(result.newComics);
          _generateCovers(result.newComics);
        }
        if (result.removedIds.isNotEmpty) {
          await _storage.deleteComics(result.removedIds);
        }
        final allComics = _storage.getAllComics();
        allComics.sort((a, b) {
          if (a.sortNumber >= 0 && b.sortNumber >= 0) {
            return a.sortNumber.compareTo(b.sortNumber);
          } else if (a.sortNumber >= 0) return -1;
          else if (b.sortNumber >= 0) return 1;
          return a.title.compareTo(b.title);
        });
        state = state.copyWith(comics: allComics, isSyncing: false);
      } else {
        state = state.copyWith(isSyncing: false);
      }
    } catch (_) {
      state = state.copyWith(isSyncing: false);
    }
  }

  void _generateCovers(List<Comic> comics) async {
    for (final comic in comics) {
      if (comic.coverImagePath != null) continue;
      if (comic.filePaths.isEmpty) continue;

      final firstFile = comic.filePaths.first;
      if (!firstFile.toLowerCase().endsWith('.pdf')) continue;

      final coverPath = await _coverCache.getCoverPath(
        comicId: comic.id,
        pdfPath: firstFile,
      );

      if (coverPath != null) {
        await _storage.updateCoverPath(comic.id, coverPath);
        // Update in state
        final updated = state.comics.map((c) {
          if (c.id == comic.id) {
            c.coverImagePath = coverPath;
          }
          return c;
        }).toList();
        state = state.copyWith(comics: updated);
      }
    }
  }

  Future<void> toggleFavorite(String comicId) async {
    await _storage.toggleFavorite(comicId);
    _refreshFromStorage();
  }

  Future<void> toggleBookmark(String comicId, int page) async {
    await _storage.toggleBookmark(comicId, page);
    _refreshFromStorage();
  }

  Future<void> updateReadProgress(String comicId, int page) async {
    await _storage.updateReadProgress(comicId, page);
    _refreshFromStorage();
  }

  void _refreshFromStorage() {
    final comics = _storage.getAllComics();
    comics.sort((a, b) {
      if (a.sortNumber >= 0 && b.sortNumber >= 0) {
        return a.sortNumber.compareTo(b.sortNumber);
      } else if (a.sortNumber >= 0) return -1;
      else if (b.sortNumber >= 0) return 1;
      return a.title.compareTo(b.title);
    });
    state = state.copyWith(comics: comics);
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setFilter(LibraryFilter filter) {
    state = state.copyWith(filter: filter);
  }

  Future<void> refreshLibrary() async {
    final settings = _ref.read(appSettingsProvider);
    if (settings.rootDirectoryPath != null) {
      await scanLibrary(settings.rootDirectoryPath!);
    }
  }

  Comic? getComicById(String id) => _storage.getComic(id);

  /// Get next comic in sorted order
  Comic? getNextComic(String currentComicId) {
    final comics = state.comics;
    final idx = comics.indexWhere((c) => c.id == currentComicId);
    if (idx >= 0 && idx < comics.length - 1) return comics[idx + 1];
    return null;
  }

  /// Get prev comic in sorted order
  Comic? getPrevComic(String currentComicId) {
    final comics = state.comics;
    final idx = comics.indexWhere((c) => c.id == currentComicId);
    if (idx > 0) return comics[idx - 1];
    return null;
  }

  List<Comic> getRecentlyRead() => _storage.getRecentlyRead();
}
