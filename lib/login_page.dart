import 'package:flutter/material.dart';
import 'auth.dart';

class LoginPage extends StatefulWidget {
  final void Function(BuildContext ctx) onLogin;
  const LoginPage({super.key, required this.onLogin});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailCtrl = TextEditingController();
  final passCtrl  = TextEditingController();
  bool obscure = true;

  bool isLogin = true;        // toggle Login/Registrazione
  bool hasAccount = false;    // solo per sapere se esiste già qualcosa salvato

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    hasAccount = await Auth().hasAccount();
    // default: se esiste già un account, tab su "Accedi", altrimenti su "Crea account"
    setState(() => isLogin = hasAccount);
  }

  @override
  void dispose() {
    emailCtrl.dispose();
    passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = emailCtrl.text.trim();
    final pass  = passCtrl.text;
    if (email.isEmpty || pass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inserisci email e password')),
      );
      return;
    }

    // se l’utente seleziona "Crea account" e c’è già un account, chiedi conferma (lo sovrascrive)
    if (!isLogin && hasAccount) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Sovrascrivere account?'),
          content: const Text('Esiste già un account salvato. Vuoi sostituirlo con le nuove credenziali?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annulla')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sì, sostituisci')),
          ],
        ),
      );
      if (ok != true) return;
    }

    bool ok;
    if (isLogin) {
      ok = await Auth().login(email, pass);
    } else {
      ok = await Auth().register(email, pass);
      hasAccount = ok; // ora esiste
    }

    if (ok) {
      widget.onLogin(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Credenziali non valide')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final selStyle = ButtonStyle(
      backgroundColor: WidgetStateProperty.resolveWith<Color?>(
        (states) => states.contains(WidgetState.selected) ? Theme.of(context).colorScheme.primary : null,
      ),
      foregroundColor: WidgetStateProperty.resolveWith<Color?>(
        (states) => states.contains(WidgetState.selected) ? Colors.white : null,
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Autenticazione')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Toggle Accedi / Crea account
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FilterChip(
                  label: const Text('Accedi'),
                  selected: isLogin,
                  onSelected: (_) => setState(() => isLogin = true),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Crea account'),
                  selected: !isLogin,
                  onSelected: (_) => setState(() => isLogin = false),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            TextField(
              controller: passCtrl,
              obscureText: obscure,
              decoration: InputDecoration(
                labelText: 'Password',
                suffixIcon: IconButton(
                  icon: Icon(obscure ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => obscure = !obscure),
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _submit,
              child: Text(isLogin ? 'Entra' : 'Crea account'),
            ),
          ],
        ),
      ),
    );
  }
}
