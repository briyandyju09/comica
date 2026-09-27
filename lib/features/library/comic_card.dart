import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/comic.dart';
import '../../data/repositories/comic_repository.dart';
import '../library/library_provider.dart';

class ComicCard extends ConsumerStatefulWidget {
  final Comic comic;
  final int index;

  const ComicCard({super.key, required this.comic, required this.index});

  @override
  ConsumerState<ComicCard> createState() => _ComicCardState();
}

class _ComicCardState extends ConsumerState<ComicCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressCtrl;
  late Animation<double> _pressScale;
  String? _thumbPath;
  bool _thumbLoading = true;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.0,
      upperBound: 0.03,
    );
    _pressScale =
        Tween<double>(begin: 1.0, end: 0.97).animate(_pressCtrl);

    _loadThumbnail();
  }

  Future<void> _loadThumbnail() async {
    final repo = ref.read(comicRepositoryProvider);
    final path = await repo.ensureThumbnail(widget.comic);
    if (mounted) {
      setState(() {
        _thumbPath = path;
        _thumbLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  void _openComic() {
    HapticFeedback.selectionClick();
    context.pushNamed(
      'reader',
      pathParameters: {'id': widget.comic.id},
    );
  }

  void _showContextMenu(BuildContext context) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      builder: (ctx) => _ComicContextMenu(comic: widget.comic),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final comic = widget.comic;

    return GestureDetector(
      onTapDown: (_) => _pressCtrl.forward(),
      onTapUp: (_) {
        _pressCtrl.reverse();
        _openComic();
      },
      onTapCancel: () => _pressCtrl.reverse(),
      onLongPress: () => _showContextMenu(context),
      child: ScaleTransition(
        scale: _pressScale,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Hero(
                tag: 'comic_cover_${comic.id}',
                child: Material(
                  borderRadius: BorderRadius.circular(16),
                  clipBehavior: Clip.antiAlias,
                  elevation: 2,
                  shadowColor: scheme.shadow.withOpacity(0.3),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Cover image
                      _buildCover(scheme),

                      // Favorite badge
                      if (comic.isFavorite)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: scheme.errorContainer,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.favorite_rounded,
                                size: 12, color: scheme.error),
                          ),
                        ),

                      // Gradient overlay at bottom
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 50,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                Colors.black.withOpacity(0.55),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 7),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Text(
                comic.title,
                style: tt.labelMedium?.copyWith(fontWeight: FontWeight.w700),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (comic.sortNumber != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Text(
                  '#${comic.sortNumber}',
                  style: tt.bodySmall
                      ?.copyWith(color: scheme.primary, fontWeight: FontWeight.w600),
                ),
              ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }

  Widget _buildCover(ColorScheme scheme) {
    if (_thumbLoading) {
      return Container(
        color: scheme.surfaceContainerHighest,
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: scheme.primary.withOpacity(0.5),
          ),
        ),
      );
    }
    if (_thumbPath != null && File(_thumbPath!).existsSync()) {
      return Image.file(
        File(_thumbPath!),
        fit: BoxFit.cover,
        cacheWidth: 400,
      );
    }
    // Fallback
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primaryContainer,
            scheme.secondaryContainer,
          ],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.menu_book_rounded, size: 40, color: scheme.primary),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              widget.comic.title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: scheme.onPrimaryContainer,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Context menu bottom sheet ─────────────────────────────────────────────────
class _ComicContextMenu extends ConsumerWidget {
  final Comic comic;
  const _ComicContextMenu({required this.comic});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(comic.title,
                style: tt.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          const Divider(height: 1),
          const SizedBox(height: 8),

          _MenuItem(
            icon: comic.isFavorite
                ? Icons.favorite_rounded
                : Icons.favorite_border_rounded,
            label: comic.isFavorite ? 'Remove from Favorites' : 'Add to Favorites',
            color: scheme.error,
            onTap: () {
              ref.read(libraryProvider.notifier).toggleFavorite(comic.id);
              Navigator.pop(context);
              HapticFeedback.lightImpact();
            },
          ),

          _MenuItem(
            icon: Icons.play_arrow_rounded,
            label: 'Open from Beginning',
            onTap: () {
              Navigator.pop(context);
              context.pushNamed('reader',
                  pathParameters: {'id': comic.id},
                  queryParameters: {'page': '1'});
            },
          ),

          _MenuItem(
            icon: Icons.info_outline_rounded,
            label: 'Info — ${comic.totalPages} pages',
            onTap: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final effective = color ?? scheme.onSurface;
    return ListTile(
      leading: Icon(icon, color: effective),
      title: Text(label,
          style: TextStyle(color: effective, fontWeight: FontWeight.w500)),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}
