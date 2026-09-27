import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../data/models/comic.dart';
import '../../data/models/reading_progress.dart';
import '../../data/services/database_service.dart';
import '../library/library_provider.dart';

class ReaderScreen extends ConsumerStatefulWidget {
  final String comicId;
  final int startPage;

  const ReaderScreen({
    super.key,
    required this.comicId,
    this.startPage = 1,
  });

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen>
    with TickerProviderStateMixin {
  Comic? _comic;
  bool _loadingComic = true;

  // PDF controller
  late final PdfViewerController _pdfCtrl;

  // UI overlay state
  bool _showOverlay = true;
  Timer? _overlayTimer;

  // Page tracking
  int _currentPage = 1;
  int _totalPages = 0;

  // Animation controllers
  late AnimationController _overlayAnimCtrl;
  late Animation<double> _overlayFade;

  // Auto-next
  bool _showEndScreen = false;
  Comic? _nextComic;

  @override
  void initState() {
    super.initState();
    _pdfCtrl = PdfViewerController();

    _overlayAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
      value: 1.0,
    );
    _overlayFade =
        CurvedAnimation(parent: _overlayAnimCtrl, curve: Curves.easeInOut);

    WakelockPlus.enable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _loadComic();
    _scheduleOverlayHide();
  }

  Future<void> _loadComic() async {
    final repo = ref.read(comicRepositoryProvider);
    final comic = await repo.getComic(widget.comicId);
    if (!mounted) return;

    // Load saved progress
    final prog = await DatabaseService.instance.getProgress(widget.comicId);
    final startPage = widget.startPage > 1
        ? widget.startPage
        : (prog?.lastPage ?? 1);

    setState(() {
      _comic = comic;
      _currentPage = startPage;
      _totalPages = comic?.totalPages ?? 0;
      _loadingComic = false;
    });

    // Pre-find next comic
    _nextComic = ref.read(libraryProvider.notifier).getNextComic(widget.comicId);
  }

  @override
  void dispose() {
    _overlayTimer?.cancel();
    _overlayAnimCtrl.dispose();
    // _pdfCtrl.dispose(); // PdfViewerController does not have a dispose method in pdfrx 1.3.5
    WakelockPlus.disable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  // ── Overlay control ───────────────────────────────────────────────────────

  void _scheduleOverlayHide() {
    _overlayTimer?.cancel();
    _overlayTimer = Timer(const Duration(seconds: 3), _hideOverlay);
  }

  void _hideOverlay() {
    if (!mounted) return;
    setState(() => _showOverlay = false);
    _overlayAnimCtrl.reverse();
  }

  void _toggleOverlay() {
    if (_showEndScreen) return;
    setState(() => _showOverlay = !_showOverlay);
    if (_showOverlay) {
      _overlayAnimCtrl.forward();
      _scheduleOverlayHide();
    } else {
      _overlayTimer?.cancel();
      _overlayAnimCtrl.reverse();
    }
  }

  void _keepOverlayVisible() {
    _overlayTimer?.cancel();
    _scheduleOverlayHide();
  }

  // ── Page change ───────────────────────────────────────────────────────────

  void _onPageChanged(int page) {
    setState(() => _currentPage = page);
    _saveProgress(page);

    // Check if we've reached the last page
    if (page >= _totalPages && _totalPages > 0) {
      _showEndScreen = true;
      _overlayTimer?.cancel();
      _overlayAnimCtrl.forward();
      setState(() => _showOverlay = true);
    }
  }

  Future<void> _saveProgress(int page) async {
    if (_comic == null) return;
    await ref
        .read(readingProgressProvider.notifier)
        .saveProgress(widget.comicId, page, _totalPages);
  }

  // ── Navigation ────────────────────────────────────────────────────────────

  void _goBack() {
    _saveProgress(_currentPage);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    if (context.canPop()) {
      context.pop();
    } else {
      context.goNamed('library');
    }
  }

  void _openNextComic() {
    if (_nextComic == null) return;
    context.pushReplacementNamed(
      'reader',
      pathParameters: {'id': _nextComic!.id},
      queryParameters: {'page': '1'},
    );
  }

  // ── Page thumbnails sheet ─────────────────────────────────────────────────

  void _showPageThumbnails() {
    _overlayTimer?.cancel();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (ctx) => _PageThumbnailsSheet(
        comic: _comic!,
        currentPage: _currentPage,
        totalPages: _totalPages,
        onPageTap: (page) {
          Navigator.pop(ctx);
          _pdfCtrl.goToPage(pageNumber: page);
          _keepOverlayVisible();
        },
      ),
    ).then((_) => _scheduleOverlayHide());
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingComic || _comic == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final scheme = Theme.of(context).colorScheme;
    final comic = _comic!;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleOverlay,
        behavior: HitTestBehavior.translucent,
        child: Stack(
          children: [
            // ── PDF Viewer ──────────────────────────────────────────────
            Positioned.fill(
              child: PdfViewer.file(
                comic.path,
                controller: _pdfCtrl,
                initialPageNumber: _currentPage,
                params: PdfViewerParams(
                  backgroundColor: Colors.black,
                  enableTextSelection: false,
                  pageDropShadow: const BoxShadow(
                    color: Colors.black54,
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                  onPageChanged: (page) {
                    if (page != null) _onPageChanged(page);
                  },
                  loadingBannerBuilder: (ctx, bytesDownloaded, totalBytes) =>
                      const Center(
                          child: CircularProgressIndicator(color: Colors.white)),
                ),
              ),
            ),

            // ── End-of-comic screen ─────────────────────────────────────
            if (_showEndScreen)
              _EndScreen(
                comic: comic,
                nextComic: _nextComic,
                onNext: _openNextComic,
                onBack: _goBack,
              ),

            // ── Top overlay bar ─────────────────────────────────────────
            if (!_showEndScreen)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: FadeTransition(
                  opacity: _overlayFade,
                  child: _TopBar(
                    comic: comic,
                    onBack: _goBack,
                    onThumbnails: _showPageThumbnails,
                    onPointerDown: (_) => _keepOverlayVisible(),
                  ),
                ),
              ),

            // ── Bottom overlay controls ─────────────────────────────────
            if (!_showEndScreen)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: FadeTransition(
                  opacity: _overlayFade,
                  child: _BottomControls(
                    currentPage: _currentPage,
                    totalPages: _totalPages,
                    onPageChanged: (page) {
                      _pdfCtrl.goToPage(pageNumber: page);
                      _keepOverlayVisible();
                    },
                    onPointerDown: (_) => _keepOverlayVisible(),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Top bar ───────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final Comic comic;
  final VoidCallback onBack;
  final VoidCallback onThumbnails;
  final PointerDownEventListener onPointerDown;

  const _TopBar({
    required this.comic,
    required this.onBack,
    required this.onThumbnails,
    required this.onPointerDown,
  });

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: onPointerDown,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black87, Colors.transparent],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: AppBar(
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: onBack,
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  comic.title,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (comic.sortNumber != null)
                  Text(
                    '#${comic.sortNumber}',
                    style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                        fontWeight: FontWeight.w400),
                  ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.grid_view_rounded),
                tooltip: 'Page thumbnails',
                onPressed: onThumbnails,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Bottom controls ───────────────────────────────────────────────────────────

class _BottomControls extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final ValueChanged<int> onPageChanged;
  final PointerDownEventListener onPointerDown;

  const _BottomControls({
    required this.currentPage,
    required this.totalPages,
    required this.onPageChanged,
    required this.onPointerDown,
  });

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: onPointerDown,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Colors.black87, Colors.transparent],
          ),
        ),
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Slider
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: Colors.white,
                  inactiveTrackColor: Colors.white30,
                  thumbColor: Colors.white,
                  overlayColor: Colors.white24,
                  trackHeight: 3,
                  thumbShape:
                      const RoundSliderThumbShape(enabledThumbRadius: 8),
                ),
                child: Slider(
                  value: totalPages > 0
                      ? currentPage.toDouble().clamp(1, totalPages.toDouble())
                      : 1,
                  min: 1,
                  max: totalPages > 0 ? totalPages.toDouble() : 1,
                  onChanged: totalPages > 0
                      ? (v) => onPageChanged(v.round())
                      : null,
                ),
              ),

              // Page counter
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$currentPage / $totalPages',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── End of comic screen ───────────────────────────────────────────────────────

class _EndScreen extends StatefulWidget {
  final Comic comic;
  final Comic? nextComic;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const _EndScreen({
    required this.comic,
    required this.nextComic,
    required this.onNext,
    required this.onBack,
  });

  @override
  State<_EndScreen> createState() => _EndScreenState();
}

class _EndScreenState extends State<_EndScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return FadeTransition(
      opacity: _fade,
      child: Container(
        color: Colors.black87,
        alignment: Alignment.center,
        child: SlideTransition(
          position: _slide,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Done icon
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.check_circle_rounded,
                      size: 52, color: scheme.primary),
                ),
                const SizedBox(height: 28),
                Text(
                  widget.nextComic != null
                      ? 'Comic Finished!'
                      : "You're all caught up!",
                  style: tt.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  widget.nextComic != null
                      ? 'Up next: ${widget.nextComic!.title}'
                      : 'No more comics in your library.',
                  style: tt.bodyLarge?.copyWith(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),

                // Next comic button
                if (widget.nextComic != null)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: widget.onNext,
                      icon: const Icon(Icons.skip_next_rounded),
                      label: Text('Read ${widget.nextComic!.title}',
                          overflow: TextOverflow.ellipsis),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                      ),
                    ),
                  ),

                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: widget.onBack,
                    icon: const Icon(Icons.library_books_rounded,
                        color: Colors.white70),
                    label: const Text('Back to Library',
                        style: TextStyle(color: Colors.white70)),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      side: const BorderSide(color: Colors.white30),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Page thumbnails bottom sheet ──────────────────────────────────────────────

class _PageThumbnailsSheet extends StatelessWidget {
  final Comic comic;
  final int currentPage;
  final int totalPages;
  final ValueChanged<int> onPageTap;

  const _PageThumbnailsSheet({
    required this.comic,
    required this.currentPage,
    required this.totalPages,
    required this.onPageTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (ctx, scrollCtrl) {
        return Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: scheme.onSurfaceVariant.withOpacity(0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Row(
                children: [
                  Text('Pages',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700)),
                  const Spacer(),
                  Text('$totalPages total',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
            Expanded(
              child: GridView.builder(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 0.68,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: totalPages,
                itemBuilder: (ctx, i) {
                  final page = i + 1;
                  final isCurrent = page == currentPage;
                  return GestureDetector(
                    onTap: () => onPageTap(page),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: PdfPageView(
                            document: null,
                            pageNumber: page,
                            alignment: Alignment.center,
                          ),
                        ),
                        if (isCurrent)
                          Positioned.fill(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: scheme.primary, width: 3),
                              ),
                            ),
                          ),
                        Positioned(
                          bottom: 4,
                          right: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isCurrent
                                  ? scheme.primary
                                  : Colors.black54,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '$page',
                              style: TextStyle(
                                color: isCurrent
                                    ? scheme.onPrimary
                                    : Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
