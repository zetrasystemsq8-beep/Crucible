import 'package:flutter/material.dart';
import 'crucible_feature.dart';

enum DiffType { same, added, removed }

class DiffLine {
  DiffLine(this.type, this.text);
  final DiffType type;
  final String text;
}

/// Simple LCS-based line diff — enough for short idea descriptions.
List<DiffLine> computeLineDiff(String a, String b) {
  final linesA = a.split('\n');
  final linesB = b.split('\n');
  final n = linesA.length;
  final m = linesB.length;

  final dp = List.generate(n + 1, (_) => List<int>.filled(m + 1, 0));
  for (int i = n - 1; i >= 0; i--) {
    for (int j = m - 1; j >= 0; j--) {
      dp[i][j] = linesA[i] == linesB[j]
          ? dp[i + 1][j + 1] + 1
          : (dp[i + 1][j] > dp[i][j + 1] ? dp[i + 1][j] : dp[i][j + 1]);
    }
  }

  final result = <DiffLine>[];
  int i = 0, j = 0;
  while (i < n && j < m) {
    if (linesA[i] == linesB[j]) {
      result.add(DiffLine(DiffType.same, linesA[i]));
      i++;
      j++;
    } else if (dp[i + 1][j] >= dp[i][j + 1]) {
      result.add(DiffLine(DiffType.removed, linesA[i]));
      i++;
    } else {
      result.add(DiffLine(DiffType.added, linesB[j]));
      j++;
    }
  }
  while (i < n) {
    result.add(DiffLine(DiffType.removed, linesA[i]));
    i++;
  }
  while (j < m) {
    result.add(DiffLine(DiffType.added, linesB[j]));
    j++;
  }
  return result;
}

class VersionCompareScreen extends StatefulWidget {
  const VersionCompareScreen({super.key, required this.controller});
  final CrucibleController controller;

  @override
  State<VersionCompareScreen> createState() => _VersionCompareScreenState();
}

class _VersionCompareScreenState extends State<VersionCompareScreen> {
  late int _versionA;
  late int _versionB;

  @override
  void initState() {
    super.initState();
    final versions = widget.controller.versions;
    _versionA = versions.first.versionNumber;
    _versionB = versions.last.versionNumber;
  }

  @override
  Widget build(BuildContext context) {
    final versions = widget.controller.versions;
    final a = versions.firstWhere((v) => v.versionNumber == _versionA);
    final b = versions.firstWhere((v) => v.versionNumber == _versionB);
    final diff = computeLineDiff(a.content, b.content);

    return Scaffold(
      backgroundColor: const Color(0xFF0B0C10),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0C10),
        elevation: 0,
        title: const Text('Compare Versions', style: TextStyle(color: Colors.white, fontSize: 16)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(child: _versionDropdown('FROM', _versionA, versions, (v) => setState(() => _versionA = v))),
                const SizedBox(width: 12),
                const Icon(Icons.arrow_forward, color: Colors.white38),
                const SizedBox(width: 12),
                Expanded(child: _versionDropdown('TO', _versionB, versions, (v) => setState(() => _versionB = v))),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: diff.length,
              itemBuilder: (ctx, i) {
                final line = diff[i];
                if (line.text.trim().isEmpty) return const SizedBox(height: 4);
                final Color bg;
                final Color fg;
                final String prefix;
                switch (line.type) {
                  case DiffType.added:
                    bg = Colors.green.withOpacity(0.12);
                    fg = Colors.greenAccent;
                    prefix = '+ ';
                    break;
                  case DiffType.removed:
                    bg = Colors.red.withOpacity(0.12);
                    fg = Colors.redAccent;
                    prefix = '- ';
                    break;
                  case DiffType.same:
                    bg = Colors.transparent;
                    fg = Colors.white54;
                    prefix = '  ';
                    break;
                }
                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 2),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  color: bg,
                  child: Text('$prefix${line.text}',
                      style: TextStyle(
                        color: fg,
                        fontSize: 13,
                        fontFamily: 'monospace',
                        decoration: line.type == DiffType.removed ? TextDecoration.lineThrough : null,
                      )),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _versionDropdown(String label, int value, List<IdeaVersion> versions, void Function(int) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11, letterSpacing: 1)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF14161C),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.white12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: value,
              dropdownColor: const Color(0xFF14161C),
              isExpanded: true,
              style: const TextStyle(color: Colors.white),
              items: versions
                  .map((v) => DropdownMenuItem(value: v.versionNumber, child: Text('v${v.versionNumber}')))
                  .toList(),
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
            ),
          ),
        ),
      ],
    );
  }
}
