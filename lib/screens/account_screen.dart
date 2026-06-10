import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/sync_provider.dart';
import '../services/auth_service.dart';
import 'auth_screen.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  List<Map<String, dynamic>> _members = [];
  bool _loadingMembers = false;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    setState(() => _loadingMembers = true);
    final sync = context.read<SyncProvider>();
    final members = await sync.getMembers();
    if (mounted) setState(() { _members = members; _loadingMembers = false; });
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
            'You\'ll switch to local-only mode. Your data stays on this device.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Sign Out')),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await AuthService.instance.signOut();
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final auth = AuthService.instance;
    final sync = context.watch<SyncProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Account & Sync')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Account status ────────────────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        sync.isCloudMode
                            ? Icons.cloud_done_outlined
                            : Icons.cloud_off_outlined,
                        color: sync.isCloudMode ? Colors.green : Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        sync.isCloudMode ? 'Cloud Sync Active' : 'Local Only',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ),
                  if (auth.isSignedIn) ...[
                    const SizedBox(height: 8),
                    Text(auth.email ?? '',
                        style: TextStyle(color: cs.onSurfaceVariant)),
                    if (auth.displayName != null)
                      Text(auth.displayName!,
                          style: TextStyle(color: cs.onSurfaceVariant)),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Not signed in ────────────────────────────────────────────────
          if (!auth.isSignedIn) ...[
            FilledButton.icon(
              icon: const Icon(Icons.login),
              label: const Text('Sign In or Create Account'),
              onPressed: () async {
                final result = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(builder: (_) => const AuthScreen()),
                );
                if (result == true && mounted) {
                  await context.read<SyncProvider>().initSync();
                  _loadMembers();
                  setState(() {});
                }
              },
              style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52)),
            ),
            const SizedBox(height: 8),
            const Text(
              'Sign in to sync your pantry across multiple devices '
              'and share it with family members.',
              style: TextStyle(color: Colors.grey, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],

          // ── Signed in ─────────────────────────────────────────────────────
          if (auth.isSignedIn) ...[
            // Pantry invite code
            if (sync.pantryId != null) ...[
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Invite Code',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 4),
                      const Text(
                        'Share this code with family members so they can '
                        'join your pantry.',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: cs.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                sync.pantryId!,
                                style: const TextStyle(
                                    fontFamily: 'monospace', fontSize: 13),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filled(
                            icon: const Icon(Icons.copy, size: 18),
                            tooltip: 'Copy code',
                            onPressed: () {
                              Clipboard.setData(
                                  ClipboardData(text: sync.pantryId!));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Invite code copied'),
                                  behavior: SnackBarBehavior.floating,
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Members list
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Pantry Members',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 8),
                      if (_loadingMembers)
                        const Center(child: CircularProgressIndicator())
                      else if (_members.isEmpty)
                        const Text('No members yet.',
                            style: TextStyle(color: Colors.grey))
                      else
                        ..._members.map((m) => ListTile(
                              dense: true,
                              leading: const Icon(Icons.person_outline),
                              title: Text(m['displayName'] as String? ?? 'Unknown'),
                              trailing: m['role'] == 'owner'
                                  ? Chip(
                                      label: const Text('Owner',
                                          style: TextStyle(fontSize: 11)),
                                      padding: EdgeInsets.zero,
                                    )
                                  : null,
                            )),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 16),
            OutlinedButton.icon(
              icon: const Icon(Icons.logout, color: Colors.red),
              label: const Text('Sign Out',
                  style: TextStyle(color: Colors.red)),
              onPressed: _signOut,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red),
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
