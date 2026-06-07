import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/food_item.dart';
import '../models/meal_plan.dart';
import '../providers/inventory_provider.dart';
import '../services/database_service.dart';
import '../services/gemini_service.dart';

class MealPlanScreen extends StatefulWidget {
  const MealPlanScreen({super.key});

  @override
  State<MealPlanScreen> createState() => _MealPlanScreenState();
}

class _MealPlanScreenState extends State<MealPlanScreen> {
  late DateTime _weekStart;
  List<MealPlan> _meals = [];
  bool _loading = false;

  static const _mealTypes = ['Breakfast', 'Lunch', 'Dinner', 'Snack'];
  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  void initState() {
    super.initState();
    // Week starts on Monday
    final now = DateTime.now();
    _weekStart = now.subtract(Duration(days: now.weekday - 1));
    _weekStart = DateTime(_weekStart.year, _weekStart.month, _weekStart.day);
    _loadMeals();
  }

  Future<void> _loadMeals() async {
    setState(() => _loading = true);
    final meals = await DatabaseService.instance.getMealsForWeek(_weekStart);
    if (mounted) setState(() { _meals = meals; _loading = false; });
  }

  DateTime _dayDate(int dayIndex) =>
      _weekStart.add(Duration(days: dayIndex));

  List<MealPlan> _mealsForSlot(int dayIndex, String mealType) {
    final date = _dayDate(dayIndex);
    return _meals.where((m) =>
        m.date.year == date.year &&
        m.date.month == date.month &&
        m.date.day == date.day &&
        m.mealType == mealType).toList();
  }

  void _prevWeek() {
    setState(() => _weekStart = _weekStart.subtract(const Duration(days: 7)));
    _loadMeals();
  }

  void _nextWeek() {
    setState(() => _weekStart = _weekStart.add(const Duration(days: 7)));
    _loadMeals();
  }

  void _today() {
    final now = DateTime.now();
    setState(() {
      _weekStart = now.subtract(Duration(days: now.weekday - 1));
      _weekStart = DateTime(_weekStart.year, _weekStart.month, _weekStart.day);
    });
    _loadMeals();
  }

  Future<void> _addMeal(int dayIndex, String mealType) async {
    final inventory = context.read<InventoryProvider>().items.toList();
    final date = _dayDate(dayIndex);

    final result = await showDialog<_MealEntry>(
      context: context,
      builder: (ctx) => _AddMealDialog(
        date: date,
        mealType: mealType,
        inventory: inventory,
      ),
    );

    if (result == null) return;

    final meal = MealPlan(
      id: 0,
      date: date,
      mealType: result.mealType,
      mealName: result.mealName,
      ingredients: result.ingredients,
    );

    final id = await DatabaseService.instance.insertMeal(meal);
    setState(() => _meals.add(meal.copyWith(id: id)));
  }

  Future<void> _deleteMeal(MealPlan meal) async {
    await DatabaseService.instance.deleteMeal(meal.id);
    setState(() => _meals.removeWhere((m) => m.id == meal.id));
  }

  /// Collect all missing ingredients across the whole week's plan
  List<String> get _missingIngredients {
    final inventory = context.read<InventoryProvider>().items;
    final inventoryNames =
        inventory.map((i) => i.product.toLowerCase()).toSet();

    final missing = <String>{};
    for (final meal in _meals) {
      for (final ing in meal.ingredients) {
        final lower = ing.toLowerCase();
        final found = inventoryNames.any(
            (name) => name.contains(lower) || lower.contains(name));
        if (!found) missing.add(ing);
      }
    }
    return missing.toList()..sort();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final today = DateTime.now();
    final weekLabel =
        '${DateFormat('MMM d').format(_weekStart)} – ${DateFormat('MMM d').format(_weekStart.add(const Duration(days: 6)))}';
    final missing = _missingIngredients;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meal Planner'),
        actions: [
          TextButton(
            onPressed: _today,
            child: const Text('Today',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // ── Week nav bar ─────────────────────────────────────────
                Container(
                  color: cs.primaryContainer,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 6),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left),
                        onPressed: _prevWeek,
                        color: cs.onPrimaryContainer,
                      ),
                      Expanded(
                        child: Text(
                          weekLabel,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: cs.onPrimaryContainer,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right),
                        onPressed: _nextWeek,
                        color: cs.onPrimaryContainer,
                      ),
                    ],
                  ),
                ),

                // ── Missing ingredients banner ───────────────────────────
                if (missing.isNotEmpty)
                  InkWell(
                    onTap: () => _showMissingDialog(missing),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      color: cs.errorContainer,
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber_rounded,
                              size: 16, color: cs.onErrorContainer),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${missing.length} ingredient${missing.length == 1 ? '' : 's'} needed for this week — tap to see',
                              style: TextStyle(
                                  color: cs.onErrorContainer, fontSize: 13),
                            ),
                          ),
                          Icon(Icons.chevron_right,
                              size: 16, color: cs.onErrorContainer),
                        ],
                      ),
                    ),
                  ),

                // ── Day columns ──────────────────────────────────────────
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: 7,
                    itemBuilder: (context, dayIndex) {
                      final date = _dayDate(dayIndex);
                      final isToday = date.year == today.year &&
                          date.month == today.month &&
                          date.day == today.day;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Day header
                          Container(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isToday
                                        ? cs.primary
                                        : cs.surfaceContainerHigh,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${_days[dayIndex]}  ${DateFormat('d').format(date)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: isToday
                                          ? cs.onPrimary
                                          : cs.onSurface,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Meal type rows
                          ..._mealTypes.map((type) {
                            final slotMeals =
                                _mealsForSlot(dayIndex, type);
                            return _MealSlotRow(
                              mealType: type,
                              meals: slotMeals,
                              inventory: context
                                  .read<InventoryProvider>()
                                  .items
                                  .toList(),
                              onAdd: () => _addMeal(dayIndex, type),
                              onDelete: _deleteMeal,
                            );
                          }),

                          const Divider(height: 1),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  void _showMissingDialog(List<String> missing) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.shopping_cart_outlined,
                color: Theme.of(ctx).colorScheme.primary),
            const SizedBox(width: 8),
            const Text('Needed This Week'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: missing
                .map((ing) => ListTile(
                      dense: true,
                      leading: const Icon(Icons.shopping_basket_outlined,
                          size: 18),
                      title: Text(ing),
                    ))
                .toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

// ── Meal slot row ─────────────────────────────────────────────────────────────

class _MealSlotRow extends StatelessWidget {
  final String mealType;
  final List<MealPlan> meals;
  final List<FoodItem> inventory;
  final VoidCallback onAdd;
  final void Function(MealPlan) onDelete;

  const _MealSlotRow({
    required this.mealType,
    required this.meals,
    required this.inventory,
    required this.onAdd,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Meal type label
          SizedBox(
            width: 72,
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                mealType,
                style: TextStyle(
                  fontSize: 11,
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),

          // Meal chips + add button
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ...meals.map((meal) => _MealChip(
                      meal: meal,
                      inventory: inventory,
                      onDelete: () => onDelete(meal),
                    )),
                ActionChip(
                  label: const Text('+ Add'),
                  labelStyle:
                      TextStyle(fontSize: 12, color: cs.primary),
                  side: BorderSide(color: cs.primary.withAlpha(80)),
                  backgroundColor: Colors.transparent,
                  padding: EdgeInsets.zero,
                  onPressed: onAdd,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Meal chip ─────────────────────────────────────────────────────────────────

class _MealChip extends StatelessWidget {
  final MealPlan meal;
  final List<FoodItem> inventory;
  final VoidCallback onDelete;

  const _MealChip({
    required this.meal,
    required this.inventory,
    required this.onDelete,
  });

  bool get _hasMissing {
    final names = inventory.map((i) => i.product.toLowerCase()).toSet();
    return meal.ingredients.any((ing) {
      final lower = ing.toLowerCase();
      return !names.any((n) => n.contains(lower) || lower.contains(n));
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final missing = _hasMissing;

    return GestureDetector(
      onLongPress: () => _confirmDelete(context),
      child: Chip(
        label: Text(
          meal.mealName,
          style: const TextStyle(fontSize: 12),
        ),
        avatar: missing
            ? Icon(Icons.warning_amber_rounded,
                size: 14, color: cs.error)
            : Icon(Icons.check_circle_outline,
                size: 14, color: Colors.green[600]),
        backgroundColor:
            missing ? cs.errorContainer : Colors.green.shade50,
        side: BorderSide.none,
        deleteIcon: const Icon(Icons.close, size: 14),
        onDeleted: onDelete,
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove meal?'),
        content: Text('Remove "${meal.mealName}" from the plan?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Remove')),
        ],
      ),
    );
    if (confirmed == true) onDelete();
  }
}

// ── Add meal dialog ───────────────────────────────────────────────────────────

class _MealEntry {
  final String mealName;
  final String mealType;
  final List<String> ingredients;
  const _MealEntry(
      {required this.mealName,
      required this.mealType,
      required this.ingredients});
}

class _AddMealDialog extends StatefulWidget {
  final DateTime date;
  final String mealType;
  final List<FoodItem> inventory;

  const _AddMealDialog({
    required this.date,
    required this.mealType,
    required this.inventory,
  });

  @override
  State<_AddMealDialog> createState() => _AddMealDialogState();
}

class _AddMealDialogState extends State<_AddMealDialog> {
  final _controller = TextEditingController();
  late String _selectedType;
  bool _lookingUp = false;
  List<String> _ingredients = [];

  static const _mealTypes = ['Breakfast', 'Lunch', 'Dinner', 'Snack'];

  @override
  void initState() {
    super.initState();
    _selectedType = widget.mealType;
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _lookupIngredients() async {
    final name = _controller.text.trim();
    if (name.isEmpty) return;

    setState(() { _lookingUp = true; _ingredients = []; });

    try {
      final response = await GeminiService.instance.askAboutMeal(
        userMessage: name,
        inventory: widget.inventory,
      );
      if (mounted) {
        setState(() {
          _ingredients =
              response.ingredients.map((i) => i.name).toList();
          _lookingUp = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _lookingUp = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AlertDialog(
      title: Text(
          'Add ${DateFormat('EEE, MMM d').format(widget.date)}'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Meal type selector
              DropdownButtonFormField<String>(
                value: _selectedType,
                decoration: const InputDecoration(labelText: 'Meal'),
                items: _mealTypes
                    .map((t) =>
                        DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (v) =>
                    setState(() => _selectedType = v ?? _selectedType),
              ),
              const SizedBox(height: 12),

              // Meal name + AI lookup
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: const InputDecoration(
                        labelText: 'Meal name',
                        hintText: 'e.g. Lasagna',
                      ),
                      textCapitalization: TextCapitalization.words,
                      onSubmitted: (_) => _lookupIngredients(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    icon: _lookingUp
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white))
                        : const Icon(Icons.auto_awesome, size: 18),
                    tooltip: 'Look up ingredients with AI',
                    onPressed: _lookingUp ? null : _lookupIngredients,
                  ),
                ],
              ),

              // Ingredient list
              if (_ingredients.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('Ingredients (${_ingredients.length})',
                    style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: _ingredients.map((ing) {
                    final inStock = widget.inventory.any((item) {
                      final lower = ing.toLowerCase();
                      final name = item.product.toLowerCase();
                      return name.contains(lower) ||
                          lower.contains(name);
                    });
                    return Chip(
                      label: Text(ing,
                          style: const TextStyle(fontSize: 11)),
                      backgroundColor: inStock
                          ? Colors.green.shade50
                          : cs.errorContainer,
                      side: BorderSide.none,
                      padding: EdgeInsets.zero,
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _controller.text.trim().isEmpty
              ? null
              : () {
                  Navigator.of(context).pop(_MealEntry(
                    mealName: _controller.text.trim(),
                    mealType: _selectedType,
                    ingredients: _ingredients,
                  ));
                },
          child: const Text('Add'),
        ),
      ],
    );
  }
}
