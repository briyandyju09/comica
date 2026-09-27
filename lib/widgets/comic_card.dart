import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shimmer/shimmer.dart';
import '../models/comic.dart';

class ComicCard extends StatefulWidget {
  final Comic comic;
  final VoidCallback onTap;
  final VoidCallback onFavorite;
  final VoidCallback onBookmark;
  final bool isSelected;

  const ComicCard({
    super.key,
    required this.comic,
    required this.onTap,
    required this.onFavorite,
    required this.onBookmark,
    this.isSelected = false,
  });

  @override
  State<ComicCard> createState() => _ComicCardState();
}

class _ComicCardState extends State<ComicCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    _pressController.forward();
  }

  void _onTapUp(TapUpDetails _) {
    _pressController.reverse();
    widget.onTap();
  }

  void _onTapCancel() {
    _pressController.reverse();
  }

  void _showContextMenu(BuildContext context) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ComicContextMenu(
        comic: widget.comic,
        onFavorite: widget.onFavorite,
        onBookmark: widget.onBookmark,
        onOpen: widget.onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        );
      },
      child: GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        onLongPress: () => _showContextMenu(context),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.35),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Cover image
                _CoverImage(comic: widget.comic),

                // Gradient overlay
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0.45, 0.85, 1.0],
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.7),
                          Colors.black.withOpacity(0.92),
                        ],
                      ),
                    ),
                  ),
                ),

                // Title & progress
                Positioned(
                  left: 10,
                  right: 10,
                  bottom: 10,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.comic.title,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              color: Colors.black.withOpacity(0.8),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (widget.comic.isRead) ...[
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: widget.comic.readProgress,
                            backgroundColor: Colors.white.withOpacity(0.2),
                            color: colorScheme.primary,
                            minHeight: 3,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Favorite badge
                if (widget.comic.isFavorite)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.favorite,
                        color: colorScheme.error,
                        size: 14,
                      ),
                    ),
                  ),

                // "NEW" badge for unread
                if (!widget.comic.isRead)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'NEW',
                        style: TextStyle(
                          color: colorScheme.onPrimary,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ),

                // Selection indicator
                if (widget.isSelected)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withOpacity(0.3),
                        border: Border.all(
                          color: colorScheme.primary,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        Icons.check_circle,
                        color: colorScheme.primary,
                        size: 32,
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

class _CoverImage extends StatelessWidget {
  final Comic comic;
  const _CoverImage({required this.comic});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (comic.coverImagePath != null) {
      final file = File(comic.coverImagePath!);
      return Image.file(
        file,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _Placeholder(colorScheme: colorScheme),
      );
    }

    return Shimmer.fromColors(
      baseColor: colorScheme.surfaceContainerHighest,
      highlightColor: colorScheme.surfaceContainerHigh,
      child: Container(color: colorScheme.surfaceContainerHighest),
    );
  }
}

class _Placeholder extends StatelessWidget {
  final ColorScheme colorScheme;
  const _Placeholder({required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: colorScheme.surfaceContainerHighest,
      child: Icon(
        Icons.auto_stories_rounded,
        size: 48,
        color: colorScheme.onSurfaceVariant.withOpacity(0.4),
      ),
    );
  }
}

class _ComicContextMenu extends StatelessWidget {
  final Comic comic;
  final VoidCallback onFavorite;
  final VoidCallback onBookmark;
  final VoidCallback onOpen;

  const _ComicContextMenu({
    required this.comic,
    required this.onFavorite,
    required this.onBookmark,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.onSurfaceVariant.withOpacity(0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Comic title
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Text(
              comic.title,
              style: theme.textTheme.titleMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Divider(height: 1),
          _MenuItem(
            icon: Icons.play_circle_fill_rounded,
            label: comic.isRead ? 'Continue Reading' : 'Start Reading',
            color: colorScheme.primary,
            onTap: () {
              Navigator.pop(context);
              onOpen();
            },
          ),
          _MenuItem(
            icon: comic.isFavorite
                ? Icons.favorite_rounded
                : Icons.favorite_border_rounded,
            label: comic.isFavorite ? 'Remove Favorite' : 'Add to Favorites',
            color: colorScheme.error,
            onTap: () {
              Navigator.pop(context);
              onFavorite();
            },
          ),
          _MenuItem(
            icon: Icons.bookmark_add_rounded,
            label: 'Bookmark Current Page',
            color: colorScheme.secondary,
            onTap: () {
              Navigator.pop(context);
              onBookmark();
            },
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 16),
            Text(label, style: theme.textTheme.bodyLarge),
          ],
        ),
      ),
    );
  }
}
