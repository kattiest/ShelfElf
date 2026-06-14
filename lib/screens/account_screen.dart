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
  bool _actionLoading = false;
  String? _actionError;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    setState(() => _loadingMembers = true);
    try {
      final members = await context.read<SyncProvider>().getMembers();
      if (mounted) setState(() { _members = members; _loadingMembers = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingMembers = false);
    }
  }

  Future<void> _createPantry() async {
    final auth = AuthService.instance;
    final name = auth.displayName?.isNotEmpty == true
        ? auth.displayName!
        : auth.email?.split('@').first ?? 'My';

    setState(() { _actionLoading = true; _actionError = null; });

    try {
      final sync = context.read<SyncProvider>();
      await sync.createPantry('$name\'s Pantry');

      // Wait briefly for Firestore to confirm, then reload everything
      await Future.delayed(const Duration(milliseconds: 500));
      await sync.initSync(); // re-read pantryId from Firestore
      if (mounted) {
        await context.read<InventoryProvider>().loadItems();
        await _loadMembers();
        setState(() { _actionLoading = false; });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Pantry created! Share the invite code with family.'),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _actionLoading = false;
          _actionError = 'Failed to create pantry: ${e.toString()}';
        });
      }
    }
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
              'Paste the invite code from the pantry owner.',
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

    setState(() { _actionLoading = true; _actionError = null; });

    try {
      final sync = context.read<SyncProvider>();
      final auth = AuthService.instance;
      final name = auth.displayName ?? auth.email?.split('@').first ?? 'Member';

      await sync.joinPantry(codeCtrl.text.trim(), name);
      await Future.delayed(const Duration(milliseconds: 500));
      await sync.initSync();

      if (mounted) {
        await context.read<InventoryProvider>().loadItems();
        await _loadMembers();
        setState(() { _actionLoading = false; });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Joined pantry! Your items are now syncing.'),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _actionLoading = false;
          _actionError = 'Could not join: Check the invite code and try again.';
        });
      }
    }
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
            'You\'ll switch to local-only mode. Your cloud data stays safe.'),
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
      'Join my Shelf Elf pantry!\n\n'
      'Use this invite code when you register or tap "Join Another Pantry":\n\n'
      '$pantryId\n\n'
      'Download Shelf Elf, create an account, then paste this code.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final auth = AuthService.instance;
    final sync = context.watch<SyncProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Account & Sync')),
      body: _actionLoading
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Setting up your pantry…'),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── Status card ─────────────────────────────────────────────
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
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
                            sync.isCloudMode
                                ? 'Cloud Sync Active'
                                : 'Local Only',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ]),
                        if (auth.isSignedIn) ...[
                          const SizedBox(height: 8),
                          if (auth.displayName?.isNotEmpty == true)
                            Text(auth.displayName!,
                                style: const TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.w500)),
                          Text(auth.email ?? '',
                              style: TextStyle(
                                  color: cs.onSurfaceVariant, fontSize: 13)),
                        ],
                      ],
                    ),
                  ),
                ),

                // ── Error message ────────────────────────────────────────────
                if (_actionError != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cs.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline,
                            color: cs.onErrorContainer, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(_actionError!,
                              style:
                                  TextStyle(color: cs.onErrorContainer)),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 12),

                // ── Not signed in ─────────────────────────────────────────
                if (!auth.isSignedIn) ...[
                  FilledButton.icon(
                    icon: const Icon(Icons.login),
                    label: const Text('Sign In or Create Account'),
                    onPressed: () async {
                      final result = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const AuthScreen()),
                      );
                      if (result == true && mounted) {
                        setState(() { _actionLoading = true; });
                        await context.read<SyncProvider>().initSync();
                        await context.read<InventoryProvider>().loadItems();
                        await _loadMembers();
                        if (mounted) setState(() { _actionLoading = false; });
                      }
                    },
                    style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52)),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Sign in to sync your pantry across devices '
                    'and share with family.',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ],

                // ── Signed in, has pantry ─────────────────────────────────
                if (auth.isSignedIn && sync.pantryId != null) ...[
                  // Invite code
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
                            'Share this code so family members can join '
                            'your pantry.',
                            style:
                                TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                          const SizedBox(height: 12),
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
                            child: SelectableText(
                              sync.pantryId!,
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 14,
                                color: cs.onSurface,
                                letterSpacing: 0.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.copy, size: 16),
                                label: const Text('Copy'),
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(
                                      text: sync.pantryId!));
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(const SnackBar(
                                    content: Text('Code copied'),
                                    behavior: SnackBarBehavior.floating,
                                    duration: Duration(seconds: 2),
                                  ));
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
                          ]),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Members
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
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
                          ]),
                          if (_loadingMembers)
                            const Center(
                                child: Padding(
                              padding: EdgeInsets.all(8),
                              child: CircularProgressIndicator(),
                            ))
                          else if (_members.isEmpty)
                            const Padding(
                              padding: EdgeInsets.only(top: 4),
                              child: Text(
                                  'Just you so far. Share the invite code!',
                                  style: TextStyle(color: Colors.grey)),
                            )
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
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  title: Text(m['displayName'] as String? ??
                                      'Unknown'),
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
                                                  color:
                                                      cs.onPrimaryContainer)),
                                        )
                                      : null,
                                )),
                        ],
                      ),
                    ),
                  ),
                ],

                // ── Signed in, no pantry yet ──────────────────────────────
                if (auth.isSignedIn && sync.pantryId == null) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Icon(Icons.home_outlined,
                              size: 48, color: cs.primary),
                          const SizedBox(height: 12),
                          const Text('Set Up Your Pantry',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 6),
                          const Text(
                            'Create a new pantry to start syncing, '
                            'or join an existing one with an invite code.',
                            style:
                                TextStyle(color: Colors.grey, fontSize: 13),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            icon: const Icon(Icons.add_home_outlined),
                            label: const Text('Create Family Pantry'),
                            onPressed: _createPantry,
                            style: FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(48)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 12),

                if (auth.isSignedIn) ...[
                  OutlinedButton.icon(
                    icon: const Icon(Icons.group_add_outlined),
                    label: const Text('Join Another Pantry'),
                    onPressed: _joinExistingPantry,
                    style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48)),
                  ),
                  const SizedBox(height: 8),
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
