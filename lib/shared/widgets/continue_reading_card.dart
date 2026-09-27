import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/comic.dart';
import '../../data/models/reading_progress.dart';
import '../../features/library/library_provider.dart';

class ContinueReadingCard extends ConsumerStatefulWidget {
  const ContinueReadingCard({super.key});

  @override
  ConsumerState<ContinueReadingCard> createState() =>
      _ContinueReadingCardState();
}

class _ContinueReadingCardState extends ConsumerState<ContinueReadingCard> {
  Comic? _comic;
  ReadingProgress? _progress;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prog = await ref
        .read(readingProgressProvider.notifier)
        .getMostRecent();
    if (prog == null || !mounted) {
      setState(() => _loaded = true);
      return;
    }
    final comic = await ref
        .read(comicRepositoryProvider)
        .getComic(prog.comicId);
    if (!mounted) return;
    setState(() {
      _progress = prog;
      _comic = comic;
      _loaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _comic == null || _progress == null) {
      return const SizedBox.shrink();
    }
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final comic = _comic!;
    final prog = _progress!;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Material(
        borderRadius: BorderRadius.circular(20),
        color: scheme.primaryContainer,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.pushNamed(
            'reader',
            pathParameters: {'id': comic.id},
            queryParameters: {'page': '${prog.lastPage}'},
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Thumbnail
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 56,
                    height: 78,
                    child: comic.thumbnailPath != null &&
                            File(comic.thumbnailPath!).existsSync()
                        ? Image.file(File(comic.thumbnailPath!),
                            fit: BoxFit.cover)
                        : Container(
                            color: scheme.primary.withOpacity(0.2),
                            child: Icon(Icons.menu_book_rounded,
                                color: scheme.primary),
                          ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(Icons.play_circle_filled_rounded,
                            size: 16, color: scheme.primary),
                        const SizedBox(width: 4),
                        Text('Continue Reading',
                            style: tt.labelMedium?.copyWith(
                                color: scheme.primary,
                                fontWeight: FontWeight.w700)),
                      ]),
                      const SizedBox(height: 4),
                      Text(comic.title,
                          style: tt.titleSmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 6),
                      // Progress bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: prog.progressPercent,
                          minHeight: 4,
                          backgroundColor:
                              scheme.onPrimaryContainer.withOpacity(0.15),
                          valueColor: AlwaysStoppedAnimation(scheme.primary),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Page ${prog.lastPage} of ${prog.totalPages}',
                        style: tt.bodySmall
                            ?.copyWith(color: scheme.onPrimaryContainer),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right_rounded,
                    color: scheme.onPrimaryContainer),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
