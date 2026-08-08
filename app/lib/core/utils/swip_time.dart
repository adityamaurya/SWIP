import 'package:intl/intl.dart';

/// How the ledger renders a timestamp.
///
/// Ideation `D-06` / `D-07`. You gave three instructions in sequence:
///
///   1. "time and date in relative format — 2 hours ago"
///   2. "the time below it will be replaced with date and time"
///   3. "you could swap it first — keep the time just below the day, the date
///      and the month"
///
/// Instruction 3 revises 2 and is what ships as the default ([absolute]).
/// Instruction 1 is preserved as [relative]. Changing your mind mid-sentence is
/// the strongest possible signal that both readings are right in different
/// moments — "2h ago" wins for something that just happened, "08 Aug / 4:12 PM"
/// wins for reconciling against a statement — so this is a toggle, not a
/// decision. Tap any time cell to switch; the choice is global and persisted.
enum TimeFormatPref {
  /// Line 1 `08 Aug`, line 2 `4:12 PM`. Default.
  absolute,

  /// Single line, `2h ago`.
  relative,
}

/// The two lines of a ledger time cell. [secondary] is null in relative mode.
typedef TimeCell = ({String primary, String? secondary});

abstract final class SwipTime {
  static final _dayMonth = DateFormat('dd MMM');
  static final _dayMonthYear = DateFormat('dd MMM yy');
  static final _clock = DateFormat('h:mm a');
  static final _full = DateFormat('dd MMM yyyy, h:mm a');

  /// Renders [utc] for a ledger row under [pref].
  ///
  /// [now] is injectable so the behaviour is testable without waiting for the
  /// clock — every boundary below has a test.
  static TimeCell cell(
    DateTime utc,
    TimeFormatPref pref, {
    DateTime? now,
  }) {
    final local = utc.toLocal();
    final ref = (now ?? DateTime.now()).toLocal();

    if (pref == TimeFormatPref.relative) {
      return (primary: relative(utc, now: ref), secondary: null);
    }

    // Today keeps the clock on line 2 in both modes — "Today / 4:12 PM" reads
    // better than "08 Aug / 4:12 PM" for something that happened this morning.
    if (_isSameDay(local, ref)) {
      return (primary: 'Today', secondary: _clock.format(local));
    }
    if (_isSameDay(local, ref.subtract(const Duration(days: 1)))) {
      return (primary: 'Yesterday', secondary: _clock.format(local));
    }

    // The year appears only when it is not the current one, so the common case
    // stays short and the column stays narrow.
    final datePart = local.year == ref.year
        ? _dayMonth.format(local)
        : _dayMonthYear.format(local);

    return (primary: datePart, secondary: _clock.format(local));
  }

  /// Compact relative time: `now`, `4m ago`, `2h ago`, `3d ago`, `5w ago`,
  /// then falls back to an absolute date beyond a year.
  ///
  /// Deliberately short — this string lives in a 64dp column, so "about 2 hours
  /// ago" would truncate and truncation in a time column reads as a bug.
  static String relative(DateTime utc, {DateTime? now}) {
    final ref = (now ?? DateTime.now()).toUtc();
    final d = ref.difference(utc.toUtc());

    // Clock skew, or a capture timestamped by a terminal running fast.
    if (d.isNegative) return 'now';

    if (d.inSeconds < 60) return 'now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    if (d.inDays < 7) return '${d.inDays}d ago';
    if (d.inDays < 365) return '${(d.inDays / 7).floor()}w ago';
    return _dayMonthYear.format(utc.toLocal());
  }

  /// `08 Aug 2026, 4:12 PM` — the unambiguous form, used on detail screens
  /// where there is room to show both this and the relative string at once.
  static String full(DateTime utc) => _full.format(utc.toLocal());

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
