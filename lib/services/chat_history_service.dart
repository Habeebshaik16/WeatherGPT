
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class ChatHistoryService {
  static const String _storageKey = 'weathergpt_chat_history';

  final SharedPreferencesAsync _preferences = SharedPreferencesAsync();

  Future<List<Map<String, dynamic>>> getConversations() async {
    try {
      final saved = await _preferences.getString(_storageKey);

      if (saved == null || saved.isEmpty) {
        return [];
      }

      final decoded = jsonDecode(saved);

      if (decoded is! List) return [];

      return decoded
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveConversation({
    required String id,
    required String title,
    required String location,
    required List<Map<String, dynamic>> messages,
  }) async {
    final conversations = await getConversations();

    final conversation = <String, dynamic>{
      'id': id,
      'title': title,
      'location': location,
      'updatedAt': DateTime.now().toIso8601String(),
      'messages': messages,
    };

    final existingIndex = conversations.indexWhere(
      (item) => item['id'] == id,
    );

    if (existingIndex >= 0) {
      conversations[existingIndex] = conversation;
    } else {
      conversations.insert(0, conversation);
    }

    conversations.sort((a, b) {
      final first = DateTime.tryParse(a['updatedAt']?.toString() ?? '');
      final second = DateTime.tryParse(b['updatedAt']?.toString() ?? '');

      return (second ?? DateTime(2000))
          .compareTo(first ?? DateTime(2000));
    });

    await _preferences.setString(
      _storageKey,
      jsonEncode(conversations),
    );
  }

  Future<void> deleteConversation(String id) async {
    final conversations = await getConversations();

    conversations.removeWhere((item) => item['id'] == id);

    await _preferences.setString(
      _storageKey,
      jsonEncode(conversations),
    );
  }

  Future<void> clearHistory() async {
    await _preferences.remove(_storageKey);
  }
}
