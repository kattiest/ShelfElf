import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../models/food_item.dart';
import '../providers/inventory_provider.dart';
import '../services/barcode_lookup_service.dart';
import 'add_item_screen.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
  );

  bool _isProcessing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onBarcodeDetected(BarcodeCapture capture) async {
    if (_isProcessing) return;

    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null || barcode.rawValue == null) return;

    final upc = barcode.rawValue!;
    setState(() => _isProcessing = true);
    await _controller.stop();

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final productName =
        await BarcodeLookupService.instance.lookupProduct(upc);

    if (!mounted) return;
    Navigator.of(context).pop(); // close loading dialog

    // Check if this UPC already exists in the pantry
    final existing = context.read<InventoryProvider>().findByUpc(upc);
    _showResultBottomSheet(upc, productName, existing);
  }

  void _showResultBottomSheet(
      String upc, String? productName, FoodItem? existing) {
    final displayName = (productName != null && productName.isNotEmpty)
        ? productName
        : (existing?.product ?? 'Unknown Product');

    final isExisting = existing != null;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isDismissible: false,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Title
              Row(
                children: [
                  Icon(
                    isExisting
                        ? Icons.inventory_2_outlined
                        : Icons.barcode_reader,
                    size: 20,
                    color: Theme.of(ctx).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isExisting ? 'Already in Pantry' : 'Barcode Scanned',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              _ResultRow(label: 'Product', value: displayName),
              const SizedBox(height: 6),
              _ResultRow(label: 'UPC', value: upc),

              // Show current level if item exists
              if (isExisting) ...[
                const SizedBox(height: 6),
                _ResultRow(
                  label: 'Currently',
                  value:
                      '${existing.quantityRemaining} of ${existing.quantity} remaining — ${existing.location}',
                ),
              ],

              const SizedBox(height: 24),

              if (isExisting) ...[
                // Existing item — offer restock or edit
                FilledButton.icon(
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Restock to Full'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _restockItem(existing);
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          setState(() => _isProcessing = false);
                          _controller.start();
                        },
                        child: const Text('Scan Again'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  AddItemScreen(existingItem: existing),
                            ),
                          );
                        },
                        child: const Text('Edit Item'),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                // New item — add to pantry
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          setState(() => _isProcessing = false);
                          _controller.start();
                        },
                        child: const Text('Scan Again'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AddItemScreen(
                                scannedUpc: upc,
                                scannedProductName:
                                    displayName == 'Unknown Product'
                                        ? ''
                                        : displayName,
                              ),
                            ),
                          );
                        },
                        child: const Text('Add to Pantry'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    ).whenComplete(() {
      if (_isProcessing && mounted) {
        setState(() => _isProcessing = false);
        _controller.start();
      }
    });
  }

  Future<void> _restockItem(FoodItem item) async {
    final provider = context.read<InventoryProvider>();
    // Add 1 to quantity (new unit scanned) and reduce quantityUsed if > 0
    final updated = item.copyWith(
      quantity: item.quantity + 1,
      quantityUsed: item.quantityUsed > 0 ? item.quantityUsed - 1 : 0,
    );
    await provider.restockItem(updated);

    if (!mounted) return;

    // Show confirmation and resume scanning
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('${item.product} restocked to full'),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ));

    setState(() => _isProcessing = false);
    _controller.start();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: const Text('Scan Barcode'),
        actions: [
          ValueListenableBuilder(
            valueListenable: _controller,
            builder: (context, state, child) {
              final torchIcon = state.torchState == TorchState.on
                  ? Icons.flash_off
                  : Icons.flash_on;
              return IconButton(
                icon: Icon(torchIcon),
                onPressed: () => _controller.toggleTorch(),
                tooltip: 'Toggle flashlight',
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onBarcodeDetected,
          ),
          Center(
            child: Container(
              width: 260,
              height: 160,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.green, width: 3),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Text(
              'Align barcode within the frame',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  final String label;
  final String value;

  const _ResultRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            '$label:',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
        ),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 15))),
      ],
    );
  }
}
