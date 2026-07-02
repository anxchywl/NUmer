import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import 'package:numer_app/app/app_state.dart';
import 'package:numer_app/features/courses/course.dart';
import 'package:numer_app/features/ai_analysis/ai_analysis_service.dart';
import 'package:numer_app/core/data/storage.dart';
import 'package:numer_app/l10n/app_localizations.dart';

class AiAnalysisScreen extends StatefulWidget {
  const AiAnalysisScreen({super.key});

  @override
  State<AiAnalysisScreen> createState() => _AiAnalysisScreenState();
}

class _AiAnalysisScreenState extends State<AiAnalysisScreen> {
  static final Map<String, AiCourseAnalysis> _memoryAnalysisCache = {};

  String? _selectedCourseId;
  AnalysisPeriod _selectedPeriod = AnalysisPeriod.lastMonth;
  bool _isLoading = false;
  // New state variables
  int _notesCount = 0;
  bool _isLimitReached = false;
  bool _isChecking = false;
  int _remainingDays = 0;
  
  AiCourseAnalysis? _analysis;
  
  final ScrollController _scrollController = ScrollController();
  bool _headerCollapsed = false;
  bool _selectionInitScheduled = false;

  void _scrollToBottom({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final target = _scrollController.position.maxScrollExtent;
      if (animated) {
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOut,
        );
      } else {
        _scrollController.jumpTo(target);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState = Provider.of<AppState>(context, listen: false);
      if (appState.courses.isNotEmpty) {
        setState(() {
          _selectedCourseId = appState.courses.first.id;
        });
        _fetchStatus();
      }
    });
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    final collapse = _scrollController.offset > 12;
    if (collapse == _headerCollapsed) return;
    if (!mounted) return;
    setState(() => _headerCollapsed = collapse);
  }

  Future<void> _fetchStatus() async {
    if (_selectedCourseId == null) {
      if (mounted) {
        setState(() => _isChecking = false);
      }
      return;
    }
    setState(() => _isChecking = true);

    final courseId = _selectedCourseId!;
    final period = _selectedPeriod;
    final cacheKey = '${courseId}_${period.months}m';
    try {
      // Keep analysis only in memory while app process is alive.
      final inMemory = _memoryAnalysisCache[cacheKey];
      final lastTs = await Storage.getLastAnalysisTimestamp(courseId, period.months);
      final lastAnalysisDate =
          lastTs != null ? DateTime.fromMillisecondsSinceEpoch(lastTs) : null;
      final nextAvailableAt = _nextAvailableDate(lastAnalysisDate, period);
      final limitReached =
          nextAvailableAt != null && DateTime.now().isBefore(nextAvailableAt);

      if (mounted && _selectedCourseId == courseId && _selectedPeriod == period) {
        setState(() {
          _analysis = inMemory;
          _isLimitReached = limitReached;
          _remainingDays = _calculateRemainingDays(nextAvailableAt);
          _isChecking = false;
        });
      }

      // Fetch notes after cooldown state is already visible.
      final reflections = await AiAnalysisService.fetchReflections(
        courseId,
        period,
        since: lastAnalysisDate,
      ).timeout(const Duration(seconds: 8));
      final count = reflections.where((r) {
        final comment = r['comment'] as String?;
        return comment != null && comment.trim().isNotEmpty;
      }).length;

      if (mounted && _selectedCourseId == courseId && _selectedPeriod == period) {
        setState(() {
          _notesCount = count;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isChecking = false);
      }
    }
  }

  void _ensureSelectionFromCourses(List<Course> courses) {
    if (courses.isEmpty) return;
    final selected = _selectedCourseId;
    final selectedExists = selected != null && courses.any((c) => c.id == selected);
    if (selectedExists || _selectionInitScheduled) return;
    _selectionInitScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _selectionInitScheduled = false;
      if (!mounted) return;
      final current = _selectedCourseId;
      final existsNow = current != null && courses.any((c) => c.id == current);
      if (existsNow) return;
      setState(() {
        _selectedCourseId = courses.first.id;
      });
      _fetchStatus();
    });
  }

  DateTime? _nextAvailableDate(DateTime? last, AnalysisPeriod period) {
    if (last == null) return null;
    final monthsToAdd = period.months;
    final monthIndex = last.month - 1 + monthsToAdd;
    final year = last.year + (monthIndex ~/ 12);
    final month = (monthIndex % 12) + 1;
    final maxDay = DateTime(year, month + 1, 0).day;
    final day = math.min(last.day, maxDay);
    return DateTime(
      year,
      month,
      day,
      last.hour,
      last.minute,
      last.second,
      last.millisecond,
      last.microsecond,
    );
  }

  int _calculateRemainingDays(DateTime? nextAvailableAt) {
    if (nextAvailableAt == null) return 0;
    final now = DateTime.now();
    if (!nextAvailableAt.isAfter(now)) return 0;
    final seconds = nextAvailableAt.difference(now).inSeconds;
    return (seconds / Duration.secondsPerDay).ceil();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _runAnalysis() async {
    if (_selectedCourseId == null) return;

    setState(() {
      _isLoading = true;
      _analysis = null;
    });

    try {
      final appState = Provider.of<AppState>(context, listen: false);
      final course =
          appState.courses.firstWhere((c) => c.id == _selectedCourseId);

      final locale = Localizations.localeOf(context);
      final languageCode = locale.languageCode;

      final result = await AiAnalysisService.analyzeCourse(
          _selectedCourseId!, course.name, _selectedPeriod, language: languageCode);
      
      // Save only cooldown timestamp. Analysis body is memory-only.
      await Storage.setLastAnalysisTimestamp(
          _selectedCourseId!, _selectedPeriod.months, DateTime.now().millisecondsSinceEpoch);
      final cacheKey = '${_selectedCourseId!}_${_selectedPeriod.months}m';
      _memoryAnalysisCache[cacheKey] = result;

      if (mounted) {
        setState(() {
          _analysis = result;
        });
        _scrollToBottom();
        // Refresh status to update limit & button state
        _fetchStatus();
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final courses = appState.courses;
    final isIos = Theme.of(context).platform == TargetPlatform.iOS;
    _ensureSelectionFromCourses(courses);
    
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              height: _headerCollapsed ? 0 : kToolbarHeight,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 140),
                opacity: _headerCollapsed ? 0 : 1,
                child: Row(
                  children: [
                    SizedBox(
                      width: 52,
                      child: isIos
                          ? IconButton(
                              onPressed: () => Navigator.of(context).maybePop(),
                              color: Theme.of(context).colorScheme.primary,
                              icon: const Icon(Icons.arrow_back_ios_new_rounded),
                              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                            )
                          : const SizedBox.shrink(),
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          AppLocalizations.of(context)!.courseAnalysis,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 52),
                  ],
                ),
              ),
            ),
            Expanded(
              child: courses.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                   Icon(Icons.analytics_outlined, size: 64, color: Theme.of(context).colorScheme.outline),
                   const SizedBox(height: 16),
                   Text(AppLocalizations.of(context)!.noCoursesAvailable, style: Theme.of(context).textTheme.bodyLarge),
                ],
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        
                        _buildControls(courses),
                        const SizedBox(height: 24),

                        // Button Section
                        _buildGenerateButton(),
                        
                        const SizedBox(height: 32),

                        
                        if (_analysis != null)
                          _buildAnalysisResults(_analysis!)
                        else if (!_isLoading && !_isLimitReached)
                          _buildEmptyPlaceholder(),
                      ],
                    ),
                  ),
                ),
                
                // Limit info fixed at bottom
                if (!_isChecking && !_isLimitReached)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      border: Border(
                        top: BorderSide(
                          color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.info_outline, size: 14, color: Theme.of(context).colorScheme.outline),
                            const SizedBox(width: 6),
                            Text(
                              AppLocalizations.of(context)!.limitOneAnalysisPerPeriod,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.outline,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'We do not store your analysis data.\nPlease save it yourself if you need.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                            fontSize: 10,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenerateButton() {
    final l10n = AppLocalizations.of(context)!;
    final notesRequirementMet = _notesCount >= 20;
    final canGenerate = !_isLoading && !_isChecking && !_isLimitReached && notesRequirementMet;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: canGenerate ? _runAnalysis : null,
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor: canGenerate ? null : Colors.grey,
            foregroundColor: canGenerate ? null : Colors.white70,
          ),
          icon: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Icon(Icons.auto_awesome),
          label: Text(_isLoading ? l10n.analyzing : l10n.generateInsight),
        ),
        const SizedBox(height: 12),
        // Status Helpers
        if (_isLimitReached)
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              'Next analysis available in $_remainingDays ${_remainingDays == 1 ? 'day' : 'days'}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.outline,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        if (!notesRequirementMet)
          Text(
             _formatNotesRequirement(l10n.minNotesRequired(_notesCount, 20)),
             textAlign: TextAlign.center,
             style: Theme.of(context).textTheme.bodySmall?.copyWith(
               color: Theme.of(context).colorScheme.outline,
             ),
          )
        else
          Text(
             _formatNotesRequirement(l10n.minNotesRequired(_notesCount, 20)),
             textAlign: TextAlign.center,
             style: Theme.of(context).textTheme.bodySmall?.copyWith(
               color: Theme.of(context).colorScheme.primary,
               fontWeight: FontWeight.bold,
             ),
          ),
      ],
    );
  }

  String _formatNotesRequirement(String text) {
    // Keep the "More notes give better insights." clause on a second line.
    return text.replaceFirst('. ', '.\n');
  }

  Widget _buildControls(List<Course> courses) {
    final l10n = AppLocalizations.of(context)!;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.selectCourse,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 50,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: courses.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final course = courses[index];
              final isSelected = course.id == _selectedCourseId;
              return ChoiceChip(
                label: Text(course.name),
                selected: isSelected,
                avatar: CircleAvatar(
                  radius: 8,
                  backgroundColor: course.color,
                ),
                selectedColor: Theme.of(context).colorScheme.secondaryContainer,
                labelStyle: TextStyle(
                  color: isSelected 
                    ? Theme.of(context).colorScheme.onSecondaryContainer 
                    : Theme.of(context).colorScheme.onSurface,
                ),
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      _selectedCourseId = course.id;
                      _analysis = null;
                    });
                    _fetchStatus();
                  }
                },
              );
            },
          ),
        ),
        const SizedBox(height: 20),
        Text(
          l10n.timePeriod,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<AnalysisPeriod>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                  value: AnalysisPeriod.lastMonth, label: Text(l10n.oneMonth)),
              ButtonSegment(
                  value: AnalysisPeriod.last2Months, label: Text(l10n.twoMonths)),
              ButtonSegment(
                  value: AnalysisPeriod.last3Months, label: Text(l10n.threeMonths)),
            ],
            selected: {_selectedPeriod},
            onSelectionChanged: (newSelection) {
              setState(() {
                _selectedPeriod = newSelection.first;
                _analysis = null;
              });
              _fetchStatus();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyPlaceholder() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Text(
          AppLocalizations.of(context)!.analysisPlaceholder,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
        ),
      ),
    );
  }

  Widget _buildAnalysisResults(AiCourseAnalysis data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Icon(Icons.format_quote, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 8),
              Text(
                data.motivationalMessage,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontStyle: FontStyle.italic,
                    ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        if (data.recommendations.isNotEmpty) ...[
          Text(AppLocalizations.of(context)!.recommendations, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ...data.recommendations.map((rec) => Card(
            elevation: 2,
            shadowColor: Colors.black12,
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.lightbulb, size: 20, color: Colors.amber.shade700),
                      const SizedBox(width: 8),
                      Text(
                        rec.type.toUpperCase(),
                        style: TextStyle(
                           fontSize: 11,
                           fontWeight: FontWeight.bold,
                           color: Colors.amber.shade900,
                           letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(rec.text),
                ],
              ),
            ),
          )),
          const SizedBox(height: 12),
        ],

        Text(AppLocalizations.of(context)!.insights, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ...data.patterns.map((p) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              elevation: 0,
              color: Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.5),
              child: ListTile(
                leading: Icon(Icons.timeline, color: Theme.of(context).colorScheme.secondary),
                title: Text(p),
              ),
            )),
        ...data.weakSpots.map((w) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              elevation: 0,
              color: Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.5),
              child: ListTile(
                leading: Icon(Icons.warning_amber, color: Theme.of(context).colorScheme.error),
                title: Text(w),
              ),
            )),
        const SizedBox(height: 16),

        Text(AppLocalizations.of(context)!.topTopics, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Card(
          elevation: 0,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: data.topTopics.map((topic) {
              return ListTile(
                title: Text(topic.name),
                subtitle: Text(topic.category),
                trailing: Chip(
                  label: Text("${topic.count}"),
                  visualDensity: VisualDensity.compact,
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 24),

        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(context).colorScheme.primaryContainer,
                Theme.of(context).colorScheme.surfaceContainerHighest,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.auto_awesome,
                        size: 20,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      AppLocalizations.of(context)!.overview,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  data.summary,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        height: 1.5,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.9),
                      ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.keyboard_arrow_up_rounded,
              size: 18,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              AppLocalizations.of(context)!.scrollUpHint,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
