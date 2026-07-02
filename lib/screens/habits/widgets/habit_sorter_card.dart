import 'package:flutter/material.dart';
import 'package:numer_app/models/habit.dart';
import 'package:numer_app/l10n/app_localizations.dart';

/// Single habit card shown one at a time during sorting phase
/// Animates in when appearing, animates out when placed
class HabitSorterCard extends StatefulWidget {
  const HabitSorterCard({
    super.key,
    required this.habit,
    required this.onPlaced,
  });

  final Habit habit;
  final VoidCallback onPlaced;

  @override
  State<HabitSorterCard> createState() => _HabitSorterCardState();
}

class _HabitSorterCardState extends State<HabitSorterCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    // Animate in
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(HabitSorterCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.habit.id != widget.habit.id) {
      // New habit - animate in
      _controller.reset();
      _controller.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final habitColor = widget.habit.color;

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: LongPressDraggable<Habit>(
            data: widget.habit,
            onDragEnd: (details) {
              if (details.wasAccepted) {
                // Animate out then notify
                _controller.reverse().then((_) => widget.onPlaced());
              }
            },
            feedback: Transform.scale(
              scale: 0.95,
              child: Material(
                elevation: 12,
                borderRadius: BorderRadius.circular(16), // Match container radius
                color: Colors.transparent, 
                child: _buildCardContent(theme, habitColor, isDragging: true),
              ),
            ),
            childWhenDragging: Opacity(
              opacity: 0.3,
              child: _buildCardContent(theme, habitColor),
            ),
            child: _buildCardContent(theme, habitColor),
          ),
        ),
      ),
    );
  }

  Widget _buildCardContent(ThemeData theme, Color habitColor, {bool isDragging = false}) {
    return Container(
      width: isDragging ? MediaQuery.of(context).size.width - 32 : null,
      height: 70, // Compact height matching calendar strip area approx
      margin: isDragging ? null : const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDragging ? habitColor : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDragging ? habitColor : theme.colorScheme.outlineVariant.withAlpha(50),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDragging ? 50 : 10),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Drag Indicator
          Icon(
            Icons.drag_indicator_rounded,
            color: isDragging ? Colors.white.withAlpha(200) : theme.colorScheme.onSurfaceVariant.withAlpha(100),
            size: 20,
          ),
          const SizedBox(width: 12),
          
          // Icon
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDragging ? Colors.white.withAlpha(40) : habitColor.withAlpha(30),
              shape: BoxShape.circle,
            ),
            child: Icon(
              IconData(widget.habit.iconCodePoint, fontFamily: 'MaterialIcons'),
              color: isDragging ? Colors.white : habitColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          
          // Text Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  widget.habit.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: isDragging ? Colors.white : theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  AppLocalizations.of(context)!.habitDragToCategorize,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDragging ? Colors.white.withAlpha(180) : theme.colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
