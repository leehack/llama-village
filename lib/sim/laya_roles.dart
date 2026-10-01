const List<String> reactionLevels = ['offended', 'annoyed', 'indifferent', 'pleased', 'delighted'];

/// A topic the opener could bring up, with the features the rules use.
class TopicOption {
  const TopicOption(
    this.id,
    this.short,
    this.text, {
    this.goal = 0,
    this.ownSecret = false,
    this.confessing = false,
    this.fromListener = false,
    this.aboutListener = false,
    this.recent = false,
    this.juicy = false,
    this.public = false,
    this.toldListener = false,
    this.raisedLately = 0,
  });
  final String id;
  final String short;
  final String text;

  /// Weight of the opener's goal that names this topic, 0 when none.
  final double goal;
  final bool ownSecret;
  final bool confessing;
  final bool fromListener;
  final bool aboutListener;
  final bool recent;
  final bool juicy;
  final bool public;

  /// The opener already brought this up with this listener.
  final bool toldListener;

  /// How often the opener brought this up with anyone in the last few hours.
  final int raisedLately;
}

class TopicCase {
  const TopicCase(
    this.speaker,
    this.traits,
    this.listener,
    this.feeling,
    this.place,
    this.time,
    this.goals,
    this.options, {
    this.label = const {},
  });
  final String speaker;
  final String traits;
  final String listener;
  final String feeling;
  final String place;
  final String time;
  final List<String> goals;
  final List<TopicOption> options;

  /// Acceptable answers, for the hand-labelled evaluation.
  final Set<String> label;
}

double topicScore(TopicCase c, TopicOption o) {
  var s = 0.0;
  s += o.goal * 2;
  if (o.ownSecret && !o.confessing) s -= 1.5;
  if (o.fromListener) s -= 1.0;
  if (o.public) s -= 0.6;
  if (o.aboutListener) s += 0.3;
  if (o.recent) s += 0.3;
  if (o.juicy && (c.traits.contains('nosy') || c.traits.contains('chatty'))) s += 0.6;
  // Novelty: a topic already told to this listener, or raised over and
  // over today, outweighs even a strong goal ("the bread rumour is false"
  // to everyone, every hour).
  if (o.toldListener) s -= 2.5;
  s -= 0.7 * o.raisedLately;
  return s;
}

String ruleTopic(TopicCase c) {
  var best = c.options.first;
  for (final o in c.options) {
    if (topicScore(c, o) > topicScore(c, best)) best = o;
  }
  return best.id;
}

String topicState(TopicCase c) => [
  '${c.speaker} (${c.traits}) meets ${c.listener} at the ${c.place} at ${c.time}. ${c.speaker} ${c.feeling} ${c.listener}.',
  if (c.goals.isNotEmpty) '${c.speaker} wants to: ${c.goals.join('; ')}.',
].join(' ');

/// Rules veto the options a llama would not volunteer (its own secret unless
/// confessing, news the listener told it, something it already told this
/// listener, or a topic it keeps raising); Laya picks among the rest.
TopicCase vetoed(TopicCase c) {
  final kept = c.options.where((o) => !(o.ownSecret && !o.confessing) && !o.fromListener && !o.toldListener && o.raisedLately < 2).toList();
  return kept.isEmpty ? c : TopicCase(c.speaker, c.traits, c.listener, c.feeling, c.place, c.time, c.goals, kept, label: c.label);
}

/// Picks a casual topic among already-vetoed options; the app backs it with
/// the Laya decision model.
abstract interface class TopicChooser {
  /// Returns the id of one of [c]'s options.
  Future<String> choose(TopicCase c);
}

/// The topic policy kept in the sim: a strong goal topic (weight >= 0.3)
/// is chosen by the rules; casual talk goes to [laya] over the vetoed
/// options when it is available.
Future<(String, String)> gatedTopic(TopicChooser? laya, TopicCase c) async {
  final rule = ruleTopic(c);
  final strong = c.options.firstWhere((o) => o.id == rule).goal >= 0.3;
  if (strong || laya == null) return (rule, 'rules');
  final kept = vetoed(c);
  if (kept.options.length == 1) return (kept.options.single.id, 'rules');
  try {
    final choice = await laya.choose(kept);
    if (kept.options.any((o) => o.id == choice)) return (choice, 'laya');
  } catch (_) {
    // A failed model call falls back to the rules.
  }
  return (rule, 'rules');
}

class ReactionCase {
  const ReactionCase(
    this.name,
    this.traits,
    this.likes,
    this.intent,
    this.text, {
    this.feelingToDash = 0,
    this.mood = 0,
    this.giftLiked = false,
    this.subjectFriendship,
    this.label,
  });
  final String name;
  final String traits;
  final String likes;
  final String intent;
  final String text;
  final int feelingToDash;
  final int mood;
  final bool giftLiked;

  /// For gossip and tell: how the listener feels about the llama it is about.
  final int? subjectFriendship;

  /// Hand label, 0-4, for the evaluation.
  final int? label;
}

int ruleReaction(ReactionCase c) {
  bool has(String t) => c.traits.contains(t);
  var level = switch (c.intent) {
    'compliment' => has('vain') ? 4 : (has('grumpy') ? 2 : 3),
    'gift' => c.giftLiked ? 4 : (has('grumpy') ? 2 : 3),
    'help' => has('proud') ? 2 : 3,
    'gossip' =>
      has('nosy')
          ? 4
          : (c.subjectFriendship ?? 0) >= 5
          ? 1
          : (has('kind') ? 1 : 2),
    'tell' => has('nosy') ? 4 : 3,
    'praise' => (c.subjectFriendship ?? 0) <= -3 ? 1 : (has('grumpy') ? 2 : 3),
    'tease' =>
      has('playful')
          ? 3
          : has('grumpy')
          ? 0
          : (has('vain') || has('shy') || has('anxious'))
          ? 1
          : 2,
    _ => 2,
  };
  if (c.mood <= -3) level -= 1;
  if (c.feelingToDash >= 5) level += 1;
  return level.clamp(0, 4);
}
