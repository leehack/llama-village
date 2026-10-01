/// Game time: day number (1-based) and minute of the day.
class GameTime implements Comparable<GameTime> {
  const GameTime(this.day, this.minute);

  /// The inverse of [absolute].
  factory GameTime.fromAbsolute(int total) => GameTime((total / 1440).floor() + 1, total % 1440);

  final int day;
  final int minute;

  int get absolute => (day - 1) * 1440 + minute;
  int get hour => minute ~/ 60;

  GameTime plus(int minutes) {
    final total = absolute + minutes;
    return GameTime(total ~/ 1440 + 1, total % 1440);
  }

  int minutesSince(GameTime other) => absolute - other.absolute;

  String get hhmm => '${hour.toString().padLeft(2, '0')}:${(minute % 60).toString().padLeft(2, '0')}';
  String get label => 'D$day $hhmm';

  String get partOfDay => switch (hour) {
    < 9 => 'early morning',
    < 12 => 'late morning',
    < 14 => 'midday',
    < 17 => 'afternoon',
    < 20 => 'evening',
    _ => 'night',
  };

  /// How [then] reads from now, for prompts ("this morning", "yesterday").
  String relative(GameTime then) {
    if (then.day < 1 || then.absolute < 0) return 'before the story began';
    if (then.day < day) return then.day == day - 1 ? 'yesterday ${then.partOfDay}' : 'days ago';
    final ago = minutesSince(then);
    if (ago < 45) return 'just now';
    if (ago < 120) return 'about ${(ago / 60).round()} hour ago';
    return 'today at ${then.hhmm}';
  }

  @override
  int compareTo(GameTime other) => absolute.compareTo(other.absolute);

  @override
  bool operator ==(Object other) => other is GameTime && other.absolute == absolute;

  @override
  int get hashCode => absolute.hashCode;

  @override
  String toString() => label;
}

/// Festival Week runs for [weekDays] days; the Berry Festival is on the last.
const int weekDays = 5;
const int festivalDay = 5;
const int festivalMinute = 16 * 60;

/// When everyone still chatting elsewhere breaks off for the festival:
/// time for the longest gallop up the hill (about 30 minutes).
const int festivalCall = festivalMinute - 40;

/// When festival day's walk to the hilltop begins. Walks take up to about
/// 100 game minutes, so even a llama that has just set off the other way
/// gets back in time.
const int festivalSetOff = 13 * 60 + 30;
const int stormDay = 3;

/// Backstory facts are stamped before day 1.
const GameTime backstory = GameTime(0, 0);
