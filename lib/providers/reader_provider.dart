import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/comic.dart';
import 'library_provider.dart';

class ReaderState {
  final Comic? comic;
  final int currentPage; // 0-indexed
  final int totalPages;
  final bool showUI;
  final bool isLoading;
  final double brightness;
  final bool isVerticalScroll;
  final bool isFinished;

  const ReaderState({
    this.comic,
    this.currentPage = 0,
    this.totalPages = 0,
    this.showUI = true,
    this.isLoading = false,
    this.brightness = 1.0,
    this.isVerticalScroll = false,
    this.isFinished = false,
  });

  bool get isBookmarked =>
      comic?.bookmarkedPages.contains(currentPage) ?? false;

  double get progress =>
      totalPages > 0 ? (currentPage + 1) / totalPages : 0;

  ReaderState copyWith({
    Comic? comic,
    int? currentPage,
    int? totalPages,
    bool? showUI,
    bool? isLoading,
    double? brightness,
    bool? isVerticalScroll,
    bool? isFinished,
  }) {
    return ReaderState(
      comic: comic ?? this.comic,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      showUI: showUI ?? this.showUI,
      isLoading: isLoading ?? this.isLoading,
      brightness: brightness ?? this.brightness,
      isVerticalScroll: isVerticalScroll ?? this.isVerticalScroll,
      isFinished: isFinished ?? this.isFinished,
    );
  }
}

final readerProvider =
    StateNotifierProvider.autoDispose<ReaderNotifier, ReaderState>((ref) {
  return ReaderNotifier(ref);
});

class ReaderNotifier extends StateNotifier<ReaderState> {
  final Ref _ref;

  ReaderNotifier(this._ref) : super(const ReaderState());

  void openComic(Comic comic, {bool? verticalScroll}) {
    final settings = _ref.read(appSettingsProvider);
    final startPage = comic.lastReadPage >= 0 ? comic.lastReadPage : 0;
    state = ReaderState(
      comic: comic,
      currentPage: startPage,
      showUI: true,
      isLoading: true,
      isVerticalScroll: verticalScroll ?? settings.useVerticalScroll,
    );
    // Mark as recently opened
    _ref.read(appSettingsProvider.notifier).setLastOpenedComic(comic.id);
  }

  void setTotalPages(int total) {
    state = state.copyWith(totalPages: total, isLoading: false);
  }

  void goToPage(int page) {
    if (state.totalPages > 0 && page >= 0 && page < state.totalPages) {
      state = state.copyWith(currentPage: page);
      _saveProgress(page);
    }
  }

  void nextPage() {
    final next = state.currentPage + 1;
    if (next >= state.totalPages) {
      state = state.copyWith(isFinished: true);
    } else {
      state = state.copyWith(currentPage: next);
      _saveProgress(next);
    }
  }

  void prevPage() {
    final prev = state.currentPage - 1;
    if (prev >= 0) {
      state = state.copyWith(currentPage: prev);
      _saveProgress(prev);
    }
  }

  void toggleUI() {
    state = state.copyWith(showUI: !state.showUI);
  }

  void showUIControls() {
    state = state.copyWith(showUI: true);
  }

  void setBrightness(double value) {
    state = state.copyWith(brightness: value.clamp(0.1, 1.0));
  }

  void toggleScrollMode() {
    state = state.copyWith(isVerticalScroll: !state.isVerticalScroll);
    _ref.read(appSettingsProvider.notifier).setScrollMode(state.isVerticalScroll);
  }

  void toggleBookmark() {
    final comic = state.comic;
    if (comic == null) return;
    _ref.read(libraryProvider.notifier).toggleBookmark(comic.id, state.currentPage);
  }

  void _saveProgress(int page) {
    final comic = state.comic;
    if (comic == null) return;
    _ref.read(libraryProvider.notifier).updateReadProgress(comic.id, page);
  }

  Comic? getNextComic() {
    final comic = state.comic;
    if (comic == null) return null;
    return _ref.read(libraryProvider.notifier).getNextComic(comic.id);
  }

  void resetFinished() {
    state = state.copyWith(isFinished: false);
  }
}
