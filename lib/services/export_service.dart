
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:excel/excel.dart';
import 'storage.dart';

class ExportService {
  ExportService._();

  static DateTime? _lastExportTime;
  static const Duration cooldownDuration = Duration(seconds: 30);

  /// Returns the remaining cooldown time in seconds.
  /// Returns 0 if no cooldown is active.
  static int get remainingCooldownSeconds {
    if (_lastExportTime == null) return 0;
    final diff = DateTime.now().difference(_lastExportTime!);
    final remaining = cooldownDuration.inSeconds - diff.inSeconds;
    return remaining > 0 ? remaining : 0;
  }

  /// Marks the current time as the last export time to start the cooldown.
  static void markExportStarted() {
    _lastExportTime = DateTime.now();
  }

  static Future<Directory> _getTargetDirectory() async {
    if (Platform.isAndroid) {
      // Use External Storage Directory for better user visibility 
      // (usually Android/data/com.package/files)
      // This doesn't require extra permissions on modern Android.
      return await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
    } else if (Platform.isIOS) {
      return await getApplicationDocumentsDirectory();
    } else {
      return await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
    }
  }

  static Future<void> _cleanupOldFiles() async {
    try {
      final directory = await _getTargetDirectory();
      if (await directory.exists()) {
        final files = directory.listSync();
        for (final file in files) {
          if (file is File) {
            final name = file.path.split(Platform.pathSeparator).last;
            // Matches:
            // numer_sessions_...
            // habits_... (based on habitReportFileName)
            if (name.startsWith('numer_sessions_') || name.startsWith('habits_')) {
              await file.delete();
            }
          }
        }
      }
    } catch (e) {
      // Ignore cleanup errors to not block export
    }
  }

  static Future<String> exportSessionsToCalendar({
    required String? courseId,
    required String exportTitle,
    required DateTime sinceDate,
    required DateTime untilDate,
    required Map<String, String> courseNames,
    required String studiedLabel,
  }) async {
    await _cleanupOldFiles();
    
    // 1. Fetch sessions
    final allSessions = await Storage.getSessions();
    
    // 2. Filter sessions
    final sessions = allSessions.where((s) {
      if (courseId != null && s['courseId'] != courseId) return false;
      final start = s['startUtc'] as DateTime;
      return (start.isAtSameMomentAs(sinceDate) || start.isAfter(sinceDate)) && start.isBefore(untilDate) && (s['seconds'] as int) > 0;
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
 
    // 4. Save to directory
    final directory = await _getTargetDirectory();
    
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final safeName = exportTitle.replaceAll(RegExp(r'[^\w\s]+'), '').replaceAll(' ', '_');
    final fileName = 'numer_sessions_${safeName}_$timestamp.ics';
    final path = '${directory.path}/$fileName';
    final file = File(path);
    await file.writeAsString(buffer.toString());
 
    return path;
  }
 
  static Future<String> generateCsvFile({
    required String fileName,
    required List<List<dynamic>> rows,
  }) async {
    await _cleanupOldFiles();
    
    final buffer = StringBuffer();
    
    for (final row in rows) {
      buffer.writeln(row.map((e) {
        final cell = e.toString();
        // Escape quotes
        if (cell.contains(',') || cell.contains('"') || cell.contains('\n')) {
          return '"${cell.replaceAll('"', '""')}"';
        }
        return cell;
      }).join(','));
    }
 
    final targetDir = await _getTargetDirectory();
 
    final path = '${targetDir.path}/$fileName';
    final file = File(path);
    await file.writeAsString(buffer.toString());
    return path;
  }
 
  static Future<String> generateExcelFile({
    required String fileName,
    required List<List<dynamic>> rows,
  }) async {
    await _cleanupOldFiles();

    final excel = Excel.createExcel();
    final sheet = excel['Sheet1'];
    
    // Add data to sheet
    for (int rowIndex = 0; rowIndex < rows.length; rowIndex++) {
      final row = rows[rowIndex];
      for (int colIndex = 0; colIndex < row.length; colIndex++) {
        final cellValue = row[colIndex];
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: colIndex, rowIndex: rowIndex));
        
        // Set cell value
        if (cellValue is int) {
          cell.value = IntCellValue(cellValue);
        } else if (cellValue is double) {
          cell.value = DoubleCellValue(cellValue);
        } else {
          cell.value = TextCellValue(cellValue.toString());
        }
        
        // Apply alignment based on position
        if (rowIndex == 0) {
          // Header row: left-aligned
          cell.cellStyle = CellStyle(
            horizontalAlign: HorizontalAlign.Left,
            verticalAlign: VerticalAlign.Center,
            bold: true,
          );
        } else if (colIndex == 0) {
          // First column (days): left-aligned
          cell.cellStyle = CellStyle(
            horizontalAlign: HorizontalAlign.Left,
            verticalAlign: VerticalAlign.Center,
          );
        } else {
          // All other cells: center-aligned
          cell.cellStyle = CellStyle(
            horizontalAlign: HorizontalAlign.Center,
            verticalAlign: VerticalAlign.Center,
          );
        }
      }
    }
 
    final targetDir = await _getTargetDirectory();
 
    final path = '${targetDir.path}/$fileName';
    final fileBytes = excel.encode();
    
    if (fileBytes != null) {
      final file = File(path);
      await file.writeAsBytes(fileBytes);
    } else {
      throw Exception('Failed to encode Excel file');
    }
    
    return path;
  }
}
