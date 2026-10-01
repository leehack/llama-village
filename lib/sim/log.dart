import 'dart:convert';

import 'cast.dart';
import 'clock.dart';
import 'dash.dart';
import 'dialogue.dart';
import 'facts.dart';
import 'laya_roles.dart';
import 'places.dart';

/// The machine-readable stream: one JSON-able map per event.
class EventLog {
  EventLog(this.clock);
  final GameTime Function() clock;
  final List<Map<String, Object?>> events = [];
  final List<void Function(Map<String, Object?>)> listeners = [];

  void emit(String type, Map<String, Object?> data) {
    final e = {'t': clock().label, 'type': type, ...data};
    events.add(e);
    if (events.length > 4000) events.removeRange(0, 1000);
    for (final l in listeners) {
      l(e);
    }
  }

  String jsonl() => events.map(jsonEncode).join('\n');
}

enum LogKind { event, talk, line, know, thread, dash, note }

/// One row of the in-game village log.
class LogEntry {
  LogEntry(this.at, this.kind, this.text, {this.who = const []});
  final GameTime at;
  final LogKind kind;
  final String text;
  final List<String> who;
}

String _plain(String s) => s.replaceAll(RegExp(r'[_*`]'), '').replaceAll(RegExp(r'<[^>]+>'), '').trim();

/// The village log: a markdown transcript plus plain entries for the HUD.
class Transcript {
  Transcript(this.clock);
  final GameTime Function() clock;
  final StringBuffer out = StringBuffer();
  final List<LogEntry> entries = [];

  void _entry(LogKind kind, String text, {List<String> who = const []}) {
    entries.add(LogEntry(clock(), kind, _plain(text), who: who));
    if (entries.length > 600) entries.removeRange(0, 100);
  }

  void raw(String s) => out.writeln(s);
  void note(String s, {LogKind kind = LogKind.note}) {
    out.writeln('`${clock().hhmm}` $s  ');
    _entry(kind, s);
  }

  void heading(String s) => out
    ..writeln()
    ..writeln(s)
    ..writeln();

  void event(String title, String text) {
    out
      ..writeln()
      ..writeln('#### `${clock().hhmm}` $title')
      ..writeln()
      ..writeln(text)
      ..writeln();
    _entry(LogKind.event, '$title. $text');
  }

  void talkStarted(Conversation c, KnowledgeBase kb) {
    final topic = c.topic == null ? '' : ' about ${kb[c.topic!].short}';
    _entry(LogKind.talk, '${c.a.name} and ${c.b.name} talk at ${theP(c.place)}$topic', who: [c.a.name, c.b.name]);
  }

  void line(String speaker, String text) => _entry(LogKind.line, '$speaker: "$text"', who: [speaker]);

  void conversation(Conversation c, KnowledgeBase kb) {
    final topic = c.topic == null ? '' : ' · _topic: ${kb[c.topic!].short} (${c.topicSource})_';
    out
      ..writeln()
      ..writeln('> **`${c.start.hhmm}` ${c.a.name} and ${c.b.name}, ${c.place}**$topic  ');
    for (final l in c.lines) {
      out.writeln('> **${l.speaker}:** "${l.text}"${l.fallback ? ' _(fallback)_' : ''}  ');
    }
    for (final n in c.notes) {
      out.writeln('> _${n}_  ');
      _entry(LogKind.know, n.replaceAll(RegExp(r'^\(|\)$'), ''));
    }
    final fx = [
      for (final l in [c.a, c.b])
        '${l.name} mood ${_signed(c.moodDelta[l.name] ?? 0)}, toward ${c.other(l).name} ${_signed(c.friendshipDelta[l.name] ?? 0)}',
    ];
    out
      ..writeln('> <sub>${fx.join(' · ')}</sub>')
      ..writeln();
  }

  void dash(GameTime t, Llama l, List<DashOption> options, DashOption pick, int level, String reply, List<String> effects) {
    out
      ..writeln()
      ..writeln('#### `${t.hhmm}` Dash visits ${l.name} at ${theP(l.place)}')
      ..writeln();
    for (var i = 0; i < options.length; i++) {
      final o = options[i];
      out.writeln('${i + 1}. [${o.intent}${o.about == null ? '' : ' → ${o.about}'}] "${o.text}"${o == pick ? ' **← Dash picks**' : ''}');
    }
    out
      ..writeln()
      ..writeln('> **${l.name}** (${reactionLevels[level]}): "$reply"')
      ..writeln()
      ..writeln('<sub>${effects.join('; ')}</sub>')
      ..writeln();
    _entry(LogKind.dash, '${l.name} is ${reactionLevels[level]}. ${effects.join('; ')}', who: ['Dash', l.name]);
  }

  void knows(Llama l, KnowledgeBase kb, GameTime now) {
    final facts = kb.known(l.name);
    out.writeln('- **${l.name}** knows ${facts.length}:');
    for (final f in facts) {
      final k = f.knownBy[l.name]!;
      final tag = f.truth ? '' : ' (false)';
      out.writeln(
        '  - ${f.text}$tag <sub>(${k.how}${k.from == null ? '' : ' from ${k.from}'}, ${k.at.label}${k.believes ? '' : ', doubts it'})</sub>',
      );
    }
  }
}

String _signed(int v) => v > 0 ? '+$v' : '$v';
