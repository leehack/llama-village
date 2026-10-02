import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:llamadart/llamadart.dart';

import '../sim/laya_roles.dart';
import '../sim/model.dart';

/// Where the model files are. Every path can be set by an environment
/// variable or by `~/.config/llama-village/models.json` (same keys); the
/// defaults look in the llamadart model cache.
class ModelConfig {
  ModelConfig({required this.chat, required this.embed, this.layaModel, this.layaHead, required this.searched});

  final String? chat;
  final String? embed;
  final String? layaModel;
  final String? layaHead;

  /// Where the defaults were looked for, for the "missing" message.
  final List<String> searched;

  static const String chatFile = 'gemma-4-E2B-it-Q4_K_S.gguf';
  static const String embedFile = 'embeddinggemma-300M-Q8_0.gguf';
  static const String layaFile = 'laya-Q8_0.gguf';
  static const String layaHeadFile = 'laya-head.safetensors';
  static String get configPath => '${Platform.environment['HOME']}/.config/llama-village/models.json';

  bool get hasRequired => chat != null && embed != null;
  bool get hasLaya => layaModel != null && layaHead != null;

  /// The missing required files, as file names.
  List<String> get missing => [if (chat == null) chatFile, if (embed == null) embedFile];

  static ModelConfig resolve({Map<String, String>? environment}) {
    final env = environment ?? Platform.environment;
    final file = <String, Object?>{};
    try {
      final f = File(configPath);
      if (f.existsSync()) file.addAll(jsonDecode(f.readAsStringSync()) as Map<String, Object?>);
    } catch (_) {
      // An unreadable config file is ignored; the defaults still apply.
    }
    String? setting(String key) => env[key] ?? file[key] as String?;
    final home = env['HOME'] ?? '';
    final cache = setting('VILLAGE_MODELS_DIR') ?? '$home/Library/Caches/llamadart/models';
    const layaDir = '/opt/UnitySrc/personal/llama/models/embed-evidence';
    String? existing(String? p) => p != null && File(p).existsSync() ? p : null;
    String? find(String dir, String name) {
      final direct = existing('$dir/$name');
      if (direct != null) return direct;
      final d = Directory(dir);
      if (!d.existsSync()) return null;
      for (final sub in d.listSync().whereType<Directory>()) {
        final p = existing('${sub.path}/$name');
        if (p != null) return p;
      }
      return null;
    }

    final layaOff = setting('VILLAGE_LAYA') == '0';
    final layaRoot = setting('VILLAGE_LAYA_DIR') ?? layaDir;
    return ModelConfig(
      chat: existing(setting('VILLAGE_CHAT_MODEL')) ?? find(cache, chatFile),
      embed: existing(setting('VILLAGE_EMBED_MODEL')) ?? find(cache, embedFile),
      layaModel: layaOff ? null : existing(setting('VILLAGE_LAYA_MODEL')) ?? find(layaRoot, layaFile),
      layaHead: layaOff ? null : existing(setting('VILLAGE_LAYA_HEAD')) ?? find(layaRoot, layaHeadFile),
      searched: [cache, layaRoot],
    );
  }
}

/// Loading progress: the stage (dialogue, embedding, laya or warmup) and a
/// 0-1 fraction.
typedef LoadProgress = void Function(String stage, double fraction);

/// The loaded engines behind the sim's model interfaces. [dispose] frees
/// every engine; the app awaits it before exiting, because ggml's Metal
/// teardown crashes if the process exits with models still loaded.
class VillageModels implements ChatModel, EmbedModel, TopicChooser {
  VillageModels._(this._chat, this._embed, this._layaEngine, this._decisions, this.description);

  final LlamaEngine _chat;
  final LlamaEngine _embed;
  final LlamaEngine? _layaEngine;
  final DecisionEngine? _decisions;

  /// "gemma-4-E2B (Metal) + EmbeddingGemma + Laya", for the HUD.
  final String description;
  bool get hasLaya => _decisions != null;
  Future<void>? _disposing;

  static Future<VillageModels> load(ModelConfig config, {LoadProgress? onProgress}) async {
    LlamaEngine.configureLogging(level: LlamaLogLevel.none);
    final opened = <LlamaEngine>[];
    DecisionEngine? decisions;
    Future<LlamaEngine> open(String path, {required int contextSize, int parallel = 1, int microBatch = 0}) async {
      final engine = LlamaEngine(LlamaBackend());
      opened.add(engine);
      await engine.loadModel(
        path,
        modelParams: ModelParams(
          contextSize: contextSize,
          gpuLayers: ModelParams.maxGpuLayers,
          maxParallelSequences: parallel,
          microBatchSize: microBatch,
        ),
      );
      return engine;
    }

    try {
      onProgress?.call('dialogue', 0.05);
      // Small prompt micro-batches keep each GPU submission short, so the
      // renderer's frames slip in between them instead of waiting: frames
      // that came late while the model generated were mostly behind prompt
      // micro-batches (about 35 ms of GPU each at 128 tokens, 14 ms at 32).
      // Below 32 a micro-batch costs no less and prompts read slower.
      final chat = await open(config.chat!, contextSize: 4096, microBatch: 32);
      onProgress?.call('embedding', 0.55);
      final embed = await open(config.embed!, contextSize: 2048, parallel: 8);
      LlamaEngine? laya;
      if (config.hasLaya) {
        onProgress?.call('laya', 0.7);
        try {
          laya = await open(config.layaModel!, contextSize: 512);
          decisions = await DecisionEngine.load(laya, headPath: config.layaHead!);
        } catch (_) {
          // Laya is optional: topics fall back to the rules.
          await decisions?.dispose();
          decisions = null;
          if (laya != null) {
            opened.remove(laya);
            await laya.dispose();
          }
          laya = null;
        }
      }
      final backend = await chat.getBackendName();
      final models = VillageModels._(
        chat,
        embed,
        laya,
        decisions,
        'gemma-4-E2B ($backend) · EmbeddingGemma${decisions != null ? ' · Laya' : ''}',
      );
      onProgress?.call('warmup', 0.85);
      await models.complete('Reply briefly.', 'Say hello.', maxTokens: 4, temp: 0.1, seed: 1);
      await models.embedBatch(const ['hello']);
      return models;
    } catch (_) {
      await decisions?.dispose();
      for (final e in opened) {
        await e.dispose();
      }
      rethrow;
    }
  }

  @override
  Future<String> complete(
    String system,
    String user, {
    required int maxTokens,
    required double temp,
    required int seed,
    List<String> stop = const [],
    Map<String, dynamic>? jsonSchema,
    void Function(String text)? onText,
  }) async {
    final format = jsonSchema == null
        ? null
        : LlamaStructuredOutput<Map<String, dynamic>>.jsonSchema(schema: jsonSchema, decoder: (j) => j).responseFormat;
    final buffer = StringBuffer();
    await for (final chunk in _chat.create(
      [
        LlamaChatMessage.fromText(role: LlamaChatRole.system, text: system),
        LlamaChatMessage.fromText(role: LlamaChatRole.user, text: user),
      ],
      enableThinking: false,
      responseFormat: format,
      params: GenerationParams(maxTokens: maxTokens, temp: temp, seed: seed, topP: 0.95, penalty: 1.1, stopSequences: stop),
    )) {
      for (final choice in chunk.choices) {
        final content = choice.delta.content;
        if (content != null) buffer.write(content);
      }
      onText?.call(buffer.toString());
    }
    return buffer.toString();
  }

  @override
  Future<List<List<double>>> embedBatch(List<String> texts) => _embed.embedBatch(texts);

  @override
  Future<String> choose(TopicCase c) async {
    final decisions = _decisions;
    if (decisions == null) throw StateError('Laya is not loaded');
    final r = await decisions.systemOne(
      state: topicState(c),
      questions: {
        'topic': DecisionQuestion.choice(
          'Which topic will ${c.speaker} bring up with ${c.listener}?',
          criteria: {
            for (final o in c.options)
              o.id:
                  '${o.text}${o.ownSecret ? ' (${c.speaker}\'s own secret)' : ''}${o.fromListener ? ' (${c.listener} told ${c.speaker} this)' : ''}',
          },
        ),
      },
    );
    return r.choices['topic']!.choice;
  }

  /// Stops whatever the engines are generating, so a game being left can
  /// release them quickly; the engines stay loaded.
  void cancel() {
    _chat.cancelGeneration();
    _embed.cancelGeneration();
  }

  /// Cancels generation and frees every engine. Safe to call twice.
  Future<void> dispose() => _disposing ??= _dispose();

  Future<void> _dispose() async {
    _chat.cancelGeneration();
    _embed.cancelGeneration();
    _layaEngine?.cancelGeneration();
    Future<void> quietly(Future<void> Function() f) async {
      try {
        await f().timeout(const Duration(seconds: 8));
      } catch (_) {
        // Keep freeing the others.
      }
    }

    final decisions = _decisions;
    if (decisions != null) await quietly(decisions.dispose);
    await quietly(_chat.dispose);
    await quietly(_embed.dispose);
    final laya = _layaEngine;
    if (laya != null) await quietly(laya.dispose);
  }
}
