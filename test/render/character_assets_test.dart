import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:llama_village/render/llama_rig.dart';

/// The JSON chunk of a .glb, plus helpers over it.
class Glb {
  Glb(String path) {
    final bytes = File(path).readAsBytesSync();
    final view = ByteData.sublistView(bytes);
    final length = view.getUint32(12, Endian.little);
    json = jsonDecode(utf8.decode(bytes.sublist(20, 20 + length))) as Map<String, dynamic>;
  }

  late final Map<String, dynamic> json;

  List<dynamic> get nodes => json['nodes'] as List<dynamic>;
  List<String> get nodeNames => [for (final n in nodes) (n as Map)['name'] as String];

  /// Child name -> parent name.
  Map<String, String> get parents => {
    for (final n in nodes)
      for (final c in ((n as Map)['children'] as List<dynamic>? ?? const [])) nodeNames[c as int]: n['name'] as String,
  };

  Set<String> get joints => {for (final j in ((json['skins'] as List).first as Map)['joints'] as List) nodeNames[j as int]};

  Map<String, Map<String, dynamic>> get animations => {
    for (final a in json['animations'] as List) (a as Map)['name'] as String: a.cast<String, dynamic>(),
  };

  Set<String> animatedNodes(String clip) => {
    for (final c in animations[clip]!['channels'] as List) nodeNames[((c as Map)['target'] as Map)['node'] as int],
  };

  double duration(String clip) {
    var end = 0.0;
    for (final s in animations[clip]!['samplers'] as List) {
      final acc = (json['accessors'] as List)[(s as Map)['input'] as int] as Map;
      end = end < (acc['max'] as List).first ? ((acc['max'] as List).first as num).toDouble() : end;
    }
    return end;
  }

  List<String> morphTargets(String mesh) {
    final m = (json['meshes'] as List).firstWhere((m) => (m as Map)['name'] == mesh) as Map;
    return [for (final t in (m['extras'] as Map)['targetNames'] as List) t as String];
  }

  int get triangles {
    var n = 0;
    for (final m in json['meshes'] as List) {
      for (final p in (m as Map)['primitives'] as List) {
        n += (((json['accessors'] as List)[(p as Map)['indices'] as int] as Map)['count'] as int) ~/ 3;
      }
    }
    return n;
  }
}

void main() {
  final llamas = {for (final MapEntry(:key, :value) in llamaSpecs.entries) key: Glb('assets/llama_${value.id}.glb')};

  test('every llama shares one skeleton', () {
    final first = llamas.values.first;
    expect(first.joints, containsAll(['spine', 'neck', 'head', 'leg_HR_lower', ...proceduralBones]));
    for (final MapEntry(key: name, value: glb) in llamas.entries) {
      expect(glb.joints, first.joints, reason: name);
      final p = glb.parents;
      for (final j in first.joints) {
        expect(p[j], first.parents[j], reason: '$name: parent of $j');
      }
    }
  });

  test('the clips never key the bones the game drives', () {
    for (final MapEntry(key: name, value: glb) in llamas.entries) {
      expect(glb.animations.keys, containsAll(['Idle', 'Walk', 'Gallop']), reason: name);
      for (final clip in glb.animations.keys) {
        expect(glb.animatedNodes(clip).intersection(proceduralBones.toSet()), isEmpty, reason: '$name $clip');
        expect(glb.animatedNodes(clip), containsAll(['spine', 'neck', 'head', 'leg_FL_upper']), reason: '$name $clip');
      }
    }
  });

  test('each llama walks to the gait the game expects', () {
    for (final MapEntry(key: name, value: glb) in llamas.entries) {
      expect(glb.duration('Walk'), closeTo(llamaSpecs[name]!.walkSeconds, 1e-3), reason: name);
    }
  });

  test('faces carry the expression morphs in order', () {
    for (final MapEntry(key: name, value: glb) in llamas.entries) {
      expect(glb.morphTargets('Face'), llamaMorphs, reason: name);
    }
  });

  test('about 20k triangles per llama, accessories included', () {
    for (final MapEntry(key: name, value: glb) in llamas.entries) {
      expect(glb.triangles, lessThanOrEqualTo(20000), reason: name);
    }
  });

  test('accessories ride on bones', () {
    final pip = llamas['Pip']!;
    expect(pip.parents['Scarf'], 'neck');
    expect(pip.parents['ScarfTail'], 'scarf');
    for (final MapEntry(key: name, value: glb) in llamas.entries) {
      final gear = glb.nodeNames.where((n) => n.startsWith('Acc_')).toList();
      expect(gear, isNotEmpty, reason: name);
      for (final g in gear) {
        expect(g, 'Acc_${glb.parents[g]}', reason: '$name: $g');
      }
    }
    expect(llamas['Mo']!.nodeNames, isNot(contains('Scarf')));
  });

  test("Dash's rig, clips and face", () {
    final dash = Glb('assets/dash.glb');
    expect(dash.joints, containsAll(['body', 'head', 'wing_L', 'wing_R', 'tail', 'lid_L', 'lid_R']));
    expect(dash.animations.keys, containsAll(['Fly', 'Hover', 'Happy', 'Sad']));
    for (final clip in dash.animations.keys) {
      expect(dash.animatedNodes(clip), containsAll(['wing_L', 'wing_R']), reason: clip);
      expect(dash.animatedNodes(clip).intersection({'lid_L', 'lid_R'}), isEmpty, reason: clip);
    }
    expect(dash.morphTargets('Face'), ['Happy', 'Sad']);
  });

  test('every llama has a portrait', () {
    for (final s in llamaSpecs.values) {
      expect(File('assets/portraits/${s.id}.png').existsSync(), isTrue, reason: s.id);
    }
  });
}
