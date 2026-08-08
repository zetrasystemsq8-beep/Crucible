import 'package:flutter/foundation.dart';
import '../../core/groq_client.dart';
import '../../core/error_handler.dart';
import '../../core/connectivity.dart';

/// ---------- The Idea Canvas ----------

class IdeaCanvasData {
  IdeaCanvasData({
    required this.title,
    required this.oneSentence,
    required this.problem,
    required this.currentSolution,
    required this.mySolution,
    required this.whyItWins,
    required this.evidence,
    required this.unknowns,
  });

  final String title;
  final String oneSentence;
  final String problem;
  final String currentSolution;
  final String mySolution;
  final String whyItWins;
  final String evidence;
  final String unknowns;

  String toIdeaContent() => '''
Title: $title
One-sentence pitch: $oneSentence
Problem: $problem
Current solutions in the world: $currentSolution
My solution: $mySolution
Why it wins: $whyItWins
Evidence so far: $evidence
Known unknowns: $unknowns
''';
}

class IdeaVersion {
  IdeaVersion({
    required this.versionNumber,
    required this.content,
    required this.createdAt,
  });

  final int versionNumber;
  final String content;
  final DateTime createdAt;
}

/// ---------- Dossier ----------

enum FindingTag { assumption, evidenceGap, contradiction, risk, novelty }

class Finding {
  Finding({required this.tag, required this.text});
  final FindingTag tag;
  final String text;
}

class JudgeReport {
  JudgeReport({
    required this.strongestArguments,
    required this.weakestArguments,
    required this.unsupportedAssumptions,
    required this.contradictions,
    required this.unansweredQuestions,
    required this.suggestedExperiments,
    required this.readinessSummary,
  });

  final List<String> strongestArguments;
  final List<String> weakestArguments;
  final List<String> unsupportedAssumptions;
  final List<String> contradictions;
  final List<String> unansweredQuestions;
  final List<String> suggestedExperiments;
  final String readinessSummary;

  factory JudgeReport.fromRawText(String raw) {
    List<String> section(String label) {
      final pattern =
          RegExp('$label:(.*?)(?=\\n[A-Z][a-zA-Z ]+:|\$)', dotAll: true);
      final match = pattern.firstMatch(raw);
      if (match == null) return [];
      return match
          .group(1)!
          .split('\n')
          .map((l) => l.trim().replaceFirst(RegExp(r'^[-*]\s*'), ''))
          .where((l) => l.isNotEmpty)
          .toList();
    }

    return JudgeReport(
      strongestArguments: section('Strongest Arguments'),
      weakestArguments: section('Weakest Arguments'),
      unsupportedAssumptions: section('Unsupported Assumptions'),
      contradictions: section('Contradictions'),
      unansweredQuestions: section('Unanswered Questions'),
      suggestedExperiments: section('Suggested Experiments'),
      readinessSummary: section('Readiness Summary').join(' '),
    );
  }
}

/// ---------- Arena transcript ----------

class ArenaMessage {
  ArenaMessage({
    required this.fromZetra,
    required this.text,
    this.isHold = false,
    this.isReport = false,
    this.stageLabel,
  });

  final bool fromZetra;
  final String text;
  final bool isHold;
  final bool isReport;
  final String? stageLabel;
}

/// ---------- Zetra: the Challenger ----------

class ZetraTurn {
  ZetraTurn({required this.advance, required this.tag, required this.text});
  final bool advance;
  final FindingTag tag;
  final String text;
}

enum IntakeVerdict { serious, notSerious }

class IntakeCheck {
  IntakeCheck({required this.verdict, required this.reason});
  final IntakeVerdict verdict;
  final String reason;
}

class ZetraService {
  ZetraService(this._client);
  final GroqClient _client;
  static const model = 'llama-3.3-70b-versatile';

  static const stageLabels = [
    'Assumptions',
    'Evidence',
    'Novelty',
    'Viability',
    'Synthesis',
  ];
  static const totalStages = 5;

  Future<IntakeCheck> classifyIntake(String ideaContent) async {
    final messages = <Map<String, String>>[
      {
        'role': 'system',
        'content': '''
You are Zetra's intake gate for the Crucible platform.
Decide if the following submission is a genuine idea, invention, theory,
business concept, or claim that deserves serious pressure-testing — or if
it is gibberish, random characters, a joke, or placeholder text with no
real content.

When in doubt, prefer SERIOUS — this gate is only meant to catch obvious
non-ideas, not to judge idea quality. Weak or underdeveloped ideas should
still pass through and get pressure-tested, not be rejected here.

Respond with exactly one line, no other text:
SERIOUS: <one sentence why>
or
NOT_SERIOUS: <one sentence why>
''',
      },
      {'role': 'user', 'content': 'Submission:\n$ideaContent'},
    ];

    final raw = await _client.chat(
      model: model,
      messages: messages,
      temperature: 0.1,
      maxTokens: 100,
    );

    final upper = raw.toUpperCase();
    final isSerious = upper.contains('NOT_SERIOUS') ? false : upper.contains('SERIOUS');
    final reason = raw.contains(':') ? raw.split(':').skip(1).join(':').trim() : raw.trim();

    return IntakeCheck(
      verdict: isSerious ? IntakeVerdict.serious : IntakeVerdict.notSerious,
      reason: reason,
    );
  }

  static const _systemPrompt = '''
You are Zetra, an adversarial reasoning AI inside the Crucible platform.
Your only purpose is to pressure-test the idea the user presents. You are
respectful but extremely difficult to convince, and you do not let weak
answers slide.

You will be told the current stage focus and, if this is not the first
challenge, the user's most recent reply.

Your response MUST be exactly this format, nothing else:
[ADVANCE] or [HOLD]
[ASSUMPTION] or [EVIDENCE_GAP] or [CONTRADICTION] or [RISK] or [NOVELTY]
<your challenge text>

Rules for the first line:
- If there is no prior reply yet (this is the opening challenge), always
  output [ADVANCE].
- Output [ADVANCE] ONLY if the user's most recent reply gave real
  reasoning, a specific mechanism, data, or a concrete answer that
  actually engages the challenge.
- Output [HOLD] if the reply was vague, a bare assertion, an
  acknowledgement with no content, off-topic, or a non-answer. If you
  HOLD, name specifically what was missing and press the exact same
  issue again, harder. Do not quote or repeat your own prior message
  verbatim — restate the core issue freshly, in new words.
- Never soften a HOLD to be polite. A weak answer must not advance.

Rules for the challenge text:
- Raise exactly one issue. Do not summarize what they said back to them.
- Never declare the idea good or bad. Your job is pressure, not verdicts.
- Keep it to 2-4 sentences.
- ALWAYS include both bracket tags on their own line before your text,
  in the exact order shown above. Never omit the second (category) tag.
''';

  Future<ZetraTurn> challenge({
    required String ideaContent,
    required List<Map<String, String>> priorTurns,
    required int stageIndex,
  }) async {
    final stage = stageLabels[(stageIndex - 1).clamp(0, totalStages - 1)];
    final focusNote = 'Current stage: $stage.';

    final messages = <Map<String, String>>[
      {'role': 'system', 'content': '$_systemPrompt\n$focusNote'},
      {'role': 'user', 'content': 'The idea under review:\n$ideaContent'},
      ...priorTurns,
    ];

    final raw = await _client.chat(model: model, messages: messages, temperature: 0.5);
    final trimmed = raw.trim();

    final tagPattern = RegExp(r'^\s*\[([A-Za-z_]+)\]\s*');
    final foundTags = <String>[];
    String remaining = trimmed;
    while (true) {
      final m = tagPattern.firstMatch(remaining);
      if (m == null) break;
      foundTags.add(m.group(1)!.toUpperCase());
      remaining = remaining.substring(m.end);
    }

    final advance = foundTags.contains('ADVANCE');

    const categoryNames = {
      'ASSUMPTION', 'EVIDENCE_GAP', 'CONTRADICTION', 'RISK', 'NOVELTY',
    };
    final categoryTag = foundTags.firstWhere(
      (t) => categoryNames.contains(t),
      orElse: () => '',
    );
    final tag = switch (categoryTag) {
      'ASSUMPTION' => FindingTag.assumption,
      'EVIDENCE_GAP' => FindingTag.evidenceGap,
      'CONTRADICTION' => FindingTag.contradiction,
      'RISK' => FindingTag.risk,
      'NOVELTY' => FindingTag.novelty,
      _ => FindingTag.assumption,
    };

    final text = remaining.trim().isNotEmpty ? remaining.trim() : trimmed;

    return ZetraTurn(advance: advance, tag: tag, text: text);
  }
}

/// ---------- Arbiter: the Judge ----------

class ArbiterService {
  ArbiterService(this._client);
  final GroqClient _client;
  static const model = 'llama-3.1-8b-instant';

  static const _systemPrompt = '''
You are Arbiter, the Judge AI inside the Crucible platform.
You never debate. You only observe and analyze.

Output your analysis using exactly these labeled sections, each followed
by a dash-bulleted list (or a single sentence for Readiness Summary):

Strongest Arguments:
Weakest Arguments:
Unsupported Assumptions:
Contradictions:
Unanswered Questions:
Suggested Experiments:
Readiness Summary:

Never state the invention is true or false. Only assess whether the
reasoning presented is strong enough to justify further investigation.
If the discussion contains mostly evasive or low-content replies, say so
plainly in the Readiness Summary rather than being generous.
''';

  Future<JudgeReport> judge({
    required String ideaContent,
    required List<Map<String, String>> fullTranscript,
  }) async {
    final messages = <Map<String, String>>[
      {'role': 'system', 'content': _systemPrompt},
      {'role': 'user', 'content': 'The idea under review:\n$ideaContent'},
      ...fullTranscript,
      {'role': 'user', 'content': 'Produce your full structured report now.'},
    ];

    final raw = await _client.chat(
      model: model,
      messages: messages,
      temperature: 0.3,
      maxTokens: 1500,
    );
    return JudgeReport.fromRawText(raw);
  }
}

/// ---------- Controller ----------

class CrucibleController extends ChangeNotifier {
  CrucibleController({
    required GroqClient client,
    required this.id,
    required this.title,
    required this.oneLiner,
    this.onSessionChanged,
  })  : _zetra = ZetraService(client),
        _arbiter = ArbiterService(client);

  final String id;
  final String title;
  final String oneLiner;

  final void Function(Map<String, dynamic> session)? onSessionChanged;

  final ZetraService _zetra;
  final ArbiterService _arbiter;

  final List<IdeaVersion> versions = [];
  final List<Map<String, String>> _transcript = [];
  final List<Finding> findings = [];
  final List<String> evidenceLog = [];
  final List<ArenaMessage> messages = [];

  int stageIndex = 1;
  bool isLoading = false;
  bool isCheckingIntake = false;
  String? errorMessage;
  String? rejectionReason;
  JudgeReport? report;

  IdeaVersion? get currentVersion => versions.isEmpty ? null : versions.last;
  int get totalStages => ZetraService.totalStages;
  List<String> get stageLabels => ZetraService.stageLabels;
  bool get canRequestJudgment => stageIndex >= 3;

  bool get isProven {
    if (report == null) return false;
    final finalStages = {stageLabels[3], stageLabels[4]};
    return !messages.any((m) => m.isHold && finalStages.contains(m.stageLabel));
  }

  @override
  void notifyListeners() {
    super.notifyListeners();
    if (versions.isNotEmpty) {
      onSessionChanged?.call(toJson());
    }
  }

  bool _isTriviallyWeak(String reply) {
    final words = reply.trim().split(RegExp(r'\s+'));
    if (words.length <= 2) return true;
    const fillerOnly = {'yes', 'no', 'ok', 'okay', 'sure', 'true', 'idk', 'maybe', 'hi', 'hello'};
    if (words.length <= 4 &&
        words.every((w) => fillerOnly.contains(w.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '')))) {
      return true;
    }
    return false;
  }

  Future<void> startPressureTest(IdeaCanvasData canvas) async {
    isCheckingIntake = true;
    errorMessage = null;
    rejectionReason = null;
    notifyListeners();

    if (!await hasInternetConnection()) {
      errorMessage = noConnectionMessage;
      isCheckingIntake = false;
      notifyListeners();
      return;
    }

    final content = canvas.toIdeaContent();
    try {
      final check = await _zetra.classifyIntake(content);
      if (check.verdict == IntakeVerdict.notSerious) {
        rejectionReason = check.reason;
        isCheckingIntake = false;
        notifyListeners();
        return;
      }
    } catch (e) {
      errorMessage = friendlyMessage(e);
    }

    isCheckingIntake = false;
    versions.add(IdeaVersion(versionNumber: 1, content: content, createdAt: DateTime.now()));
    if (canvas.evidence.trim().isNotEmpty) evidenceLog.add(canvas.evidence.trim());
    notifyListeners();
    await _requestChallenge();
  }

  Future<void> _requestChallenge() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    if (!await hasInternetConnection()) {
      errorMessage = noConnectionMessage;
      isLoading = false;
      notifyListeners();
      return;
    }

    try {
      final turn = await _zetra.challenge(
        ideaContent: currentVersion!.content,
        priorTurns: _transcript,
        stageIndex: stageIndex,
      );
      _transcript.add({'role': 'assistant', 'content': '[${turn.advance ? "ADVANCE" : "HOLD"}] ${turn.text}'});
      findings.add(Finding(tag: turn.tag, text: turn.text));

      final wasReplyExpected = messages.any((m) => !m.fromZetra);
      final isHold = wasReplyExpected && !turn.advance;

      messages.add(ArenaMessage(
        fromZetra: true,
        text: turn.text,
        isHold: isHold,
        stageLabel: stageLabels[stageIndex - 1],
      ));

      if (wasReplyExpected && turn.advance && stageIndex < totalStages) {
        stageIndex += 1;
      }
    } catch (e) {
      errorMessage = friendlyMessage(e);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> replyToChallenge(String text) async {
    if (text.trim().isEmpty) return;
    messages.add(ArenaMessage(fromZetra: false, text: text.trim()));

    if (_isTriviallyWeak(text)) {
      messages.add(ArenaMessage(
        fromZetra: true,
        text: "That's not an answer — I need real reasoning, a mechanism, or evidence for the point above. Try again.",
        isHold: true,
        stageLabel: stageLabels[stageIndex - 1],
      ));
      notifyListeners();
      return;
    }

    _transcript.add({'role': 'user', 'content': text.trim()});
    notifyListeners();
    await _requestChallenge();
  }

  void addEvidence(String text) {
    if (text.trim().isEmpty) return;
    evidenceLog.add(text.trim());
    _transcript.add({'role': 'user', 'content': 'Additional evidence submitted: ${text.trim()}'});
    notifyListeners();
  }

  void submitRevision(String newContent) {
    if (newContent.trim().isEmpty) return;
    versions.add(IdeaVersion(
      versionNumber: versions.length + 1,
      content: newContent.trim(),
      createdAt: DateTime.now(),
    ));
    notifyListeners();
  }

  Future<void> requestJudgment() async {
    if (currentVersion == null) return;
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    if (!await hasInternetConnection()) {
      errorMessage = noConnectionMessage;
      isLoading = false;
      notifyListeners();
      return;
    }

    try {
      report = await _arbiter.judge(
        ideaContent: currentVersion!.content,
        fullTranscript: _transcript,
      );
      messages.add(ArenaMessage(fromZetra: true, text: _reportToText(report!), isReport: true));
    } catch (e) {
      errorMessage = friendlyMessage(e);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  String _reportToText(JudgeReport r) {
    String block(String title, List<String> items) =>
        items.isEmpty ? '' : '$title\n${items.map((i) => '• $i').join('\n')}\n\n';

    return '${block('Strongest Arguments', r.strongestArguments)}'
        '${block('Weakest Arguments', r.weakestArguments)}'
        '${block('Unsupported Assumptions', r.unsupportedAssumptions)}'
        '${block('Contradictions', r.contradictions)}'
        '${block('Unanswered Questions', r.unansweredQuestions)}'
        '${block('Suggested Experiments', r.suggestedExperiments)}'
        '${r.readinessSummary.isNotEmpty ? 'Readiness: ${r.readinessSummary}' : ''}'
        .trim();
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'oneLiner': oneLiner,
        'stageIndex': stageIndex,
        'totalStages': totalStages,
        'versions': versions
            .map((v) => {
                  'versionNumber': v.versionNumber,
                  'content': v.content,
                  'createdAt': v.createdAt.toIso8601String(),
                })
            .toList(),
        'transcript': _transcript,
        'messages': messages
            .map((m) => {
                  'fromZetra': m.fromZetra,
                  'text': m.text,
                  'isHold': m.isHold,
                  'isReport': m.isReport,
                  'stageLabel': m.stageLabel,
                })
            .toList(),
        'findings': findings.map((f) => {'tag': f.tag.name, 'text': f.text}).toList(),
        'evidenceLog': evidenceLog,
        'report': report == null
            ? null
            : {
                'strongestArguments': report!.strongestArguments,
                'weakestArguments': report!.weakestArguments,
                'unsupportedAssumptions': report!.unsupportedAssumptions,
                'contradictions': report!.contradictions,
                'unansweredQuestions': report!.unansweredQuestions,
                'suggestedExperiments': report!.suggestedExperiments,
                'readinessSummary': report!.readinessSummary,
              },
      };

  factory CrucibleController.fromJson(
    Map<String, dynamic> json, {
    required GroqClient client,
    void Function(Map<String, dynamic> session)? onSessionChanged,
  }) {
    final controller = CrucibleController(
      client: client,
      id: json['id'] as String,
      title: json['title'] as String,
      oneLiner: json['oneLiner'] as String,
      onSessionChanged: onSessionChanged,
    );

    controller.stageIndex = json['stageIndex'] as int? ?? 1;

    for (final v in (json['versions'] as List<dynamic>)) {
      controller.versions.add(IdeaVersion(
        versionNumber: v['versionNumber'] as int,
        content: v['content'] as String,
        createdAt: DateTime.parse(v['createdAt'] as String),
      ));
    }

    controller._transcript.addAll(
      (json['transcript'] as List<dynamic>).map((e) => Map<String, String>.from(e as Map)),
    );

    for (final m in (json['messages'] as List<dynamic>)) {
      controller.messages.add(ArenaMessage(
        fromZetra: m['fromZetra'] as bool,
        text: m['text'] as String,
        isHold: m['isHold'] as bool? ?? false,
        isReport: m['isReport'] as bool? ?? false,
        stageLabel: m['stageLabel'] as String?,
      ));
    }

    for (final f in (json['findings'] as List<dynamic>)) {
      final tagName = f['tag'] as String;
      final tag = FindingTag.values.firstWhere((t) => t.name == tagName, orElse: () => FindingTag.assumption);
      controller.findings.add(Finding(tag: tag, text: f['text'] as String));
    }

    controller.evidenceLog.addAll((json['evidenceLog'] as List<dynamic>).cast<String>());

    final reportJson = json['report'] as Map<String, dynamic>?;
    if (reportJson != null) {
      controller.report = JudgeReport(
        strongestArguments: (reportJson['strongestArguments'] as List).cast<String>(),
        weakestArguments: (reportJson['weakestArguments'] as List).cast<String>(),
        unsupportedAssumptions: (reportJson['unsupportedAssumptions'] as List).cast<String>(),
        contradictions: (reportJson['contradictions'] as List).cast<String>(),
        unansweredQuestions: (reportJson['unansweredQuestions'] as List).cast<String>(),
        suggestedExperiments: (reportJson['suggestedExperiments'] as List).cast<String>(),
        readinessSummary: reportJson['readinessSummary'] as String,
      );
    }

    return controller;
  }
}
