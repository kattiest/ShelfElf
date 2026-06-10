import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/food_item.dart';
import '../providers/inventory_provider.dart';
class AddItemScreen extends StatefulWidget {
  /// Pre-fill from barcode scan
  final String? scannedUpc;
  final String? scannedProductName;

  /// Existing item for edit mode
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
  final _packageSizeController = TextEditingController();
  final _servingSizeController = TextEditingController();

  late String _upc;
  String _sellByDate = '';
  String _location = 'Pantry';
  int _percentUsed = 0;
  int _orderingLevel = 20;

  static const List<String> _locations = [
    'Fridge',
    'Freezer',
    'Pantry',
    'Cabinet',
    'Other',
  ];

  bool get _isEditing => widget.existingItem != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final item = widget.existingItem!;
      _upc = item.upc;
      _productController.text = item.product;
      _packageSizeController.text =
          item.packageSize > 0 ? item.packageSize.toString() : '';
      _servingSizeController.text =
          item.servingSize > 0 ? item.servingSize.toString() : '';
      _sellByDate = item.sellByDate;
      _location = item.location;
      _percentUsed = item.percentUsed;
      _orderingLevel = item.orderingLevel;
    } else {
      _upc = widget.scannedUpc ?? '';
      _productController.text = widget.scannedProductName ?? '';
      // Auto-suggest location based on product name
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
    _packageSizeController.dispose();
    _servingSizeController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    DateTime initial = DateTime.now();
    if (_sellByDate.isNotEmpty) {
      try {
        initial = DateFormat('yyyy-MM-dd').parse(_sellByDate);
      } catch (_) {}
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );

    if (picked != null) {
      setState(() {
        _sellByDate = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final packageSize = double.tryParse(_packageSizeController.text) ?? 0;
    final servingSize = double.tryParse(_servingSizeController.text) ?? 0;

    final item = FoodItem(
      id: widget.existingItem?.id,
      upc: _upc,
      product: _productController.text.trim(),
      packageSize: packageSize,
      servingSize: servingSize,
      sellByDate: _sellByDate,
      percentUsed: _percentUsed,
      location: _location,
      orderingLevel: _orderingLevel,
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
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Item' : 'Add Item'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // UPC (read-only)
            if (_upc.isNotEmpty) ...[
              _SectionLabel('Barcode'),
              TextFormField(
                initialValue: _upc,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'UPC',
                  prefixIcon: Icon(Icons.qr_code),
                  filled: true,
                ),
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),
            ],

            // Product Name
            _SectionLabel('Product Details'),
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
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _packageSizeController,
                    decoration: const InputDecoration(
                      labelText: 'Package Size (g/ml)',
                      prefixIcon: Icon(Icons.inventory_2_outlined),
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _servingSizeController,
                    decoration: const InputDecoration(
                      labelText: 'Serving Size (g/ml)',
                      prefixIcon: Icon(Icons.restaurant_outlined),
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                    ],
                  ),
                ),
              ],
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
                    color: _sellByDate.isNotEmpty ? null : Colors.grey,
                  ),
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
                  .map((loc) => DropdownMenuItem(value: loc, child: Text(loc)))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _location = v);
              },
            ),
            const SizedBox(height: 16),

            // Percent Used slider
            _SectionLabel('Current Level'),
            Row(
              children: [
                const Text('Percent Used:', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 8),
                Text(
                  '$_percentUsed%',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const Spacer(),
                Text(
                  '${100 - _percentUsed}% remaining',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
            Slider(
              value: _percentUsed.toDouble(),
              min: 0,
              max: 100,
              divisions: 10,
              label: '$_percentUsed% used',
              onChanged: (v) {
                setState(() => _percentUsed = v.round());
              },
              onChangeEnd: (v) {
                setState(() => _percentUsed = ((v / 10).round() * 10));
              },
            ),
            const SizedBox(height: 8),

            // Ordering level slider
            _SectionLabel('Reorder Threshold'),
            Row(
              children: [
                const Text('Alert when below:', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 8),
                Text(
                  '$_orderingLevel%',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ],
            ),
            Slider(
              value: _orderingLevel.toDouble(),
              min: 0,
              max: 100,
              divisions: 10,
              label: '$_orderingLevel%',
              activeColor: Colors.orange,
              onChanged: (v) {
                setState(() => _orderingLevel = v.round());
              },
              onChangeEnd: (v) {
                setState(() => _orderingLevel = ((v / 10).round() * 10));
              },
            ),
            const SizedBox(height: 32),

            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save_outlined),
              label: Text(_isEditing ? 'Save Changes' : 'Add to Pantry'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
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
