import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:share_plus/share_plus.dart';
import 'login_page.dart';
import 'models/user.dart';
import 'user_storage.dart';
import 'auth.dart';
import 'meteo_page.dart';

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
      theme: (() {
        final scheme = ColorScheme.fromSeed(seedColor: Colors.indigo);
        return ThemeData(
          useMaterial3: true,
          colorScheme: scheme,
          scaffoldBackgroundColor: scheme.surface,
          appBarTheme: AppBarTheme(
            backgroundColor: scheme.primary,
            foregroundColor: scheme.onPrimary, // icone/overflow
            elevation: 0,
            centerTitle: false,
            // 🔥 forziamo il colore del titolo (su web altrimenti resta nero)
            titleTextStyle: TextStyle(
              color: scheme.onPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
            // opzionale ma utile per coerenza (sub-title/toolbar text)
            toolbarTextStyle: TextStyle(color: scheme.onPrimary),
            // opzionali: garantiscono il colore delle icone anche su temi particolari
            iconTheme: IconThemeData(color: scheme.onPrimary),
            actionsIconTheme: IconThemeData(color: scheme.onPrimary),
          ),

          floatingActionButtonTheme: FloatingActionButtonThemeData(
            backgroundColor: scheme.primary,
            foregroundColor: scheme.onPrimary,
            elevation: 3,
            extendedTextStyle: const TextStyle(fontWeight: FontWeight.w600),
          ),

          cardTheme: CardThemeData(
            elevation: 1,
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            surfaceTintColor: Colors.transparent, // niente “tinta” M3
          ),

          inputDecorationTheme: InputDecorationTheme(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            isDense: true,
            filled: true,
            fillColor: scheme.surfaceVariant.withOpacity(.6),
          ),

          listTileTheme: ListTileThemeData(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            iconColor: scheme.primary,
          ),

          dividerTheme: DividerThemeData(color: scheme.outlineVariant),
        );
      })(),

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

  Future<void> _shareJson() async {
    try {
      // Assicura ultimo stato salvato
      await _storage.saveUsers(_users);

      if (kIsWeb) {
        // Web: copia negli appunti (fallback universale)
        final raw = await _storage.readRawJson();
        await Clipboard.setData(ClipboardData(text: raw));
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('JSON copiato negli appunti')),
        );
        return;
      }

      // Mobile: share_plus con XFile
      final srcPath = await _storage.filePath();
      await Share.shareXFiles([
        XFile(srcPath, mimeType: 'application/json', name: 'users.json'),
      ], text: 'users.json');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore condivisione: ${e.toString()}')),
      );
    }
  }

  Future<void> _openJsonPretty() async {
    final raw = await _storage.readRawJson();
    final pretty = const JsonEncoder.withIndent('  ').convert(jsonDecode(raw));
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('users.json'),
        content: SingleChildScrollView(child: SelectableText(pretty)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Chiudi'),
          ),
        ],
      ),
    );
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
          // Barra di ricerca
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
                leading: const Icon(Icons.ios_share),
                title: const Text('Condividi JSON'),
                onTap: () async {
                  Navigator.pop(context);
                  await Future.delayed(const Duration(milliseconds: 250));
                  await _shareJson();
                },
              ),

              ListTile(
                leading: const Icon(Icons.visibility),
                title: const Text('Apri JSON (anteprima)'),
                onTap: () {
                  Navigator.pop(context);
                  _openJsonPretty();
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
                            MaterialPageRoute(
                              builder: (_) => const UsersPage(),
                            ),
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
}
