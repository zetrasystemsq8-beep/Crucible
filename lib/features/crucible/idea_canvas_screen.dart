import 'package:flutter/material.dart';
import 'crucible_feature.dart';
import 'crucible_arena_screen.dart';

class IdeaCanvasScreen extends StatefulWidget {
  const IdeaCanvasScreen({super.key, required this.controller});
  final CrucibleController controller;

  @override
  State<IdeaCanvasScreen> createState() => _IdeaCanvasScreenState();
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

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChange);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChange);
    _title.dispose();
    _oneSentence.dispose();
    _problem.dispose();
    _currentSolution.dispose();
    _mySolution.dispose();
    _whyItWins.dispose();
    _evidence.dispose();
    _unknowns.dispose();
    super.dispose();
  }

  void _onControllerChange() => setState(() {});

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
          content: Text(
            'Zetra rejected this submission: ${widget.controller.rejectionReason}',
          ),
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
      backgroundColor: const Color(0xFF0F1115),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F1115),
        elevation: 0,
        title: const Text('CRUCIBLE',
            style: TextStyle(
                color: Colors.white,
                letterSpacing: 3,
                fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          const Text('Submit for pressure testing',
              style: TextStyle(color: Colors.white54, fontSize: 13)),
          const SizedBox(height: 20),
          _field('TITLE', _title, hint: 'Name the invention', lines: 1),
          _field('ONE-SENTENCE PITCH', _oneSentence,
              hint: 'What is it, in one line?', lines: 2),
          _field('PROBLEM', _problem,
              hint: 'What problem does this solve, and for whom?', lines: 3),
          _field('CURRENT SOLUTIONS', _currentSolution,
              hint: 'How is this problem solved today?', lines: 3),
          _field('MY SOLUTION', _mySolution,
              hint: 'What exactly are you proposing?', lines: 4),
          _field('WHY IT WINS', _whyItWins,
              hint: 'Why is this better than what exists?', lines: 3),
          _field('EVIDENCE', _evidence,
              hint: 'Any data, research, or proof you already have',
              lines: 3),
          _field('KNOWN UNKNOWNS', _unknowns,
              hint: "What don't you know yet / what worries you?", lines: 3),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor:
                    _isComplete ? Colors.redAccent[700] : Colors.white24,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4)),
              ),
              onPressed: (_isComplete && !checking) ? _submit : null,
              child: checking
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('START PRESSURE TEST',
                      style: TextStyle(letterSpacing: 1.5)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(String label, TextEditingController c,
      {required String hint, required int lines}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1)),
          const SizedBox(height: 6),
          TextField(
            controller: c,
            maxLines: lines,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
              filled: true,
              fillColor: Colors.white.withOpacity(0.05),
              contentPadding: const EdgeInsets.all(12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: const BorderSide(color: Colors.redAccent),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
