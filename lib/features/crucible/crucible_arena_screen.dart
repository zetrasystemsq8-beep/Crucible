import 'package:flutter/material.dart';
import 'crucible_feature.dart';
import 'version_compare_screen.dart';

class CrucibleArenaScreen extends StatefulWidget {
  const CrucibleArenaScreen({super.key, required this.controller});
  final CrucibleController controller;

  @override
  State<CrucibleArenaScreen> createState() => _CrucibleArenaScreenState();
}

class _CrucibleArenaScreenState extends State<CrucibleArenaScreen> {
  final _replyController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChange);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChange);
    _replyController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onChange() {
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 200,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _showEvidenceSheet() async {
    final c = TextEditingController();
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
                filled: true, fillColor: Colors.white10,
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
    final c = TextEditingController(text: widget.controller.currentVersion?.content ?? '');
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
        backgroundColor: const Color(0xFF0B0C10),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0B0C10),
          elevation: 0,
          title: Text(c.currentVersion?.content.split('\n').first ?? 'Arena',
              style: const TextStyle(color: Colors.white, fontSize: 15),
              overflow: TextOverflow.ellipsis),
          bottom: const TabBar(
            indicatorColor: Color(0xFFE0272E),
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
      color: const Color(0xFF14161C),
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
                          color: isDone || isCurrent ? const Color(0xFFE0272E) : Colors.white24,
                        ),
                      ),
                    Container(
                      width: 22, height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDone
                            ? const Color(0xFFE0272E)
                            : isCurrent
                                ? const Color(0xFFE0272E).withOpacity(0.25)
                                : Colors.white12,
                        border: isCurrent ? Border.all(color: const Color(0xFFE0272E), width: 2) : null,
                      ),
                      child: Center(
                        child: isDone
                            ? const Icon(Icons.check, size: 14, color: Colors.white)
                            : Text('$stageNum', style: TextStyle(fontSize: 11, color: isCurrent ? Colors.white : Colors.white38)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(c.stageLabels[i], style: TextStyle(fontSize: 9, color: isCurrent ? Colors.white : Colors.white38)),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildArenaTab(CrucibleController c) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            itemCount: c.messages.length + (c.isLoading ? 1 : 0),
            itemBuilder: (ctx, i) {
              if (i == c.messages.length) return _typingIndicator();
              final msg = c.messages[i];
              final isLatest = i == c.messages.length - 1;
              return _buildMessage(msg, highlight: isLatest);
            },
          ),
        ),
        if (c.errorMessage != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(c.errorMessage!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
          ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
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
                    icon: const Icon(Icons.send, color: Color(0xFFE0272E)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(onPressed: _showRevisionSheet, child: const Text('Submit Revision')),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: c.canRequestJudgment && !c.isLoading ? c.requestJudgment : null,
                      style: FilledButton.styleFrom(backgroundColor: Colors.indigo),
                      child: const Text('Get Judgment'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMessage(ArenaMessage msg, {required bool highlight}) {
    if (msg.isReport) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF171A21),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.indigo.withOpacity(0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.gavel, size: 16, color: Colors.indigo[300]),
                const SizedBox(width: 6),
                const Text('ARBITER REPORT', style: TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold, letterSpacing: 1)),
              ],
            ),
            const SizedBox(height: 8),
            Text(msg.text, style: const TextStyle(color: Colors.white, fontSize: 13)),
          ],
        ),
      );
    }

    if (!msg.fromZetra) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
          decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(14)),
          child: Text(msg.text, style: const TextStyle(color: Colors.white70, fontSize: 14)),
        ),
      );
    }

    final borderColor = msg.isHold ? Colors.orangeAccent : const Color(0xFFE0272E);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF14161C),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor.withOpacity(highlight ? 0.6 : 0.25), width: highlight ? 1.4 : 1),
        boxShadow: highlight ? [BoxShadow(color: borderColor.withOpacity(0.15), blurRadius: 12)] : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(msg.isHold ? Icons.block : Icons.bolt, size: 14, color: borderColor),
              const SizedBox(width: 6),
              Text(
                msg.isHold ? 'ZETRA · HELD' : 'ZETRA${msg.stageLabel != null ? " · ${msg.stageLabel!.toUpperCase()}" : ""}',
                style: TextStyle(color: borderColor, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(msg.text, style: const TextStyle(color: Colors.white, fontSize: 14.5, height: 1.4)),
        ],
      ),
    );
  }

  Widget _typingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(color: const Color(0xFF14161C), borderRadius: BorderRadius.circular(14)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFE0272E))),
            SizedBox(width: 8),
            Text('Zetra is thinking...', style: TextStyle(color: Colors.white38)),
          ],
        ),
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
                Text('$title (${items.length})', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
              ],
            ),
            const SizedBox(height: 8),
            if (items.isEmpty)
              const Text('None yet.', style: TextStyle(color: Colors.white24, fontSize: 12))
            else
              ...items.map((f) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text('• ${f.text}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  )),
          ],
        ),
      );
    }

    List<Finding> byTag(FindingTag tag) => c.findings.where((f) => f.tag == tag).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        section('Assumptions Found', Icons.help_outline, Colors.amber, byTag(FindingTag.assumption)),
        section('Evidence Gaps', Icons.search_off, Colors.orange, byTag(FindingTag.evidenceGap)),
        section('Contradictions', Icons.warning_amber, Colors.redAccent, byTag(FindingTag.contradiction)),
        section('Risks', Icons.dangerous_outlined, Colors.deepOrange, byTag(FindingTag.risk)),
        section('Novelty Concerns', Icons.new_releases_outlined, Colors.purpleAccent, byTag(FindingTag.novelty)),
        const Divider(color: Colors.white12),
        const SizedBox(height: 8),
        Row(
          children: const [
            Icon(Icons.folder_outlined, size: 16, color: Colors.lightBlueAccent),
            SizedBox(width: 6),
            Text('Evidence Log', style: TextStyle(color: Colors.lightBlueAccent, fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
        const SizedBox(height: 8),
        if (c.evidenceLog.isEmpty)
          const Text('No evidence submitted yet.', style: TextStyle(color: Colors.white24, fontSize: 12))
        else
          ...c.evidenceLog.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('• $e', style: const TextStyle(color: Colors.white70, fontSize: 13)),
              )),
        if (c.versions.length > 1) ...[
          const SizedBox(height: 20),
          const Divider(color: Colors.white12),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => VersionCompareScreen(controller: c),
              )),
              icon: const Icon(Icons.compare_arrows, size: 18),
              label: const Text('Compare Versions'),
            ),
          ),
        ],
      ],
    );
  }
}
