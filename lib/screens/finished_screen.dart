import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/comic.dart';

class FinishedScreen extends StatefulWidget {
  final Comic currentComic;
  final Comic? nextComic;
  final VoidCallback? onContinue;
  final VoidCallback onReturn;

  const FinishedScreen({
    super.key,
    required this.currentComic,
    this.nextComic,
    this.onContinue,
    required this.onReturn,
  });

  @override
  State<FinishedScreen> createState() => _FinishedScreenState();
}

class _FinishedScreenState extends State<FinishedScreen>
    with TickerProviderStateMixin {
  late AnimationController _entryCtrl;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _scaleAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _entryCtrl, curve: Curves.elasticOut),
    );
    _entryCtrl.forward();
    HapticFeedback.mediumImpact();
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final hasNext = widget.nextComic != null;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Stack(
        children: [
          // Background gradient orbs
          Positioned(
            top: -100,
            left: -80,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colorScheme.primary.withOpacity(0.12),
              ),
            ),
          ),
          Positioned(
            bottom: -60,
            right: -60,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colorScheme.secondary.withOpacity(0.1),
              ),
            ),
          ),

          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: ScaleTransition(
                scale: _scaleAnim,
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Spacer(),

                      // Completion icon
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              colorScheme.primary,
                              colorScheme.secondary,
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: colorScheme.primary.withOpacity(0.4),
                              blurRadius: 32,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.done_all_rounded,
                          color: colorScheme.onPrimary,
                          size: 52,
                        ),
                      ),
                      const SizedBox(height: 32),

                      Text(
                        hasNext ? 'Issue Complete!' : "You're All Caught Up!",
                        style: theme.textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        hasNext
                            ? 'Ready for the next issue?'
                            : 'You\'ve read every comic in your library. More issues coming?',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      // Next comic preview
                      if (hasNext) ...[
                        const SizedBox(height: 36),
                        _NextComicPreview(
                          comic: widget.nextComic!,
                          colorScheme: colorScheme,
                          theme: theme,
                        ),
                      ] else ...[
                        const SizedBox(height: 36),
                        _AllReadAnimation(colorScheme: colorScheme),
                      ],

                      const Spacer(),

                      // Actions
                      if (hasNext)
                        FilledButton.icon(
                          onPressed: widget.onContinue,
                          icon: const Icon(Icons.arrow_forward_rounded),
                          label: Text('Read ${widget.nextComic!.title}'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 18),
                          ),
                        ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: widget.onReturn,
                        icon: const Icon(Icons.library_books_rounded),
                        label: const Text('Back to Library'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NextComicPreview extends StatelessWidget {
  final Comic comic;
  final ColorScheme colorScheme;
  final ThemeData theme;

  const _NextComicPreview({
    required this.comic,
    required this.colorScheme,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          // Cover
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 64,
              height: 90,
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
                        size: 28,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'UP NEXT',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.primary,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  comic.title,
                  style: theme.textTheme.titleMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (comic.seriesName != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    comic.seriesName!,
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}

class _AllReadAnimation extends StatefulWidget {
  final ColorScheme colorScheme;
  const _AllReadAnimation({required this.colorScheme});

  @override
  State<_AllReadAnimation> createState() => _AllReadAnimationState();
}

class _AllReadAnimationState extends State<_AllReadAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (i) {
            final offset = ((_ctrl.value * 5) + i) % 5;
            final scale = 0.6 + (0.4 * (1 - ((offset - 2.5).abs() / 2.5)));
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Transform.scale(
                scale: scale,
                child: Icon(
                  Icons.star_rounded,
                  color: widget.colorScheme.primary.withOpacity(scale),
                  size: 28,
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
