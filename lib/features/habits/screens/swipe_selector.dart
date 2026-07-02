import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SwipeSelector<T> extends StatefulWidget {
  final List<T> items;
  final T selectedValue;
  final ValueChanged<T> onChanged;
  final Widget Function(BuildContext, T) builder;
  final Color? backgroundColor;

  const SwipeSelector({
    super.key,
    required this.items,
    required this.selectedValue,
    required this.onChanged,
    required this.builder,
    this.backgroundColor,
  });

  @override
  State<SwipeSelector<T>> createState() => _SwipeSelectorState<T>();
}

class _SwipeSelectorState<T> extends State<SwipeSelector<T>>
    with SingleTickerProviderStateMixin {
  late int _index;
  late AnimationController _anim;
  late Animation<double> _slide;
  double _slideDir = 1.0;

  @override
  void initState() {
    super.initState();
    _index = widget.items.indexOf(widget.selectedValue);
    if (_index == -1) _index = 0;
    
    _anim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 200));
    _slide = CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic);
  }
  
  @override
  void didUpdateWidget(covariant SwipeSelector<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedValue != oldWidget.selectedValue) {
       final newIndex = widget.items.indexOf(widget.selectedValue);
       if (newIndex != -1 && newIndex != _index) {
         _index = newIndex;
         // We do not animate here usually to avoid loop, 
         // but if external change happens, we update _index instantly.
       }
    }
  }

  Future<void> _change(int dir) async {
    final newIndex = (_index + dir).clamp(0, widget.items.length - 1);
    if (newIndex == _index) return;

    HapticFeedback.selectionClick();
    setState(() => _slideDir = dir.toDouble());
    await _anim.forward(from: 0);
    if (!mounted) return;
    
    setState(() => _index = newIndex);
    widget.onChanged(widget.items[_index]);
    
    if (!mounted) return;
    await _anim.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return GestureDetector(
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity > 100) _change(-1);
        if (velocity < -100) _change(1);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: widget.backgroundColor ?? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        ),
        child: SlideTransition(
          position: _slide.drive(Tween<Offset>(
            begin: Offset.zero,
            end: Offset(0.15 * -_slideDir, 0),
          )),
          child: widget.builder(context, widget.items[_index]),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }
}
