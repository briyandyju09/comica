import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:animations/animations.dart';
import 'library_screen.dart';
import 'series_screen.dart';
import 'settings_screen.dart';
import 'reader_screen.dart';
import '../providers/library_provider.dart';
import '../models/comic.dart';
import '../widgets/comic_card.dart';

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _selectedIndex = 0;

  void _onNavTap(int index) {
    if (index == _selectedIndex) return;
    HapticFeedback.selectionClick();
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: PageTransitionSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (child, animation, secondaryAnimation) =>
            FadeThroughTransition(
          animation: animation,
          secondaryAnimation: secondaryAnimation,
          child: child,
        ),
        child: _buildPage(_selectedIndex),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onNavTap,
        animationDuration: const Duration(milliseconds: 400),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view_rounded),
            label: 'Library',
          ),
          NavigationDestination(
            icon: Icon(Icons.collections_bookmark_outlined),
            selectedIcon: Icon(Icons.collections_bookmark_rounded),
            label: 'Series',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  Widget _buildPage(int index) {
    switch (index) {
      case 0:
        return const LibraryScreen();
      case 1:
        return const _SeriesListScreen();
      case 2:
        return const SettingsScreen();
      default:
        return const LibraryScreen();
    }
  }
}

// ── Series list screen ────────────────────────────────────────────────────

class _SeriesListScreen extends ConsumerWidget {
  const _SeriesListScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final libraryState = ref.watch(libraryProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Group comics by series
    final Map<String, List<Comic>> seriesMap = {};
    final List<Comic> standalone = [];

    for (final comic in libraryState.comics) {
      final series = comic.seriesName;
      if (series != null && series.isNotEmpty) {
        seriesMap.putIfAbsent(series, () => []).add(comic);
      } else {
        standalone.add(comic);
      }
    }

    final seriesEntries = seriesMap.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 100,
            floating: true,
            pinned: true,
            backgroundColor: colorScheme.surface,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              title: Text(
                'Series',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          if (libraryState.comics.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.collections_bookmark_outlined,
                      size: 80,
                      color: colorScheme.onSurfaceVariant.withOpacity(0.4),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No series yet',
                      style: theme.textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Comics with #1, #2... in the title\nwill be grouped here automatically',
                      style: theme.textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          else ...[
            // Series groups
            if (seriesEntries.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                  child: Text('Collections', style: theme.textTheme.titleLarge),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final entry = seriesEntries[index];
                      return _SeriesGroupTile(
                        seriesName: entry.key,
                        comics: entry.value,
                      );
                    },
                    childCount: seriesEntries.length,
                  ),
                ),
              ),
            ],

            // Standalone comics
            if (standalone.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                  child: Text('Standalone', style: theme.textTheme.titleLarge),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                sliver: SliverGrid(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final comic = standalone[index];
                      return _StandaloneComicTile(comic: comic);
                    },
                    childCount: standalone.length,
                  ),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.62,
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _SeriesGroupTile extends StatelessWidget {
  final String seriesName;
  final List<Comic> comics;

  const _SeriesGroupTile({
    required this.seriesName,
    required this.comics,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final readCount = comics.where((c) => c.isRead).length;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => SeriesScreen(
                  seriesName: seriesName,
                  comics: comics,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Cover stack
                _CoverStack(comics: comics, colorScheme: colorScheme),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        seriesName,
                        style: theme.textTheme.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${comics.length} issues · $readCount read',
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: comics.isEmpty ? 0 : readCount / comics.length,
                          backgroundColor: colorScheme.surfaceContainerHighest,
                          color: colorScheme.primary,
                          minHeight: 4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  color: colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CoverStack extends StatelessWidget {
  final List<Comic> comics;
  final ColorScheme colorScheme;

  const _CoverStack({required this.comics, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    final covers = comics.take(3).toList().reversed.toList();
    return SizedBox(
      width: 72,
      height: 90,
      child: Stack(
        children: [
          for (int i = 0; i < covers.length; i++)
            Positioned(
              left: i * 8.0,
              top: i * 2.0,
              child: Transform.rotate(
                angle: (i - 1) * 0.04,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 52,
                    height: 72,
                    child: covers[i].coverImagePath != null
                        ? Image.file(
                            File(covers[i].coverImagePath!),
                            fit: BoxFit.cover,
                          )
                        : Container(color: colorScheme.primaryContainer),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StandaloneComicTile extends StatelessWidget {
  final Comic comic;
  const _StandaloneComicTile({required this.comic});

  @override
  Widget build(BuildContext context) {
    return ComicCard(
      comic: comic,
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ReaderScreen(comic: comic)),
        );
      },
      onFavorite: () {},
      onBookmark: () {},
    );
  }
}
