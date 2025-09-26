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
import 'dart:io'; // per download JSON
import 'meteo_page.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import 'package:open_filex/open_filex.dart';

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
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          isDense: true,
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        ),

        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ButtonStyle(
            padding: WidgetStatePropertyAll(
              EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ),

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
  final _searchCtrl = TextEditingController();
  String _query = '';
  String? _weatherText; // es: "24.3°C, Sereno"

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<User> get _filteredUsers {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _users;
    return _users.where((u) {
      final n = u.name.toLowerCase();
      final e = u.email.toLowerCase();
      return n.contains(q) || e.contains(q) || u.id.toString() == q;
    }).toList();
  }

Future<void> _downloadJson() async {
  try {
    final srcPath = await _storage.filePath();

    final params = SaveFileDialogParams(
      sourceFilePath: srcPath,
      fileName: 'users.json',
      mimeTypesFilter: ['application/json', 'text/plain'],
    );

    final savedPath = await FlutterFileDialog.saveFile(params: params);
    if (!mounted) return;

    if (savedPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Salvataggio annullato')),
      );
      return;
    }

    // Prova ad aprire automaticamente
    try {
      final res = await OpenFilex.open(savedPath);
      if (res.type != ResultType.done) {
        // fallback: share sheet (l'utente può aprirlo con l'app preferita)
        await Share.shareXFiles(
          [XFile(savedPath, mimeType: 'application/json', name: 'users.json')],
        );
      }
    } on MissingPluginException {
      // fallback se il plugin non è registrato (es. dopo hot-reload)
      await Share.shareXFiles(
        [XFile(savedPath, mimeType: 'application/json', name: 'users.json')],
      );
    }
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Errore: ${e.toString()}')));
  }
}




  String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  Future<void> _confirmDelete(User user) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminare utente?'),
        content: Text('Sei sicuro di voler eliminare "${user.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            style: ButtonStyle(
              backgroundColor: WidgetStatePropertyAll(
                Theme.of(context).colorScheme.error,
              ),
              foregroundColor: const WidgetStatePropertyAll(Colors.white),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
    if (ok == true) {
      _deleteUser(user);
    }
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
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: user?.name ?? '');
    final emailController = TextEditingController(text: user?.email ?? '');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(user == null ? 'Aggiungi utente' : 'Modifica utente'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Nome'),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Inserisci un nome'
                    : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  final s = v?.trim() ?? '';
                  if (s.isEmpty) return 'Inserisci un’email';
                  final re = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                  if (!re.hasMatch(s)) return 'Email non valida';
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() != true) return;
              if (user == null) {
                _addUser(
                  nameController.text.trim(),
                  emailController.text.trim(),
                );
              } else {
                _updateUser(
                  user,
                  nameController.text.trim(),
                  emailController.text.trim(),
                );
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
        title: Row(
          children: [
            const Text('Gestione Utenti'),
            const SizedBox(width: 12),
            Chip(
              label: Text('${_users.length}'),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),

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
          // IconButton(
          //   icon: const Icon(Icons.cloud_outlined),
          //   tooltip: 'Meteo (mia posizione)',
          //   onPressed: _fetchWeatherFromDevice,
          // ),
          // IconButton(
          //   icon: const Icon(Icons.share),
          //   tooltip: 'Esporta users.json',
          //   onPressed: _exportJson,
          // ),
          // IconButton(
          //   icon: const Icon(Icons.logout),
          //   tooltip: 'Logout',
          //   onPressed: () async {
          //     await Auth().logout();
          //     if (!context.mounted) return;
          //     Navigator.pushAndRemoveUntil(
          //       context,
          //       MaterialPageRoute(
          //         builder: (_) => LoginPage(
          //           onLogin: (ctx) {
          //             Navigator.pushReplacement(
          //               ctx,
          //               MaterialPageRoute(builder: (_) => const UsersPage()),
          //             );
          //           },
          //         ),
          //       ),
          //       (_) => false,
          //     );
          //   },
          // ),
        ],
      ),
      body: Column(
        children: [
          if (_weatherText != null)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Card(
                child: ListTile(
                  leading: const Icon(Icons.cloud_queue),
                  title: const Text('Meteo attuale'),
                  subtitle: Text(_weatherText!),
                  trailing: const Icon(Icons.chevron_right),
                ),
              ),
            ),

          // 🔎 Barra di ricerca
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _query = v),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Cerca per nome o email…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _query = '');
                        },
                      ),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),

          Expanded(
            child: ListView.builder(
              itemCount: _filteredUsers.length,
              itemBuilder: (context, index) {
                final user = _filteredUsers[index];
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(child: Text(_initials(user.name))),
                    title: Text(
                      user.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(user.email),
                    onTap: () => _showUserDialog(user: user),
                    trailing: Wrap(
                      spacing: 4,
                      children: [
                        IconButton(
                          tooltip: 'Modifica',
                          icon: const Icon(Icons.edit),
                          onPressed: () => _showUserDialog(user: user),
                        ),
                        IconButton(
                          tooltip: 'Elimina',
                          icon: const Icon(Icons.delete_outline),
                          color: Theme.of(context).colorScheme.error,
                          onPressed: () => _confirmDelete(user),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showUserDialog(),
        icon: const Icon(Icons.person_add_alt),
        label: const Text('Aggiungi utente'),
      ),

      drawer: Drawer(
  child: SafeArea(
    child: ListView(
      children: [
        const DrawerHeader(
          child: ListTile(
            leading: Icon(Icons.apps),
            title: Text('Menu'),
            subtitle: Text('Eirsaf Demo'),
          ),
        ),

        ListTile(
          leading: const Icon(Icons.people),
          title: const Text('Gestione Utenti'),
          onTap: () {
            Navigator.pop(context); // sei già su questa pagina
          },
        ),

        ListTile(
          leading: const Icon(Icons.cloud),
          title: const Text('Meteo'),
          onTap: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MeteoPage()),
            );
          },
        ),

        ListTile(
          leading: const Icon(Icons.file_download),
          title: const Text('Scarica dati (JSON)'),
          onTap: () {
            Navigator.pop(context);
            _downloadJson(); // usa il tuo metodo già presente
          },
        ),

        const Divider(),

        ListTile(
          leading: const Icon(Icons.logout),
          title: const Text('Logout'),
          onTap: () async {
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
  ),
),

    );
  }

  Future<void> _exportJson() async {
    final path = await _storage.filePath();
    await Share.shareXFiles([XFile(path)], text: 'users.json');
  }
}
