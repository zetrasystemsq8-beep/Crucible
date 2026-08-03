import 'package:flutter/foundation.dart';
import '../../core/groq_client.dart';

/// ---------- Models ----------

/// One immutable snapshot of the idea at a point in its evolution.
class IdeaVersion {
  IdeaVersion({
    required this.versionNumber,
    required this.content,
    required this.createdAt,
    this.deltaFromPrevious,
  });

  final int versionNumber;
  final String content;
  final DateTime createdAt;
  final String? deltaFromPrevious;
}

/// A single exchange in a challenge round.
class ChallengeExchange {
  ChallengeExchange({
    required this.zetraMessage,
    this.innovatorReply,
  });

  final String zetraMessage;
  String? innovatorReply;
}

/// Full structured output from Arbiter at the end of a session.
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
    // Arbiter is prompted to return labeled sections; this is a defensive
    // parser in case the model doesn't return strict JSON.
    List<String> section(String label) {
      final pattern = RegExp(
        '$label:(.*?)(?=\\n[A-Z][a-zA-Z ]+:|\$)',
        dotAll: true,
      );
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

  /// Swap for whatever fast model you have available on Groq.
  static const model = 'llama-3.3-70b-versatile';

  static const _systemPrompt = '''
You are Zetra, an adversarial reasoning AI inside the Crucible platform.
Your only purpose is to pressure-test the idea the user presents.

Rules:
- Never insult the user. Be respectful but extremely difficult to convince.
- Challenge assumptions, request evidence, find contradictions, compare
  against existing knowledge, propose counterexamples.
- Ask exactly one sharp, specific question or raise exactly one issue per turn.
  Do not soften with praise. Do not summarize what they said back to them.
- If the user gives evidence, test whether it actually supports the claim,
  don't just accept it because evidence was offered.
- Never declare the idea good or bad. Your job is pressure, not verdicts.
''';

  Future<String> challenge({
    required String ideaContent,
    required List<Map<String, String>> priorTurns,
    required int roundNumber,
  }) async {
    final difficultyNote = roundNumber == 1
        ? 'This is round 1: focus on clarity and core assumptions.'
        : roundNumber == 2
            ? 'This is round 2: focus on evidence quality.'
            : roundNumber == 3
                ? 'This is round 3: focus on novelty vs. existing prior art.'
                : 'This is round $roundNumber: focus on practical/economic viability.';

    final messages = <Map<String, String>>[
      {'role': 'system', 'content': '$_systemPrompt\n$difficultyNote'},
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

  /// Deliberately a different model/family than Zetra where possible,
  /// so the Judge isn't inheriting the Challenger's blind spots.
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
      {
        'role': 'user',
        'content': 'Produce your full structured report now.',
      },
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

/// ---------- Controller: orchestrates state for the UI ----------

class CrucibleController extends ChangeNotifier {
  CrucibleController({required GroqClient client})
      : _zetra = ZetraService(client),
        _arbiter = ArbiterService(client);

  final ZetraService _zetra;
  final ArbiterService _arbiter;

  final List<IdeaVersion> versions = [];
  final List<ChallengeExchange> currentRoundExchanges = [];
  final List<Map<String, String>> _transcript = [];

  int roundNumber = 1;
  bool isLoading = false;
  JudgeReport? latestReport;
  String? errorMessage;

  IdeaVersion? get currentVersion =>
      versions.isEmpty ? null : versions.last;

  void submitIdea(String content) {
    versions.add(
      IdeaVersion(
        versionNumber: 1,
        content: content,
        createdAt: DateTime.now(),
      ),
    );
    notifyListeners();
  }

  Future<void> requestChallenge() async {
    if (currentVersion == null) return;
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final reply = await _zetra.challenge(
        ideaContent: currentVersion!.content,
        priorTurns: _transcript,
        roundNumber: roundNumber,
      );
      _transcript.add({'role': 'assistant', 'content': reply});
      currentRoundExchanges.add(ChallengeExchange(zetraMessage: reply));
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void submitInnovatorReply(String reply) {
    if (currentRoundExchanges.isEmpty) return;
    currentRoundExchanges.last.innovatorReply = reply;
    _transcript.add({'role': 'user', 'content': reply});
    notifyListeners();
  }

  /// Call when the innovator revises the idea after a round of pressure.
  void submitRevision(String newContent, {String? delta}) {
    final nextVersionNumber = versions.length + 1;
    versions.add(
      IdeaVersion(
        versionNumber: nextVersionNumber,
        content: newContent,
        createdAt: DateTime.now(),
        deltaFromPrevious: delta,
      ),
    );
    roundNumber += 1;
    currentRoundExchanges.clear();
    notifyListeners();
  }

  Future<void> requestJudgment() async {
    if (currentVersion == null) return;
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      latestReport = await _arbiter.judge(
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
