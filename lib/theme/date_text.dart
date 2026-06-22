//
//  date_text.dart
//
//  Date/time formatting in the reference (Chinese) style — the Flutter port of
//  the Swift `DateText`: "晚上10:47", "昨天", "星期二", "05/19", "2024/06/05".
//

class DateText {
  // 星期日 … 星期六, indexed by DateTime.weekday (Mon=1 … Sun=7).
  static const _weekdays = ['星期一', '星期二', '星期三', '星期四', '星期五', '星期六', '星期日'];

  static String _two(int n) => n.toString().padLeft(2, '0');

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Chat-list timestamp.
  static String listLabel(int unix) {
    if (unix <= 0) return '';
    final date = DateTime.fromMillisecondsSinceEpoch(unix * 1000);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (_sameDay(date, now)) return _periodTime(date);
    if (_sameDay(date, now.subtract(const Duration(days: 1)))) return '昨天';
    final dayStart = DateTime(date.year, date.month, date.day);
    final days = today.difference(dayStart).inDays;
    if (days < 7) return _weekdays[date.weekday - 1];
    if (date.year == now.year) return '${_two(date.month)}/${_two(date.day)}';
    return '${date.year}/${_two(date.month)}/${_two(date.day)}';
  }

  /// Centered in-conversation separator: "2024/06/04 晚上7:54".
  static String separatorLabel(int unix) {
    if (unix <= 0) return '';
    final date = DateTime.fromMillisecondsSinceEpoch(unix * 1000);
    final now = DateTime.now();
    if (_sameDay(date, now)) return _periodTime(date);
    final datePart = date.year == now.year
        ? '${_two(date.month)}/${_two(date.day)}'
        : '${date.year}/${_two(date.month)}/${_two(date.day)}';
    return '$datePart ${_periodTime(date)}';
  }

  /// In-bubble 24-hour time, e.g. "22:47".
  static String bubbleLabel(int unix) {
    if (unix <= 0) return '';
    final date = DateTime.fromMillisecondsSinceEpoch(unix * 1000);
    return '${_two(date.hour)}:${_two(date.minute)}';
  }

  /// "晚上7:54" / "凌晨0:30" — Chinese day-period + 12-hour clock.
  static String _periodTime(DateTime date) {
    final hour = date.hour;
    final String period;
    if (hour < 5) {
      period = '凌晨';
    } else if (hour < 8) {
      period = '早上';
    } else if (hour < 11) {
      period = '上午';
    } else if (hour < 13) {
      period = '中午';
    } else if (hour < 18) {
      period = '下午';
    } else {
      period = '晚上';
    }
    final displayHour = hour <= 12 ? hour : hour - 12;
    return '$period$displayHour:${_two(date.minute)}';
  }
}
