import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'models/user.dart';

class UserStorage {
  Future<String> get _localPath async {
    final dir = await getApplicationDocumentsDirectory();
    return dir.path;
  }

  Future<File> get _localFile async {
    final path = await _localPath;
    return File('$path/users.json');
  }

  Future<void> saveUsers(List<User> users) async {
    final file = await _localFile;
    final jsonString = jsonEncode(users.map((u) => u.toJson()).toList());
    await file.writeAsString(jsonString);
  }

  Future<List<User>> loadUsers() async {
    try {
      final file = await _localFile;
      if (await file.exists()) {
        final contents = await file.readAsString();
        final List<dynamic> data = jsonDecode(contents);
        return data.map((e) => User.fromJson(e)).toList();
      } else {
        return [];
      }
    } catch (e) {
      return [];
    }
  }

  // Ritorna il path completo del file users.json
  Future<String> filePath() async {
    final f = await _localFile;
    return f.path;
  }

  // Ritorna il contenuto raw del JSON (o [] se il file non esiste ancora)
  Future<String> readRawJson() async {
    final f = await _localFile;
    if (await f.exists()) return await f.readAsString();
    return '[]';
  }
}
