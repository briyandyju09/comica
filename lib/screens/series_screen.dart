import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/comic.dart';
import '../providers/library_provider.dart';
import 'reader_screen.dart';

class SeriesScreen extends ConsumerWidget {
  final String seriesName;
  final List<Comic> comics;

  const SeriesScreen({
    super.key,
    required this.seriesName,
    required this.comics,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Series app bar with cover mosaic
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: colorScheme.surface,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                seriesName,
                style: theme.textTheme.titleLarge?.copyWith(
                  shadows: [
                    Shadow(
                      color: Colors.black.withOpacity(0.6),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
              background: _SeriesCoverMosaic(comics: comics),
            ),
          ),

          // Stats bar
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  _StatChip(
                    icon: Icons.library_books_rounded,
                    label: '${comics.length} issues',
                    colorScheme: colorScheme,
                  ),
                  const SizedBox(width: 10),
                  _StatChip(
                    icon: Icons.check_circle_rounded,
                    label: '${comics.where((c) => c.isRead).length} read',
                    colorScheme: colorScheme,
                  ),
                  const Spacer(),
                  // Read all button
                  if (comics.isNotEmpty)
                    FilledButton.tonalIcon(
                      onPressed: () => _readNext(context, comics),
                      icon: const Icon(Icons.play_arrow_rounded, size: 18),
                      label: const Text('Continue'),
                      style: FilledButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Comics list
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final comic = comics[index];
                  return _SeriesComicTile(
                    comic: comic,
                    index: index,
                    onTap: () => _openComic(context, comic),
                    onFavorite: () =>
                        ref.read(libraryProvider.notifier).toggleFavorite(comic.id),
                  );
                },
                childCount: comics.length,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openComic(BuildContext context, Comic comic) {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ReaderScreen(comic: comic)),
    );
  }

  void _readNext(BuildContext context, List<Comic> comics) {
    // Find first unfinished comic or start from beginning
    final next = comics.firstWhere(
      (c) => c.lastReadPage < 0 || c.readProgress < 1.0,
      orElse: () => comics.first,
    );
    _openComic(context, next);
  }
}

class _SeriesCoverMosaic extends StatelessWidget {
  final List<Comic> comics;
  const _SeriesCoverMosaic({required this.comics});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final covers = comics.take(4).toList();

    return Stack(
      fit: StackFit.expand,
      children: [
        // Background grid of covers
        GridView.count(
          crossAxisCount: 2,
          physics: const NeverScrollableScrollPhysics(),
          children: covers.map((c) {
            if (c.coverImagePath != null) {
              return Image.file(
                File(c.coverImagePath!),
                fit: BoxFit.cover,
              );
            }
            return Container(color: colorScheme.primaryContainer);
          }).toList(),
        ),
        // Scrim
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.2),
                Colors.black.withOpacity(0.75),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SeriesComicTile extends StatelessWidget {
  final Comic comic;
  final int index;
  final VoidCallback onTap;
  final VoidCallback onFavorite;

  const _SeriesComicTile({
    required this.comic,
    required this.index,
    required this.onTap,
    required this.onFavorite,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Number badge
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        color: colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Cover thumbnail
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 46,
                    height: 64,
                    child: comic.coverImagePath != null
                        ? Image.file(
                            File(comic.coverImagePath!),
                            fit: BoxFit.cover,
                          )
                        : Container(
                            color: colorScheme.primaryContainer,
                            child: Icon(
                              Icons.auto_stories_rounded,
                              color: colorScheme.onPrimaryContainer,
                              size: 22,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 14),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        comic.title,
                        style: theme.textTheme.titleMedium,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      if (comic.isRead) ...[
                        Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(2),
                                child: LinearProgressIndicator(
                                  value: comic.readProgress,
                                  backgroundColor:
                                      colorScheme.surfaceContainerHighest,
                                  color: colorScheme.primary,
                                  minHeight: 3,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'p.${comic.lastReadPage + 1}',
                              style: theme.textTheme.labelSmall,
                            ),
                          ],
                        ),
                      ] else
                        Text(
                          'Unread',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.primary,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Actions
                Column(
                  children: [
                    IconButton(
                      icon: Icon(
                        comic.isFavorite
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        size: 20,
                      ),
                      color: comic.isFavorite
                          ? colorScheme.error
                          : colorScheme.onSurfaceVariant,
                      onPressed: onFavorite,
                      visualDensity: VisualDensity.compact,
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: colorScheme.onSurfaceVariant,
                      size: 20,
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

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final ColorScheme colorScheme;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
