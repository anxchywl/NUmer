import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:numer_app/l10n/app_localizations.dart';

class HoldToConfirmButton extends StatefulWidget {
  const HoldToConfirmButton({
    super.key,
    required this.label,
    required this.onConfirmed,
    this.holdDuration = const Duration(seconds: 5),
    this.backgroundColor,
    this.fillColor,
    this.textColor,
  });

  final String label;
  final VoidCallback onConfirmed;
  final Duration holdDuration;
  final Color? backgroundColor;
  final Color? fillColor;
  final Color? textColor;

  @override
  State<HoldToConfirmButton> createState() => _HoldToConfirmButtonState();
}

class _HoldToConfirmButtonState extends State<HoldToConfirmButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _confirmed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.holdDuration,
    );
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && !_confirmed) {
        _confirmed = true;
        HapticFeedback.mediumImpact();
        widget.onConfirmed();
      }
    });
  }

  @override
  void didUpdateWidget(covariant HoldToConfirmButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.holdDuration != widget.holdDuration) {
      _controller.duration = widget.holdDuration;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _startHold() {
    if (_confirmed) return;
    _controller.forward(from: _controller.value);
  }

  void _cancelHold() {
    if (_confirmed) return;
    _controller.animateBack(
      0,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final backgroundColor = widget.backgroundColor ?? scheme.errorContainer;
    final textColor = widget.textColor ?? scheme.onError;
    final radius = BorderRadius.circular(12);

    return Material(
      color: Colors.transparent,
      borderRadius: radius,
      child: InkWell(
        onTapDown: _confirmed ? null : (_) => _startHold(),
        onTapUp: _confirmed ? null : (_) => _cancelHold(),
        onTapCancel: _confirmed ? null : _cancelHold,
        borderRadius: radius,
        child: SizedBox(
          height: 44,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final background =
                  Color.lerp(
                    backgroundColor,
                    Colors.white,
                    _controller.value,
                  ) ??
                  backgroundColor;
              return DecoratedBox(
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: radius,
                ),
                child: child,
              );
            },
            child: Center(
              child: IconTheme(
                data: IconThemeData(color: textColor, size: 18),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.delete_forever),
                    const SizedBox(width: 6),
                    Text(
                      widget.label,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: textColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class DeleteAccountTextConfirmDialog extends StatefulWidget {
  const DeleteAccountTextConfirmDialog({super.key});

  @override
  State<DeleteAccountTextConfirmDialog> createState() =>
      _DeleteAccountTextConfirmDialogState();
}

class _DeleteAccountTextConfirmDialogState
    extends State<DeleteAccountTextConfirmDialog> {
  final _controller = TextEditingController();
  static const _requiredPhrase = 'I really want to delete my account';
  bool _isValid = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final valid = _controller.text.trim() == _requiredPhrase;
      if (valid != _isValid) {
        setState(() => _isValid = valid);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return AlertDialog(
      icon: Icon(Icons.warning_amber_rounded, color: scheme.error, size: 40),
      title: const Text('Final Confirmation'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'To confirm deletion, please type:',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: scheme.errorContainer.withAlpha(100),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: scheme.error.withAlpha(100)),
            ),
            child: SelectableText(
              _requiredPhrase,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: scheme.error,
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Type the phrase above',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              errorText: _controller.text.isNotEmpty && !_isValid
                  ? 'Phrase does not match'
                  : null,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _isValid ? () => Navigator.pop(context, true) : null,
          style: FilledButton.styleFrom(
            backgroundColor: scheme.error,
            foregroundColor: scheme.onError,
          ),
          child: const Text('Delete Forever'),
        ),
      ],
    );
  }
}
