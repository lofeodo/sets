import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/workouts_provider.dart';
import '../ui/confirm_destructive_sheet.dart';
import '../screens/workout_creation_screen.dart';

class WorkoutSwipeTile extends ConsumerStatefulWidget {
  static const double editTrigger = 0.2;
  static const double deleteTrigger = 0.3;
  static const double fadeWindow = 0.07;

  final dynamic workout;
  final VoidCallback onOpenDetails;

  const WorkoutSwipeTile({
    super.key,
    required this.workout,
    required this.onOpenDetails,
  });

  @override
  ConsumerState<WorkoutSwipeTile> createState() => _WorkoutSwipeTileState();
}

class _WorkoutSwipeTileState extends ConsumerState<WorkoutSwipeTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _anim;

  double _dragDx = 0.0;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController.unbounded(vsync: this)
      ..addListener(() {
        setState(() => _dragDx = _controller.value);
      });
    _anim = const AlwaysStoppedAnimation(0.0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _snapBack() {
    _controller.animateTo(
      0.0,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final workout = widget.workout;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth <= 0 ? 1.0 : constraints.maxWidth;

        final swipeLeftPx = (-_dragDx).clamp(0.0, width);
        final frac = (swipeLeftPx / width).clamp(0.0, 1.0);

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: _busy ? null : (_) => _controller.stop(),
          onHorizontalDragUpdate: _busy
              ? null
              : (d) {
                  final next = _controller.value + d.delta.dx;
                  _controller.value = next > 0 ? 0.0 : next; // only allow left swipe
                },
          onHorizontalDragCancel: _busy ? null : _snapBack,
          onHorizontalDragEnd: _busy
              ? null
              : (_) async {
                  if (frac >= WorkoutSwipeTile.deleteTrigger) {
                    setState(() => _busy = true);
                    final ok = await showDestructiveConfirmSheet(
                      context,
                      title: 'Delete workout?',
                      message:
                          'This will remove “${workout.name}” and its configuration.',
                      confirmText: 'Delete',
                    );
                    setState(() => _busy = false);

                    if (ok) {
                      ref
                          .read(workoutsProvider.notifier)
                          .deleteWorkout(workout.name);
                      return;
                    }

                    _snapBack();
                    return;
                  }

                  if (frac >= WorkoutSwipeTile.editTrigger) {
                    setState(() => _busy = true);
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            WorkoutCreationScreen(initialWorkout: workout),
                      ),
                    );
                    setState(() => _busy = false);
                    _snapBack();
                    return;
                  }

                  _snapBack();
                },
          child: Stack(
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: ClipRect(
                    child: Align(
                      alignment: Alignment.centerRight,
                      widthFactor: frac, // reveal from the right as you swipe left
                      child: _SwipeBackground(progress: frac),
                    ),
                  ),
                ),
              ),
              Transform.translate(
                offset: Offset(_dragDx, 0),
                child: Material(
                  color: Theme.of(context).colorScheme.surface,
                  child: ListTile(
                    title: Text(workout.name),
                    subtitle: Text('${workout.exercises.length} exercises'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _busy ? null : widget.onOpenDetails,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SwipeBackground extends StatelessWidget {
  final double progress;

  const _SwipeBackground({required this.progress});

  @override
  Widget build(BuildContext context) {
    final t = WorkoutSwipeTile.deleteTrigger;
    final w = WorkoutSwipeTile.fadeWindow;

    // Crossfade only inside [t - w, t + w]
    final x = ((progress - (t - w)) / (2 * w)).clamp(0.0, 1.0);

    // Keep edit fully opaque until close to delete threshold
    final editOpacity = (1.0 - x);
    final deleteOpacity = x;

    return Container(
      alignment: Alignment.centerRight,
      child: Stack(
        alignment: Alignment.centerRight,
        children: [
          Opacity(
            opacity: deleteOpacity,
            child: _ActionTile(
              icon: Icons.delete_outline,
              label: 'Delete',
              background: Theme.of(context).colorScheme.errorContainer,
              foreground: Theme.of(context).colorScheme.onErrorContainer,
            ),
          ),
          Opacity(
            opacity: editOpacity,
            child: _ActionTile(
              icon: Icons.edit,
              label: 'Edit',
              background: Theme.of(context).colorScheme.secondaryContainer,
              foreground: Theme.of(context).colorScheme.onSecondaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color background;
  final Color foreground;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.background,
    required this.foreground,
  });

  static const double _outerInset = 6; // space from row edges

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final rowH = constraints.maxHeight;
          final size = (rowH - 2 * _outerInset).clamp(0.0, rowH);

          return Container(
            width: size,
            height: size,
            margin: const EdgeInsets.all(_outerInset),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: foreground),
                const SizedBox(height: 4),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: foreground,
                      ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}