import 'package:flutter/material.dart';
import 'crucible_feature.dart';
import 'crucible_arena_screen.dart';

class IdeaCanvasScreen extends StatefulWidget {
  const IdeaCanvasScreen({super.key, required this.controller});
  final CrucibleController controller;

  @override
  State<IdeaCanvasScreen> createState() => _IdeaCanvasScreenState();
}

class _CanvasField {
  _CanvasField(this.label, this.hint, this.icon, this.lines, {this.required = false});
  final String label;
  final String hint;
  final IconData icon;
  final int lines;
  final bool required;
}

class _IdeaCanvasScreenState extends State<IdeaCanvasScreen> {
  final _title = TextEditingController();
  final _oneSentence = TextEditingController();
  final _problem = TextEditingController();
  final _currentSolution = TextEditingController();
  final _mySolution = TextEditingController();
  final _whyItWins = TextEditingController();
  final _evidence = TextEditingController();
  final _unknowns = TextEditingController();

  late final List<MapEntry<_CanvasField, TextEditingController>> _fields = [
    MapEntry(_CanvasField('Title', 'Name the invention', Icons.bolt, 1, required: true), _title),
    MapEntry(_CanvasField('One-sentence pitch', 'What is it, in one line?', Icons.short_text, 2, required: true), _oneSentence),
    MapEntry(_CanvasField('Problem', 'What problem does this solve, and for whom?', Icons.gps_fixed, 3, required: true), _problem),
    MapEntry(_CanvasField('Current solutions', 'How is this problem solved today?', Icons.history, 3), _currentSolution),
    MapEntry(_CanvasField('My solution', 'What exactly are you proposing?', Icons.build_outlined, 4, required: true), _mySolution),
    MapEntry(_CanvasField('Why it wins', 'Why is this better than what exists?', Icons.emoji_events_outlined, 3), _whyItWins),
    MapEntry(_CanvasField('Evidence', 'Any data, research, or proof you already have', Icons.fact_check_outlined, 3), _evidence),
    MapEntry(_CanvasField('Known unknowns', "What don't you know yet / what worries you?", Icons.help_outline, 3), _unknowns),
  ];

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChange);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChange);
    for (final f in _fields) {
      f.value.dispose();
    }
    super.dispose();
  }

  void _onControllerChange() => setState(() {});

  int get _filledCount => _fields.where((f) => f.value.text.trim().isNotEmpty).length;

  bool get _isComplete =>
      _title.text.trim().isNotEmpty &&
      _oneSentence.text.trim().isNotEmpty &&
      _problem.text.trim().isNotEmpty &&
      _mySolution.text.trim().isNotEmpty;

  Future<void> _submit() async {
    final canvas = IdeaCanvasData(
      title: _title.text.trim(),
      oneSentence: _oneSentence.text.trim(),
      problem: _problem.text.trim(),
      currentSolution: _currentSolution.text.trim(),
      mySolution: _mySolution.text.trim(),
      whyItWins: _whyItWins.text.trim(),
      evidence: _evidence.text.trim(),
      unknowns: _unknowns.text.trim(),
    );

    await widget.controller.startPressureTest(canvas);
    if (!mounted) return;

    if (widget.controller.rejectionReason != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Zetra rejected this submission: ${widget.controller.rejectionReason}'),
          backgroundColor: Colors.redAccent[700],
        ),
      );
    } else {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => CrucibleArenaScreen(controller: widget.controller),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final checking = widget.controller.isCheckingIntake;

    return Scaffold(
      backgroundColor: const Color(0xFF0B0C10),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildHero()),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) => _buildFieldCard(_fields[i].key, _fields[i].value, i + 1),
                childCount: _fields.length,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: _isComplete ? const Color(0xFFE0272E) : Colors.white12,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    elevation: _isComplete ? 6 : 0,
                    shadowColor: const Color(0xFFE0272E).withOpacity(0.5),
                  ),
                  onPressed: (_isComplete && !checking) ? _submit : null,
                  child: checking
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.local_fire_department,
                                color: _isComplete ? Colors.white : Colors.white38, size: 20),
                            const SizedBox(width: 10),
                            Text('ENTER THE CRUCIBLE',
                                style: TextStyle(
                                    letterSpacing: 1.8,
                                    fontWeight: FontWeight.bold,
                                    color: _isComplete ? Colors.white : Colors.white38)),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHero() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 56, 24, 28),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1A0B0C), Color(0xFF0B0C10)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFE0272E), width: 1.5),
                ),
                child: const Icon(Icons.diamond_outlined, color: Color(0xFFE0272E), size: 20),
              ),
              const SizedBox(width: 12),
              const Text('CRUCIBLE',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      letterSpacing: 4,
                      fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Every invention starts as an assumption.\nSubmit yours for pressure testing.',
            style: TextStyle(color: Colors.white54, fontSize: 13.5, height: 1.5),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: _filledCount / _fields.length,
                    minHeight: 4,
                    backgroundColor: Colors.white12,
                    valueColor: const AlwaysStoppedAnimation(Color(0xFFE0272E)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text('$_filledCount / ${_fields.length}',
                  style: const TextStyle(color: Colors.white38, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFieldCard(_CanvasField field, TextEditingController c, int number) {
    final filled = c.text.trim().isNotEmpty;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF14161C),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: filled ? const Color(0xFFE0272E).withOpacity(0.35) : Colors.white.withOpacity(0.06),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: filled ? const Color(0xFFE0272E) : Colors.white10,
                  ),
                  child: filled
                      ? const Icon(Icons.check, size: 13, color: Colors.white)
                      : Text('$number', style: const TextStyle(fontSize: 11, color: Colors.white54)),
                ),
                const SizedBox(width: 8),
                Icon(field.icon, size: 15, color: Colors.white38),
                const SizedBox(width: 6),
                Text(field.label.toUpperCase(),
                    style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8)),
                if (field.required) ...[
                  const SizedBox(width: 4),
                  const Text('*', style: TextStyle(color: Color(0xFFE0272E), fontWeight: FontWeight.bold)),
                ],
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: c,
              maxLines: field.lines,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(color: Colors.white, fontSize: 14),
              cursorColor: const Color(0xFFE0272E),
              decoration: InputDecoration(
                hintText: field.hint,
                hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
                isDense: true,
                border: InputBorder.none,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
