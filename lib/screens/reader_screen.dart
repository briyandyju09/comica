import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfx/pdfx.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import '../models/comic.dart';
import '../providers/library_provider.dart';
import '../providers/reader_provider.dart';
import 'finished_screen.dart';

class ReaderScreen extends ConsumerStatefulWidget {
  final Comic comic;

  const ReaderScreen({super.key, required this.comic});

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen>
    with TickerProviderStateMixin {
  PdfController? _pdfController;
  late AnimationController _uiAnimController;
  late Animation<double> _uiFade;
  late AnimationController _pageNumController;

  @override
  void initState() {
    super.initState();

    _uiAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
      value: 1.0,
    );
    _uiFade = CurvedAnimation(parent: _uiAnimController, curve: Curves.easeOut);

    _pageNumController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    // Init reader state
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(readerProvider.notifier).openComic(widget.comic);
      _initPdf();
    });

    // Enter immersive mode
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  Future<void> _initPdf() async {
    final comic = widget.comic;
    if (comic.filePaths.isEmpty) return;

    final firstFile = comic.filePaths.first;
    if (!firstFile.toLowerCase().endsWith('.pdf')) return;

    final readerState = ref.read(readerProvider);
    final startPage = (readerState.currentPage) + 1; // pdfx is 1-indexed

    final controller = PdfController(
      document: PdfDocument.openFile(firstFile),
      initialPage: startPage,
    );

    setState(() => _pdfController = controller);
  }

  @override
  void dispose() {
    _pdfController?.dispose();
    _uiAnimController.dispose();
    _pageNumController.dispose();
    // Restore system UI
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _toggleUI() {
    final notifier = ref.read(readerProvider.notifier);
    notifier.toggleUI();
    if (ref.read(readerProvider).showUI) {
      _uiAnimController.forward();
    } else {
      _uiAnimController.reverse();
    }
  }

  void _goToPage(int page) {
    ref.read(readerProvider.notifier).goToPage(page);
    _pdfController?.animateToPage(
      page + 1,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
    );
    _pageNumController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final readerState = ref.watch(readerProvider);
    final colorScheme = Theme.of(context).colorScheme;

    // Handle finished state
    if (readerState.isFinished) {
      final nextComic = ref.read(readerProvider.notifier).getNextComic();
      return FinishedScreen(
        currentComic: readerState.comic!,
        nextComic: nextComic,
        onContinue: nextComic != null
            ? () {
                ref.read(readerProvider.notifier).resetFinished();
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => ReaderScreen(comic: nextComic),
                  ),
                );
              }
            : null,
        onReturn: () => Navigator.of(context).pop(),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleUI,
        child: Stack(
          children: [
            // PDF Viewer
            if (_pdfController != null)
              _buildPdfViewer(readerState, colorScheme)
            else
              const Center(
                child: CircularProgressIndicator(),
              ),

            // Brightness filter
            if (readerState.brightness < 1.0)
              Positioned.fill(
                child: IgnorePointer(
                  child: ColoredBox(
                    color: Colors.black
                        .withOpacity(1.0 - readerState.brightness),
                  ),
                ),
              ),

            // Top bar
            AnimatedBuilder(
              animation: _uiFade,
              builder: (_, child) => Opacity(
                opacity: _uiFade.value,
                child: IgnorePointer(
                  ignoring: !readerState.showUI,
                  child: child!,
                ),
              ),
              child: _buildTopBar(context, readerState, colorScheme),
            ),

            // Bottom controls
            AnimatedBuilder(
              animation: _uiFade,
              builder: (_, child) => Opacity(
                opacity: _uiFade.value,
                child: IgnorePointer(
                  ignoring: !readerState.showUI,
                  child: child!,
                ),
              ),
              child: _buildBottomControls(context, readerState, colorScheme),
            ),

            // Page number indicator (center, brief)
            if (readerState.totalPages > 0)
              Positioned(
                bottom: 100,
                left: 0,
                right: 0,
                child: AnimatedBuilder(
                  animation: _pageNumController,
                  builder: (_, child) => Opacity(
                    opacity: (1.0 - _pageNumController.value).clamp(0.0, 1.0),
                    child: child,
                  ),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${readerState.currentPage + 1} / ${readerState.totalPages}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPdfViewer(ReaderState readerState, ColorScheme colorScheme) {
    return PdfView(
      controller: _pdfController!,
      backgroundDecoration: const BoxDecoration(color: Colors.black),
      onDocumentLoaded: (doc) {
        ref.read(readerProvider.notifier).setTotalPages(doc.pagesCount);
      },
      onPageChanged: (page) {
        // page is 1-indexed in pdfx
        ref.read(readerProvider.notifier).goToPage(page - 1);
        _pageNumController.forward(from: 0);
      },
      builders: PdfViewBuilders<DefaultBuilderOptions>(
        options: const DefaultBuilderOptions(),
        documentLoaderBuilder: (_) => const Center(
          child: CircularProgressIndicator(),
        ),
        pageLoaderBuilder: (_) => const Center(
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        pageBuilder: (context, pageImage, index, document) {
          return PhotoViewGalleryPageOptions(
            imageProvider: PdfPageImageProvider(pageImage, index, document.id),
            heroAttributes: PhotoViewHeroAttributes(
              tag: '${document.id}-$index',
            ),
            minScale: PhotoViewComputedScale.contained * 0.8,
            maxScale: PhotoViewComputedScale.covered * 4.0,
            initialScale: PhotoViewComputedScale.contained,
          );
        },
      ),
    );
  }

  Widget _buildTopBar(
    BuildContext context,
    ReaderState readerState,
    ColorScheme colorScheme,
  ) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withOpacity(0.85),
              Colors.transparent,
            ],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 20),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  color: Colors.white,
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'Back',
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    readerState.comic?.title ?? '',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Bookmark toggle
                IconButton(
                  icon: Icon(
                    readerState.isBookmarked
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
                  ),
                  color: readerState.isBookmarked
                      ? colorScheme.primary
                      : Colors.white,
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    ref.read(readerProvider.notifier).toggleBookmark();
                  },
                  tooltip: 'Bookmark',
                ),
                // Scroll mode toggle
                IconButton(
                  icon: Icon(
                    readerState.isVerticalScroll
                        ? Icons.swap_vert_rounded
                        : Icons.swap_horiz_rounded,
                  ),
                  color: Colors.white,
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    ref.read(readerProvider.notifier).toggleScrollMode();
                  },
                  tooltip: 'Toggle Scroll Mode',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomControls(
    BuildContext context,
    ReaderState readerState,
    ColorScheme colorScheme,
  ) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              Colors.black.withOpacity(0.9),
              Colors.transparent,
            ],
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Page slider
                if (readerState.totalPages > 1)
                  Row(
                    children: [
                      Text(
                        '${readerState.currentPage + 1}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                      Expanded(
                        child: Slider(
                          value: readerState.currentPage.toDouble(),
                          min: 0,
                          max: (readerState.totalPages - 1).toDouble(),
                          onChanged: (v) => _goToPage(v.round()),
                          activeColor: colorScheme.primary,
                          inactiveColor: Colors.white.withOpacity(0.2),
                        ),
                      ),
                      Text(
                        '${readerState.totalPages}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),

                // Brightness slider
                Row(
                  children: [
                    const Icon(
                      Icons.brightness_low_rounded,
                      color: Colors.white54,
                      size: 18,
                    ),
                    Expanded(
                      child: Slider(
                        value: readerState.brightness,
                        min: 0.1,
                        max: 1.0,
                        onChanged: (v) =>
                            ref.read(readerProvider.notifier).setBrightness(v),
                        activeColor: Colors.amber,
                        inactiveColor: Colors.white.withOpacity(0.2),
                      ),
                    ),
                    const Icon(
                      Icons.brightness_high_rounded,
                      color: Colors.white54,
                      size: 18,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
