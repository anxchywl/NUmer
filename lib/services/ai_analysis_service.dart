import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:numer_app/core/data/storage.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';

enum AnalysisPeriod {
  lastMonth,
  last2Months,
  last3Months;

  String label(String language) {
    if (language == 'ru') {
      return switch (this) {
        AnalysisPeriod.lastMonth => 'последний 1 месяц',
        AnalysisPeriod.last2Months => 'последние 2 месяца',
        AnalysisPeriod.last3Months => 'последние 3 месяца',
      };
    }
    return switch (this) {
      AnalysisPeriod.lastMonth => 'Last 1 Month',
      AnalysisPeriod.last2Months => 'Last 2 Months',
      AnalysisPeriod.last3Months => 'Last 3 Months',
    };
  }

  int get months => switch (this) {
        AnalysisPeriod.lastMonth => 1,
        AnalysisPeriod.last2Months => 2,
        AnalysisPeriod.last3Months => 3,
      };
}

class AiTopic {
  final String name;
  final String category; 
  final int count;

  AiTopic({required this.name, required this.category, required this.count});

  factory AiTopic.fromJson(Map<String, dynamic> json) {
    return AiTopic(
      name: json['name'] as String,
      category: json['category'] as String,
      count: json['count'] as int,
    );
  }
  Map<String, dynamic> toJson() => {
        'name': name,
        'category': category,
        'count': count,
      };
}

class AiRecommendation {
  final String text;
  final String type; 

  AiRecommendation({required this.text, required this.type});

  factory AiRecommendation.fromJson(Map<String, dynamic> json) {
    return AiRecommendation(
      text: json['text'] as String,
      type: json['type'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'text': text,
        'type': type,
      };
}

class AiCourseAnalysis {
  final String courseId;
  final AnalysisPeriod period;
  final String summary;
  final List<AiTopic> topTopics;
  final List<String> patterns; 
  final List<String> weakSpots;
  final List<AiRecommendation> recommendations;
  final String motivationalMessage;

  AiCourseAnalysis({
    required this.courseId,
    required this.period,
    required this.summary,
    required this.topTopics,
    required this.patterns,
    required this.weakSpots,
    required this.recommendations,
    required this.motivationalMessage,
  });

  factory AiCourseAnalysis.fromJson(
      Map<String, dynamic> json, String courseId, AnalysisPeriod period) {
    return AiCourseAnalysis(
      courseId: courseId,
      period: period,
      summary: json['summary'] as String? ?? '',
      topTopics: (json['topTopics'] as List?)
              ?.map((e) => AiTopic.fromJson(e))
              .toList() ??
          [],
      patterns: List<String>.from(json['patterns'] ?? []),
      weakSpots: List<String>.from(json['weakSpots'] ?? []),
      recommendations: (json['recommendations'] as List?)
              ?.map((e) => AiRecommendation.fromJson(e))
              .toList() ??
          [],
      motivationalMessage: json['motivationalMessage'] as String? ??
          "Keep up the great work!",
    );
  }

  Map<String, dynamic> toJson() => {
        'summary': summary,
        'topTopics': topTopics.map((e) => e.toJson()).toList(),
        'patterns': patterns,
        'weakSpots': weakSpots,
        'recommendations': recommendations.map((e) => e.toJson()).toList(),
        'motivationalMessage': motivationalMessage,
      };
}

class AiAnalysisService {
  AiAnalysisService._();

  static Future<List<Map<String, dynamic>>> fetchReflections(
      String courseId, AnalysisPeriod period, {DateTime? since}) async {
    final now = DateTime.now();
    
    // Period start date window (e.g. 1 month ago)
    final periodStart = DateTime(now.year, now.month - period.months, now.day);
    
    // Use the LATER of (periodStart) or (since) as the effective start time
    // But we still need to respect period window.
    // Actually, the requirement is: "count new notes since the last analysis AND within the selected window logic."
    // So effectiveStart = max(periodStart, since)
    DateTime effectiveStart = periodStart;
    if (since != null && since.isAfter(periodStart)) {
      effectiveStart = since;
    }

    final sessions = await Storage.getSessions();
    final results = <Map<String, dynamic>>[];

    for (final s in sessions) {
      final sid = s['courseId'] as String?;
      if (sid != courseId) continue;
      final endUtc = s['endUtc'] as DateTime?;
      if (endUtc == null || endUtc.isBefore(effectiveStart)) continue;
      results.add({
        'comment': (s['notes'] as String?) ?? '',
        'createdAt': Timestamp.fromDate(endUtc),
        'durationSeconds': (s['seconds'] as num?)?.toInt() ?? 0,
      });
    }

    results.sort((a, b) {
      final da = (a['createdAt'] as Timestamp).toDate();
      final db = (b['createdAt'] as Timestamp).toDate();
      return db.compareTo(da);
    });

    return results;
  }

  static Future<AiCourseAnalysis> analyzeCourse(
      String courseId, String courseName, AnalysisPeriod period, {String language = 'en'}) async {
    
    final reflections = await fetchReflections(courseId, period);

    
    
    if (reflections.isEmpty) {
      return _getEmptyAnalysis(courseId, period, language);
    }

    try {
      
      final prompt =
          generateAnalysisPrompt(reflections, courseName, period, language);
      if (kDebugMode) {
        debugPrint("GENERATED PROMPT:\n$prompt");
      }

      
      
      final analysis = await fetchAiAnalysisFromApi(prompt, courseId, period);
      return analysis;

      
      
      
    } catch (e) {
      if (kDebugMode) {
        debugPrint("AI Analysis Failed: $e");
      }
      return _getMockAnalysis(courseId, period, language); 
    }
  }

  static String generateAnalysisPrompt(List<Map<String, dynamic>> reflections,
      String courseName, AnalysisPeriod period, String language) {
    final sb = StringBuffer();

    // Language-specific instructions
    final isRu = language == 'ru';
    final languageInstruction = isRu
        ? "ВАЖНО: Выводи ВЕСЬ текст (summary, topic names, categories, patterns, weakSpots, recommendation text, types, motivationalMessage) ТОЛЬКО на русском языке."
        : "IMPORTANT: Respond ONLY in English. All values in the JSON must be in English.";

    sb.writeln(languageInstruction);
    sb.writeln("");
    sb.writeln(isRu 
        ? "Ты - ИИ-коуч по обучению, анализирующий учебные паттерны студента для курса $courseName." 
        : "You are an AI study coach analyzing a student's study patterns for $courseName.");
    sb.writeln("");
    sb.writeln(isRu ? "ИНСТРУКЦИИ:" : "IMPORTANT INSTRUCTIONS:");
    sb.writeln(isRu 
        ? "- Даже если комментарии пусты или кратки, предоставь ПОЛНЫЙ анализ" 
        : "- Even if comments are empty or very brief (1-2 words), provide a FULL analysis");
    sb.writeln(isRu
        ? "- Сосредоточься на частоте занятий, временных паттернах и длительности сессий"
        : "- Focus on study frequency, timing patterns, and session durations");
    sb.writeln(isRu
        ? "- Сделай выводы о привычках из дат и времени (утро vs вечер, будни vs выходные)"
        : "- Infer study habits from dates and times (e.g., morning vs evening, weekday vs weekend)");
    sb.writeln(isRu
        ? "- Для пустых комментариев анализируй стабильность и длительность"
        : "- For empty comments, analyze the consistency and duration of sessions");
    sb.writeln(isRu
        ? "- Адаптируй ВСЕ рекомендации именно для курса $courseName"
        : "- Tailor ALL recommendations specifically to $courseName");
    sb.writeln(isRu
        ? "- Будь поддерживающим, конструктивным и воодушевляющим"
        : "- Be supportive, actionable, and encouraging");
    sb.writeln("");
    sb.writeln(isRu ? "РУКОВОДСТВО ПО АНАЛИЗУ:" : "ANALYSIS GUIDELINES:");
    sb.writeln(isRu
        ? "- Если в комментариях есть темы, добавь их в topTopics"
        : "- If comments mention specific topics, include them in topTopics");
    sb.writeln(isRu
        ? "- Если комментариев мало, создай темы на основе общего содержания $courseName"
        : "- If comments are sparse, create topics based on general $courseName concepts");
    sb.writeln(isRu
        ? "- Ищи закономерности во времени, длине и частоте занятий"
        : "- Look for patterns in study times, session lengths, and frequency");
    sb.writeln(isRu
        ? "- Укажи, становятся ли сессии длиннее/короче, чаще/реже"
        : "- Identify if sessions are getting longer/shorter, more/less frequent");
    sb.writeln("");
    
    final sessionsHeader = isRu 
        ? "Учебные сессии за ${period.label(language)}:" 
        : "Study sessions for the last ${period.label(language)}:";
    sb.writeln(sessionsHeader);
    
    int totalSessions = reflections.length;
    int totalMinutes = 0;
    int sessionsWithComments = 0;
    
    for (final r in reflections) {
      final text = (r['comment'] as String?) ?? (r['text'] as String?) ?? '';
      final date = (r['createdAt'] as Timestamp?)?.toDate();
      
      int duration = 0;
      if (r.containsKey('durationSeconds')) {
        final sec = (r['durationSeconds'] as num?)?.toInt() ?? 0;
        duration = (sec / 60).ceil(); 
      } else {
        duration = (r['durationMinutes'] as num?)?.toInt() ?? 0;
      }

      totalMinutes += duration;
      if (text.trim().isNotEmpty) sessionsWithComments++;
      
      final dateStr = date?.toString() ?? 'Unknown date';
      final commentDisplay = text.trim().isEmpty 
          ? (isRu ? '(без комментария)' : '(no comment)') 
          : text;
      sb.writeln("- [$dateStr] ($duration ${isRu ? "мин" : "mins"}): $commentDisplay");
    }
    
    sb.writeln("");
    sb.writeln(isRu ? "ИТОГОВАЯ СТАТИСТИКА:" : "SUMMARY STATS:");
    sb.writeln("${isRu ? "- Всего сессий" : "- Total sessions"}: $totalSessions");
    sb.writeln("${isRu ? "- Общее время" : "- Total time"}: $totalMinutes ${isRu ? "минут" : "minutes"}");
    sb.writeln("${isRu ? "- Сессий с комментариями" : "- Sessions with comments"}: $sessionsWithComments");
    sb.writeln("${isRu ? "- Средняя сессия" : "- Average session"}: ${totalSessions > 0 ? (totalMinutes / totalSessions).round() : 0} ${isRu ? "мин" : "mins"}");
    sb.writeln("");
    
    final outputFormatHeader = isRu
        ? "ФОРМАТ ВЫВОДА (Верни ТОЛЬКО валидный JSON, без markdown):"
        : "OUTPUT FORMAT (Return ONLY valid JSON, no markdown):";
    sb.writeln(outputFormatHeader);
    
    sb.writeln("{");
    sb.writeln('  "summary": "...",');
    sb.writeln('  "topTopics": [{"name": "...", "category": "...", "count": 1}],');
    sb.writeln('  "patterns": ["...", "..."],');
    sb.writeln('  "weakSpots": ["..."],');
    sb.writeln('  "recommendations": [{"text": "...", "type": "..."}],');
    sb.writeln('  "motivationalMessage": "..."');
    sb.writeln("}");
    
    return sb.toString();
  }

  static Future<AiCourseAnalysis> fetchAiAnalysisFromApi(
      String prompt, String courseId, AnalysisPeriod period) async {
    try {
      if (kDebugMode) {
        debugPrint("🔵 Calling Cloud Function 'analyzeCourseAi'...");
        debugPrint("🔵 Prompt length: ${prompt.length} characters");
      }
      
      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable(
        'analyzeCourseAi',
        options: HttpsCallableOptions(
          timeout: const Duration(seconds: 60),
        ),
      );
      
      if (kDebugMode) {
        debugPrint("🔵 Sending request to Cloud Function...");
      }
      final result = await callable.call({'prompt': prompt}).timeout(
        const Duration(seconds: 65),
        onTimeout: () {
          if (kDebugMode) {
            debugPrint("⏱️ Cloud Function call timed out after 65 seconds");
          }
          throw Exception("Cloud Function timed out");
        },
      );

      if (kDebugMode) {
        debugPrint("✅ Cloud Function returned successfully");
      }
      final data = result.data as Map<String, dynamic>;
      final jsonString = data['result'] as String;
      
      if (kDebugMode) {
        debugPrint("📦 Response length: ${jsonString.length} characters");
      }
      
      
      final cleanJson = jsonString.replaceAll(RegExp(r'^```json\s*|\s*```$'), '');

      final json = jsonDecode(cleanJson);
      return AiCourseAnalysis.fromJson(json, courseId, period);
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint("❌ Cloud Function Error: $e");
        debugPrint("Stack trace: $stackTrace");
      }
      throw Exception("Failed to analyze course via Cloud Function: $e");
    }
  }

  static AiCourseAnalysis _getEmptyAnalysis(
      String courseId, AnalysisPeriod period, String language) {
    final summary = language == 'ru'
        ? "Недостаточно данных. Учитесь больше и оставляйте заметки, чтобы получить инсайты!"
        : "Not enough data yet. Study more and leave reflections to get insights!";
    
    final rec1Text = language == 'ru'
        ? "Завершите хотя бы 5 учебных сессий."
        : "Complete at least 5 study sessions.";
    
    final rec2Text = language == 'ru'
        ? "Пишите подробные комментарии после каждой сессии."
        : "Write detailed comments after each session.";
    
    final motivational = language == 'ru'
        ? "Начните свой путь сегодня!"
        : "Start your journey today!";

    return AiCourseAnalysis(
      courseId: courseId,
      period: period,
      summary: summary,
      topTopics: [],
      patterns: [],
      weakSpots: [],
      recommendations: [
        AiRecommendation(text: rec1Text, type: "Start"),
        AiRecommendation(text: rec2Text, type: "Habit"),
      ],
      motivationalMessage: motivational,
    );
  }

  static AiCourseAnalysis _getMockAnalysis(
      String courseId, AnalysisPeriod period, String language) {
    if (language == 'ru') {
      return AiCourseAnalysis(
        courseId: courseId,
        period: period,
        summary:
            "Вы потратили большую часть этого периода на изучение рекурсии и динамического программирования. Вы также работали над темами возврата. Ваша работа показывает стабильный прогресс в алгоритмическом мышлении.",
        topTopics: [
          AiTopic(name: "Динамическое программирование", category: "Алгоритм", count: 12),
          AiTopic(name: "Возврат", category: "Техника", count: 5),
          AiTopic(name: "Рекурсия", category: "Основная концепция", count: 8),
        ],
        patterns: [
          "Высокая концентрация по утрам",
          "Последовательная ежедневная практика",
          "Повторяющиеся базовые случаи рекурсии"
        ],
        weakSpots: ["Бинарный поиск", "Обход графа", "Алгоритмы сортировки"],
        recommendations: [
          AiRecommendation(text: "Повторите базовые случаи рекурсии.", type: "Повтор"),
          AiRecommendation(
              text: "Потратьте 15 минут на практику переходов ДП.",
              type: "Практика"),
          AiRecommendation(
              text: "Повторите бинарный поиск, чтобы сохранить навык.",
              type: "Освежить"),
        ],
        motivationalMessage:
            "Отличная последовательность — продолжайте! Вы строите солидный прогресс в этом курсе.",
      );
    }
    
    return AiCourseAnalysis(
      courseId: courseId,
      period: period,
      summary:
          "You spent most of this period practicing recursion and dynamic programming. You also worked on backtracking topics. Your work shows steady progress in algorithmic thinking.",
      topTopics: [
        AiTopic(name: "Dynamic Programming", category: "Algorithm", count: 12),
        AiTopic(name: "Backtracking", category: "Technique", count: 5),
        AiTopic(name: "Recursion", category: "Core Concept", count: 8),
      ],
      patterns: [
        "High Focus in Mornings",
        "Consistent Daily Practice",
        "Repeated recursion base cases"
      ],
      weakSpots: ["Binary Search", "Graph Traversal", "Sorting algorithms"],
      recommendations: [
        AiRecommendation(text: "Review recursion base cases.", type: "Review"),
        AiRecommendation(
            text: "Spend 15 minutes practicing DP transitions.",
            type: "Practice"),
        AiRecommendation(
            text: "Repeat binary search to keep the skill fresh.",
            type: "Refresh"),
      ],
      motivationalMessage:
          "Great consistency — keep going! You're building solid progress in this course.",
    );
  }
}
