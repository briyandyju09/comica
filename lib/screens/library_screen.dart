import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:animations/animations.dart';
import '../models/comic.dart';
import '../providers/library_provider.dart';
import '../widgets/comic_card.dart';
import '../widgets/continue_reading_card.dart';
import '../widgets/skeleton_loader.dart';
import 'reader_screen.dart';
import 'onboarding_screen.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen>
    with TickerProviderStateMixin {
  final TextEditingController _searchCtrl = TextEditingController();
  late TabController _tabController;
  bool _isSearchOpen = false;

  static const int _tabAll = 0;
  static const int _tabFavorites = 1;
  static const int _tabInProgress = 2;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        switch (_tabController.index) {
          case _tabAll:
            ref.read(libraryProvider.notifier).setFilter(LibraryFilter.all);
            break;
          case _tabFavorites:
            ref.read(libraryProvider.notifier).setFilter(LibraryFilter.favorites);
            break;
          case _tabInProgress:
            ref.read(libraryProvider.notifier).setFilter(LibraryFilter.inProgress);
            break;
        }
      }
    });

    // Load library on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(libraryProvider.notifier).loadLibrary();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _openComic(Comic comic) {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => ReaderScreen(comic: comic),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }

  Future<void> _changeFolder() async {
    HapticFeedback.mediumImpact();
    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select comics folder',
    );
    if (result != null && mounted) {
      await ref.read(appSettingsProvider.notifier).setRootDirectory(result);
      await ref.read(libraryProvider.notifier).scanLibrary(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final libraryState = ref.watch(libraryProvider);
    final settings = ref.watch(appSettingsProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    // If no root dir, go to onboarding
    if (settings.rootDirectoryPath == null &&
        libraryState.status == LibraryStatus.ready &&
        libraryState.comics.isEmpty) {
      return const OnboardingScreen();
    }

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          _buildSliverAppBar(context, libraryState, colorScheme, theme, innerBoxIsScrolled),
        ],
        body: _buildBody(context, libraryState, colorScheme, theme),
      ),
      floatingActionButton: libraryState.status == LibraryStatus.ready &&
              libraryState.comics.isNotEmpty
          ? FloatingActionButton(
              onPressed: () {
                HapticFeedback.mediumImpact();
                ref.read(libraryProvider.notifier).refreshLibrary();
              },
              tooltip: 'Sync Library',
              child: libraryState.isSyncing
                  ? SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    )
                  : const Icon(Icons.sync_rounded),
            )
          : null,
    );
  }

  Widget _buildSliverAppBar(
    BuildContext context,
    LibraryState libraryState,
    ColorScheme colorScheme,
    ThemeData theme,
    bool innerBoxIsScrolled,
  ) {
    return SliverAppBar(
      expandedHeight: _isSearchOpen ? 130 : 160,
      floating: true,
      pinned: true,
      snap: true,
      forceElevated: innerBoxIsScrolled,
      backgroundColor: colorScheme.surface,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.fromLTRB(20, 0, 20, 60),
        title: _isSearchOpen
            ? null
            : Text(
                'Comica',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                colorScheme.primary.withOpacity(0.08),
                colorScheme.surface,
              ],
            ),
          ),
        ),
      ),
      actions: [
        if (!_isSearchOpen) ...[
          IconButton(
            icon: const Icon(Icons.search_rounded),
            onPressed: () => setState(() => _isSearchOpen = true),
            tooltip: 'Search',
          ),
          IconButton(
            icon: const Icon(Icons.folder_open_rounded),
            onPressed: _changeFolder,
            tooltip: 'Change Folder',
          ),
          const SizedBox(width: 4),
        ] else ...[
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 0, 8),
              child: TextField(
                controller: _searchCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search comics...',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
                onChanged: (q) {
                  ref.read(libraryProvider.notifier).setSearchQuery(q);
                },
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () {
              setState(() => _isSearchOpen = false);
              _searchCtrl.clear();
              ref.read(libraryProvider.notifier).setSearchQuery('');
            },
          ),
        ],
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(48),
        child: TabBar(
          controller: _tabController,
          labelStyle: theme.textTheme.labelLarge,
          unselectedLabelStyle: theme.textTheme.labelLarge,
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.grid_view_rounded, size: 16),
                  const SizedBox(width: 6),
                  Text('All (${libraryState.comics.length})'),
                ],
              ),
            ),
            const Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.favorite_rounded, size: 16),
                  SizedBox(width: 6),
                  Text('Favorites'),
                ],
              ),
            ),
            const Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.schedule_rounded, size: 16),
                  SizedBox(width: 6),
                  Text('Reading'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    LibraryState libraryState,
    ColorScheme colorScheme,
    ThemeData theme,
  ) {
    switch (libraryState.status) {
      case LibraryStatus.initial:
      case LibraryStatus.scanning:
        return const ComicGridSkeleton();

      case LibraryStatus.error:
        return _buildErrorState(context, libraryState, colorScheme, theme);

      case LibraryStatus.ready:
        final comics = libraryState.filteredComics;
        if (comics.isEmpty) {
          return _buildEmptyState(context, colorScheme, theme, libraryState);
        }
        return _buildLibraryContent(comics, colorScheme);
    }
  }

  Widget _buildLibraryContent(List<Comic> comics, ColorScheme colorScheme) {
    final recentlyRead = ref.read(libraryProvider.notifier).getRecentlyRead();
    final lastRead = recentlyRead.isNotEmpty ? recentlyRead.first : null;

    return CustomScrollView(
      slivers: [
        // Continue Reading card
        if (lastRead != null && _tabController.index == _tabAll)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: ContinueReadingCard(
                comic: lastRead,
                onTap: () => _openComic(lastRead),
              ),
            ),
          ),

        // Section header
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Row(
              children: [
                Text(
                  'Library',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${comics.length}',
                    style: TextStyle(
                      color: colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Grid
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
          sliver: SliverGrid(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final comic = comics[index];
                return _AnimatedComicCard(
                  key: ValueKey(comic.id),
                  index: index,
                  comic: comic,
                  onTap: () => _openComic(comic),
                  onFavorite: () => ref
                      .read(libraryProvider.notifier)
                      .toggleFavorite(comic.id),
                  onBookmark: () => ref
                      .read(libraryProvider.notifier)
                      .toggleBookmark(comic.id, comic.lastReadPage),
                );
              },
              childCount: comics.length,
            ),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 14,
              childAspectRatio: 0.62,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    ColorScheme colorScheme,
    ThemeData theme,
    LibraryState state,
  ) {
    final isSearch = state.searchQuery.isNotEmpty;
    final isFilter = state.filter != LibraryFilter.all;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colorScheme.primaryContainer,
              ),
              child: Icon(
                isSearch
                    ? Icons.search_off_rounded
                    : isFilter
                        ? Icons.filter_list_off_rounded
                        : Icons.auto_stories_outlined,
                size: 52,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              isSearch
                  ? 'No results found'
                  : isFilter
                      ? 'Nothing here yet'
                      : 'Your library is empty',
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              isSearch
                  ? 'Try a different search term'
                  : isFilter
                      ? 'Start reading to see comics here'
                      : 'Add PDF or CBZ comic files to your selected folder',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            if (!isSearch && !isFilter) ...[
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: _changeFolder,
                icon: const Icon(Icons.folder_open_rounded),
                label: const Text('Choose Folder'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(
    BuildContext context,
    LibraryState state,
    ColorScheme colorScheme,
    ThemeData theme,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 64,
              color: colorScheme.error,
            ),
            const SizedBox(height: 20),
            Text('Something went wrong', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              state.errorMessage ?? 'Unknown error',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () =>
                  ref.read(libraryProvider.notifier).refreshLibrary(),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Comic card with staggered entry animation
class _AnimatedComicCard extends StatefulWidget {
  final int index;
  final Comic comic;
  final VoidCallback onTap;
  final VoidCallback onFavorite;
  final VoidCallback onBookmark;

  const _AnimatedComicCard({
    super.key,
    required this.index,
    required this.comic,
    required this.onTap,
    required this.onFavorite,
    required this.onBookmark,
  });

  @override
  State<_AnimatedComicCard> createState() => _AnimatedComicCardState();
}

class _AnimatedComicCardState extends State<_AnimatedComicCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    final delay = (widget.index % 9) * 40;
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

    Future.delayed(Duration(milliseconds: delay), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: ComicCard(
          comic: widget.comic,
          onTap: widget.onTap,
          onFavorite: widget.onFavorite,
          onBookmark: widget.onBookmark,
        ),
      ),
    );
  }
}
