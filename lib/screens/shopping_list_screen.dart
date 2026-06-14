import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/food_item.dart';
import '../providers/inventory_provider.dart';
import '../services/share_service.dart';

class ShoppingListScreen extends StatefulWidget {
  const ShoppingListScreen({super.key});

  @override
  State<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends State<ShoppingListScreen> {
  // Local checked state — does not affect inventory
  final Set<int> _checkedIds = {};

  Color _remainingColor(FoodItem item) {
    if (item.quantityRemaining == 0) return Colors.red;
    if (item.quantityRemaining <= 1) return Colors.orange;
    return Colors.amber;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shopping List'),
        actions: [
          // Share button — only shown when there are items
          Consumer<InventoryProvider>(
            builder: (_, provider, __) {
              final list = provider.shoppingList;
              if (list.isEmpty) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(Icons.share_outlined),
                tooltip: 'Share list',
                onPressed: () =>
                    ShareService.instance.shareList(list.toList()),
              );
            },
          ),
          if (_checkedIds.isNotEmpty)
            TextButton.icon(
              onPressed: () => setState(() => _checkedIds.clear()),
              icon: const Icon(Icons.deselect),
              label: const Text('Clear'),
              style: TextButton.styleFrom(foregroundColor: Colors.white),
            ),
        ],
      ),
      body: Consumer<InventoryProvider>(
        builder: (context, provider, _) {
          final list = provider.shoppingList;

          if (list.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_outline,
                      size: 72, color: Colors.green[300]),
                  const SizedBox(height: 16),
                  const Text(
                    'Your pantry is well stocked!',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Nothing needs restocking right now.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          final checked = list.where((i) => _checkedIds.contains(i.id)).length;

          return Column(
            children: [
              // Summary bar
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        size: 16,
                        color: Theme.of(context).colorScheme.onPrimaryContainer),
                    const SizedBox(width: 6),
                    Text(
                      '${list.length} item${list.length == 1 ? '' : 's'} to buy'
                      '${checked > 0 ? ' · $checked in cart' : ''}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final item = list[index];
                    final isChecked = _checkedIds.contains(item.id);
                    return _ShoppingItemTile(
                      item: item,
                      isChecked: isChecked,
                      remainingColor: _remainingColor(item),
                      onToggle: (checked) {
                        setState(() {
                          if (checked == true) {
                            _checkedIds.add(item.id!);
                          } else {
                            _checkedIds.remove(item.id);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ShoppingItemTile extends StatelessWidget {
  final FoodItem item;
  final bool isChecked;
  final Color remainingColor;
  final ValueChanged<bool?> onToggle;

  const _ShoppingItemTile({
    required this.item,
    required this.isChecked,
    required this.remainingColor,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: isChecked ? 0.5 : 1.0,
      duration: const Duration(milliseconds: 200),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: isChecked ? 0 : 2,
        child: CheckboxListTile(
          value: isChecked,
          onChanged: onToggle,
          controlAffinity: ListTileControlAffinity.leading,
          title: Text(
            item.product,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              decoration: isChecked ? TextDecoration.lineThrough : null,
            ),
          ),
          subtitle: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(right: 5),
                decoration: BoxDecoration(
                  color: remainingColor,
                  shape: BoxShape.circle,
                ),
              ),
              Text(
                '${item.quantityRemaining} of ${item.quantity} left',
                style: TextStyle(
                  color: remainingColor,
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 10),
              const Icon(Icons.place_outlined, size: 12, color: Colors.grey),
              const SizedBox(width: 3),
              Text(
                item.location,
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
          secondary: isChecked
              ? const Icon(Icons.check_circle, color: Colors.green)
              : null,
        ),
      ),
    );
  }
}
