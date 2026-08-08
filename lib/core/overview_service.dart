import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'groq_client.dart';
import 'zetra_auth.dart';
import '../features/crucible/crucible_feature.dart';

class OverviewMeta {
  OverviewMeta({required this.category, required this.executiveSummary});
  final String category;
  final String executiveSummary;
}

class OverviewResult {
  OverviewResult({required this.id});
  final String id;
}

/// Generates an "Overview" — the only document Tribunal ever accepts —
/// and writes it directly into the shared Supabase `overviews` table.
/// Tribunal never trusts a file the innovator uploads; it looks the
/// Overview ID up live in this same table and recomputes the content
/// hash to confirm the row matches exactly what was submitted here.
class OverviewService {
  static const List<String> categories = [
    'Technology',
    'Medicine & Health',
    'Politics & Policy',
    'Business & Economics',
    'Environment',
    'Education',
    'Science & Engineering',
    'Social & Culture',
    'Other',
  ];

  /// Drafts a category and a short executive summary via AI. Nothing
  /// here is final — the UI shows this to the innovator to review and
  /// edit before anything is written to Supabase.
  static Future<OverviewMeta> draftMeta({
    required GroqClient client,
    required CrucibleController controller,
  }) async {
    final report = controller.report!;
    final prompt = '''
Idea title: ${controller.title}
One-line pitch: ${controller.oneLiner}
Idea content:
${controller.currentVersion!.content}

Arbiter's readiness summary: ${report.readinessSummary}

Pick exactly ONE category from this list that best fits the idea: ${categories.join(', ')}
Then write a neutral 2-3 sentence executive summary of the idea for an expert reviewer who has not seen it yet.

Respond in exactly this format, nothing else:
CATEGORY: <one item from the list, verbatim>
SUMMARY: <2-3 sentences>
''';

    final raw = await client.chat(
      model: 'llama-3.1-8b-instant',
      messages: [
        {'role': 'user', 'content': prompt},
      ],
      temperature: 0.3,
      maxTokens: 300,
    );

    final categoryMatch = RegExp(r'CATEGORY:\s*(.+)').firstMatch(raw);
    final summaryMatch = RegExp(r'SUMMARY:\s*([\s\S]+)').firstMatch(raw);

    var category = categoryMatch?.group(1)?.trim() ?? 'Other';
    if (!categories.contains(category)) category = 'Other';
    final summary = summaryMatch?.group(1)?.trim() ?? report.readinessSummary;

    return OverviewMeta(category: category, executiveSummary: summary);
  }

  /// Writes the final, person-reviewed Overview to Supabase. Requires a
  /// fully authenticated session — an Overview always carries a real
  /// ZetraMail identity as owner_id, never a guest.
  static Future<OverviewResult> submit({
    required CrucibleController controller,
    required String category,
    required String executiveSummary,
  }) async {
    final profile = AuthService.instance.currentProfile;
    if (profile == null || !AuthService.instance.isFullyAuthenticated) {
      throw Exception('You must be logged in to submit an Overview.');
    }
    if (!controller.isProven || controller.report == null || controller.currentVersion == null) {
      throw Exception('This idea has not cleared the Crucible process yet.');
    }

    final overviewId = const Uuid().v4();
    final createdAt = DateTime.now().toUtc();
    final fullContent = controller.currentVersion!.content;

    // Deterministic hash Tribunal recomputes from the stored row to
    // confirm it matches this exact submission. This is tamper-evidence
    // against the one source of truth (this table) — not a client-side
    // cryptographic signature, and we don't claim it's one.
    final hashInput = '$overviewId|${controller.title}|$fullContent|${profile.username}|${createdAt.toIso8601String()}';
    final contentHash = sha256.convert(utf8.encode(hashInput)).toString();

    final report = controller.report!;
    final findingsJson = controller.findings
        .map((f) => {'tag': f.tag.name, 'text': f.text})
        .toList();
    final reportJson = {
      'strongestArguments': report.strongestArguments,
      'weakestArguments': report.weakestArguments,
      'unsupportedAssumptions': report.unsupportedAssumptions,
      'contradictions': report.contradictions,
      'unansweredQuestions': report.unansweredQuestions,
      'suggestedExperiments': report.suggestedExperiments,
      'readinessSummary': report.readinessSummary,
    };

    await Supabase.instance.client.from('overviews').insert({
      'id': overviewId,
      'crucible_idea_id': controller.id,
      'owner_id': profile.id,
      'owner_name': profile.username,
      'title': controller.title,
      'one_liner': controller.oneLiner,
      'category': category,
      'executive_summary': executiveSummary,
      'full_idea_content': fullContent,
      'findings': findingsJson,
      'arbiter_report': reportJson,
      'content_hash': contentHash,
      'created_at': createdAt.toIso8601String(),
    });

    return OverviewResult(id: overviewId);
  }
}
