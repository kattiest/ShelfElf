import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart';
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

  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  void initState() {
    super.initState();
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

  MealPlan? _dinnerForDay(int dayIndex) {
    final date = _dayDate(dayIndex);
    final matches = _meals.where((m) =>
        m.date.year == date.year &&
        m.date.month == date.month &&
        m.date.day == date.day &&
        m.mealType == 'Dinner').toList();
    return matches.isEmpty ? null : matches.first;
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

  Future<void> _planDinner(int dayIndex) async {
    final inventory = context.read<InventoryProvider>().items.toList();
    final date = _dayDate(dayIndex);
    final existing = _dinnerForDay(dayIndex);

    final result = await showDialog<_MealEntry>(
      context: context,
      builder: (ctx) => _PlanDinnerDialog(
        date: date,
        inventory: inventory,
        existing: existing,
      ),
    );

    if (result == null || !mounted) return;

    // Save meal to DB
    if (existing != null) {
      await DatabaseService.instance.deleteMeal(existing.id);
      setState(() => _meals.removeWhere((m) => m.id == existing.id));
    }

    final meal = MealPlan(
      id: 0,
      date: date,
      mealType: 'Dinner',
      mealName: result.mealName,
      ingredients: result.ingredients,
    );
    final id = await DatabaseService.instance.insertMeal(meal);
    setState(() => _meals.add(meal.copyWith(id: id)));

    // Auto-add missing ingredients to shopping list
    if (result.missingIngredients.isNotEmpty) {
      _addMissingToShoppingList(result.missingIngredients);
    }
  }

  void _addMissingToShoppingList(List<String> missing) {
    final provider = context.read<InventoryProvider>();
    int added = 0;

    for (final name in missing) {
      final exists = provider.items.any(
          (i) => i.product.toLowerCase() == name.toLowerCase());
      if (exists) continue;

      provider.addItem(FoodItem(
        upc: '',
        product: name,
        quantity: 1,
        quantityUsed: 1,
        sellByDate: '',
        location: 'Shopping List',
        alertAt: 1,
      ));
      added++;
    }

    if (added > 0 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            '$added missing ingredient${added == 1 ? '' : 's'} added to shopping list'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'View',
          onPressed: () {
            // Switch to shopping tab (index 1)
            // We use the root navigator context here
          },
        ),
      ));
    }
  }

  Future<void> _deleteMeal(MealPlan meal) async {
    await DatabaseService.instance.deleteMeal(meal.id);
    setState(() => _meals.removeWhere((m) => m.id == meal.id));
  }

  List<String> get _missingIngredients {
    final inventory = context.read<InventoryProvider>().items;
    final inventoryNames =
        inventory.map((i) => i.product.toLowerCase()).toSet();
    final missing = <String>{};
    for (final meal in _meals) {
      for (final ing in meal.ingredients) {
        final lower = ing.toLowerCase();
        if (!inventoryNames.any((n) => n.contains(lower) || lower.contains(n))) {
          missing.add(ing);
        }
      }
    }
    return missing.toList()..sort();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final today = DateTime.now();
    final weekLabel =
        '${DateFormat('MMM d').format(_weekStart)} – '
        '${DateFormat('MMM d').format(_weekStart.add(const Duration(days: 6)))}';
    final missing = _missingIngredients;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dinner Planner'),
        actions: [
          TextButton(
            onPressed: _today,
            child: const Text('Today', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // ── Week nav ─────────────────────────────────────────────
                Container(
                  color: cs.primaryContainer,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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

                // ── Missing ingredients banner ────────────────────────────
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
                              '${missing.length} ingredient${missing.length == 1 ? '' : 's'} still needed this week',
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

                // ── Day list ─────────────────────────────────────────────
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: 7,
                    itemBuilder: (context, dayIndex) {
                      final date = _dayDate(dayIndex);
                      final isToday = date.year == today.year &&
                          date.month == today.month &&
                          date.day == today.day;
                      final dinner = _dinnerForDay(dayIndex);

                      return _DayRow(
                        dayLabel:
                            '${_days[dayIndex]}  ${DateFormat('MMM d').format(date)}',
                        isToday: isToday,
                        meal: dinner,
                        inventory: context
                            .read<InventoryProvider>()
                            .items
                            .toList(),
                        onTap: () => _planDinner(dayIndex),
                        onDelete: dinner != null
                            ? () => _deleteMeal(dinner)
                            : null,
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
            const Text('Still Needed'),
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

// ── Day row ───────────────────────────────────────────────────────────────────

class _DayRow extends StatelessWidget {
  final String dayLabel;
  final bool isToday;
  final MealPlan? meal;
  final List<FoodItem> inventory;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const _DayRow({
    required this.dayLabel,
    required this.isToday,
    required this.meal,
    required this.inventory,
    required this.onTap,
    required this.onDelete,
  });

  bool get _hasMissing {
    if (meal == null) return false;
    final names = inventory.map((i) => i.product.toLowerCase()).toSet();
    return meal!.ingredients.any((ing) {
      final lower = ing.toLowerCase();
      return !names.any((n) => n.contains(lower) || lower.contains(n));
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final missing = _hasMissing;

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isToday
            ? BorderSide(color: cs.primary, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
          child: Row(
            children: [
              // Day label
              SizedBox(
                width: 90,
                child: Text(
                  dayLabel,
                  style: TextStyle(
                    fontWeight:
                        isToday ? FontWeight.bold : FontWeight.w500,
                    fontSize: 13,
                    color: isToday ? cs.primary : cs.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Meal or empty prompt
              Expanded(
                child: meal == null
                    ? Row(
                        children: [
                          Icon(Icons.add_circle_outline,
                              size: 16, color: cs.onSurfaceVariant),
                          const SizedBox(width: 6),
                          Text(
                            'Plan dinner…',
                            style: TextStyle(
                              color: cs.onSurfaceVariant,
                              fontStyle: FontStyle.italic,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Icon(
                            missing
                                ? Icons.warning_amber_rounded
                                : Icons.check_circle_outline,
                            size: 16,
                            color: missing
                                ? cs.error
                                : Colors.green[600],
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              meal!.mealName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
              ),

              // Delete button
              if (meal != null && onDelete != null)
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  color: cs.onSurfaceVariant,
                  onPressed: onDelete,
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Plan dinner dialog ────────────────────────────────────────────────────────

class _MealEntry {
  final String mealName;
  final List<String> ingredients;
  final List<String> missingIngredients;

  const _MealEntry({
    required this.mealName,
    required this.ingredients,
    required this.missingIngredients,
  });
}

class _PlanDinnerDialog extends StatefulWidget {
  final DateTime date;
  final List<FoodItem> inventory;
  final MealPlan? existing;

  const _PlanDinnerDialog({
    required this.date,
    required this.inventory,
    this.existing,
  });

  @override
  State<_PlanDinnerDialog> createState() => _PlanDinnerDialogState();
}

class _PlanDinnerDialogState extends State<_PlanDinnerDialog> {
  final _controller = TextEditingController();
  final _speech = SpeechToText();

  bool _isListening = false;
  bool _speechAvailable = false;
  bool _isLookingUp = false;
  String _liveTranscript = '';

  List<String> _allIngredients = [];
  List<String> _missingIngredients = [];

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
    _initSpeech();

    // Pre-fill if editing existing
    if (widget.existing != null) {
      _controller.text = widget.existing!.mealName;
    }
  }

  Future<void> _initSpeech() async {
    final available = await _speech.initialize();
    if (mounted) setState(() => _speechAvailable = available);
  }

  @override
  void dispose() {
    _controller.dispose();
    _speech.cancel();
    super.dispose();
  }

  Future<void> _toggleListening() async {
    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
      if (_liveTranscript.isNotEmpty) {
        _controller.text = _liveTranscript;
        _liveTranscript = '';
        await _lookupIngredients();
      }
      return;
    }

    setState(() {
      _isListening = true;
      _liveTranscript = '';
      _allIngredients = [];
      _missingIngredients = [];
    });

    await _speech.listen(
      onResult: (result) {
        setState(() => _liveTranscript = result.recognizedWords);
        if (result.finalResult && result.recognizedWords.isNotEmpty) {
          _speech.stop();
          setState(() {
            _isListening = false;
            _controller.text = result.recognizedWords;
            _liveTranscript = '';
          });
          _lookupIngredients();
        }
      },
      listenFor: const Duration(seconds: 20),
      pauseFor: const Duration(seconds: 2),
      localeId: 'en_US',
    );
  }

  Future<void> _lookupIngredients() async {
    final name = _controller.text.trim();
    if (name.isEmpty) return;

    setState(() {
      _isLookingUp = true;
      _allIngredients = [];
      _missingIngredients = [];
    });

    try {
      final response = await GeminiService.instance.askAboutMeal(
        userMessage: name,
        inventory: widget.inventory,
      );

      if (!mounted) return;

      final inventoryNames =
          widget.inventory.map((i) => i.product.toLowerCase()).toSet();

      final all = response.ingredients.map((i) => i.name).toList();
      final missing = all.where((ing) {
        final lower = ing.toLowerCase();
        return !inventoryNames
            .any((n) => n.contains(lower) || lower.contains(n));
      }).toList();

      setState(() {
        _allIngredients = all;
        _missingIngredients = missing;
        _isLookingUp = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLookingUp = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dateStr = DateFormat('EEEE, MMM d').format(widget.date);
    final canSave = _controller.text.trim().isNotEmpty && !_isLookingUp;

    return AlertDialog(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Plan Dinner'),
          Text(dateStr,
              style: TextStyle(
                  fontSize: 13,
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.normal)),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Input row ────────────────────────────────────────────
              Row(
                children: [
                  // Mic button
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: _isListening ? cs.error : cs.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: Icon(
                        _isListening ? Icons.stop : Icons.mic,
                        color: _isListening
                            ? cs.onError
                            : cs.onPrimaryContainer,
                        size: 20,
                      ),
                      onPressed:
                          _speechAvailable ? _toggleListening : null,
                      tooltip: _isListening ? 'Stop' : 'Speak meal name',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        labelText: 'What\'s for dinner?',
                        hintText: _isListening
                            ? (_liveTranscript.isNotEmpty
                                ? _liveTranscript
                                : 'Listening…')
                            : 'e.g. Lasagna',
                      ),
                      textCapitalization: TextCapitalization.words,
                      onSubmitted: (_) => _lookupIngredients(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // AI lookup button
                  IconButton.filled(
                    icon: _isLookingUp
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.auto_awesome, size: 18),
                    tooltip: 'Ask the Elf for ingredients',
                    onPressed: (_isLookingUp ||
                            _controller.text.trim().isEmpty)
                        ? null
                        : _lookupIngredients,
                  ),
                ],
              ),

              // ── Ingredient results ───────────────────────────────────
              if (_allIngredients.isNotEmpty) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${_allIngredients.length} ingredients',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: cs.onSurfaceVariant),
                      ),
                    ),
                    if (_missingIngredients.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: cs.errorContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_missingIngredients.length} missing — will add to shopping list',
                          style: TextStyle(
                              fontSize: 11, color: cs.onErrorContainer),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'All in stock!',
                          style: TextStyle(
                              fontSize: 11,
                              color: Colors.green.shade800),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: _allIngredients.map((ing) {
                    final isMissing = _missingIngredients.contains(ing);
                    return Chip(
                      label: Text(ing,
                          style: const TextStyle(fontSize: 11)),
                      avatar: Icon(
                        isMissing
                            ? Icons.add_shopping_cart
                            : Icons.check,
                        size: 12,
                        color: isMissing
                            ? cs.onErrorContainer
                            : Colors.green[700],
                      ),
                      backgroundColor: isMissing
                          ? cs.errorContainer
                          : Colors.green.shade50,
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
        FilledButton.icon(
          icon: const Icon(Icons.dinner_dining, size: 16),
          label: const Text('Plan It'),
          onPressed: canSave
              ? () => Navigator.of(context).pop(_MealEntry(
                    mealName: _controller.text.trim(),
                    ingredients: _allIngredients,
                    missingIngredients: _missingIngredients,
                  ))
              : null,
        ),
      ],
    );
  }
}
