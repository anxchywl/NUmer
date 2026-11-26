import 'package:flutter/material.dart';
import 'package:numer_app/l10n/app_localizations.dart';

// lightbulb button that toggles a floating help bubble anchored to itself
class TipIcon extends StatefulWidget {
  final String title;
  final String message;

  const TipIcon({super.key, required this.title, required this.message});

  @override
  State<TipIcon> createState() => _TipIconState();
}

class _TipIconState extends State<TipIcon> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  void _toggleTip() {
    if (_overlayEntry != null) {
      _hideTip();
    } else {
      _showTip();
    }
  }

  void _showTip() {
    setState(() {
      _overlayEntry = _createOverlayEntry();
    });
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideTip() {
    if (_overlayEntry == null) return;
    _overlayEntry?.remove();
    setState(() {
      _overlayEntry = null;
    });
  }

  // builds the help bubble overlay, positioned relative to the icon and
  // dismissed on a tap outside its shared tap region
  OverlayEntry _createOverlayEntry() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return OverlayEntry(
      builder: (context) => Stack(
        children: [
          CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            offset: const Offset(-240, 40),
            child: Material(
              color: Colors.transparent,
              child: TapRegion(
                groupId: 'tip_icon_region',
                onTapOutside: (_) => _hideTip(),
                child: Container(
                  width: 280,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(20),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    border: Border.all(
                      color: colorScheme.outlineVariant.withAlpha(100),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              widget.title,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.primary,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: _hideTip,
                            child: Icon(
                              Icons.close,
                              size: 16,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.message,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface,
                        ),
                      ),
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

  @override
  void dispose() {
    _hideTip();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isActive = _overlayEntry != null;
    final activeColor = theme.colorScheme.primary;
    final normalColor = theme.colorScheme.onSurfaceVariant;

    return CompositedTransformTarget(
      link: _layerLink,
      child: TapRegion(
        groupId: 'tip_icon_region',
        child: IconButton(
          icon: TweenAnimationBuilder<Color?>(
            duration: const Duration(milliseconds: 300),
            tween: ColorTween(
              begin: isActive ? normalColor : activeColor,
              end: isActive ? activeColor : normalColor,
            ),
            builder: (context, color, child) {
              return Icon(
                isActive ? Icons.lightbulb : Icons.lightbulb_outline,
                color: color,
              );
            },
          ),
          tooltip: AppLocalizations.of(context)!.tip,
          onPressed: _toggleTip,
        ),
      ),
    );
  }
}
