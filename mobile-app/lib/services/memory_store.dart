// memory_store.dart — Persistent fact memory for Lumen X1 Lite
// Two storage paths:
//   1. Demographic facts — extracted deterministically via regex from natural speech
//   2. Explicit facts — stored when user says "remember that X" or the LLM decides to persist
// All storage uses SharedPreferences (no Hive, no extra deps).

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class MemoryStore {
  static const String _storageKey = 'lumen_memory_facts_v2';
  static const String _notesKey = 'lumen_memory_notes_v2';

  Map<String, String> _facts =
      {}; // keyed demographic facts (user_name, user_location, …)
  List<String> _notes = []; // freeform notes stored via "remember that …"
  bool _loaded = false;

  // ─── SINGLETON LIGHT PATTERN ─────────────────────────────────────────────────
  // Allows ToolRegistry to call MemoryStore.instance without a full DI framework.
  static MemoryStore? _instance;
  static MemoryStore get instance {
    _instance ??= MemoryStore();
    return _instance!;
  }

  // ─── DEMOGRAPHIC EXTRACTION RULES ────────────────────────────────────────────
  static final List<_ExtractionRule> _rules = [
    _ExtractionRule(
      'user_name',
      RegExp(
        r"(?:my name is|i'm|i am|call me|they call me)\s+(\w+)",
        caseSensitive: false,
      ),
      1,
    ),
    _ExtractionRule(
      'user_location',
      RegExp(
        r"(?:i live in|i'm from|i am from|i stay in|i reside in)\s+(.+?)(?:\.|,|$)",
        caseSensitive: false,
      ),
      1,
    ),
    _ExtractionRule(
      'user_work',
      RegExp(
        r"(?:i work at|i work for|i'm working at|i am working at)\s+(.+?)(?:\.|,|$)",
        caseSensitive: false,
      ),
      1,
    ),
    _ExtractionRule(
      'user_age',
      RegExp(
        r"(?:i'm|i am)\s+(\d{1,3})\s*(?:years old|yr|yrs)",
        caseSensitive: false,
      ),
      1,
    ),
    _ExtractionRule(
      'user_school',
      RegExp(
        r"(?:i study at|i go to|my school is|my college is|my university is)\s+(.+?)(?:\.|,|$)",
        caseSensitive: false,
      ),
      1,
    ),
    _ExtractionRule(
      'user_language',
      RegExp(
        r"(?:i speak|my language is|i prefer)\s+(english|hindi|tamil|telugu|kannada|bengali|marathi|gujarati|malayalam|punjabi|urdu|spanish|french|german|japanese|korean|chinese|arabic)\b",
        caseSensitive: false,
      ),
      1,
    ),
  ];

  // ─── EXPLICIT MEMORY PATTERNS ─────────────────────────────────────────────────
  // Catches: "remember that X", "don't forget X", "note that X", "save this: X", etc.
  static final _explicitMemoryPattern = RegExp(
    r"\b(?:remember\s+that|remember\s+this\s*:?|don'?t\s+forget\s+(?:that)?|note\s+that|save\s+this\s*:?|keep\s+in\s+mind\s+that|store\s+this\s*:?|make\s+a\s+note\s+(?:that)?)\s+(.+?)(?:\.|$)",
    caseSensitive: false,
  );

  /// Returns true if the message is an explicit memory storage request.
  static bool isMemoryRequest(String message) =>
      _explicitMemoryPattern.hasMatch(message);

  // ─── INIT ─────────────────────────────────────────────────────────────────────
  Future<void> init() async {
    if (_loaded) return;
    _instance ??= this; // register as singleton on first init
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawFacts = prefs.getString(_storageKey);
      if (rawFacts != null) {
        _facts = Map<String, String>.from(jsonDecode(rawFacts) as Map);
      }
      final rawNotes = prefs.getStringList(_notesKey);
      if (rawNotes != null) {
        _notes = List<String>.from(rawNotes);
      }
    } catch (_) {
      _facts = {};
      _notes = [];
    }
    _loaded = true;
  }

  // ─── REMEMBER / RECALL ────────────────────────────────────────────────────────
  Future<void> remember(String key, String value) async {
    _facts[key] = value.trim();
    await _persist();
  }

  String? recall(String key) => _facts[key];
  Map<String, String> get allFacts => Map.unmodifiable(_facts);
  List<String> get allNotes => List.unmodifiable(_notes);

  // ─── STORE NOTE (freeform, LLM or explicit user request) ─────────────────────
  /// Stores a free-form note string. Called by the 'remember' tool and from
  /// storeFromMessage when the user says "remember that …".
  /// Returns the stored note text.
  Future<String> storeNote(String note) async {
    final trimmed = note.trim();
    if (trimmed.isEmpty) return '';
    // Deduplicate
    if (!_notes.contains(trimmed)) {
      _notes.add(trimmed);
      if (_notes.length > 100) _notes.removeAt(0); // rolling cap
      await _persistNotes();
    }
    return trimmed;
  }

  // ─── EXTRACT FACTS FROM USER MESSAGE ─────────────────────────────────────────
  /// Call on every user message. Returns true if anything new was stored.
  Future<bool> extractFacts(String userMessage) async {
    bool extracted = false;
    for (final rule in _rules) {
      final match = rule.pattern.firstMatch(userMessage);
      if (match != null) {
        final value = match.group(rule.groupIndex)?.trim();
        if (value != null && value.isNotEmpty && value.length < 100) {
          if (_facts[rule.key] != value) {
            _facts[rule.key] = value;
            extracted = true;
          }
        }
      }
    }
    if (extracted) await _persist();
    return extracted;
  }

  /// Combined: extract demographic facts AND handle explicit memory requests.
  /// Returns a human-readable confirmation string if something was stored, else null.
  Future<String?> storeFromMessage(String userMessage) async {
    bool stored = await extractFacts(userMessage);
    String? confirmation;

    final match = _explicitMemoryPattern.firstMatch(userMessage);
    if (match != null) {
      final content = match.group(1)?.trim();
      if (content != null && content.isNotEmpty && content.length < 300) {
        await storeNote(content);
        stored = true;
        confirmation = "Got it — I'll remember: \"$content\"";
      }
    }
    return stored ? (confirmation ?? 'Noted.') : null;
  }

  // ─── BUILD MEMORY BLOCK FOR SYSTEM PROMPT ────────────────────────────────────
  /// Returns a block injected into the system prompt. Empty if nothing stored.
  String buildMemoryBlock() {
    final buf = StringBuffer();
    if (_facts.isNotEmpty) {
      buf.writeln('\nKnown facts about the user:');
      for (final e in _facts.entries) {
        buf.writeln('- ${_humanize(e.key)}: ${e.value}');
      }
    }
    if (_notes.isNotEmpty) {
      buf.writeln('\nUser notes to remember:');
      // Only last 10 notes in the prompt to keep token count bounded
      final recent = _notes.length > 10
          ? _notes.sublist(_notes.length - 10)
          : _notes;
      for (final n in recent) {
        buf.writeln('- $n');
      }
    }
    return buf.toString();
  }

  // ─── CLEAR ────────────────────────────────────────────────────────────────────
  Future<void> clearAll() async {
    _facts.clear();
    _notes.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
    await prefs.remove(_notesKey);
  }

  // ─── INTERNALS ────────────────────────────────────────────────────────────────
  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, jsonEncode(_facts));
    } catch (_) {}
  }

  Future<void> _persistNotes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_notesKey, _notes);
    } catch (_) {}
  }

  static String _humanize(String key) => key
      .replaceAll('_', ' ')
      .replaceFirstMapped(RegExp(r'^\w'), (m) => m.group(0)!.toUpperCase());
}

class _ExtractionRule {
  final String key;
  final RegExp pattern;
  final int groupIndex;
  const _ExtractionRule(this.key, this.pattern, this.groupIndex);
}
