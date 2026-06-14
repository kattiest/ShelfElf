import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/food_item.dart';
import '../providers/inventory_provider.dart';

class AddItemScreen extends StatefulWidget {
  final String? scannedUpc;
  final String? scannedProductName;
  final FoodItem? existingItem;

  const AddItemScreen({
    super.key,
    this.scannedUpc,
    this.scannedProductName,
    this.existingItem,
  });

  @override
  State<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends State<AddItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final _productController = TextEditingController();

  late String _upc;
  String _sellByDate = '';
  String _location = 'Pantry';
  int _quantity = 1;
  int _quantityUsed = 0;
  int _alertAt = 1;

  static const List<String> _locations = [
    'Fridge', 'Freezer', 'Pantry', 'Cabinet', 'Other',
  ];

  bool get _isEditing => widget.existingItem != null;
  int get _quantityRemaining => (_quantity - _quantityUsed).clamp(0, _quantity);

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final item = widget.existingItem!;
      _upc = item.upc;
      _productController.text = item.product;
      _sellByDate = item.sellByDate;
      _location = item.location;
      _quantity = item.quantity;
      _quantityUsed = item.quantityUsed;
      _alertAt = item.alertAt;
    } else {
      _upc = widget.scannedUpc ?? '';
      _productController.text = widget.scannedProductName ?? '';
      if (_productController.text.isNotEmpty) {
        _location = context
            .read<InventoryProvider>()
            .suggestLocation(_productController.text);
      }
    }
  }

  @override
  void dispose() {
    _productController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    DateTime initial = DateTime.now();
    if (_sellByDate.isNotEmpty) {
      try { initial = DateFormat('yyyy-MM-dd').parse(_sellByDate); } catch (_) {}
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (picked != null) {
      setState(() => _sellByDate = DateFormat('yyyy-MM-dd').format(picked));
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final item = FoodItem(
      id: widget.existingItem?.id,
      firestoreId: widget.existingItem?.firestoreId,
      upc: _upc,
      product: _productController.text.trim(),
      quantity: _quantity,
      quantityUsed: _quantityUsed,
      sellByDate: _sellByDate,
      location: _location,
      alertAt: _alertAt,
    );

    final provider = context.read<InventoryProvider>();
    if (_isEditing) {
      await provider.updateItem(item);
    } else {
      await provider.addItem(item);
    }

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit Item' : 'Add Item')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // UPC
            if (_upc.isNotEmpty) ...[
              _SectionLabel('Barcode'),
              TextFormField(
                initialValue: _upc,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'UPC',
                  prefixIcon: Icon(Icons.barcode_reader),
                  filled: true,
                ),
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),
            ],

            // Product name
            _SectionLabel('Product'),
            TextFormField(
              controller: _productController,
              decoration: const InputDecoration(
                labelText: 'Product Name *',
                prefixIcon: Icon(Icons.label_outline),
              ),
              textCapitalization: TextCapitalization.words,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 16),

            // Sell-by date
            _SectionLabel('Expiry'),
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(8),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Sell-By Date',
                  prefixIcon: Icon(Icons.calendar_month_outlined),
                ),
                child: Text(
                  _sellByDate.isNotEmpty ? _sellByDate : 'Tap to select',
                  style: TextStyle(
                      color: _sellByDate.isNotEmpty ? null : Colors.grey),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Location
            _SectionLabel('Storage'),
            DropdownButtonFormField<String>(
              value: _location,
              decoration: const InputDecoration(
                labelText: 'Location',
                prefixIcon: Icon(Icons.place_outlined),
              ),
              items: _locations
                  .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                  .toList(),
              onChanged: (v) { if (v != null) setState(() => _location = v); },
            ),
            const SizedBox(height: 16),

            // Quantity in stock
            _SectionLabel('Quantity in Stock'),
            _buildQtyRow(
              label: 'How many do you have?',
              value: _quantity,
              min: 1,
              onDecrement: () => setState(() {
                _quantity = (_quantity - 1).clamp(1, 999);
                _quantityUsed = _quantityUsed.clamp(0, _quantity);
                _alertAt = _alertAt.clamp(0, _quantity);
              }),
              onIncrement: () => setState(() => _quantity++),
              cs: cs,
            ),
            const SizedBox(height: 12),

            // Quantity used
            _SectionLabel('Quantity Used'),
            _buildQtyRow(
              label: 'How many have been used?',
              value: _quantityUsed,
              min: 0,
              max: _quantity,
              onDecrement: () => setState(
                  () => _quantityUsed = (_quantityUsed - 1).clamp(0, _quantity)),
              onIncrement: () => setState(() {
                if (_quantityUsed < _quantity) _quantityUsed++;
              }),
              cs: cs,
              suffix: '  →  $_quantityRemaining remaining',
              suffixColor: _quantityRemaining <= _alertAt
                  ? cs.error
                  : Colors.green[700]!,
            ),
            const SizedBox(height: 16),

            // Alert threshold
            _SectionLabel('Low Stock Alert'),
            _buildQtyRow(
              label: 'Add to shopping list when ≤',
              value: _alertAt,
              min: 0,
              max: _quantity,
              onDecrement: () =>
                  setState(() => _alertAt = (_alertAt - 1).clamp(0, _quantity)),
              onIncrement: () =>
                  setState(() => _alertAt = (_alertAt + 1).clamp(0, _quantity)),
              cs: cs,
              accentColor: Colors.orange,
              suffix: '  ${_alertAt == 1 ? '(last one)' : _alertAt == 0 ? '(only when empty)' : 'left'}',
            ),
            const SizedBox(height: 32),

            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save_outlined),
              label: Text(_isEditing ? 'Save Changes' : 'Add to Pantry'),
              style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52)),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildQtyRow({
    required String label,
    required int value,
    required int min,
    int? max,
    required VoidCallback onDecrement,
    required VoidCallback onIncrement,
    required ColorScheme cs,
    Color? accentColor,
    String? suffix,
    Color? suffixColor,
  }) {
    final color = accentColor ?? cs.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
        const SizedBox(height: 8),
        Row(
          children: [
            // Decrement
            _QtyButton(
              icon: Icons.remove,
              onTap: value > min ? onDecrement : null,
              color: color,
            ),
            const SizedBox(width: 12),
            // Value display
            Container(
              width: 64,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withAlpha(20),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: color.withAlpha(80)),
              ),
              child: Text(
                '$value',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Increment
            _QtyButton(
              icon: Icons.add,
              onTap: (max == null || value < max) ? onIncrement : null,
              color: color,
            ),
            if (suffix != null) ...[
              const SizedBox(width: 12),
              Text(
                suffix,
                style: TextStyle(
                  fontSize: 13,
                  color: suffixColor ?? cs.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Color color;

  const _QtyButton(
      {required this.icon, required this.onTap, required this.color});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: onTap != null ? color.withAlpha(20) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: onTap != null ? color.withAlpha(80) : Colors.grey.shade300),
        ),
        child: Icon(icon,
            size: 20,
            color: onTap != null ? color : Colors.grey.shade400),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
