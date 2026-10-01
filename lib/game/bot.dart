import '../sim/cast.dart';
import '../sim/clock.dart';
import '../sim/dash.dart';
import '../sim/village.dart';

/// How the self-test bot plays Dash, one preset per ending.
enum BotPreset {
  /// Wins trust, learns the truth and passes it on, says kind things.
  harmony,

  /// Wins just enough trust to be believed, then spreads lies.
  drama,

  /// Never talks to anyone.
  quiet,
}

/// Plays Dash by rules: picks whom to visit and which option to choose.
/// Pure sim logic, so the presets can be checked headless.
class PlayerBot {
  PlayerBot(this.preset);
  final BotPreset preset;

  double _nextVisitMs = 0;
  double? _doneSince;
  int visits = 0;
  final List<String> picks = [];

  /// How long to look at the options before choosing (real ms); the
  /// self-test sets it so the options can be photographed.
  double thinkMs = 0;

  static const double _gapMs = 2500;
  static const double _giveUpMs = 45000;

  void tick(Village v) {
    if (preset == BotPreset.quiet || v.paused || v.isNight || v.weekOver) return;
    if (v.now.day == festivalDay && v.now.minute >= 14 * 60) return;
    final dash = v.dash;
    final visit = dash.visit;
    if (visit == null) {
      if (v.uiMs < _nextVisitMs) return;
      final target = _target(v);
      if (target == null) return;
      visits++;
      _doneSince = null;
      dash.talk(target);
      return;
    }
    if (v.uiMs - visit.startMs > _giveUpMs && visit.stage != VisitStage.replying) {
      _leave(v);
      return;
    }
    switch (visit.stage) {
      case VisitStage.choosing:
        final options = visit.options;
        if (options == null || options.isEmpty) return;
        if (v.uiMs - (visit.optionsReadyMs ?? v.uiMs) < thinkMs) return;
        final i = _pick(v, visit.target, options);
        picks.add('${visit.target.name}:${options[i].intent}');
        dash.choose(i);
      case VisitStage.done:
        _doneSince ??= v.uiMs;
        if (v.uiMs - _doneSince! > 1500) _leave(v);
      case VisitStage.flying || VisitStage.waiting || VisitStage.replying:
        break;
    }
  }

  void _leave(Village v) {
    v.dash.leave();
    _nextVisitMs = v.uiMs + _gapMs;
  }

  bool _awake(Llama l) => !l.asleep;

  /// A correction Dash knows that [l] needs: a true fact disproving
  /// something [l] still believes.
  bool _canCorrect(Village v, Llama l) =>
      v.kb.known('Dash').any((f) => f.truth && f.contradicts != null && !v.kb.knows(l.name, f.id) && v.kb.believes(l.name, f.contradicts!));

  Llama? _target(Village v) {
    final awake = v.cast.where(_awake).toList();
    if (awake.isEmpty) return null;
    int trust(Llama l) => l.friendship['Dash'] ?? 0;
    switch (preset) {
      case BotPreset.harmony:
        final needy = awake.where((l) => _canCorrect(v, l)).toList();
        if (needy.isNotEmpty) return needy.first;
        final misled = v.cast.any((l) => v.kb.known(l.name).any((f) => !f.truth && v.kb.believes(l.name, f.id)));
        if (misled) {
          // Someone who knows the truth may tell it to a pleased Dash.
          final knowers = awake
              .where((l) => v.kb.known(l.name).any((f) => f.contradicts != null && f.truth && !v.kb.knows('Dash', f.id)))
              .toList();
          if (knowers.isNotEmpty) return knowers[visits % knowers.length];
        }
        // A miserable llama snaps at anything, so leave it be for now.
        final calm = awake.where((l) => l.mood > -3).toList();
        if (calm.isEmpty) return null;
        calm.sort((a, b) => trust(a).compareTo(trust(b)));
        return calm[visits % 2 == 0 ? 0 : (visits ~/ 2) % calm.length];
      case BotPreset.drama:
        final believers = awake.where((l) => trust(l) >= 1 || l.traits.contains('nosy')).toList();
        final pool = believers.isNotEmpty && visits.isOdd ? believers : awake;
        return pool[visits % pool.length];
      case BotPreset.quiet:
        return null;
    }
  }

  int _pick(Village v, Llama l, List<DashOption> options) {
    final trust = l.friendship['Dash'] ?? 0;
    int score(DashOption o) {
      final correction = o.fact != null && v.kb.maybe(o.fact!)?.contradicts != null;
      final likesSubject = o.about == null || (l.friendship[o.about!] ?? 0) > -3;
      return switch (preset) {
        BotPreset.harmony => switch (o.intent) {
          'tell' => correction ? 100 : 40,
          'compliment' => 60,
          'praise' => !likesSubject ? 5 : (trust >= 2 ? 70 : 50),
          'gift' => 55,
          'help' => 30,
          _ => 0,
        },
        BotPreset.drama => switch (o.intent) {
          'gossip' => trust >= 1 || l.traits.contains('nosy') ? 100 : 10,
          'compliment' => 60,
          'gift' => 55,
          'tease' => 20,
          _ => 5,
        },
        BotPreset.quiet => 0,
      };
    }

    var best = 0;
    for (var i = 1; i < options.length; i++) {
      if (score(options[i]) > score(options[best])) best = i;
    }
    return best;
  }
}

BotPreset? botPresetFrom(String? name) => BotPreset.values.where((p) => p.name == name).firstOrNull;
