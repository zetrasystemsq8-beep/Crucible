import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SavedIdeaSummary {
  SavedIdeaSummary({
    required this.id,
    required this.title,
    required this.oneLiner,
    required this.stageIndex,
    required this.totalStages,
    required this.versionCount,
    required this.lastUpdated,
    this.readinessSummary,
  });

  final String id;
  final String title;
  final String oneLiner;
  final int stageIndex;
  final int totalStages;
  final int versionCount;
  final DateTime lastUpdated;
  final String? readinessSummary;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'oneLiner': oneLiner,
        'stageIndex': stageIndex,
        'totalStages': totalStages,
        'versionCount': versionCount,
        'lastUpdated': lastUpdated.toIso8601String(),
        'readinessSummary': readinessSummary,
      };

  factory SavedIdeaSummary.fromJson(Map<String, dynamic> j) => SavedIdeaSummary(
        id: j['id'] as String,
        title: j['title'] as String,
        oneLiner: j['oneLiner'] as String,
        stageIndex: j['stageIndex'] as int,
        totalStages: j['totalStages'] as int,
        versionCount: j['versionCount'] as int,
        lastUpdated: DateTime.parse(j['lastUpdated'] as String),
        readinessSummary: j['readinessSummary'] as String?,
      );

  static SavedIdeaSummary fromSession(Map<String, dynamic> session) {
    final versions = session['versions'] as List;
    final report = session['report'] as Map<String, dynamic>?;
    return SavedIdeaSummary(
      id: session['id'] as String,
      title: session['title'] as String,
      oneLiner: session['oneLiner'] as String,
      stageIndex: session['stageIndex'] as int,
      totalStages: session['totalStages'] as int,
      versionCount: versions.length,
      lastUpdated: DateTime.now(),
      readinessSummary: report?['readinessSummary'] as String?,
    );
  }
}

/// Persists idea sessions on-device. This is the only class that knows
/// about storage — swap it for a Supabase-backed repository later without
/// touching VaultController or any screen.
class VaultRepository {
  static const _indexKey = 'crucible_vault_index';
  static const _sessionPrefix = 'crucible_session_';

  Future<List<Map<String, dynamic>>> loadIndex() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_indexKey);
    if (raw == null) return [];
    return (jsonDecode(raw) as List<dynamic>).cast<Map<String, dynamic>>();
  }

  Future<void> saveIndex(List<Map<String, dynamic>> index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_indexKey, jsonEncode(index));
  }

  Future<Map<String, dynamic>?> loadSession(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_sessionPrefix$id');
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<void> saveSession(String id, Map<String, dynamic> session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_sessionPrefix$id', jsonEncode(session));
  }

  Future<void> deleteSession(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_sessionPrefix$id');
  }
}

class VaultController extends ChangeNotifier {
  VaultController({required VaultRepository repository}) : _repository = repository;

  final VaultRepository _repository;
  List<SavedIdeaSummary> ideas = [];
  bool isLoading = true;

  Future<void> load() async {
    isLoading = true;
    notifyListeners();
    final index = await _repository.loadIndex();
    ideas = index.map(SavedIdeaSummary.fromJson).toList()
      ..sort((a, b) => b.lastUpdated.compareTo(a.lastUpdated));
    isLoading = false;
    notifyListeners();
  }

  Future<Map<String, dynamic>?> loadFullSession(String id) => _repository.loadSession(id);

  /// Wired into CrucibleController as onSessionChanged — called automatically
  /// every time a session's state changes, so nothing has to be saved manually.
  Future<void> upsertFromSession(Map<String, dynamic> session) async {
    final summary = SavedIdeaSummary.fromSession(session);
    ideas = [summary, ...ideas.where((i) => i.id != summary.id)]
      ..sort((a, b) => b.lastUpdated.compareTo(a.lastUpdated));

    await _repository.saveSession(summary.id, session);
    await _repository.saveIndex(ideas.map((i) => i.toJson()).toList());
    notifyListeners();
  }

  Future<void> delete(String id) async {
    ideas = ideas.where((i) => i.id != id).toList();
    await _repository.deleteSession(id);
    await _repository.saveIndex(ideas.map((i) => i.toJson()).toList());
    notifyListeners();
  }
}
