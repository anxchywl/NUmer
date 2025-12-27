import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../models.dart';
import '../services/ai_analysis_service.dart';
import '../l10n/app_localizations.dart';

class AiAnalysisScreen extends StatefulWidget {
  const AiAnalysisScreen({super.key});

  @override
  State<AiAnalysisScreen> createState() => _AiAnalysisScreenState();
}

class _AiAnalysisScreenState extends State<AiAnalysisScreen> {
  String? _selectedCourseId;
  AnalysisPeriod _selectedPeriod = AnalysisPeriod.lastMonth;
  bool _isLoading = false;
  AiCourseAnalysis? _analysis;
  
  final ScrollController _scrollController = ScrollController();

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState = Provider.of<AppState>(context, listen: false);
      if (appState.courses.isNotEmpty) {
        setState(() {
          _selectedCourseId = appState.courses.first.id;
        });
      }
    });
  }

  @override
  void dispose() {
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

      // Get user's language from locale
      final locale = Localizations.localeOf(context);
      final languageCode = locale.languageCode; // 'en', 'ru', etc.

      final result = await AiAnalysisService.analyzeCourse(
          _selectedCourseId!, course.name, _selectedPeriod, language: languageCode);
      if (mounted) {
        setState(() {
          _analysis = result;
        });
        _scrollToBottom();
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
    
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.courseAnalysis),
        centerTitle: true,
      ),
      body: courses.isEmpty
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
          : SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  
                  _buildControls(courses),
                  const SizedBox(height: 24),

                  
                  FilledButton.icon(
                    onPressed: _isLoading ? null : _runAnalysis,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    icon: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                        color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.auto_awesome),
                      label: Text(_isLoading ? AppLocalizations.of(context)!.analyzing : AppLocalizations.of(context)!.generateInsight),
                    ),
                  const SizedBox(height: 32),

                  
                  if (_analysis != null)
                    _buildAnalysisResults(_analysis!)
                  else if (!_isLoading)
                    _buildEmptyPlaceholder(),
                ],
              ),
            ),
    );
  }

  Widget _buildControls(List<Course> courses) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context)!.selectCourse,
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
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      _selectedCourseId = course.id;
                      _analysis = null;
                    });
                  }
                },
              );
            },
          ),
        ),
        const SizedBox(height: 20),
        Text(
          AppLocalizations.of(context)!.timePeriod,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<AnalysisPeriod>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                  value: AnalysisPeriod.lastMonth, label: Text(AppLocalizations.of(context)!.oneMonth)),
              ButtonSegment(
                  value: AnalysisPeriod.last3Months, label: Text(AppLocalizations.of(context)!.threeMonths)),
              ButtonSegment(
                  value: AnalysisPeriod.last6Months, label: Text(AppLocalizations.of(context)!.sixMonths)),
            ],
            selected: {_selectedPeriod},
            onSelectionChanged: (newSelection) {
              setState(() {
                _selectedPeriod = newSelection.first;
                _analysis = null;
              });
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
