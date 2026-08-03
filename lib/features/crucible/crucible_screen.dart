import 'package:flutter/material.dart';
import 'crucible_feature.dart';

class CrucibleScreen extends StatefulWidget {
  const CrucibleScreen({super.key, required this.controller});

  final CrucibleController controller;

  @override
  State<CrucibleScreen> createState() => _CrucibleScreenState();
}

class _CrucibleScreenState extends State<CrucibleScreen> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChange);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChange);
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onChange() {
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _handleSend() {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    _inputController.clear();
    widget.controller.sendMessage(text);
  }

  Future<void> _showRevisionSheet() async {
    final c = TextEditingController(
      text: widget.controller.currentVersion?.content ?? '',
    );
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
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
            const Text('Submit a revised version',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            TextField(
              controller: c,
              maxLines: 6,
              decoration: const InputDecoration(border: OutlineInputBorder()),
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
    final hasIdea = c.currentVersion != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FB),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFFF7F7FB),
        foregroundColor: Colors.black87,
        title: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Crucible',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
            if (hasIdea)
              Text(
                'v${c.currentVersion!.versionNumber} · round ${c.roundNumber}',
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
          ],
        ),
        actions: [
          if (hasIdea)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                if (value == 'revise') _showRevisionSheet();
                if (value == 'judge') c.requestJudgment();
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(
                  value: 'judge',
                  child: Text('Get Judgment (Arbiter)'),
                ),
                const PopupMenuItem(
                  value: 'revise',
                  child: Text('Submit Revision'),
                ),
              ],
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: !hasIdea
                  ? _buildEmptyState()
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: c.chat.length + (c.isLoading ? 1 : 0),
                      itemBuilder: (ctx, i) {
                        if (i == c.chat.length) {
                          return _typingIndicator();
                        }
                        return _buildChatItem(c.chat[i]);
                      },
                    ),
            ),
            if (c.errorMessage != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(c.errorMessage!,
                    style: const TextStyle(color: Colors.red, fontSize: 12)),
              ),
            _buildInputBar(hasIdea),
          ],
        ),
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
            Icon(Icons.science_outlined, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Present an idea below.\nZetra will start pressure-testing it.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar(bool hasIdea) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _inputController,
              minLines: 1,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: hasIdea
                    ? 'Reply to Zetra...'
                    : 'Describe your idea...',
                filled: true,
                fillColor: const Color(0xFFF1F1F5),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (_) => _handleSend(),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: Colors.indigo,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: widget.controller.isLoading ? null : _handleSend,
              child: const Padding(
                padding: EdgeInsets.all(10),
                child: Icon(Icons.arrow_upward, color: Colors.white, size: 20),
              ),
            ),
          ),
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
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 8),
            Text('Zetra is thinking...', style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildChatItem(ChatItem item) {
    switch (item.role) {
      case ChatRole.idea:
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.indigo[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.indigo[100]!),
          ),
          child: Text(item.text, style: const TextStyle(fontSize: 14)),
        );
      case ChatRole.zetra:
        return _bubble(
          text: item.text,
          alignment: Alignment.centerLeft,
          color: Colors.white,
          label: 'Zetra',
          labelColor: Colors.red[400]!,
        );
      case ChatRole.user:
        return _bubble(
          text: item.text,
          alignment: Alignment.centerRight,
          color: Colors.indigo,
          textColor: Colors.white,
        );
      case ChatRole.arbiter:
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF1FB),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.indigo[100]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.gavel, size: 16, color: Colors.indigo[400]),
                  const SizedBox(width: 6),
                  Text('Arbiter Report',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.indigo[700])),
                ],
              ),
              const SizedBox(height: 8),
              Text(item.text, style: const TextStyle(fontSize: 13.5)),
            ],
          ),
        );
    }
  }

  Widget _bubble({
    required String text,
    required Alignment alignment,
    required Color color,
    Color textColor = Colors.black87,
    String? label,
    Color? labelColor,
  }) {
    return Align(
      alignment: alignment,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (label != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(label,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: labelColor)),
              ),
            Text(text, style: TextStyle(color: textColor, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}
