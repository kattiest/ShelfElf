import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/sync_provider.dart';
import '../services/auth_service.dart';

/// Shown when the user wants to sign in, register, or join a shared pantry.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

enum _AuthMode { login, register, joinPantry }

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _pantryIdCtrl = TextEditingController();

  _AuthMode _mode = _AuthMode.login;
  bool _loading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _nameCtrl.dispose();
    _pantryIdCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _errorMessage = null; });

    try {
      final auth = AuthService.instance;
      final sync = context.read<SyncProvider>();

      switch (_mode) {
        case _AuthMode.login:
          await auth.signInWithEmail(
              _emailCtrl.text.trim(), _passwordCtrl.text);
          await sync.initSync();

        case _AuthMode.register:
          await auth.registerWithEmail(
            _emailCtrl.text.trim(),
            _passwordCtrl.text,
            displayName: _nameCtrl.text.trim(),
          );
          await sync.createPantry(_nameCtrl.text.trim().isNotEmpty
              ? _nameCtrl.text.trim()
              : 'My Pantry');

        case _AuthMode.joinPantry:
          await auth.registerWithEmail(
            _emailCtrl.text.trim(),
            _passwordCtrl.text,
            displayName: _nameCtrl.text.trim(),
          );
          await sync.joinPantry(
            _pantryIdCtrl.text.trim(),
            _nameCtrl.text.trim(),
          );
      }

      if (mounted) Navigator.of(context).pop(true);
    } on Exception catch (e) {
      setState(() => _errorMessage = _friendlyError(e.toString()));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _friendlyError(String raw) {
    if (raw.contains('wrong-password') || raw.contains('invalid-credential'))
      return 'Incorrect email or password.';
    if (raw.contains('user-not-found')) return 'No account with that email.';
    if (raw.contains('email-already-in-use'))
      return 'An account already exists with that email.';
    if (raw.contains('weak-password')) return 'Password must be 6+ characters.';
    if (raw.contains('network-request-failed'))
      return 'No internet connection.';
    return 'Something went wrong. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_mode == _AuthMode.login
            ? 'Sign In'
            : _mode == _AuthMode.register
                ? 'Create Account'
                : 'Join Shared Pantry'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Mode tabs
              SegmentedButton<_AuthMode>(
                segments: const [
                  ButtonSegment(
                      value: _AuthMode.login, label: Text('Sign In')),
                  ButtonSegment(
                      value: _AuthMode.register, label: Text('Register')),
                  ButtonSegment(
                      value: _AuthMode.joinPantry, label: Text('Join')),
                ],
                selected: {_mode},
                onSelectionChanged: (s) =>
                    setState(() { _mode = s.first; _errorMessage = null; }),
              ),
              const SizedBox(height: 24),

              // Name (register/join)
              if (_mode != _AuthMode.login) ...[
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Your Name',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  textCapitalization: TextCapitalization.words,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Required'
                      : null,
                ),
                const SizedBox(height: 12),
              ],

              // Email
              TextFormField(
                controller: _emailCtrl,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (v) =>
                    (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
              ),
              const SizedBox(height: 12),

              // Password
              TextFormField(
                controller: _passwordCtrl,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                obscureText: _obscurePassword,
                validator: (v) =>
                    (v == null || v.length < 6) ? 'Min 6 characters' : null,
              ),
              const SizedBox(height: 12),

              // Pantry ID (join mode)
              if (_mode == _AuthMode.joinPantry) ...[
                TextFormField(
                  controller: _pantryIdCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Pantry Invite Code',
                    prefixIcon: Icon(Icons.group_outlined),
                    hintText: 'Paste the code from the pantry owner',
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
              ],

              // Error
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cs.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(_errorMessage!,
                      style: TextStyle(color: cs.onErrorContainer)),
                ),
                const SizedBox(height: 12),
              ],

              // Submit
              FilledButton(
                onPressed: _loading ? null : _submit,
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52)),
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text(_mode == _AuthMode.login
                        ? 'Sign In'
                        : _mode == _AuthMode.register
                            ? 'Create Account & Pantry'
                            : 'Join Pantry'),
              ),

              // Forgot password
              if (_mode == _AuthMode.login) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () async {
                    if (_emailCtrl.text.trim().isEmpty) {
                      setState(() =>
                          _errorMessage = 'Enter your email first.');
                      return;
                    }
                    await AuthService.instance
                        .sendPasswordReset(_emailCtrl.text.trim());
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Password reset email sent.'),
                        behavior: SnackBarBehavior.floating,
                      ));
                    }
                  },
                  child: const Text('Forgot password?'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
