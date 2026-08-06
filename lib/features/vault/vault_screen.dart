import 'package:flutter/material.dart';
import '../../core/groq_client.dart';
import '../crucible/crucible_feature.dart';
import '../crucible/idea_canvas_screen.dart';
import '../crucible/crucible_arena_screen.dart';
import 'vault_feature.dart';

class VaultScreen extends StatefulWidget {
  const VaultScreen({super.key, required this.client, required this.vault});
  final GroqClient client;
  final VaultController vault;

  @override
  State<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends State<VaultScreen> {
  @override
  void initState() {
    super.initState();
    widget.vault.addListener(_onChange);
    widget.vault.load();
  }

  @override
  void dispose() {
    widget.vault.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() => setState(() {});

  Future<void> _openIdea(SavedIdeaSummary summary) async {
    final session = await widget.vault.loadFullSession(summary.id);
    if (session == null || !mounted) return;
    final controller = CrucibleController.fromJson(
      session,
      client: widget.client,
      onSessionChanged: widget.vault.upsertFromSession,
    );
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => CrucibleArenaScreen(controller: controller, client: widget.client, vault: widget.vault),
    ));
  }

  void _newIdea() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => IdeaCanvasScreen(client: widget.client, vault: widget.vault),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.vault;

    return Scaffold(
      backgroundColor: const Color(0xFF0B0C10),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0C10),
        elevation: 0,
        title: const Text('CRUCIBLE',
            style: TextStyle(color: Colors.white, letterSpacing: 3, fontWeight: FontWeight.w700)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _newIdea,
        backgroundColor: const Color(0xFFE0272E),
        icon: const Icon(Icons.add),
        label: const Text('New Idea'),
      ),
      body: v.isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFE0272E)))
          : v.ideas.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  itemCount: v.ideas.length,
                  itemBuilder: (ctx, i) => _buildIdeaCard(v.ideas[i]),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.diamond_outlined, size: 48, color: Colors.grey[700]),
            const SizedBox(height: 16),
            Text('No ideas submitted yet.\nTap "New Idea" to enter the crucible.',
                textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }

  Widget _buildIdeaCard(SavedIdeaSummary s) {
    final progress = s.stageIndex / s.totalStages;
    return Dismissible(
      key: ValueKey(s.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(color: Colors.red[900], borderRadius: BorderRadius.circular(8)),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) => widget.vault.delete(s.id),
      child: Card(
        color: const Color(0xFF14161C),
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: Colors.white.withOpacity(0.06)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _openIdea(s),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 4),
                Text(s.oneLiner,
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: progress.clamp(0, 1),
                          minHeight: 4,
                          backgroundColor: Colors.white12,
                          valueColor: const AlwaysStoppedAnimation(Color(0xFFE0272E)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('v${s.versionCount}', style: const TextStyle(color: Colors.white38, fontSize: 11)),
                  ],
                ),
                if (s.readinessSummary != null && s.readinessSummary!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('Readiness: ${s.readinessSummary}',
                      style: const TextStyle(color: Colors.indigoAccent, fontSize: 11, fontStyle: FontStyle.italic),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
