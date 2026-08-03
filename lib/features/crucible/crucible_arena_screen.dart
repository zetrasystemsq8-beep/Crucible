import 'package:flutter/material.dart';
import 'crucible_feature.dart';

class CrucibleArenaScreen extends StatefulWidget {
  const CrucibleArenaScreen({super.key, required this.controller});
  final CrucibleController controller;

  @override
  State<CrucibleArenaScreen> createState() => _CrucibleArenaScreenState();
}

class _CrucibleArenaScreenState extends State<CrucibleArenaScreen> {
  final _replyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChange);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChange);
    _replyController.dispose();
    super.dispose();
  }

  void _onChange() => setState(() {});

  Future<void> _showEvidenceSheet() async {
    final c = TextEditingController();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF171A21),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Submit evidence',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text(
              'Paste data, a citation, a link, or describe an attachment.\nFile/image upload needs a storage backend — not wired up yet.',
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: c,
              maxLines: 5,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                filled: true,
                fillColor: Colors.white10,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  widget.controller.addEvidence(c.text);
                  Navigator.pop(ctx);
                },
                child: const Text('Add to Evidence Log'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showRevisionSheet() async {
    final c = TextEditingController(
      text: widget.controller.currentVersion?.content ?? '',
    );
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF171A21),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 16, right: 16, top: 16,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Submit a revised version',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextField(
              controller: c,
              maxLines: 8,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                filled: true, fillColor: Colors.white10,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  widget.controller.submitRevision(c.text);
                  Navigator.pop(ctx);
                },
                child: const Text('Submit Revision'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F1115),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0F1115),
          elevation: 0,
          title: Text(c.currentVersion?.content.split('\n').first ?? 'Arena',
              style: const TextStyle(color: Colors.white, fontSize: 15),
              overflow: TextOverflow.ellipsis),
          bottom: const TabBar(
            indicatorColor: Colors.redAccent,
            tabs: [Tab(text: 'ARENA'), Tab(text: 'DOSSIER')],
          ),
        ),
        body: Column(
          children: [
            _buildTimeline(c),
            Expanded(
              child: TabBarView(
                children: [_buildArenaTab(c), _buildDossierTab(c)],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeline(CrucibleController c) {
    return Container(
      color: const Color(0xFF171A21),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      child: Row(
        children: List.generate(c.totalStages, (i) {
          final stageNum = i + 1;
          final isDone = stageNum < c.stageIndex;
          final isCurrent = stageNum == c.stageIndex;
          return Expanded(
            child: Column(
              children: [
                Row(
                  children: [
                    if (i > 0)
                      Expanded(
                        child: Container(
                          height: 2,
                          color: isDone || isCurrent
                              ? Colors.redAccent
                              : Colors.white24,
                        ),
                      ),
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDone
                            ? Colors.redAccent
                            : isCurrent
                                ? Colors.redAccent.withOpacity(0.25)
                                : Colors.white12,
                        border: isCurrent
                            ? Border.all(color: Colors.redAccent, width: 2)
                            : null,
                      ),
                      child: Center(
                        child: isDone
                            ? const Icon(Icons.check, size: 14, color: Colors.white)
                            : Text('$stageNum',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: isCurrent ? Colors.white : Colors.white38)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  c.stageLabels[i],
                  style: TextStyle(
                      fontSize: 9,
                      color: isCurrent ? Colors.white : Colors.white38),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildArenaTab(CrucibleController c) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ListView(
              children: [
                if (c.currentChallenge != null)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF171A21),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.bolt, size: 16, color: Colors.redAccent),
                            const SizedBox(width: 6),
                            Text('ZETRA · ${c.stageLabels[c.stageIndex - 1].toUpperCase()}',
                                style: const TextStyle(
                                    color: Colors.redAccent,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(c.currentChallenge!,
                            style: const TextStyle(color: Colors.white, fontSize: 15)),
                        if (c.lastReplyWasAdequate == false)
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Row(
                              children: const [
                                Icon(Icons.block, size: 14, color: Colors.orangeAccent),
                                SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Not accepted — same issue, try again with specifics',
                                    style: TextStyle(color: Colors.orangeAccent, fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                if (c.lastYourReply != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.75),
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(c.lastYourReply!,
                            style: const TextStyle(color: Colors.white70)),
                      ),
                    ),
                  ),
                if (c.isLoading)
                  const Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: Center(
                      child: Text('Zetra is thinking...',
                          style: TextStyle(color: Colors.white38)),
                    ),
                  ),
                if (c.errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(c.errorMessage!,
                        style: const TextStyle(color: Colors.redAccent)),
                  ),
                if (c.report != null) _buildReportCard(c.report!),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              IconButton(
                onPressed: _showEvidenceSheet,
                icon: const Icon(Icons.attach_file, color: Colors.white54),
              ),
              Expanded(
                child: TextField(
                  controller: _replyController,
                  minLines: 1,
                  maxLines: 4,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Defend your idea...',
                    hintStyle: const TextStyle(color: Colors.white30),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.06),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                onPressed: c.isLoading
                    ? null
                    : () {
                        final t = _replyController.text;
                        _replyController.clear();
                        c.replyToChallenge(t);
                      },
                icon: const Icon(Icons.send, color: Colors.redAccent),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _showRevisionSheet,
                  child: const Text('Submit Revision'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: c.canRequestJudgment && !c.isLoading
                      ? c.requestJudgment
                      : null,
                  style: FilledButton.styleFrom(backgroundColor: Colors.indigo),
                  child: const Text('Get Judgment'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDossierTab(CrucibleController c) {
    Widget section(String title, IconData icon, Color color, List<Finding> items) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 6),
                Text('$title (${items.length})',
                    style: TextStyle(
                        color: color, fontWeight: FontWeight.bold, fontSize: 13)),
              ],
            ),
            const SizedBox(height: 8),
            if (items.isEmpty)
              const Text('None yet.', style: TextStyle(color: Colors.white24, fontSize: 12))
            else
              ...items.map((f) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text('• ${f.text}',
                        style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  )),
          ],
        ),
      );
    }

    List<Finding> byTag(FindingTag tag) =>
        c.findings.where((f) => f.tag == tag).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        section('Assumptions Found', Icons.help_outline, Colors.amber,
            byTag(FindingTag.assumption)),
        section('Evidence Gaps', Icons.search_off, Colors.orange,
            byTag(FindingTag.evidenceGap)),
        section('Contradictions', Icons.warning_amber, Colors.redAccent,
            byTag(FindingTag.contradiction)),
        section('Risks', Icons.dangerous_outlined, Colors.deepOrange,
            byTag(FindingTag.risk)),
        section('Novelty Concerns', Icons.new_releases_outlined, Colors.purpleAccent,
            byTag(FindingTag.novelty)),
        const Divider(color: Colors.white12),
        const SizedBox(height: 8),
        Row(
          children: const [
            Icon(Icons.folder_outlined, size: 16, color: Colors.lightBlueAccent),
            SizedBox(width: 6),
            Text('Evidence Log',
                style: TextStyle(
                    color: Colors.lightBlueAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 13)),
          ],
        ),
        const SizedBox(height: 8),
        if (c.evidenceLog.isEmpty)
          const Text('No evidence submitted yet.',
              style: TextStyle(color: Colors.white24, fontSize: 12))
        else
          ...c.evidenceLog.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('• $e', style: const TextStyle(color: Colors.white70, fontSize: 13)),
              )),
      ],
    );
  }

  Widget _buildReportCard(JudgeReport r) {
    Widget block(String title, List<String> items) {
      if (items.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
            ...items.map((i) => Text('• $i', style: const TextStyle(color: Colors.white70, fontSize: 12))),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF171A21),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.indigo.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ARBITER REPORT',
              style: TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold, letterSpacing: 1)),
          block('Strongest Arguments', r.strongestArguments),
          block('Weakest Arguments', r.weakestArguments),
          block('Unsupported Assumptions', r.unsupportedAssumptions),
          block('Contradictions', r.contradictions),
          block('Unanswered Questions', r.unansweredQuestions),
          block('Suggested Experiments', r.suggestedExperiments),
          if (r.readinessSummary.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text('Readiness: ${r.readinessSummary}',
                  style: const TextStyle(color: Colors.white, fontStyle: FontStyle.italic, fontSize: 12)),
            ),
        ],
      ),
    );
  }
}
