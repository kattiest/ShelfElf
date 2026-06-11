import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/inventory_provider.dart';
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
      if (mounted) {
        context.read<InventoryProvider>().loadItems();
        Navigator.of(context).pop();
      }
    }
  }

  void _shareInvite(String pantryId) {
    Share.share(
      'Join my Shelf Elf pantry! Use this invite code when you register:\n\n'
      '$pantryId\n\n'
      'Download Shelf Elf and tap "Join" when creating your account.',
    );
  }

  Future<void> _joinExistingPantry() async {
    final codeCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.group_add_outlined),
          SizedBox(width: 8),
          Text('Join a Pantry'),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the invite code from the pantry owner.',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: codeCtrl,
              decoration: const InputDecoration(
                labelText: 'Invite Code',
                prefixIcon: Icon(Icons.vpn_key_outlined),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Join')),
        ],
      ),
    );

    if (confirmed != true || codeCtrl.text.trim().isEmpty || !mounted) return;

    try {
      final sync = context.read<SyncProvider>();
      final name = AuthService.instance.displayName ??
          AuthService.instance.email ??
          'Member';
      await sync.joinPantry(codeCtrl.text.trim(), name);
      await context.read<InventoryProvider>().loadItems();
      _loadMembers();
      setState(() {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Joined pantry successfully!'),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Could not join pantry: ${e.toString()}'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ));
      }
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
          // ── Status card ───────────────────────────────────────────────────
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
                        color: sync.isCloudMode
                            ? Colors.green
                            : cs.onSurfaceVariant,
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
                    if (auth.displayName != null && auth.displayName!.isNotEmpty)
                      Text(auth.displayName!,
                          style: const TextStyle(fontSize: 15,
                              fontWeight: FontWeight.w500)),
                    Text(auth.email ?? '',
                        style: TextStyle(
                            color: cs.onSurfaceVariant, fontSize: 13)),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Not signed in ─────────────────────────────────────────────────
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
                  await context.read<InventoryProvider>().loadItems();
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

            // Invite code card
            if (sync.pantryId != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Family Invite Code',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 4),
                      const Text(
                        'Share this with family members so they can sync '
                        'to your pantry.',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                      const SizedBox(height: 10),
                      // Code display
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: cs.outline.withAlpha(60)),
                        ),
                        child: Text(
                          sync.pantryId!,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 14,
                            color: cs.onSurface,
                            letterSpacing: 1,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Action buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.copy, size: 16),
                              label: const Text('Copy'),
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
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton.icon(
                              icon: const Icon(Icons.share, size: 16),
                              label: const Text('Send Invite'),
                              onPressed: () =>
                                  _shareInvite(sync.pantryId!),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Members card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text('Pantry Members',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14)),
                          ),
                          IconButton(
                            icon: const Icon(Icons.refresh, size: 18),
                            onPressed: _loadMembers,
                            tooltip: 'Refresh',
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      if (_loadingMembers)
                        const Center(
                            child: Padding(
                          padding: EdgeInsets.all(8),
                          child: CircularProgressIndicator(),
                        ))
                      else if (_members.isEmpty)
                        const Text('No members yet.',
                            style: TextStyle(color: Colors.grey))
                      else
                        ..._members.map((m) => ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: CircleAvatar(
                                radius: 16,
                                backgroundColor: cs.primaryContainer,
                                child: Text(
                                  ((m['displayName'] as String?) ?? '?')
                                      .substring(0, 1)
                                      .toUpperCase(),
                                  style: TextStyle(
                                      color: cs.onPrimaryContainer,
                                      fontSize: 12),
                                ),
                              ),
                              title: Text(
                                  m['displayName'] as String? ?? 'Unknown'),
                              trailing: m['role'] == 'owner'
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: cs.primaryContainer,
                                        borderRadius:
                                            BorderRadius.circular(12),
                                      ),
                                      child: Text('Owner',
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: cs.onPrimaryContainer)),
                                    )
                                  : null,
                            )),
                    ],
                  ),
                ),
              ),
            ],

            // If signed in but no pantry yet (shouldn't normally happen
            // but handle it gracefully)
            if (sync.pantryId == null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Icon(Icons.group_off_outlined,
                          size: 40, color: Colors.grey),
                      const SizedBox(height: 8),
                      const Text('No pantry linked yet.',
                          style: TextStyle(fontWeight: FontWeight.w500)),
                      const SizedBox(height: 4),
                      const Text(
                        'You\'re signed in but not linked to a shared pantry.',
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        icon: const Icon(Icons.add_home_outlined),
                        label: const Text('Create My Pantry'),
                        onPressed: () async {
                          final name = auth.displayName ?? 'My';
                          await context
                              .read<SyncProvider>()
                              .createPantry('$name\'s Pantry');
                          await context
                              .read<InventoryProvider>()
                              .loadItems();
                          _loadMembers();
                          setState(() {});
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 12),

            // Join a different pantry
            OutlinedButton.icon(
              icon: const Icon(Icons.group_add_outlined),
              label: const Text('Join Another Pantry'),
              onPressed: _joinExistingPantry,
              style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48)),
            ),
            const SizedBox(height: 8),

            // Sign out
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
