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
  final passCtrl = TextEditingController();
  bool obscure = true;

  bool isLogin = true; // toggle Login/Registrazione
  bool hasAccount = false; // solo per sapere se esiste già qualcosa salvato

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
    final pass = passCtrl.text;
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
          content: const Text(
            'Esiste già un account salvato. Vuoi sostituirlo con le nuove credenziali?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annulla'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Sì, sostituisci'),
            ),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Credenziali non valide')));
    }
  }

  @override
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    InputDecoration dec(String label, {Widget? suffix}) => InputDecoration(
      labelText: label,
      filled: true,
      fillColor: theme.colorScheme.surfaceVariant.withOpacity(.35),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      suffixIcon: suffix,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Autenticazione')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Toggle Accedi / Crea account
                      Center(
                        child: Wrap(
                          spacing: 8,
                          children: [
                            ChoiceChip(
                              label: const Text('Accedi'),
                              selected: isLogin,
                              onSelected: (_) => setState(() => isLogin = true),
                            ),
                            ChoiceChip(
                              label: const Text('Crea account'),
                              selected: !isLogin,
                              onSelected: (_) =>
                                  setState(() => isLogin = false),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      TextField(
                        controller: emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        decoration: dec('Email'),
                      ),

                      const SizedBox(height: 12), // 👉 spazio tra i campi

                      TextField(
                        controller: passCtrl,
                        obscureText: obscure,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _submit(),
                        decoration: dec(
                          'Password',
                          suffix: IconButton(
                            icon: Icon(
                              obscure ? Icons.visibility : Icons.visibility_off,
                            ),
                            onPressed: () => setState(() => obscure = !obscure),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      FilledButton(
                        onPressed: _submit,
                        child: Text(isLogin ? 'Entra' : 'Crea account'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
