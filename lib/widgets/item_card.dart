import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/food_item.dart';

class ItemCard extends StatefulWidget {
  final FoodItem item;
  final void Function(FoodItem updated) onPercentChanged;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  const ItemCard({
    super.key,
    required this.item,
    required this.onPercentChanged,
    required this.onDelete,
    required this.onTap,
  });

  @override
  State<ItemCard> createState() => _ItemCardState();
}

class _ItemCardState extends State<ItemCard> {
  late double _sliderValue;

  @override
  void initState() {
    super.initState();
    _sliderValue = widget.item.percentUsed.toDouble();
  }

  @override
  void didUpdateWidget(ItemCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.percentUsed != widget.item.percentUsed) {
      _sliderValue = widget.item.percentUsed.toDouble();
    }
  }

  Color _indicatorColor(int percentRemaining) {
    if (percentRemaining <= 20) return Colors.red;
    if (percentRemaining <= 30) return Colors.orange;
    return Colors.green;
  }

  bool _isExpiringSoon(String dateStr) {
    if (dateStr.isEmpty) return false;
    try {
      final date = DateFormat('yyyy-MM-dd').parse(dateStr);
      final days = date.difference(DateTime.now()).inDays;
      return days >= 0 && days <= 7;
    } catch (_) {
      return false;
    }
  }

  bool _isExpired(String dateStr) {
    if (dateStr.isEmpty) return false;
    try {
      final date = DateFormat('yyyy-MM-dd').parse(dateStr);
      return date.isBefore(DateTime.now());
    } catch (_) {
      return false;
    }
  }

  int _daysUntilExpiry(String dateStr) {
    try {
      final date = DateFormat('yyyy-MM-dd').parse(dateStr);
      return date.difference(DateTime.now()).inDays;
    } catch (_) {
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final remaining = widget.item.percentRemaining;
    final color = _indicatorColor(remaining);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Color indicator dot
                  Container(
                    width: 12,
                    height: 12,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      widget.item.product,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    tooltip: 'Delete item',
                    onPressed: () => _confirmDelete(context),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  _InfoChip(
                    icon: Icons.place_outlined,
                    label: widget.item.location,
                  ),
                  const SizedBox(width: 8),
                  _InfoChip(
                    icon: Icons.calendar_today_outlined,
                    label: widget.item.sellByDate.isNotEmpty
                        ? widget.item.sellByDate
                        : 'No date',
                    warning: _isExpiringSoon(widget.item.sellByDate),
                    expired: _isExpired(widget.item.sellByDate),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  SizedBox(
                    width: 48,
                    child: Text(
                      '$remaining%',
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: color,
                        thumbColor: color,
                        inactiveTrackColor: color.withOpacity(0.25),
                        overlayColor: color.withOpacity(0.15),
                        trackHeight: 4,
                      ),
                      child: Slider(
                        value: _sliderValue,
                        min: 0,
                        max: 100,
                        divisions: 10,
                        label: '${(100 - _sliderValue).round()}% left',
                        onChanged: (value) {
                          setState(() => _sliderValue = value);
                        },
                        onChangeEnd: (value) {
                          final snapped = (value / 10).round() * 10;
                          final updated = widget.item.copyWith(
                            percentUsed: snapped,
                          );
                          widget.onPercentChanged(updated);
                        },
                      ),
                    ),
                  ),
                ],
              ),
              if (widget.item.isLow)
                Padding(
                  padding: const EdgeInsets.only(top: 2, bottom: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.shopping_cart_outlined,
                          size: 14, color: Colors.orange),
                      const SizedBox(width: 4),
                      Text(
                        'Low — added to shopping list',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange[700],
                        ),
                      ),
                    ],
                  ),
                ),
              if (_isExpired(widget.item.sellByDate))
                Padding(
                  padding: const EdgeInsets.only(top: 2, bottom: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_rounded, size: 14, color: Colors.red),
                      const SizedBox(width: 4),
                      const Text('Expired!',
                          style: TextStyle(fontSize: 12, color: Colors.red,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                )
              else if (_isExpiringSoon(widget.item.sellByDate))
                Padding(
                  padding: const EdgeInsets.only(top: 2, bottom: 4),
                  child: Row(
                    children: [
                      Icon(Icons.schedule, size: 14, color: Colors.orange[700]),
                      const SizedBox(width: 4),
                      Text(
                        'Expires soon — ${_daysUntilExpiry(widget.item.sellByDate)} days left',
                        style: TextStyle(fontSize: 12, color: Colors.orange[700]),
                      ),
                    ],
                  ),
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
        content: Text(
            'Remove "${widget.item.product}" from your inventory?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      widget.onDelete();
    }
  }
}

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
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: (warning || expired) ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}
