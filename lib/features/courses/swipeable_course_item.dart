import 'package:flutter/material.dart';

class SwipeableCourseItem extends StatefulWidget {
  final Widget child;
  final Future<bool> Function() confirmDelete;
  final VoidCallback onDelete;

  const SwipeableCourseItem({
    super.key,
    required this.child,
    required this.confirmDelete,
    required this.onDelete,
  });

  @override
  State<SwipeableCourseItem> createState() => _SwipeableCourseItemState();
}

class _SwipeableCourseItemState extends State<SwipeableCourseItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  double _dragOffset = 0.0;
  bool _isDialogShown = false;
  
  // The threshold triggers the dialog (fraction of width)
  static const double _kTriggerThreshold = 0.5;

  Animation<double>? _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _controller.addListener(() {
      if (_animation != null) {
        setState(() {
          _dragOffset = _animation!.value;
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleHorizontalDragUpdate(DragUpdateDetails details) {
    if (_controller.isAnimating || _isDialogShown) return;
    
    setState(() {
       _dragOffset += details.primaryDelta!;
       
       // Limit dragging to max distance (same as threshold for this logic)
       final maxW = MediaQuery.of(context).size.width * _kTriggerThreshold;
       _dragOffset = _dragOffset.clamp(-maxW, maxW);
       
       if (_dragOffset.abs() >= maxW && !_isDialogShown) {
          _showDeleteDialog();
       }
    });
  }
  
  void _showDeleteDialog() async {
    _isDialogShown = true;
    // Optional: Add HapticFeedback here if desired, e.g. HapticFeedback.mediumImpact();
    
    // We pause drag interaction while dialog is open essentially by the check in handleUpdate
    final ok = await widget.confirmDelete();
    
    if (!mounted) return;

    if (ok) {
        widget.onDelete();
        // Don't reset _isDialogShown or offset, card acts as deleted/dismissed
    } else {
       // Reset
       _runAnimationTo(0.0);
       _isDialogShown = false;
    }
  }

  void _handleHorizontalDragEnd(DragEndDetails details) {
     if (_isDialogShown) return; // Dialog is handling it or cancelling
     
     // If we released and didn't trigger, snap back
     _runAnimationTo(0.0);
  }

  void _runAnimationTo(double target) {
    _animation = Tween<double>(begin: _dragOffset, end: target).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    
    _controller.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    // Opacity
    final maxDist = screenWidth * _kTriggerThreshold;
    final double opacity = (_dragOffset.abs() / (maxDist * 0.2)).clamp(0.0, 1.0);
    
    Widget binIcon = Opacity(
        opacity: opacity,
        child: Container(
             width: 48, height: 48,
             alignment: Alignment.center,
             decoration: BoxDecoration(
               color: Colors.red.withValues(alpha: 0.1),
               shape: BoxShape.circle,
             ),
             child: const Icon(Icons.delete, color: Colors.red),
        ),
    );

    return GestureDetector(
      onHorizontalDragUpdate: _handleHorizontalDragUpdate,
      onHorizontalDragEnd: _handleHorizontalDragEnd,
      child: Stack(
        children: [
          // Background
          Positioned.fill(
              child: Stack(
                 children: [
                    if (_dragOffset > 0) // Swiping right, icon on the left
                      Positioned(
                          left: (_dragOffset / 2) - 24, // Parallax center: width/2 - iconHalf
                          top: 0, bottom: 0,
                          width: 48,
                          child: Center(child: binIcon),
                      ),
                    if (_dragOffset < 0) // Swiping left, icon on the right
                       Positioned(
                          right: (_dragOffset.abs() / 2) - 24, // Parallax center
                          top: 0, bottom: 0,
                          width: 48,
                          child: Center(child: binIcon),
                       ),
                 ],
              ),
          ),
          
          // Foreground
          Transform.translate(
            offset: Offset(_dragOffset, 0),
            child: Material(
               color: Colors.transparent, 
               child: widget.child,
            ),
          ),
        ],
      ),
    );
  }
}
