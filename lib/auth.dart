import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';

class Auth {
  static const _kEmail = 'auth_email';
  static const _kPass  = 'auth_pass_hash';
  static const _kLogged = 'logged_in';

  String _hash(String s) => sha256.convert(utf8.encode(s)).toString();

  Future<bool> hasAccount() async {
    final p = await SharedPreferences.getInstance();
    return p.containsKey(_kPass);
  }

  Future<bool> register(String email, String password) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kEmail, email);
    await p.setString(_kPass, _hash(password));
    await p.setBool(_kLogged, true);
    return true;
  }

  Future<bool> login(String email, String password) async {
    final p = await SharedPreferences.getInstance();
    final savedEmail = p.getString(_kEmail);
    final savedHash  = p.getString(_kPass);
    if (savedEmail == null || savedHash == null) return false;
    if (email != savedEmail) return false;
    if (_hash(password) != savedHash) return false;
    await p.setBool(_kLogged, true);
    return true;
  }

  Future<void> logout() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kLogged, false);
  }

  Future<bool> isLoggedIn() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_kLogged) ?? false;
  }
}
