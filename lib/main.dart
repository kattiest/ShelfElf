import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'models/food_item.dart';
import 'providers/inventory_provider.dart';
import 'screens/inventory_screen.dart';
import 'screens/shopping_list_screen.dart';
import 'screens/ai_chat_screen.dart';
import 'screens/meal_plan_screen.dart';
import 'services/share_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PantryPalApp());
}

class PantryPalApp extends StatelessWidget {
  const PantryPalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => InventoryProvider(),
      child: MaterialApp(
        title: 'Shelf Elf',
        debugShowCheckedModeBanner: false,
        theme: _buildTheme(Brightness.light),
        darkTheme: _buildTheme(Brightness.dark),
        themeMode: ThemeMode.system,
        home: const AppShell(),
      ),
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    const seedColor = Color(0xFF4CAF50);

    final colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: colorScheme.onPrimary,
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: IconThemeData(color: colorScheme.onPrimary),
        actionsIconTheme: IconThemeData(color: colorScheme.onPrimary),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 4,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        filled: true,
        fillColor: isDark
            ? colorScheme.surfaceContainerHighest
            : colorScheme.surfaceContainerLowest,
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        surfaceTintColor: colorScheme.surfaceTint,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: colorScheme.primary,
        thumbColor: colorScheme.primary,
        overlayColor: colorScheme.primary.withOpacity(0.15),
        inactiveTrackColor: colorScheme.primary.withOpacity(0.25),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }
}

// ── App shell with bottom nav + deep link handling ────────────────────────────

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;
  late final AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSub;

  final _pages = const [
    InventoryScreen(),
    ShoppingListScreen(),
    MealPlanScreen(),
    AiChatScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
  }

  Future<void> _initDeepLinks() async {
    _appLinks = AppLinks();

    // Handle link that cold-started the app
    final initialUri = await _appLinks.getInitialLink();
    if (initialUri != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _handleLink(initialUri),
      );
    }

    // Handle links while app is already running
    _linkSub = _appLinks.uriLinkStream.listen(
      _handleLink,
      onError: (e) => debugPrint('Deep link error: $e'),
    );
  }

  void _handleLink(Uri uri) {
    final items = ShareService.instance.decodeUrl(uri.toString());
    if (items == null || items.isEmpty) return;

    // Switch to shopping list tab
    setState(() => _currentIndex = 1);

    // Show import dialog
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showImportDialog(context, items);
    });
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: Consumer<InventoryProvider>(
        builder: (context, provider, _) {
          final lowCount = provider.shoppingList.length;

          return NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: (i) =>
                setState(() => _currentIndex = i),
            backgroundColor: cs.surface,
            indicatorColor: cs.primaryContainer,
            destinations: [
              const NavigationDestination(
                icon: Icon(Icons.kitchen_outlined),
                selectedIcon: Icon(Icons.kitchen),
                label: 'Pantry',
              ),
              NavigationDestination(
                icon: Badge(
                  isLabelVisible: lowCount > 0,
                  label: Text('$lowCount'),
                  child: const Icon(Icons.shopping_cart_outlined),
                ),
                selectedIcon: Badge(
                  isLabelVisible: lowCount > 0,
                  label: Text('$lowCount'),
                  child: const Icon(Icons.shopping_cart),
                ),
                label: 'Shopping',
              ),
              const NavigationDestination(
                icon: Icon(Icons.calendar_month_outlined),
                selectedIcon: Icon(Icons.calendar_month),
                label: 'Meals',
              ),
              const NavigationDestination(
                icon: Icon(Icons.auto_awesome_outlined),
                selectedIcon: Icon(Icons.auto_awesome),
                label: 'Ask AI',
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Shows a dialog listing the shared items and lets the user import them.
Future<void> showImportDialog(
    BuildContext context, List<SharedItem> items) async {
  final provider = context.read<InventoryProvider>();

  return showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.share_outlined, size: 20),
          SizedBox(width: 8),
          Text('Shared Shopping List'),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${items.length} item${items.length == 1 ? '' : 's'} received:',
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 260),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: items.length,
                itemBuilder: (_, i) {
                  final item = items[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Icon(
                          Icons.shopping_basket_outlined,
                          size: 16,
                          color: Colors.green[600],
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            item.product,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                        if (item.location.isNotEmpty &&
                            item.location != 'Shopping List')
                          Text(
                            item.location,
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 12),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Dismiss'),
        ),
        FilledButton.icon(
          icon: const Icon(Icons.add_shopping_cart, size: 18),
          label: const Text('Add to My List'),
          onPressed: () {
            Navigator.of(ctx).pop();
            _importItems(provider, items, context);
          },
        ),
      ],
    ),
  );
}

void _importItems(
    InventoryProvider provider, List<SharedItem> items, BuildContext context) {
  int added = 0;
  for (final shared in items) {
    // Skip if already in inventory by name
    final exists = provider.items
        .any((i) => i.product.toLowerCase() == shared.product.toLowerCase());
    if (exists) continue;

    final newItem = FoodItem(
      upc: '',
      product: shared.product,
      packageSize: 0,
      servingSize: 0,
      sellByDate: '',
      percentUsed: 100,
      location: shared.location.isNotEmpty ? shared.location : 'Shopping List',
      orderingLevel: 100,
    );
    provider.addItem(newItem);
    added++;
  }

  final skipped = items.length - added;
  final msg = added == 0
      ? 'All items already in your pantry.'
      : skipped > 0
          ? 'Added $added item${added == 1 ? '' : 's'} ($skipped already existed).'
          : 'Added $added item${added == 1 ? '' : 's'} to your list!';

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 3),
    ),
  );
}
