import 'package:flutter/material.dart';
import 'crucible_feature.dart';

class CrucibleScreen extends StatefulWidget {
  const CrucibleScreen({super.key, required this.controller});

  final CrucibleController controller;

  @override
  State<CrucibleScreen> createState() => _CrucibleScreenState();
}

class _CrucibleScreenState extends State<CrucibleScreen> {
  final _ideaController = TextEditingController();
  final _replyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChange);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChange);
    _ideaController.dispose();
    _replyController.dispose();
    super.dispose();
  }

  void _onChange() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;

    return Scaffold(
      appBar: AppBar(title: const Text('Crucible')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: c.currentVersion == null
            ? _buildIntake()
            : _buildArena(c),
      ),
    );
  }

  Widget _buildIntake() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Present your idea',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _ideaController,
          maxLines: 6,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Describe the invention, claim, or concept...',
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: () {
            if (_ideaController.text.trim().isEmpty) return;
            widget.controller.submitIdea(_ideaController.text.trim());
          },
          child: const Text('Submit to Crucible'),
        ),
      ],
    );
  }

  Widget _buildArena(CrucibleController c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Version ${c.currentVersion!.versionNumber} · Round ${c.roundNumber}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView(
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(c.currentVersion!.content),
                ),
              ),
              const SizedBox(height: 12),
              for (final exchange in c.currentRoundExchanges) ...[
                _bubble('Zetra', exchange.zetraMessage, isChallenger: true),
                if (exchange.innovatorReply != null)
                  _bubble('You', exchange.innovatorReply!),
              ],
              if (c.latestReport != null) _buildReport(c.latestReport!),
              if (c.errorMessage != null)
                Text(
                  c.errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _replyController,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Respond to Zetra...',
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            ElevatedButton(
              onPressed: c.isLoading ? null : c.requestChallenge,
              child: const Text('Challenge (Zetra)'),
            ),
            OutlinedButton(
              onPressed: c.isLoading
                  ? null
                  : () {
                      if (_replyController.text.trim().isEmpty) return;
                      c.submitInnovatorReply(_replyController.text.trim());
                      _replyController.clear();
                    },
              child: const Text('Send Reply'),
            ),
            OutlinedButton(
              onPressed: c.isLoading
                  ? null
                  : () => c.submitRevision(_ideaController.text.trim()),
              child: const Text('Submit Revision'),
            ),
            ElevatedButton(
              onPressed: c.isLoading ? null : c.requestJudgment,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
              child: const Text('Get Judgment (Arbiter)'),
            ),
          ],
        ),
        if (c.isLoading) const Padding(
          padding: EdgeInsets.only(top: 8),
          child: LinearProgressIndicator(),
        ),
      ],
    );
  }

  Widget _bubble(String who, String text, {bool isChallenger = false}) {
    return Align(
      alignment: isChallenger ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(10),
        constraints: const BoxConstraints(maxWidth: 320),
        decoration: BoxDecoration(
          color: isChallenger ? Colors.red[50] : Colors.blue[50],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(who, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(text),
          ],
        ),
      ),
    );
  }

  Widget _buildReport(JudgeReport report) {
    Widget section(String title, List<String> items) {
      if (items.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            ...items.map((i) => Text('• $i')),
          ],
        ),
      );
    }

    return Card(
      color: Colors.indigo[50],
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Arbiter Report',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            section('Strongest Arguments', report.strongestArguments),
            section('Weakest Arguments', report.weakestArguments),
            section('Unsupported Assumptions', report.unsupportedAssumptions),
            section('Contradictions', report.contradictions),
            section('Unanswered Questions', report.unansweredQuestions),
            section('Suggested Experiments', report.suggestedExperiments),
            if (report.readinessSummary.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Readiness: ${report.readinessSummary}',
                  style: const TextStyle(fontStyle: FontStyle.italic)),
            ],
          ],
        ),
      ),
    );
  }
}
