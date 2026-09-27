import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:file_picker/file_picker.dart';

import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/skeleton_comic_card.dart';
import '../../shared/widgets/continue_reading_card.dart';
import 'comic_card.dart';
import 'library_provider.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  final _searchCtrl = TextEditingController();
  bool _searchActive = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _changeFolder() async {
    HapticFeedback.mediumImpact();
    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select your comics folder',
    );
    if (result != null && mounted) {
      await ref.read(libraryProvider.notifier).setRootPath(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(libraryProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: RefreshIndicator(
        onRefresh: () => ref.read(libraryProvider.notifier).refreshLibrary(),
        color: scheme.primary,
        child: CustomScrollView(
          slivers: [
            // ── Large App Bar ─────────────────────────────
            SliverAppBar.large(
              title: _searchActive
                  ? _SearchField(
                      controller: _searchCtrl,
                      onChanged: (q) =>
                          ref.read(libraryProvider.notifier).setSearch(q),
                      onClose: () {
                        setState(() => _searchActive = false);
                        _searchCtrl.clear();
                        ref.read(libraryProvider.notifier).setSearch('');
                      },
                    )
                  : const Text('Comica',
                      style: TextStyle(fontWeight: FontWeight.w800)),
              centerTitle: false,
              pinned: true,
              actions: [
                if (!_searchActive) ...[
                  // Favorites filter
                  IconButton(
                    icon: Icon(
                      state.showFavoritesOnly
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: state.showFavoritesOnly ? scheme.error : null,
                    ),
                    tooltip: 'Favorites',
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      ref
                          .read(libraryProvider.notifier)
                          .toggleFavoritesFilter();
                    },
                  ),
                  // Search
                  IconButton(
                    icon: const Icon(Icons.search_rounded),
                    tooltip: 'Search',
                    onPressed: () =>
                        setState(() => _searchActive = true),
                  ),
                  // More menu
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert_rounded),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    onSelected: (val) {
                      if (val == 'change') _changeFolder();
                      if (val == 'refresh') {
                        ref.read(libraryProvider.notifier).refreshLibrary();
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'refresh',
                        child: ListTile(
                          leading: Icon(Icons.refresh_rounded),
                          title: Text('Refresh Library'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'change',
                        child: ListTile(
                          leading: Icon(Icons.folder_open_rounded),
                          title: Text('Change Folder'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),

            // ── Continue Reading ──────────────────────────
            const SliverToBoxAdapter(child: ContinueReadingCard()),

            // ── Stats row ─────────────────────────────────
            if (state.status == LibraryStatus.loaded &&
                state.comics.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: Row(
                    children: [
                      Text(
                        '${state.displayComics.length} ${state.displayComics.length == 1 ? 'comic' : 'comics'}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      if (state.showFavoritesOnly) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: scheme.errorContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text('Favorites',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: scheme.onErrorContainer,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

            // ── Body ────────────────────────────────────────
            _buildBody(state, scheme),

            // Bottom padding
            const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(LibraryState state, ColorScheme scheme) {
    switch (state.status) {
      case LibraryStatus.initial:
        return SliverFillRemaining(
          child: EmptyState(
            title: 'No folder selected',
            subtitle: 'Choose your comics folder to get started.',
            icon: Icons.folder_open_rounded,
            actionLabel: 'Choose Folder',
            onAction: _changeFolder,
          ),
        );

      case LibraryStatus.loading:
        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          sliver: SliverGrid.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.58,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: 9,
            itemBuilder: (_, __) => const SkeletonComicCard(),
          ),
        );

      case LibraryStatus.error:
        return SliverFillRemaining(
          child: EmptyState(
            title: 'Something went wrong',
            subtitle: state.error ?? 'Could not load your library.',
            icon: Icons.error_outline_rounded,
            actionLabel: 'Try Again',
            onAction: () => ref.read(libraryProvider.notifier).refreshLibrary(),
          ),
        );

      case LibraryStatus.loaded:
        final comics = state.displayComics;
        if (comics.isEmpty) {
          return SliverFillRemaining(
            child: EmptyState(
              title: state.searchQuery.isNotEmpty
                  ? 'No results for "${state.searchQuery}"'
                  : state.showFavoritesOnly
                      ? 'No favorites yet'
                      : "You're all caught up!",
              subtitle: state.searchQuery.isNotEmpty
                  ? 'Try a different search term.'
                  : state.showFavoritesOnly
                      ? 'Long-press a comic to add it to favorites.'
                      : 'Add more comics to your folder and refresh.',
              icon: state.showFavoritesOnly
                  ? Icons.favorite_border_rounded
                  : Icons.auto_stories_outlined,
              actionLabel: state.showFavoritesOnly ? null : 'Refresh',
              onAction: state.showFavoritesOnly
                  ? null
                  : () => ref.read(libraryProvider.notifier).refreshLibrary(),
            ),
          );
        }

        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          sliver: AnimationLimiter(
            child: SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 0.58,
                crossAxisSpacing: 12,
                mainAxisSpacing: 16,
              ),
              itemCount: comics.length,
              itemBuilder: (ctx, i) =>
                  AnimationConfiguration.staggeredGrid(
                position: i,
                columnCount: 3,
                duration: const Duration(milliseconds: 400),
                child: ScaleAnimation(
                  scale: 0.85,
                  child: FadeInAnimation(
                    child: ComicCard(comic: comics[i], index: i),
                  ),
                ),
              ),
            ),
          ),
        );
    }
  }
}

// ── Search field ──────────────────────────────────────────────────────────────
class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClose;

  const _SearchField({
    required this.controller,
    required this.onChanged,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      autofocus: true,
      decoration: InputDecoration(
        hintText: 'Search comics…',
        border: InputBorder.none,
        suffixIcon: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: onClose,
        ),
      ),
    );
  }
}
