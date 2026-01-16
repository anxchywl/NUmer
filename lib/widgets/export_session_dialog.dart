
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../models.dart';
import '../l10n/app_localizations.dart';
import '../services/export_service.dart';
import '../services/storage.dart';
import 'app_toast.dart';
import 'package:intl/intl.dart';

class ExportSessionSheet extends StatefulWidget {
  const ExportSessionSheet({super.key});

  @override
  State<ExportSessionSheet> createState() => _ExportSessionSheetState();
}

class _ExportSessionSheetState extends State<ExportSessionSheet> {
  late PageController _pageCtrl;
  int _index = 0;
  late DateTime _selectedMonth;
  bool _isExporting = false;
  int _countdown = 0;
  Timer? _timer;
  bool _isSuccess = false;
  String? _filePath;
  int _sessionCount = 0;
  bool _isLoadingCount = false;
  
  // Items for the carousel: null represents "All Courses", otherwise Course object
  late List<Course?> _carouselItems;

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController(viewportFraction: 0.6); // Adjusted for visibility
    final state = context.read<AppState>();
    final now = DateTime.now();
    _selectedMonth = Storage.getLastExportMonth() ?? DateTime(now.year, now.month);
    
    // Ensure default is within limits
    final earliest = DateTime(2025, 1);
    final latest = DateTime(now.year, now.month + 1);
    if (_selectedMonth.isBefore(earliest)) _selectedMonth = earliest;
    if (_selectedMonth.isAfter(latest)) _selectedMonth = latest;

    _carouselItems = [null, ...state.courses];
    _loadSessionCount();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    final remaining = ExportService.remainingCooldownSeconds;
    if (remaining == 0) {
      _export();
      return;
    }

    setState(() {
      _isExporting = true;
      _countdown = remaining;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 1) {
        setState(() {
          _countdown--;
        });
      } else {
        timer.cancel();
        _export();
      }
    });
  }

  void _cancelCountdown() {
    _timer?.cancel();
    setState(() {
      _isExporting = false;
      _countdown = 0;
    });
  }

  Future<void> _export() async {
    ExportService.markExportStarted();
    setState(() {
      _isExporting = true;
      _countdown = 0;
    });

    try {
      final l10n = AppLocalizations.of(context)!;
      final state = context.read<AppState>();
      final startOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month);
      final endOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1);

      // Prepare course names map
      final courseNames = {
        for (var c in state.courses) c.id: c.name
      };
      
      final selectedItem = _carouselItems[_index];
      final String? selectedCourseId = selectedItem?.id;
      
      final exportTitle = selectedCourseId == null 
          ? l10n.allCourses
          : (courseNames[selectedCourseId] ?? l10n.courseFallback);

      final path = await ExportService.exportSessionsToCalendar(
        courseId: selectedCourseId,
        exportTitle: exportTitle,
        sinceDate: startOfMonth,
        untilDate: endOfMonth,
        courseNames: courseNames,
        studiedLabel: l10n.studiedLabel,
      );

      if (mounted) {
        setState(() {
          _isSuccess = true;
          _filePath = path;
        });
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        final err = e.toString().replaceAll("Exception: ", "");
        showAppMessage(
          context,
          l10n.exportFailedMessage(err),
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Future<void> _loadSessionCount() async {
    if (!mounted) return;
    setState(() => _isLoadingCount = true);
    try {
      final allSessions = await Storage.getSessions();
      final startOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month);
      final endOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
      final selectedItem = _carouselItems[_index];
      final String? selectedCourseId = selectedItem?.id;

      final count = allSessions.where((s) {
        if (selectedCourseId != null && s['courseId'] != selectedCourseId) return false;
        final start = s['startUtc'] as DateTime;
        return (start.isAtSameMomentAs(startOfMonth) || start.isAfter(startOfMonth)) && start.isBefore(endOfMonth) && (s['seconds'] as int) > 0;
      }).length;

      if (mounted) {
        setState(() {
          _sessionCount = count;
          _isLoadingCount = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingCount = false);
      }
    }
  }

  String _getDisplayPath(String? fullPath) {
    if (fullPath == null) return '';
    final path = fullPath.replaceAll('\\', '/');
    final fileName = path.split('/').last;

    // Detect Downloads folder (common on Android/macOS)
    if (path.toLowerCase().contains('/download/') || path.toLowerCase().contains('/downloads/')) {
      return 'Downloads/$fileName';
    }

    // Detect Documents folder (common on iOS)
    if (path.toLowerCase().contains('/documents/')) {
      return 'Documents/$fileName';
    }

    // Default fallback
    if (path.length > 40) {
      return fileName;
    }

    return path;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    
    return Material(
      color: scheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.onSurfaceVariant.withAlpha((0.4 * 255).round()),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),

              Text(
                l10n.exportToCalendar,
                style: theme.textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              AnimatedSwitcher(
                duration: const Duration(milliseconds: 500),
                layoutBuilder: (currentChild, previousChildren) {
                  return Stack(
                    alignment: Alignment.topCenter,
                    children: <Widget>[
                      ...previousChildren,
                      if (currentChild != null) currentChild,
                    ],
                  );
                },
                transitionBuilder: (child, animation) {
                  final isIncoming = child.key == ValueKey(_isSuccess);
                  
                  final offset = isIncoming 
                    ? Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic))
                    : Tween<Offset>(begin: const Offset(0, -0.2), end: Offset.zero).animate(CurvedAnimation(parent: animation, curve: Curves.easeInCubic));
                  
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: offset,
                      child: child,
                    ),
                  );
                },
                child: _isSuccess 
                ? _buildInstructions(l10n, theme, scheme)
                : _buildSelectors(l10n, theme, scheme),
              ),

              const SizedBox(height: 32),

              // Actions
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isSuccess 
                    ? () => Navigator.pop(context) 
                    : (_isExporting 
                        ? (_countdown > 0 ? _cancelCountdown : null) 
                        : _startCountdown),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: _isExporting 
                    ? (_countdown > 0 
                        ? const Icon(Icons.close, color: Colors.white)
                        : const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))) 
                    : Icon(_isSuccess ? Icons.check_circle_outline : Icons.download_rounded),
                  label: Text(
                    _isExporting
                        ? (_countdown > 0 ? l10n.cancel : l10n.exporting)
                        : (_isSuccess ? l10n.done : l10n.export),
                  ),
                ),
              ),
              if (_isExporting && _countdown > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    l10n.exportWillStartIn(_countdown),
                    style: theme.textTheme.bodySmall?.copyWith(color: scheme.primary),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectors(AppLocalizations l10n, ThemeData theme, ColorScheme scheme) {
    return Column(
      key: const ValueKey(false),
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l10n.selectCourse,
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 80,
          child: PageView.builder(
            controller: _pageCtrl,
            scrollDirection: Axis.vertical,
            onPageChanged: (i) {
              setState(() => _index = i);
              _loadSessionCount();
            },
            itemCount: _carouselItems.length,
            itemBuilder: (context, i) {
              final item = _carouselItems[i];
              final selected = i == _index;
              final isAll = item == null;
              
              return AnimatedScale(
                duration: const Duration(milliseconds: 200),
                scale: selected ? 1.0 : 0.9,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: selected ? 1.0 : 0.5,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: selected
                            ? scheme.primary
                            : scheme.outlineVariant.withAlpha(100),
                        width: selected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: isAll ? scheme.primary : item.color,
                          child: isAll 
                            ? const Icon(Icons.all_inclusive, size: 14, color: Colors.white)
                            : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            isAll ? l10n.allCourses : item.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                              color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        if (selected)
                          Icon(Icons.check_circle, size: 18, color: scheme.primary),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Divider(
            color: scheme.outlineVariant.withAlpha(100),
            thickness: 1,
          ),
        ),

        _buildMonthPicker(theme, scheme, l10n),
      ],
    );
  }

  Widget _buildMonthPicker(ThemeData theme, ColorScheme scheme, AppLocalizations l10n) {
    final now = DateTime.now();
    final earliest = DateTime(2025, 1);
    final latest = DateTime(now.year, now.month + 1);

    final monthYearStr = DateFormat('MMMM yyyy').format(_selectedMonth);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              onPressed: _selectedMonth.year <= earliest.year && _selectedMonth.month <= earliest.month
                  ? null
                  : () {
                      setState(() {
                        _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
                        Storage.setLastExportMonth(_selectedMonth);
                        _loadSessionCount();
                      });
                    },
              icon: const Icon(Icons.chevron_left),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 160,
              child: Text(
                monthYearStr,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _selectedMonth.year >= latest.year && _selectedMonth.month >= latest.month
                  ? null
                  : () {
                      setState(() {
                        _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
                        Storage.setLastExportMonth(_selectedMonth);
                        _loadSessionCount();
                      });
                    },
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        const SizedBox(height: 16),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: _isLoadingCount
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : Text(
                _sessionCount == 1 
                  ? "1 session found"
                  : "$_sessionCount sessions found",
                style: theme.textTheme.bodySmall?.copyWith(
                  color: _sessionCount > 0 ? scheme.primary : scheme.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
        ),
      ],
    );
  }

  Widget _buildInstructions(AppLocalizations l10n, ThemeData theme, ColorScheme scheme) {
    return Column(
      key: const ValueKey(true),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: scheme.primaryContainer.withAlpha(50),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: scheme.primary.withAlpha(100)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    l10n.fileSavedSuccessfully,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                l10n.fileSavedAt,
                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              SelectableText(
                _getDisplayPath(_filePath),
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          l10n.nextSteps,
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.exportCalendarNextStepsBody,
          style: theme.textTheme.bodyMedium?.copyWith(
            height: 1.5,
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
