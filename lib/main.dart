import 'dart:convert'; // per decodificare la risposta meteo
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // per Clipboard (copia JSON)
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:share_plus/share_plus.dart';
import 'login_page.dart';
import 'models/user.dart';
import 'user_storage.dart';
import 'auth.dart';
import 'login_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Eirsaf CRUD',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: FutureBuilder<bool>(
        future: Auth().isLoggedIn(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          final logged = snap.data ?? false;
          if (logged) {
            return const UsersPage();
          }
          return LoginPage(
            onLogin: (ctx) {
              Navigator.pushReplacement(
                ctx,
                MaterialPageRoute(builder: (_) => const UsersPage()),
              );
            },
          );
        },
      ),
    );
  }
}

class UsersPage extends StatefulWidget {
  const UsersPage({super.key});

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  final List<User> _users = [];
  final UserStorage _storage = UserStorage();
  int _nextId = 1;

  String? _weatherText; // es: "24.3°C, Sereno"

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    final loaded = await _storage.loadUsers();
    setState(() {
      _users
        ..clear()
        ..addAll(loaded);
      if (_users.isNotEmpty) {
        _nextId = _users.map((u) => u.id).reduce((a, b) => a > b ? a : b) + 1;
      }
    });
  }

  Future<void> _saveUsers() async {
    await _storage.saveUsers(_users);
  }

  void _addUser(String name, String email) {
    setState(() {
      _users.add(User(id: _nextId++, name: name, email: email));
    });
    _saveUsers();
  }

  void _updateUser(User user, String newName, String newEmail) {
    setState(() {
      user.name = newName;
      user.email = newEmail;
    });
    _saveUsers();
  }

  void _deleteUser(User user) {
    setState(() {
      _users.remove(user);
    });
    _saveUsers();
  }

  void _showUserDialog({User? user}) {
    final nameController = TextEditingController(text: user?.name ?? '');
    final emailController = TextEditingController(text: user?.email ?? '');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(user == null ? 'Aggiungi utente' : 'Modifica utente'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Nome'),
            ),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () {
              if (user == null) {
                _addUser(nameController.text, emailController.text);
              } else {
                _updateUser(user, nameController.text, emailController.text);
              }
              Navigator.pop(context);
            },
            child: const Text('Salva'),
          ),
        ],
      ),
    );
  }

  // ---- Meteo (posizione + Open-Meteo) ----
  Future<Position> _getPosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled)
      throw Exception('Servizi di localizzazione disattivati');

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied)
        throw Exception('Permesso posizione negato');
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception('Permesso negato in modo permanente');
    }
    return Geolocator.getCurrentPosition();
  }

  Future<void> _fetchWeatherFromDevice() async {
    try {
      final pos = await _getPosition();
      final lat = pos.latitude;
      final lon = pos.longitude;

      final r = await http.get(
        Uri.parse(
          'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current_weather=true',
        ),
      );
      if (r.statusCode != 200) throw Exception('HTTP ${r.statusCode}');
      final data = jsonDecode(r.body);
      final cw = data['current_weather'];
      if (cw == null) throw Exception('Dati meteo non disponibili');

      final code = (cw['weathercode'] as num).toInt();
      String desc;
      if (code == 0)
        desc = 'Sereno';
      else if ([1, 2, 3].contains(code))
        desc = 'Variabile';
      else if ([45, 48].contains(code))
        desc = 'Nebbia';
      else if ([61, 63, 65].contains(code))
        desc = 'Pioggia';
      else if ([71, 73, 75].contains(code))
        desc = 'Neve';
      else if ([95].contains(code))
        desc = 'Temporale';
      else
        desc = '—';

      setState(() {
        _weatherText = '${cw['temperature']}°C, $desc';
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Meteo: ${e.toString()}')));
    }
  }
  // ----------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestione Utenti'),
        actions: [
          // Mostra path + contenuto JSON in un dialog
          IconButton(
            icon: const Icon(Icons.code),
            tooltip: 'Vedi users.json',
            onPressed: () async {
              final raw = await _storage.readRawJson();
              final path = await _storage.filePath();
              if (!mounted) return;
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('users.json'),
                  content: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Percorso:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        SelectableText(path),
                        const SizedBox(height: 12),
                        const Text(
                          'Contenuto:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        SelectableText(raw),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Chiudi'),
                    ),
                  ],
                ),
              );
            },
          ),
          // Meteo dalla posizione
          IconButton(
            icon: const Icon(Icons.cloud_outlined),
            tooltip: 'Meteo (mia posizione)',
            onPressed: _fetchWeatherFromDevice,
          ),
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Esporta users.json',
            onPressed: _exportJson,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              await Auth().logout();
              if (!context.mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (_) => LoginPage(
                    onLogin: (ctx) {
                      Navigator.pushReplacement(
                        ctx,
                        MaterialPageRoute(builder: (_) => const UsersPage()),
                      );
                    },
                  ),
                ),
                (_) => false,
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (_weatherText != null)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Card(
                child: ListTile(
                  leading: const Icon(Icons.cloud),
                  title: const Text('Meteo attuale'),
                  subtitle: Text(_weatherText!),
                ),
              ),
            ),
          Expanded(
            child: ListView.builder(
              itemCount: _users.length,
              itemBuilder: (context, index) {
                final user = _users[index];
                return ListTile(
                  title: Text(user.name),
                  subtitle: Text(user.email),
                  onTap: () => _showUserDialog(user: user),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deleteUser(user),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showUserDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _exportJson() async {
    final path = await _storage.filePath();
    await Share.shareXFiles([XFile(path)], text: 'users.json');
  }
}
