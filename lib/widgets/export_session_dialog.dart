
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../models.dart';
import '../l10n/app_localizations.dart';
import '../services/export_service.dart';
import 'app_toast.dart';

class ExportSessionSheet extends StatefulWidget {
  const ExportSessionSheet({super.key});

  @override
  State<ExportSessionSheet> createState() => _ExportSessionSheetState();
}

class _ExportSessionSheetState extends State<ExportSessionSheet> {
  late PageController _pageCtrl;
  int _index = 0;
  int _selectedMonths = 1;
  bool _isExporting = false;
  bool _isSuccess = false;
  String? _filePath;
  
  // Items for the carousel: null represents "All Courses", otherwise Course object
  late List<Course?> _carouselItems;

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController(viewportFraction: 0.6); // Adjusted for visibility
    
    final state = context.read<AppState>();
    // Prepend "All Courses" (null) to the list of courses
    _carouselItems = [null, ...state.courses];
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  Future<void> _export() async {
    setState(() => _isExporting = true);

    try {
      final l10n = AppLocalizations.of(context)!;
      final state = context.read<AppState>();
      final now = DateTime.now();
      final sinceDate = DateTime(
        now.year,
        now.month - _selectedMonths,
        now.day,
      );

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
        sinceDate: sinceDate,
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    
    final oneMonth = l10n.oneMonth; 
    final threeMonths = l10n.threeMonths; 
    final sixMonths = l10n.sixMonths; 

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
                : _buildSelectors(l10n, theme, scheme, oneMonth, threeMonths, sixMonths),
              ),

              const SizedBox(height: 32),

              // Actions
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isExporting ? null : (_isSuccess ? () => Navigator.pop(context) : _export),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: _isExporting 
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)) 
                    : Icon(_isSuccess ? Icons.check_circle_outline : Icons.download_rounded),
                  label: Text(
                    _isExporting
                        ? l10n.exporting
                        : (_isSuccess ? l10n.done : l10n.export),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectors(AppLocalizations l10n, ThemeData theme, ColorScheme scheme, String oneMonth, String threeMonths, String sixMonths) {
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
            onPageChanged: (i) => setState(() => _index = i),
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
        
        const SizedBox(height: 24),

        Text(
          l10n.timePeriod,
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<int>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: 1, label: Text(oneMonth)),
              ButtonSegment(value: 3, label: Text(threeMonths)),
              ButtonSegment(value: 6, label: Text(sixMonths)),
            ],
            selected: {_selectedMonths},
            onSelectionChanged: (newSelection) {
              setState(() {
                _selectedMonths = newSelection.first;
              });
            },
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              side: WidgetStateProperty.resolveWith<BorderSide>((states) {
                 if (states.contains(WidgetState.selected)) {
                   return BorderSide(color: scheme.primary);
                 }
                 return BorderSide(color: scheme.outlineVariant);
              }),
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
                  Icon(Icons.file_download_done, color: scheme.primary),
                  const SizedBox(width: 8),
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
                _filePath ?? l10n.unknownPath,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                  color: scheme.onSurfaceVariant,
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
