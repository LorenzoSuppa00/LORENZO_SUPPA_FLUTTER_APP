// lib/user_storage.dart
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'models/user.dart';

/// --- Mobile imports ---
import 'dart:io' as io;
import 'package:path_provider/path_provider.dart';

/// --- Web imports ---
import 'package:shared_preferences/shared_preferences.dart';

class UserStorage {
  static const _spKey = 'users_json';

  Future<List<User>> loadUsers() async {
    if (kIsWeb) {
      final sp = await SharedPreferences.getInstance();
      final raw = sp.getString(_spKey);
      if (raw == null || raw.isEmpty) return [];
      final List data = jsonDecode(raw) as List;
      return data.map((e) => User.fromJson(e as Map<String, dynamic>)).toList();
    } else {
      final path = await filePath();
      final f = io.File(path);
      if (!await f.exists()) return [];
      final raw = await f.readAsString();
      if (raw.trim().isEmpty) return [];
      final List data = jsonDecode(raw) as List;
      return data.map((e) => User.fromJson(e as Map<String, dynamic>)).toList();
    }
  }

  Future<void> saveUsers(List<User> users) async {
    final raw = jsonEncode(users.map((e) => e.toJson()).toList());
    if (kIsWeb) {
      final sp = await SharedPreferences.getInstance();
      await sp.setString(_spKey, raw);
    } else {
      final path = await filePath();
      final f = io.File(path);
      await f.writeAsString(raw);
    }
  }

  Future<String> readRawJson() async {
    if (kIsWeb) {
      final sp = await SharedPreferences.getInstance();
      return sp.getString(_spKey) ?? '[]';
    } else {
      final path = await filePath();
      final f = io.File(path);
      return (await f.exists()) ? await f.readAsString() : '[]';
    }
  }

  Future<String> filePath() async {
    if (kIsWeb) return 'browser-localstorage://$_spKey';
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/users.json';
  }
}
