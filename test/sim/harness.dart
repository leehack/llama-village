import 'package:llama_village/sim/canned.dart';
import 'package:llama_village/sim/village.dart';

/// A village on canned models where one game minute is 10 ms.
Village testVillage({int seed = 11, bool autoAck = true}) =>
    Village(chat: CannedChat(), embed: HashEmbed(), seed: seed, msPerMinute: 10, autoAck: autoAck);

/// Lets queued model futures resolve.
Future<void> settle() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

/// Advances [v] by [minutes] game minutes in 1-minute steps, letting model
/// work land between steps.
Future<void> runMinutes(Village v, int minutes) async {
  for (var i = 0; i < minutes; i++) {
    v.advance(v.msPerMinute / v.timeScale);
    await settle();
  }
}
