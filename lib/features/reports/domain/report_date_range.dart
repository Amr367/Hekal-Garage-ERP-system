import 'package:intl/intl.dart';

enum DateRangePreset {
  today,
  thisWeek,
  thisMonth,
  lastMonth,
  thisYear,
  custom,
}

/// Represents an inclusive date range for report queries.
class ReportDateRange {
  const ReportDateRange({
    required this.start,
    required this.end,
    this.preset = DateRangePreset.thisMonth,
  });

  final DateTime start;
  final DateTime end;
  final DateRangePreset preset;

  /// Creates a date range for today (00:00:00 to 23:59:59).
  factory ReportDateRange.today() {
    final now = DateTime.now();
    return ReportDateRange(
      start: DateTime(now.year, now.month, now.day, 0, 0, 0),
      end: DateTime(now.year, now.month, now.day, 23, 59, 59),
      preset: DateRangePreset.today,
    );
  }

  /// Creates a date range for the current week (starting Saturday for Egypt).
  factory ReportDateRange.thisWeek() {
    final now = DateTime.now();
    // In Egypt, the working week starts Saturday (weekday 6)
    final daysSinceSaturday = (now.weekday - DateTime.saturday + 7) % 7;
    final startOfWeek = now.subtract(Duration(days: daysSinceSaturday));
    return ReportDateRange(
      start: DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day, 0, 0, 0),
      end: DateTime(now.year, now.month, now.day, 23, 59, 59),
      preset: DateRangePreset.thisWeek,
    );
  }

  /// Creates a date range for the current calendar month.
  factory ReportDateRange.thisMonth() {
    final now = DateTime.now();
    final lastDay = DateTime(now.year, now.month + 1, 0).day;
    return ReportDateRange(
      start: DateTime(now.year, now.month, 1, 0, 0, 0),
      end: DateTime(now.year, now.month, lastDay, 23, 59, 59),
      preset: DateRangePreset.thisMonth,
    );
  }

  /// Creates a date range for the previous calendar month.
  factory ReportDateRange.lastMonth() {
    final now = DateTime.now();
    final prevMonthDate = DateTime(now.year, now.month - 1, 1);
    final lastDay = DateTime(prevMonthDate.year, prevMonthDate.month + 1, 0).day;
    return ReportDateRange(
      start: DateTime(prevMonthDate.year, prevMonthDate.month, 1, 0, 0, 0),
      end: DateTime(prevMonthDate.year, prevMonthDate.month, lastDay, 23, 59, 59),
      preset: DateRangePreset.lastMonth,
    );
  }

  /// Creates a date range for the current calendar year.
  factory ReportDateRange.thisYear() {
    final now = DateTime.now();
    return ReportDateRange(
      start: DateTime(now.year, 1, 1, 0, 0, 0),
      end: DateTime(now.year, 12, 31, 23, 59, 59),
      preset: DateRangePreset.thisYear,
    );
  }

  /// Human-readable label in Arabic.
  String get label {
    switch (preset) {
      case DateRangePreset.today:
        return 'اليوم';
      case DateRangePreset.thisWeek:
        return 'هذا الأسبوع';
      case DateRangePreset.thisMonth:
        return 'الشهر الحالي';
      case DateRangePreset.lastMonth:
        return 'الشهر السابق';
      case DateRangePreset.thisYear:
        return 'السنة الحالية';
      case DateRangePreset.custom:
        final formatter = DateFormat('yyyy/MM/dd');
        return '${formatter.format(start)} - ${formatter.format(end)}';
    }
  }
}
