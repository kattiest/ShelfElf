import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/inventory_provider.dart';
import '../widgets/item_card.dart';
import 'scan_screen.dart';
import 'add_item_screen.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  String _filter = 'All';
  static const _locations = ['All', 'Fridge', 'Freezer', 'Pantry', 'Cabinet', 'Other'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<InventoryProvider>().loadItems();
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shelf Elf'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: _buildFilterBar(cs),
        ),
      ),
      body: Consumer<InventoryProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.error != null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 12),
                  Text(provider.error!),
                  TextButton(
                    onPressed: () {
                      provider.clearError();
                      provider.loadItems();
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final items = _filter == 'All'
              ? provider.items.toList()
              : provider.items.where((i) => i.location == _filter).toList();

          if (provider.items.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.kitchen_outlined, size: 72, color: Colors.green[200]),
                  const SizedBox(height: 16),
                  const Text('Your pantry is empty.',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  const Text('Tap the barcode button to scan or add an item.',
                      style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.filter_list_off, size: 56, color: Colors.grey[400]),
                  const SizedBox(height: 12),
                  Text('No items in $_filter.',
                      style: const TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.only(top: 8, bottom: 80),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return ItemCard(
                item: item,
                onPercentChanged: (updated) => provider.updateItem(updated),
                onDelete: () => provider.deleteItem(item.id!),
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddItemScreen(existingItem: item),
                    ),
                  );
                  if (context.mounted) provider.loadItems();
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ScanScreen()),
          );
          if (context.mounted) {
            context.read<InventoryProvider>().loadItems();
          }
        },
        tooltip: 'Scan barcode',
        child: const Icon(Icons.barcode_reader),
      ),
    );
  }

  Widget _buildFilterBar(ColorScheme cs) {
    return Container(
      color: cs.primary,
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: _locations.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final loc = _locations[i];
          final selected = loc == _filter;
          return GestureDetector(
            onTap: () => setState(() => _filter = loc),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: selected ? Colors.white : Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                loc,
                style: TextStyle(
                  color: selected ? cs.primary : Colors.white,
                  fontWeight:
                      selected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 13,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
