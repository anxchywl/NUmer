import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../l10n/app_localizations.dart';

class ReflectionBottomSheet extends StatefulWidget {
  final String sessionId;
  final int durationSeconds;

  const ReflectionBottomSheet({
    super.key,
    required this.sessionId,
    required this.durationSeconds,
  });

  @override
  State<ReflectionBottomSheet> createState() => _ReflectionBottomSheetState();
}

class _ReflectionBottomSheetState extends State<ReflectionBottomSheet> {
  final TextEditingController _controller = TextEditingController();
  bool _isSaving = false;

  String get _durationString {
    final d = Duration(seconds: widget.durationSeconds);
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final l10n = AppLocalizations.of(context)!;
    if (h > 0) {
      return '$h ${l10n.hour} $m ${l10n.minute}';
    } else {
      return '$m ${l10n.minute}';
    }
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      await context.read<AppState>().saveSessionNotes(
            id: widget.sessionId,
            notes: _controller.text,
          );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.failedToSaveReflection(e.toString()))),
        );
      }
    }
  }

  void _skip() {
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    
    
    
    
    
    
    

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            AppLocalizations.of(context)!.sessionFinished(_durationString),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
            TextField(
              controller: _controller,
              autofocus: true,
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context)!.whatDidYouWorkOn,
                border: const OutlineInputBorder(),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
              minLines: 1,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              inputFormatters: [
                LengthLimitingTextInputFormatter(160),
                FilteringTextInputFormatter.allow(
                  RegExp(r'[\p{L}\p{N}]', unicode: true),
                ),
              ],
            ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _skip,
                child: Text(AppLocalizations.of(context)!.skip),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _isSaving ? null : _save,
                child: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(AppLocalizations.of(context)!.save),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
