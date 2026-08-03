import 'package:flutter/foundation.dart';
import '../../core/groq_client.dart';

/// ---------- The Idea Canvas (structured intake, replaces free-text chat) ----------

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

/// ---------- Dossier: structured findings pulled out of each challenge ----------

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

/// ---------- Zetra: the Challenger ----------

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

  static const _systemPrompt = '''
You are Zetra, an adversarial reasoning AI inside the Crucible platform.
Your only purpose is to pressure-test the idea the user presents.

Rules:
- Never insult the user. Be respectful but extremely difficult to convince.
- Raise exactly ONE issue per turn. Do not summarize what they said back to them.
- Every reply MUST start with exactly one tag, then a space, then your challenge:
  [ASSUMPTION] for an unproven premise, [EVIDENCE_GAP] for a claim lacking proof,
  [CONTRADICTION] for something inconsistent, [RISK] for a practical/economic risk,
  [NOVELTY] for a prior-art/originality concern.
- Never declare the idea good or bad. Your job is pressure, not verdicts.
''';

  Future<String> challenge({
    required String ideaContent,
    required List<Map<String, String>> priorTurns,
    required int stageIndex, // 1-5
  }) async {
    final stage = stageLabels[(stageIndex - 1).clamp(0, totalStages - 1)];
    final focusNote = 'Current stage: $stage. Focus your challenge accordingly.';

    final messages = <Map<String, String>>[
      {'role': 'system', 'content': '$_systemPrompt\n$focusNote'},
      {'role': 'user', 'content': 'The idea under review:\n$ideaContent'},
      ...priorTurns,
    ];

    return _client.chat(model: model, messages: messages, temperature: 0.6);
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
  CrucibleController({required GroqClient client})
      : _zetra = ZetraService(client),
        _arbiter = ArbiterService(client);

  final ZetraService _zetra;
  final ArbiterService _arbiter;

  final List<IdeaVersion> versions = [];
  final List<Map<String, String>> _transcript = [];
  final List<Finding> findings = [];
  final List<String> evidenceLog = [];

  String? currentChallenge;
  String? lastYourReply;
  int stageIndex = 1; // 1..5, drives the timeline
  bool isLoading = false;
  String? errorMessage;
  JudgeReport? report;

  IdeaVersion? get currentVersion => versions.isEmpty ? null : versions.last;
  int get totalStages => ZetraService.totalStages;
  List<String> get stageLabels => ZetraService.stageLabels;
  bool get canRequestJudgment => stageIndex >= 3; // allow judging from stage 3 on

  Future<void> startPressureTest(IdeaCanvasData canvas) async {
    versions.add(IdeaVersion(
      versionNumber: 1,
      content: canvas.toIdeaContent(),
      createdAt: DateTime.now(),
    ));
    if (canvas.evidence.trim().isNotEmpty) {
      evidenceLog.add(canvas.evidence.trim());
    }
    notifyListeners();
    await _requestChallenge();
  }

  Future<void> _requestChallenge() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final raw = await _zetra.challenge(
        ideaContent: currentVersion!.content,
        priorTurns: _transcript,
        stageIndex: stageIndex,
      );
      _transcript.add({'role': 'assistant', 'content': raw});

      final match = RegExp(r'^\[(\w+)\]\s*(.*)$', dotAll: true).firstMatch(raw);
      if (match != null) {
        final tagText = match.group(1)!.toUpperCase();
        final body = match.group(2)!.trim();
        currentChallenge = body;
        final tag = switch (tagText) {
          'ASSUMPTION' => FindingTag.assumption,
          'EVIDENCE_GAP' => FindingTag.evidenceGap,
          'CONTRADICTION' => FindingTag.contradiction,
          'RISK' => FindingTag.risk,
          'NOVELTY' => FindingTag.novelty,
          _ => FindingTag.assumption,
        };
        findings.add(Finding(tag: tag, text: body));
      } else {
        currentChallenge = raw;
      }
      lastYourReply = null;
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> replyToChallenge(String text) async {
    if (text.trim().isEmpty) return;
    lastYourReply = text.trim();
    _transcript.add({'role': 'user', 'content': text.trim()});
    if (stageIndex < totalStages) stageIndex += 1;
    notifyListeners();
    await _requestChallenge();
  }

  void addEvidence(String text) {
    if (text.trim().isEmpty) return;
    evidenceLog.add(text.trim());
    _transcript.add({
      'role': 'user',
      'content': 'Additional evidence submitted: ${text.trim()}',
    });
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
    try {
      report = await _arbiter.judge(
        ideaContent: currentVersion!.content,
        fullTranscript: _transcript,
      );
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
