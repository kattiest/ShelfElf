import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/food_item.dart';

class ItemCard extends StatelessWidget {
  final FoodItem item;
  final void Function(FoodItem updated) onQuantityChanged;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  const ItemCard({
    super.key,
    required this.item,
    required this.onQuantityChanged,
    required this.onDelete,
    required this.onTap,
  });

  Color _indicatorColor(int remaining, int total) {
    if (total == 0) return Colors.grey;
    final ratio = remaining / total;
    if (ratio <= 0.25) return Colors.red;
    if (ratio <= 0.5) return Colors.orange;
    return Colors.green;
  }

  bool _isExpiringSoon(String dateStr) {
    if (dateStr.isEmpty) return false;
    try {
      final date = DateFormat('yyyy-MM-dd').parse(dateStr);
      final days = date.difference(DateTime.now()).inDays;
      return days >= 0 && days <= 7;
    } catch (_) { return false; }
  }

  bool _isExpired(String dateStr) {
    if (dateStr.isEmpty) return false;
    try {
      return DateFormat('yyyy-MM-dd')
          .parse(dateStr)
          .isBefore(DateTime.now());
    } catch (_) { return false; }
  }

  int _daysUntilExpiry(String dateStr) {
    try {
      return DateFormat('yyyy-MM-dd')
          .parse(dateStr)
          .difference(DateTime.now())
          .inDays;
    } catch (_) { return 0; }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final remaining = item.quantityRemaining;
    final color = _indicatorColor(remaining, item.quantity);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Top row: dot + name + delete ─────────────────────────────
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                        color: color, shape: BoxShape.circle),
                  ),
                  Expanded(
                    child: Text(
                      item.product,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => _confirmDelete(context),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),

              // ── Location + expiry ─────────────────────────────────────────
              Row(
                children: [
                  _InfoChip(
                    icon: Icons.place_outlined,
                    label: item.location,
                  ),
                  const SizedBox(width: 8),
                  _InfoChip(
                    icon: Icons.calendar_today_outlined,
                    label: item.sellByDate.isNotEmpty
                        ? item.sellByDate
                        : 'No date',
                    warning: _isExpiringSoon(item.sellByDate),
                    expired: _isExpired(item.sellByDate),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // ── Quantity row ──────────────────────────────────────────────
              Row(
                children: [
                  // Large highlighted qty remaining
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: color.withAlpha(30),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: color.withAlpha(80)),
                    ),
                    child: Text(
                      '$remaining',
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'of ${item.quantity}',
                    style: TextStyle(
                        color: cs.onSurfaceVariant, fontSize: 14),
                  ),
                  const Spacer(),

                  // − button
                  _SmallQtyBtn(
                    icon: Icons.remove,
                    color: color,
                    enabled: item.quantityUsed < item.quantity,
                    onTap: () => onQuantityChanged(
                        item.copyWith(quantityUsed: item.quantityUsed + 1)),
                  ),
                  const SizedBox(width: 8),
                  // + button (restock)
                  _SmallQtyBtn(
                    icon: Icons.add,
                    color: Colors.green,
                    enabled: item.quantityUsed > 0,
                    onTap: () => onQuantityChanged(
                        item.copyWith(quantityUsed: item.quantityUsed - 1)),
                  ),
                ],
              ),

              // ── Status badges ─────────────────────────────────────────────
              if (item.isLow)
                _StatusBadge(
                  icon: Icons.shopping_cart_outlined,
                  text: 'Low — on shopping list',
                  color: Colors.orange[700]!,
                ),
              if (_isExpired(item.sellByDate))
                const _StatusBadge(
                  icon: Icons.warning_rounded,
                  text: 'Expired!',
                  color: Colors.red,
                  bold: true,
                )
              else if (_isExpiringSoon(item.sellByDate))
                _StatusBadge(
                  icon: Icons.schedule,
                  text:
                      'Expires in ${_daysUntilExpiry(item.sellByDate)} days',
                  color: Colors.orange[700]!,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete item?'),
        content: Text('Remove "${item.product}" from your pantry?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed == true) onDelete();
  }
}

// ── Small inline qty button ───────────────────────────────────────────────────

class _SmallQtyBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final bool enabled;
  final VoidCallback onTap;

  const _SmallQtyBtn({
    required this.icon,
    required this.color,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: enabled ? color.withAlpha(20) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: enabled ? color.withAlpha(80) : Colors.grey.shade300),
        ),
        child: Icon(icon,
            size: 18,
            color: enabled ? color : Colors.grey.shade400),
      ),
    );
  }
}

// ── Info chip ─────────────────────────────────────────────────────────────────

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool warning;
  final bool expired;

  const _InfoChip({
    required this.icon,
    required this.label,
    this.warning = false,
    this.expired = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = expired
        ? Colors.red
        : warning
            ? Colors.orange[700]!
            : Colors.grey[600]!;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 3),
        Text(label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: (warning || expired)
                  ? FontWeight.w600
                  : FontWeight.normal,
            )),
      ],
    );
  }
}

// ── Status badge ──────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  final bool bold;

  const _StatusBadge({
    required this.icon,
    required this.text,
    required this.color,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(text,
              style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontWeight:
                      bold ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }
}
