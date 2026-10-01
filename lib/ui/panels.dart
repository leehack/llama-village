import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../sim/cast.dart';
import '../sim/dash.dart';
import '../sim/log.dart';
import '../sim/village.dart';
import 'palette.dart';
import 'portrait.dart';
import 'strings.dart';

TextStyle _t(double size, {FontWeight weight = FontWeight.w600, Color color = Colors.white, FontStyle? style}) =>
    TextStyle(fontSize: size, fontWeight: weight, color: color, fontStyle: style, height: 1.3);

class _Card extends StatelessWidget {
  const _Card({required this.child, this.padding = const EdgeInsets.all(12), this.light = false});
  final Widget child;
  final EdgeInsets padding;
  final bool light;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: light ? panelLight : panel,
      borderRadius: BorderRadius.circular(16),
      boxShadow: const [BoxShadow(blurRadius: 18, color: Color(0x44000000), offset: Offset(0, 4))],
    ),
    child: child,
  );
}

// ------------------------------------------------------------ top bar

class TopBar extends StatelessWidget {
  const TopBar({
    super.key,
    required this.village,
    required this.fps,
    required this.onPause,
    required this.onSpeed,
    required this.onOverview,
    required this.onFollow,
    required this.followName,
    required this.modelLabel,
    required this.onSettings,
  });

  final Village village;
  final double? fps;
  final VoidCallback onPause;
  final ValueChanged<double> onSpeed;
  final VoidCallback onOverview;
  final VoidCallback onFollow;
  final String? followName;
  final String modelLabel;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final now = village.now;
    final weather = village.storm
        ? Icons.thunderstorm
        : village.isNight
        ? Icons.nightlight_round
        : Icons.wb_sunny;
    return _Card(
      padding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(weather, color: gold, size: 22),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l.dayClock(now.day, now.hhmm), style: _t(18, weight: FontWeight.w900)),
              Text(village.planning ? l.planningTomorrowLower : l.countdownFor(now.day), style: _t(11, color: Colors.white70)),
            ],
          ),
          const SizedBox(width: 14),
          _IconButton(icon: village.paused ? Icons.play_arrow : Icons.pause, tip: l.tipPause, onTap: onPause),
          const SizedBox(width: 4),
          for (final s in const [1.0, 2.0, 4.0])
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: _Chip(label: '${s.toInt()}×', active: village.timeScale == s && !village.paused, onTap: () => onSpeed(s)),
            ),
          const SizedBox(width: 10),
          _IconButton(icon: Icons.public, tip: l.tipOverview, onTap: onOverview),
          _IconButton(icon: followName == null ? Icons.center_focus_weak : Icons.center_focus_strong, tip: l.tipFollow, onTap: onFollow),
          _IconButton(icon: Icons.settings, tip: l.tipSettings, onTap: onSettings),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(fps == null ? '' : l.fps(fps!.toStringAsFixed(0)), style: _t(10.5, color: Colors.white60)),
              Text(
                village.chat.queue.busy ? l.thinking(village.chat.queue.runningType ?? '') : modelLabel,
                style: _t(10.5, color: village.chat.queue.busy ? gold : Colors.white38),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  const _IconButton({required this.icon, required this.tip, required this.onTap});
  final IconData icon;
  final String tip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tip,
    child: InkResponse(
      onTap: onTap,
      radius: 20,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    ),
  );
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.active, required this.onTap});
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(10),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(color: active ? gold : const Color(0x22FFFFFF), borderRadius: BorderRadius.circular(10)),
      child: Text(
        label,
        style: _t(13, weight: FontWeight.w900, color: active ? ink : Colors.white),
      ),
    ),
  );
}

// ------------------------------------------------------------ village log

class VillageLog extends StatefulWidget {
  const VillageLog({super.key, required this.entries, required this.count});
  final List<LogEntry> entries;

  /// Changes whenever an entry is added, so the list scrolls down.
  final int count;

  @override
  State<VillageLog> createState() => _VillageLogState();
}

class _VillageLogState extends State<VillageLog> {
  final ScrollController _scroll = ScrollController();
  bool _open = true;

  @override
  void didUpdateWidget(VillageLog old) {
    super.didUpdateWidget(old);
    if (old.count != widget.count && _scroll.hasClients) {
      final atEnd = _scroll.position.pixels >= _scroll.position.maxScrollExtent - 40;
      if (atEnd) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
        });
      }
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.entries.length > 250 ? widget.entries.sublist(widget.entries.length - 250) : widget.entries;
    return _Card(
      padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
      child: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () => setState(() => _open = !_open),
              child: Row(
                children: [
                  Text(
                    L10n.of(context).villageLog,
                    style: _t(13, weight: FontWeight.w900, color: gold),
                  ),
                  const Spacer(),
                  Icon(_open ? Icons.expand_more : Icons.expand_less, color: Colors.white54, size: 18),
                ],
              ),
            ),
            if (_open)
              SizedBox(
                height: 230,
                child: ListView.builder(
                  controller: _scroll,
                  itemCount: items.length,
                  itemBuilder: (context, i) => _LogRow(entry: items[i]),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LogRow extends StatelessWidget {
  const _LogRow({required this.entry});
  final LogEntry entry;

  @override
  Widget build(BuildContext context) {
    final (color, weight, style) = switch (entry.kind) {
      LogKind.event => (gold, FontWeight.w800, null),
      LogKind.thread => (const Color(0xFFFFA8C5), FontWeight.w700, FontStyle.italic),
      LogKind.know => (const Color(0xFF9EE6C2), FontWeight.w600, null),
      LogKind.talk => (Colors.white, FontWeight.w700, null),
      LogKind.dash => (const Color(0xFF9CC8FF), FontWeight.w700, null),
      LogKind.line => (Colors.white70, FontWeight.w500, FontStyle.italic),
      LogKind.note => (Colors.white60, FontWeight.w500, null),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '${entry.at.hhmm}  ',
              style: _t(11, color: Colors.white38),
            ),
            TextSpan(
              text: entry.text,
              style: _t(12, weight: weight, color: color, style: style),
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------ Dash's options

class OptionsPanel extends StatelessWidget {
  const OptionsPanel({super.key, required this.visit, required this.onChoose, required this.onMore, required this.onLeave});
  final DashVisit visit;
  final ValueChanged<int> onChoose;
  final VoidCallback onMore;
  final VoidCallback onLeave;

  static const Map<String, IconData> _icons = {
    'compliment': Icons.favorite,
    'gossip': Icons.record_voice_over,
    'tell': Icons.campaign,
    'gift': Icons.card_giftcard,
    'help': Icons.volunteer_activism,
    'tease': Icons.mood,
  };

  @override
  Widget build(BuildContext context) {
    final words = L10n.of(context);
    final l = visit.target;
    final options = visit.options;
    final Widget body = switch (visit.stage) {
      VisitStage.flying => _status(Icons.flight, words.dashFlying(l.name)),
      VisitStage.waiting => _status(Icons.hourglass_bottom, words.dashWaiting(l.name)),
      VisitStage.choosing when options == null => _status(null, words.dashThinking, spinner: true),
      VisitStage.choosing => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < options!.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Material(
                color: const Color(0xFFFFFFFF),
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => onChoose(i),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    child: Row(
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(color: dashBlue, shape: BoxShape.circle),
                          child: Text('${i + 1}', style: _t(12, weight: FontWeight.w900)),
                        ),
                        const SizedBox(width: 8),
                        Icon(_icons[options[i].intent] ?? Icons.chat, size: 18, color: const Color(0xFF6B6878)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(options[i].text, style: _t(13.5, color: ink)),
                        ),
                        const SizedBox(width: 6),
                        Text(words.intent(options[i].intent), style: _t(10.5, color: const Color(0xFF8A8796))),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      VisitStage.replying => _status(null, words.llamaAnswering(l.name), spinner: true, dark: true),
      VisitStage.done => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            words.reaction(l.name, visit.reaction ?? 2),
            style: _t(14, weight: FontWeight.w900, color: ink),
          ),
          const SizedBox(height: 4),
          for (final e in visit.effects) Text('• ${words.effectOf(e)}', style: _t(12, color: const Color(0xFF55525F))),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(onPressed: onMore, icon: const Icon(Icons.chat_bubble_outline), label: Text(words.sayMore)),
              const SizedBox(width: 6),
              FilledButton.icon(onPressed: onLeave, icon: const Icon(Icons.flight_takeoff), label: Text(words.flyOff)),
            ],
          ),
        ],
      ),
    };
    return _Card(
      light: true,
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.flutter_dash, color: dashBlue, size: 20),
                const SizedBox(width: 6),
                Text(
                  words.dashAnd(l.name),
                  style: _t(15, weight: FontWeight.w900, color: ink),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    words.atPlaceMood(words.placeName(l.place), words.moodOf(l)),
                    overflow: TextOverflow.ellipsis,
                    style: _t(12, color: const Color(0xFF8A8796)),
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: words.tipLeave,
                  onPressed: onLeave,
                  icon: const Icon(Icons.close, size: 18, color: Color(0xFF8A8796)),
                ),
              ],
            ),
            body,
          ],
        ),
      ),
    );
  }

  Widget _status(IconData? icon, String text, {bool spinner = false, bool dark = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      children: [
        if (spinner) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.5, color: dashBlue)),
        if (icon != null) Icon(icon, color: dashBlue, size: 20),
        const SizedBox(width: 10),
        Flexible(
          child: Text(text, style: _t(14, color: ink)),
        ),
      ],
    ),
  );
}

// ------------------------------------------------------------ inspector

class Inspector extends StatelessWidget {
  const Inspector({super.key, required this.data, required this.village, required this.onClose, required this.onTalk, required this.cast});
  final LlamaInspector data;
  final Village village;
  final VoidCallback onClose;
  final VoidCallback onTalk;
  final List<Llama> cast;

  @override
  Widget build(BuildContext context) {
    final words = L10n.of(context);
    final l = data.llama;
    final accent = accentOf(l.name);
    return _Card(
      padding: EdgeInsets.zero,
      child: SizedBox(
        width: 360,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.85),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  LlamaPortrait(l.name),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.name,
                          style: _t(22, weight: FontWeight.w900, color: Colors.white).copyWith(shadows: textShadow),
                        ),
                        Text(words.llamaRole(l.name), style: _t(12.5, color: Colors.white)),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: words.tipTalkAsDash,
                    onPressed: onTalk,
                    icon: const Icon(Icons.chat, color: Colors.white),
                  ),
                  IconButton(
                    tooltip: words.tipCloseEsc,
                    onPressed: onClose,
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                children: [
                  Text(
                    words.llamaTraits(l.name),
                    style: _t(12.5, color: Colors.white70, style: FontStyle.italic),
                  ),
                  const SizedBox(height: 4),
                  Text(words.llamaBio(l.name), style: _t(12, color: Colors.white60)),
                  _section(words.sectionNow),
                  Text(words.activityOf(village, l), style: _t(13)),
                  if (data.thought != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.cloud_outlined, size: 15, color: Color(0xFFB9B0E0)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            data.thought!,
                            style: _t(12.5, color: const Color(0xFFDCD6F7), style: FontStyle.italic),
                          ),
                        ),
                      ],
                    ),
                  ],
                  _section(words.sectionMoodNeeds),
                  _bar(words.barMood(words.moodOf(l)), (l.mood + 5) / 10, const Color(0xFFFFC857), centered: true),
                  _bar(words.barFed, 1 - l.hunger, const Color(0xFF7BD389)),
                  _bar(words.barEnergy, l.energy, const Color(0xFF6CB4EE)),
                  _bar(words.barCompany, l.social, const Color(0xFFF49AC2)),
                  if (l.name == 'Mo') _bar(words.barCourage, l.courage, const Color(0xFFFF9F68)),
                  _section(words.sectionFriendships),
                  for (final o in [...cast.where((o) => o != l).map((o) => o.name), 'Dash'])
                    _bar(o, ((l.friendship[o] ?? 0) + 10) / 20, accentOf(o), centered: true, value: '${l.friendship[o] ?? 0}'),
                  if (data.goals.isNotEmpty) ...[_section(words.sectionGoals), for (final g in data.goals.take(5)) _bullet(g)],
                  _section(words.sectionWhy),
                  if (l.lastDecision == null)
                    Text(words.noDecision, style: _t(12, color: Colors.white54))
                  else
                    for (final (i, o) in l.lastDecision!.options.take(5).indexed)
                      _utility(words.choiceOf(o), o, i == 0, l.lastDecision!.options.first.utility),
                  _section(words.sectionKnows(l.name, data.knows.length)),
                  for (final k in data.knows) _fact(k, words.howOf(k)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(String s) => Padding(
    padding: const EdgeInsets.only(top: 14, bottom: 6),
    child: Text(
      s.toUpperCase(),
      style: _t(11, weight: FontWeight.w900, color: gold).copyWith(letterSpacing: 1.1),
    ),
  );

  Widget _bar(String label, double v, Color c, {bool centered = false, String? value}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2.5),
    child: Row(
      children: [
        SizedBox(
          width: 150,
          child: Text(label, style: _t(12), overflow: TextOverflow.ellipsis),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, box) {
              final w = box.maxWidth;
              final x = v.clamp(0.0, 1.0) * w;
              return Container(
                height: 9,
                decoration: BoxDecoration(color: const Color(0x22FFFFFF), borderRadius: BorderRadius.circular(5)),
                child: Stack(
                  children: [
                    if (centered)
                      Positioned(
                        left: x < w / 2 ? x : w / 2,
                        width: (x - w / 2).abs(),
                        top: 0,
                        bottom: 0,
                        child: Container(
                          decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(5)),
                        ),
                      )
                    else
                      Positioned(
                        left: 0,
                        width: x,
                        top: 0,
                        bottom: 0,
                        child: Container(
                          decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(5)),
                        ),
                      ),
                    if (centered)
                      Positioned(
                        left: w / 2 - 0.5,
                        width: 1,
                        top: 0,
                        bottom: 0,
                        child: Container(color: Colors.white38),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
        if (value != null)
          SizedBox(
            width: 28,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: _t(11, color: Colors.white60),
            ),
          ),
      ],
    ),
  );

  Widget _bullet(String s) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('•  ', style: _t(12.5, color: gold)),
        Expanded(child: Text(s, style: _t(12.5))),
      ],
    ),
  );

  Widget _utility(String label, DecisionOption o, bool chosen, double top) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        SizedBox(
          width: 44,
          child: Text(
            o.utility.toStringAsFixed(2),
            style: _t(11.5, weight: FontWeight.w800, color: chosen ? gold : Colors.white60),
          ),
        ),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: label,
                  style: _t(12.5, weight: chosen ? FontWeight.w900 : FontWeight.w600, color: chosen ? Colors.white : Colors.white70),
                ),
                if (o.why.isNotEmpty)
                  TextSpan(
                    text: '  ${o.why}',
                    style: _t(11.5, color: Colors.white54),
                  ),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  Widget _fact(KnownFact k, String how) {
    final heard = k.knowing?.how == 'told' || k.knowing?.how == 'overheard';
    final (tag, color) = switch (k.how) {
      _ when k.secret => (how, const Color(0xFFFF8FA3)),
      _ when !k.believes => (how, const Color(0xFF9A97A6)),
      _ when heard => (how, const Color(0xFFFFC857)),
      _ => (how, const Color(0xFF9EE6C2)),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            k.text,
            style: _t(
              12.5,
              color: k.believes ? Colors.white : Colors.white54,
            ).copyWith(decoration: k.believes ? null : TextDecoration.lineThrough, decorationColor: Colors.white38),
          ),
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(6)),
            child: Text(
              tag,
              style: _t(10.5, weight: FontWeight.w800, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------ small bits

class Notice extends StatelessWidget {
  const Notice({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => _Card(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Text(text, style: _t(13.5, weight: FontWeight.w700)),
  );
}

class HelpHint extends StatelessWidget {
  const HelpHint({super.key});

  @override
  Widget build(BuildContext context) => _Card(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    child: Text(
      L10n.of(context).helpHint,
      textAlign: TextAlign.center,
      style: _t(11, color: Colors.white70),
    ),
  );
}

/// The loading card: progress while models load, or what is missing.
class LoadingCard extends StatelessWidget {
  const LoadingCard({super.key, required this.label, required this.progress, this.missing, this.error, this.onCanned, this.onQuit});

  final String label;
  final double progress;
  final List<String>? missing;
  final String? error;
  final VoidCallback? onCanned;
  final VoidCallback? onQuit;

  @override
  Widget build(BuildContext context) {
    final words = L10n.of(context);
    final problem = missing != null || error != null;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF2B3A67), Color(0xFFE8A87C)]),
      ),
      alignment: Alignment.center,
      child: _Card(
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 22),
        child: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                words.appTitle,
                style: _t(34, weight: FontWeight.w900, color: gold),
              ),
              Text(words.loadingTagline, style: _t(14, color: Colors.white70)),
              const SizedBox(height: 22),
              if (!problem) ...[
                Text(label, style: _t(14)),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress <= 0 ? null : progress,
                    minHeight: 10,
                    color: gold,
                    backgroundColor: const Color(0x33FFFFFF),
                  ),
                ),
              ],
              if (missing != null) ...[
                Text(
                  words.modelsNotFoundTitle,
                  style: _t(17, weight: FontWeight.w900, color: const Color(0xFFFF8FA3)),
                ),
                const SizedBox(height: 8),
                Text(words.modelsMissing(missing!.join(', ')), style: _t(13)),
                const SizedBox(height: 6),
                Text(label, style: _t(12, color: Colors.white70)),
              ],
              if (error != null) ...[
                Text(
                  words.modelsFailedTitle,
                  style: _t(17, weight: FontWeight.w900, color: const Color(0xFFFF8FA3)),
                ),
                const SizedBox(height: 8),
                Text(error!, style: _t(12.5)),
              ],
              if (problem) ...[
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (onQuit != null) TextButton(onPressed: onQuit, child: Text(words.quit)),
                    const SizedBox(width: 8),
                    if (onCanned != null) FilledButton(onPressed: onCanned, child: Text(words.playWithoutAi)),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
