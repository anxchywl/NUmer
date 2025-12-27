
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'storage.dart';

class ExportService {
  ExportService._();

  static Future<String> exportSessionsToCalendar({
    required String? courseId,
    required String exportTitle,
    required DateTime sinceDate,
    required Map<String, String> courseNames,
    required String studiedLabel,
  }) async {
    // 1. Fetch sessions
    final allSessions = await Storage.getSessions();
    
    // 2. Filter sessions
    final sessions = allSessions.where((s) {
      if (courseId != null && s['courseId'] != courseId) return false;
      final start = s['startUtc'] as DateTime;
      return start.isAfter(sinceDate) && (s['seconds'] as int) > 0;
    }).toList();

    if (sessions.isEmpty) {
      throw Exception('No sessions found for this period.');
    }

    // 3. Generate ICS content
    final buffer = StringBuffer();
    buffer.writeln('BEGIN:VCALENDAR');
    buffer.writeln('VERSION:2.0');
    buffer.writeln('PRODID:-//Numer App//NONSGML//EN');
    buffer.writeln('CALSCALE:GREGORIAN');
    buffer.writeln('METHOD:PUBLISH');

    final dateFormat = DateFormat("yyyyMMdd'T'HHmmss'Z'");

    for (final session in sessions) {
      final start = (session['startUtc'] as DateTime).toUtc();
      final end = (session['endUtc'] as DateTime).toUtc();
      final id = session['id'] as String;
      final seconds = session['seconds'] as int;
      final kind = session['kind'] as String? ?? 'session';
      final sCourseId = session['courseId'] as String;
      final sCourseName = courseNames[sCourseId] ?? 'Unknown Course';
      
      // Calculate duration string
      final d = Duration(seconds: seconds);
      final h = d.inHours;
      final m = d.inMinutes % 60;
      final durationStr = h > 0 ? '$h hr $m min' : '$m min';

      buffer.writeln('BEGIN:VEVENT');
      buffer.writeln('UID:$id');
      buffer.writeln('DTSTAMP:${dateFormat.format(DateTime.now().toUtc())}');
      buffer.writeln('DTSTART:${dateFormat.format(start)}');
      buffer.writeln('DTEND:${dateFormat.format(end)}');
      buffer.writeln('SUMMARY:$studiedLabel $sCourseName');
      
      String description = 'Course: $sCourseName\\nDuration: $durationStr\\nType: $kind';
      
      buffer.writeln('DESCRIPTION:$description');
      buffer.writeln('STATUS:CONFIRMED');
      buffer.writeln('END:VEVENT');
    }

    buffer.writeln('END:VCALENDAR');

    // 4. Save to Downloads directory
    Directory directory;
    
    if (Platform.isAndroid) {
      // On Android, use Downloads directory
      final downloadDir = Directory('/storage/emulated/0/Download');
      if (await downloadDir.exists()) {
        directory = downloadDir;
      } else {
        directory = await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
      }
    } else if (Platform.isIOS) {
      // On iOS, use app documents directory (accessible via Files app)
      directory = await getApplicationDocumentsDirectory();
    } else {
      // Fallback for other platforms
      directory = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
    }
    
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final safeName = exportTitle.replaceAll(RegExp(r'[^\w\s]+'), '').replaceAll(' ', '_');
    final fileName = 'numer_sessions_${safeName}_$timestamp.ics';
    final path = '${directory.path}/$fileName';
    final file = File(path);
    await file.writeAsString(buffer.toString());

    return path;
  }
}
