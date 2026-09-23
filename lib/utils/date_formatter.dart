import 'package:intl/intl.dart';

class AppDateFormatter {
  static const Duration _istOffset = Duration(hours: 5, minutes: 30);

  /// Converts any string or DateTime object into an IST DateTime object
  static DateTime toIST(dynamic input) {
    if (input == null) return DateTime.now().toUtc().add(_istOffset);
    if (input is DateTime) {
      final utc = input.isUtc ? input : input.toUtc();
      return utc.add(_istOffset);
    }
    String s = input.toString().trim();
    if (s.isEmpty) return DateTime.now().toUtc().add(_istOffset);

    try {
      DateTime parsed;
      if (!s.contains('Z') && !s.contains('+') && !RegExp(r'T.*\b-').hasMatch(s)) {
        if (s.length == 10 && RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(s)) {
          return DateTime.parse(s);
        }
        parsed = DateTime.parse('${s.replaceAll(' ', 'T')}Z');
      } else {
        parsed = DateTime.parse(s);
      }
      final utc = parsed.isUtc ? parsed : parsed.toUtc();
      return utc.add(_istOffset);
    } catch (_) {
      return DateTime.now().toUtc().add(_istOffset);
    }
  }

  /// Format date time to IST: "23/09/2026 05:30 PM IST" or "23/09/2026 05:30 PM"
  static String formatDateTime(dynamic input, {bool withIST = true}) {
    if (input == null || input.toString().isEmpty) return '--';
    final ist = toIST(input);
    final formatted = DateFormat('dd/MM/yyyy hh:mm a').format(ist);
    return withIST ? '$formatted IST' : formatted;
  }

  /// Format date only: "dd/MM/yyyy"
  static String formatDateOnly(dynamic input) {
    if (input == null || input.toString().isEmpty) return '--';
    if (input is String && input.length == 10 && RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(input)) {
      final parts = input.split('-');
      return '${parts[2]}/${parts[1]}/${parts[0]}';
    }
    final ist = toIST(input);
    return DateFormat('dd/MM/yyyy').format(ist);
  }

  /// Get current IST date string YYYY-MM-DD
  static String currentISTDateStr() {
    final nowIST = DateTime.now().toUtc().add(_istOffset);
    return DateFormat('yyyy-MM-dd').format(nowIST);
  }

  /// Get current IST DateTime
  static DateTime nowIST() {
    return DateTime.now().toUtc().add(_istOffset);
  }
}
