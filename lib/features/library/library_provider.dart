import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/comic.dart';
import '../../data/models/reading_progress.dart';
import '../../data/repositories/comic_repository.dart';
import '../../data/services/database_service.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

final comicRepositoryProvider = Provider<ComicRepository>((ref) {
  return ComicRepository();
});

// Library state
enum LibraryStatus { initial, loading, loaded, error }

class LibraryState {
  final LibraryStatus status;
  final List<Comic> comics;
  final String? error;
  final String? rootPath;
  final bool showFavoritesOnly;
  final String searchQuery;

  const LibraryState({
    this.status = LibraryStatus.initial,
    this.comics = const [],
    this.error,
    this.rootPath,
    this.showFavoritesOnly = false,
    this.searchQuery = '',
  });

  List<Comic> get displayComics {
    var list = comics;
    if (showFavoritesOnly) list = list.where((c) => c.isFavorite).toList();
    if (searchQuery.isNotEmpty) {
      final q = searchQuery.toLowerCase();
      list = list.where((c) => c.title.toLowerCase().contains(q)).toList();
    }
    return list;
  }

  LibraryState copyWith({
    LibraryStatus? status,
    List<Comic>? comics,
    String? error,
    String? rootPath,
    bool? showFavoritesOnly,
    String? searchQuery,
  }) {
    return LibraryState(
      status: status ?? this.status,
      comics: comics ?? this.comics,
      error: error ?? this.error,
      rootPath: rootPath ?? this.rootPath,
      showFavoritesOnly: showFavoritesOnly ?? this.showFavoritesOnly,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

class LibraryNotifier extends StateNotifier<LibraryState> {
  final ComicRepository _repo;

  LibraryNotifier(this._repo) : super(const LibraryState()) {
    _init();
  }

  Future<void> _init() async {
    final rootPath = await _repo.getRootDirectory();
    if (rootPath == null) {
      state = state.copyWith(status: LibraryStatus.initial);
      return;
    }
    state = state.copyWith(rootPath: rootPath);
    await refreshLibrary();
  }

  Future<void> refreshLibrary() async {
    if (state.rootPath == null) return;
    state = state.copyWith(status: LibraryStatus.loading);
    try {
      final comics = await _repo.scanAndSyncLibrary(state.rootPath!);
      state = state.copyWith(status: LibraryStatus.loaded, comics: comics);
    } catch (e) {
      state = state.copyWith(status: LibraryStatus.error, error: e.toString());
    }
  }

  Future<void> setRootPath(String path) async {
    await _repo.saveRootDirectory(path);
    state = state.copyWith(rootPath: path);
    await refreshLibrary();
  }

  Future<void> toggleFavorite(String comicId) async {
    await _repo.toggleFavorite(comicId);
    final updated = state.comics.map((c) {
      if (c.id == comicId) return c.copyWith(isFavorite: !c.isFavorite);
      return c;
    }).toList();
    state = state.copyWith(comics: updated);
  }

  void setSearch(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void toggleFavoritesFilter() {
    state = state.copyWith(showFavoritesOnly: !state.showFavoritesOnly);
  }

  /// Given a comic id, returns the next comic in sorted order.
  Comic? getNextComic(String currentId) {
    final list = state.comics;
    final idx = list.indexWhere((c) => c.id == currentId);
    if (idx < 0 || idx >= list.length - 1) return null;
    return list[idx + 1];
  }
}

final libraryProvider =
    StateNotifierProvider<LibraryNotifier, LibraryState>((ref) {
  final repo = ref.watch(comicRepositoryProvider);
  return LibraryNotifier(repo);
});

// ── Reading progress ──────────────────────────────────────────────────────────

class ReadingProgressNotifier extends StateNotifier<Map<String, ReadingProgress>> {
  final DatabaseService _db = DatabaseService.instance;

  ReadingProgressNotifier() : super({});

  Future<ReadingProgress?> getProgress(String comicId) async {
    if (state.containsKey(comicId)) return state[comicId];
    final prog = await _db.getProgress(comicId);
    if (prog != null) {
      state = {...state, comicId: prog};
    }
    return prog;
  }

  Future<void> saveProgress(String comicId, int page, int total) async {
    final prog = ReadingProgress(
      comicId: comicId,
      lastPage: page,
      totalPages: total,
      lastReadAt: DateTime.now(),
    );
    await _db.saveProgress(prog);
    state = {...state, comicId: prog};
  }

  Future<ReadingProgress?> getMostRecent() async {
    return _db.getMostRecentProgress();
  }
}

final readingProgressProvider =
    StateNotifierProvider<ReadingProgressNotifier, Map<String, ReadingProgress>>(
        (ref) => ReadingProgressNotifier());
