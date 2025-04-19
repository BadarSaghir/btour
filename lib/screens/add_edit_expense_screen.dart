// FILE: lib/screens/add_edit_expense_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:collection/collection.dart'; // For firstWhereOrNull
import 'package:btour/models/category.dart';
import 'package:btour/models/expense.dart';
import 'package:btour/models/person.dart';
import 'package:btour/models/tour.dart';
import 'package:btour/providers/tour_provider.dart';
// REMOVED: import 'package:btour/widgets/person_multi_selector.dart';
import 'package:btour/database/database_helper.dart'; // Direct DB access needed for initial load

class AddEditExpenseScreen extends StatefulWidget {
  final Tour tour; // The tour this expense belongs to
  final Expense? expenseToEdit; // Pass expense if editing

  const AddEditExpenseScreen({
    super.key,
    required this.tour,
    this.expenseToEdit,
  });

  bool get isEditing => expenseToEdit != null;

  @override
  State<AddEditExpenseScreen> createState() => _AddEditExpenseScreenState();
}

class _AddEditExpenseScreenState extends State<AddEditExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _amountController;
  late TextEditingController _descriptionController;
  final TextEditingController _categoryController =
      TextEditingController(); // For adding new category dialog

  // Use separate controllers for each payment field
  Map<int, TextEditingController> _paymentControllers =
      {}; // personId -> Controller

  DateTime _selectedDate = DateTime.now();
  Category? _selectedCategory;
  List<Category> _availableCategories = [];
  List<Person> _tourParticipants = []; // People participating in the tour
  List<Person> _selectedAttendees = [];

  // Payment Tracking: Keep track of amounts separate from controllers for calculation
  Map<int, double> _paymentAmounts = {}; // personId -> Amount Paid

  bool _isLoading =
      false; // Local loading state for form submission/initial load

  @override
  void initState() {
    super.initState();

    _amountController = TextEditingController(
      text: widget.expenseToEdit?.amount.toStringAsFixed(2) ?? '',
    );
    _descriptionController = TextEditingController(
      text: widget.expenseToEdit?.description ?? '',
    );
    _selectedDate = widget.expenseToEdit?.date ?? DateTime.now();

    // Add listener to amount controller to potentially auto-update default payment
    _amountController.addListener(_onAmountChanged);

    // Fetch initial data (categories, participants, and existing expense details if editing)
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    // Ensure mounted check
    if (!mounted) return;
    setState(() => _isLoading = true);
    final tourProvider = Provider.of<TourProvider>(context, listen: false);
    final dbHelper = DatabaseHelper.instance;

    // Ensure categories and participants are loaded
    // Categories might be in provider, participants specific to tour need fetching
    try {
      if (tourProvider.categories.isEmpty) {
        await tourProvider.fetchAllCategories();
      }
      // Check mounted again after async gap
      if (!mounted) return;
      _availableCategories = tourProvider.categories;

      // Fetch participants directly for this tour
      _tourParticipants = await dbHelper.getTourParticipants(widget.tour.id!);
      // Check mounted again after async gap
      if (!mounted) return;
      print(
        "Loaded Tour Participants for Expense Screen: ${_tourParticipants.length}, IDs: ${_tourParticipants.map((p) => p.id).toList()}",
      ); // DEBUG
      // Ensure the state is updated after loading participants
      setState(() {}); // Update state to reflect loaded participants

      if (widget.isEditing && widget.expenseToEdit != null) {
        final expense = widget.expenseToEdit!;
        // Pre-select category safely
        _selectedCategory = _availableCategories.firstWhereOrNull(
          (cat) => cat.id == expense.categoryId,
        );

        // Pre-select attendees
        final attendees = await dbHelper.getExpenseAttendees(expense.id!);
        // Check mounted again after async gap
        if (!mounted) return;
        if (attendees.isNotEmpty) {
          _selectedAttendees = attendees;
        } else {
          // Fallback if no attendees were previously saved (shouldn't happen ideally)
          // Defaulting to all participants if none were explicitly saved might be too aggressive
          // Let's default to empty and let user re-select if needed
          _selectedAttendees = [];
        }
        if (!mounted) return;

        // Load existing payments
        final existingPayments = await dbHelper.getExpensePayments(expense.id!);
        // Check mounted again after async gap
        if (!mounted) return;
        _paymentAmounts = {
          for (var p in existingPayments) p.personId: p.amountPaid,
        };
      } else {
        // Default for new expense:
        // No default category initially
        _selectedCategory = null;
        // Default attendees: Start empty for explicit selection.
        _selectedAttendees = [];
        // Default payment: Advance holder pays (will be set by _initializePaymentControllers)
        _paymentAmounts = {}; // Start empty, will be populated
      }

      // Initialize controllers and amounts for ALL participants AFTER loading
      _initializePaymentControllersAndAmounts();
    } catch (e) {
      print("Error loading initial expense data: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading data: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Initialize/Update payment controllers and amounts map for all current tour participants
  void _initializePaymentControllersAndAmounts() {
    // Dispose old controllers first
    _paymentControllers.values.forEach((controller) => controller.dispose());
    _paymentControllers = {};

    final currentTotalAmount = double.tryParse(_amountController.text) ?? 0.0;
    bool isNewExpenseOrNoPayments =
        !widget.isEditing || _paymentAmounts.isEmpty;
    bool onlyZeroPaymentsExist =
        _paymentAmounts.isNotEmpty &&
        _paymentAmounts.values.every((amount) => amount == 0.0);

    // Determine if we should apply the default payment (holder pays all)
    bool applyDefaultPayment =
        isNewExpenseOrNoPayments || onlyZeroPaymentsExist;

    for (var participant in _tourParticipants) {
      // Check participant has a valid ID
      if (participant.id == null) {
        print(
          "Warning: Participant ${participant.name} has null ID, skipping payment controller init.",
        );
        continue;
      }

      double initialAmount = 0.0;
      if (applyDefaultPayment &&
          participant.id == widget.tour.advanceHolderPersonId) {
        initialAmount = currentTotalAmount; // Holder pays total if defaulting
      } else {
        initialAmount =
            _paymentAmounts[participant.id] ?? 0.0; // Use existing or 0
      }

      // Update the internal amount map
      _paymentAmounts[participant.id!] = initialAmount;

      // Create and initialize the controller
      final controller = TextEditingController(
        text: initialAmount.toStringAsFixed(2),
      );
      controller.addListener(
        () => _onPaymentControllerChanged(participant.id!, controller.text),
      );
      _paymentControllers[participant.id!] = controller;
    }
    // Ensure the state reflects the initialized controllers/amounts
    if (mounted) setState(() {});
  }

  // --- Listener Callbacks ---

  void _onAmountChanged() {
    // If payments haven't been manually edited (i.e., only holder has non-zero amount or all are zero),
    // update the holder's payment controller to match the new total amount.
    final currentTotalAmount = double.tryParse(_amountController.text) ?? 0.0;
    final holderId = widget.tour.advanceHolderPersonId;

    // Check if the controller for the holder actually exists before proceeding
    if (!_paymentControllers.containsKey(holderId)) {
      // This might happen if participants haven't loaded yet or holder isn't a participant
      // print("Warning: Holder payment controller not found during amount change.");
      return;
    }

    // Check if only the holder has a non-zero payment amount in the internal map
    bool onlyHolderPaid = _paymentAmounts.entries.every((entry) {
      // Check if entry key exists and is the holder ID
      if (entry.key == holderId)
        return entry.value > 0.001; // Allow for float inaccuracies
      // For others, check if value is close to 0.0
      return entry.value.abs() < 0.001;
    });
    // Or if all payments are effectively zero
    bool allZero = _paymentAmounts.values.every(
      (amount) => amount.abs() < 0.001,
    );

    final holderController =
        _paymentControllers[holderId]; // We know this exists now

    if (holderController != null && (onlyHolderPaid || allZero)) {
      final formattedAmount = currentTotalAmount.toStringAsFixed(2);
      // Update controller only if value is different to avoid cursor jumps/loops
      if (holderController.text != formattedAmount) {
        // Use WidgetsBinding.instance.addPostFrameCallback to avoid issues if called during build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          // Check mounted & controller still valid inside callback
          if (mounted && _paymentControllers.containsKey(holderId)) {
            // Update text (this will trigger listener)
            // Need to temporarily remove listener to avoid infinite loop if listener also updates map
            final listener =
                () => _onPaymentControllerChanged(
                  holderId!,
                  _paymentControllers[holderId]!.text,
                );
            _paymentControllers[holderId]?.removeListener(listener);
            _paymentControllers[holderId]?.text = formattedAmount;
            // Manually update the internal map as well since listener was removed
            _paymentAmounts[holderId!] = currentTotalAmount;
            _paymentControllers[holderId]?.addListener(listener);
          }
        });
      }
    }
  }

  void _onPaymentControllerChanged(int personId, String textValue) {
    final amount = double.tryParse(textValue) ?? 0.0;
    // Update the internal map only if the value has actually changed
    // Use mounted check before setState
    if (mounted && (_paymentAmounts[personId] ?? 0.0) != amount) {
      setState(() {
        _paymentAmounts[personId] = amount;
      });
    }
  }

  @override
  void dispose() {
    _amountController.removeListener(_onAmountChanged);
    _amountController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    // Dispose all payment controllers
    _paymentControllers.values.forEach((controller) => controller.dispose());
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: widget.tour.startDate.subtract(const Duration(days: 30)),
      lastDate:
          widget.tour.endDate?.add(const Duration(days: 1)) ??
          DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != _selectedDate) {
      if (mounted) {
        setState(() {
          _selectedDate = picked;
        });
      }
    }
  }

  Future<void> _showAddCategoryDialog() async {
    _categoryController.clear();
    final newCategoryName = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Add New Category'),
          content: TextField(
            controller: _categoryController,
            decoration: const InputDecoration(hintText: "Category Name"),
            textCapitalization: TextCapitalization.words,
            autofocus: true,
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Add'),
              onPressed: () {
                if (_categoryController.text.trim().isNotEmpty) {
                  Navigator.of(context).pop(_categoryController.text.trim());
                }
              },
            ),
          ],
        );
      },
    );

    if (newCategoryName != null && mounted) {
      final tourProvider = Provider.of<TourProvider>(context, listen: false);
      setState(() => _isLoading = true);
      try {
        final newCategory = await tourProvider.addCategory(newCategoryName);
        if (!mounted) return;
        setState(() {
          _availableCategories = tourProvider.categories;
          _selectedCategory = newCategory;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Category "${newCategory.name}" added.'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        print("Error adding category: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error adding category: $e'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  // --- NEW: Attendee Selection Dialog ---
  Future<void> _showAttendeeSelectionDialog() async {
    final List<Person> tempSelectedAttendees = List.from(_selectedAttendees);

    final List<Person>? result = await showDialog<List<Person>>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Select Attendees'),
              content: Container(
                width: double.maxFinite,
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.6,
                ),
                child:
                    _tourParticipants.isEmpty
                        ? const Center(child: Text('No participants found.'))
                        : ListView.builder(
                          shrinkWrap: true,
                          itemCount: _tourParticipants.length,
                          itemBuilder: (context, index) {
                            final person = _tourParticipants[index];
                            final bool isSelected = tempSelectedAttendees.any(
                              (p) => p.id == person.id,
                            );

                            return CheckboxListTile(
                              title: Text(person.name),
                              value: isSelected,
                              onChanged: (bool? checked) {
                                if (checked == null) return;
                                setStateDialog(() {
                                  if (checked) {
                                    if (!tempSelectedAttendees.any(
                                      (p) => p.id == person.id,
                                    )) {
                                      tempSelectedAttendees.add(person);
                                    }
                                  } else {
                                    tempSelectedAttendees.removeWhere(
                                      (p) => p.id == person.id,
                                    );
                                  }
                                });
                              },
                              controlAffinity: ListTileControlAffinity.leading,
                              dense: true,
                            );
                          },
                        ),
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () => Navigator.of(context).pop(null),
                ),
                TextButton(
                  child: const Text('Confirm'),
                  onPressed:
                      () => Navigator.of(context).pop(tempSelectedAttendees),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null && mounted) {
      setState(() {
        _selectedAttendees = result;
      });
    }
  }

  // --- NEW: Helper to display selected attendees ---
  Widget _buildAttendeesDisplay() {
    if (_selectedAttendees.isEmpty) {
      return Container(); // Use hintText in InputDecorator
    } else if (_selectedAttendees.length == 1) {
      return Text(_selectedAttendees.first.name);
    } else if (_selectedAttendees.length <= 3) {
      return Text(
        _selectedAttendees.map((p) => p.name).join(', '),
        overflow: TextOverflow.ellipsis,
      );
    } else {
      return Text('${_selectedAttendees.length} Attendees Selected');
    }
  }

  // --- Form Submission ---
  Future<void> _submitForm() async {
    if (!mounted) return;

    if (_formKey.currentState!.validate()) {
      if (_selectedCategory == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select or add a Category.'),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }
      if (_selectedAttendees.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Please select at least one Attendee for this expense.',
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }

      final totalAmount = double.tryParse(_amountController.text) ?? 0.0;
      final totalPaid = _paymentAmounts.values.fold<double>(
        0.0,
        (sum, item) => sum + item,
      );

      if ((totalPaid - totalAmount).abs() > 0.01) {
        if (!mounted) return;
        bool? continueSave = await showDialog<bool>(
          context: context,
          builder:
              (ctx) => AlertDialog(
                title: const Text('Payment Mismatch'),
                content: Text(
                  'The sum of individual payments (${NumberFormat.currency(locale: 'en_US', symbol: '"\$"').format(totalPaid)}) does not match the total expense amount (${NumberFormat.currency(locale: 'en_US', symbol: "\$").format(totalAmount)}). \n\nSave anyway? The total amount (${NumberFormat.currency(locale: 'en_US', symbol: '"\$"').format(totalAmount)}) will be recorded as the expense cost.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: const Text('Save Anyway'),
                  ),
                ],
              ),
        );
        if (continueSave == null || !continueSave) {
          return; // User cancelled
        }
      }

      if (!mounted) return;
      setState(() => _isLoading = true);
      final tourProvider = Provider.of<TourProvider>(context, listen: false);

      final expenseData = Expense(
        id: widget.expenseToEdit?.id,
        tourId: widget.tour.id!,
        categoryId: _selectedCategory!.id!,
        amount: totalAmount,
        date: _selectedDate,
        description:
            _descriptionController.text.trim().isEmpty
                ? null
                : _descriptionController.text.trim(),
      );

      final attendeeIds = _selectedAttendees.map((p) => p.id!).toList();
      final validPayments =
          _paymentAmounts.entries
              .where(
                (entry) => entry.value > 0.001,
              ) // Use tolerance for comparison
              .map(
                (entry) => ExpensePayment(
                  expenseId: widget.expenseToEdit?.id ?? 0,
                  personId: entry.key,
                  amountPaid: entry.value,
                ),
              )
              .toList();

      try {
        if (widget.isEditing) {
          await tourProvider.updateExpenseInCurrentTour(
            expenseData,
            attendeeIds,
            validPayments,
          );
          if (mounted)
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Expense Updated Successfully!'),
                backgroundColor: Colors.green,
              ),
            );
        } else {
          await tourProvider.addExpenseToCurrentTour(
            expenseData,
            attendeeIds,
            validPayments,
          );
          if (mounted)
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Expense Added Successfully!'),
                backgroundColor: Colors.green,
              ),
            );
        }
        if (mounted) Navigator.of(context).pop();
      } catch (e) {
        print("Error saving expense: $e");
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error saving expense: $e'),
              backgroundColor: Colors.redAccent,
            ),
          );
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please fix the errors in the form.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy-MM-dd');
    final currencyFormat = NumberFormat.currency(locale: 'en_US', symbol: "\$");

    final double currentPaymentSum = _paymentAmounts.values.fold(
      0.0,
      (a, b) => a + b,
    );
    final double currentTotalAmount =
        double.tryParse(_amountController.text) ?? 0.0;
    final bool paymentMismatch =
        (currentPaymentSum - currentTotalAmount).abs() > 0.01;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit Expense' : 'Add New Expense'),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.only(right: 16.0),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          if (!_isLoading)
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _submitForm,
              tooltip: 'Save Expense',
            ),
        ],
      ),
      body:
          _isLoading &&
                  _availableCategories.isEmpty &&
                  _tourParticipants
                      .isEmpty // Show loading only on initial data fetch
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      // --- Category ---
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<Category>(
                              value: _selectedCategory,
                              items:
                                  _availableCategories.map((Category category) {
                                    return DropdownMenuItem<Category>(
                                      value: category,
                                      child: Text(category.name),
                                    );
                                  }).toList(),
                              onChanged: (Category? newValue) {
                                setState(() {
                                  _selectedCategory = newValue;
                                });
                              },
                              decoration: const InputDecoration(
                                labelText: 'Category *',
                                border: OutlineInputBorder(),
                              ),
                              validator:
                                  (value) =>
                                      value == null
                                          ? 'Category required'
                                          : null,
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            onPressed: _showAddCategoryDialog,
                            tooltip: 'Add New Category',
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // --- Amount ---
                      TextFormField(
                        controller: _amountController,
                        decoration: const InputDecoration(
                          labelText: 'Total Amount *',
                          prefixText: "\$",
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Amount required';
                          }
                          final amount = double.tryParse(value);
                          if (amount == null || amount <= 0) {
                            return 'Must be > 0';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // --- Date ---
                      InkWell(
                        onTap: () => _selectDate(context),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Date *',
                            border: OutlineInputBorder(),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(dateFormat.format(_selectedDate)),
                              const Icon(
                                Icons.calendar_month_outlined,
                                color: Colors.grey,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // --- Description ---
                      TextFormField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Description (Optional)',
                          border: OutlineInputBorder(),
                        ),
                        textCapitalization: TextCapitalization.sentences,
                        maxLines: 2,
                      ),
                      const SizedBox(height: 20),

                      // --- Attendees ---
                      Text(
                        'Attendees *',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      // --- Custom Dropdown-like Field for Attendees ---
                      InkWell(
                        onTap:
                            _tourParticipants.isNotEmpty
                                ? _showAttendeeSelectionDialog
                                : null, // Disable tap if no participants
                        child: InputDecorator(
                          decoration: InputDecoration(
                            border: const OutlineInputBorder(),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12.0,
                              vertical: 15.0,
                            ),
                            hintText:
                                _selectedAttendees.isEmpty
                                    ? 'Select Attendees'
                                    : null,
                            suffixIcon: const Icon(Icons.arrow_drop_down),
                            enabled:
                                _tourParticipants
                                    .isNotEmpty, // Visually disable if no participants
                          ),
                          child: _buildAttendeesDisplay(),
                        ),
                      ),
                      // Validation message for attendees
                      if (_selectedAttendees.isEmpty &&
                          !_isLoading &&
                          _tourParticipants.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0, left: 12.0),
                          child: Text(
                            'Select at least one attendee.',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                              fontSize: 12,
                            ),
                          ),
                        )
                      else if (_tourParticipants.isEmpty && !_isLoading)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0, left: 12.0),
                          child: Text(
                            'Load/add participants to the tour first.',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      const SizedBox(height: 20),

                      // --- Payers ---
                      Text(
                        'Paid By',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '(Specify amounts paid by each person. Total should match expense amount.)',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_tourParticipants.isEmpty && !_isLoading)
                        const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Text(
                            'Load/add participants to specify payments.',
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      else if (_tourParticipants.isNotEmpty)
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _tourParticipants.length,
                          itemBuilder: (context, index) {
                            final person = _tourParticipants[index];
                            final paymentController =
                                _paymentControllers[person.id];

                            if (paymentController == null) {
                              // This might happen briefly, render placeholder or nothing
                              return const SizedBox.shrink();
                            }

                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 4.0,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      person.name,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  SizedBox(
                                    width: 130,
                                    child: TextFormField(
                                      key: ValueKey('payment_${person.id}'),
                                      controller: paymentController,
                                      decoration: const InputDecoration(
                                        prefixText: "\$",
                                        border: OutlineInputBorder(),
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 10,
                                        ),
                                        isDense: true,
                                      ),
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                      validator: (value) {
                                        final amount = double.tryParse(
                                          value ?? '',
                                        );
                                        if (amount == null || amount < 0) {
                                          return '>= 0';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        )
                      else // Show loading indicator if participants aren't loaded yet
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Text("Loading participants..."),
                          ),
                        ),

                      // Display Sum of Payments for verification
                      Padding(
                        padding: const EdgeInsets.only(top: 12.0, right: 8),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            'Payments Sum: ${currencyFormat.format(currentPaymentSum)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color:
                                  paymentMismatch
                                      ? Colors.redAccent
                                      : Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ),
                      if (paymentMismatch)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0, right: 8),
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              'Does not match total amount!',
                              style: TextStyle(
                                color: Colors.redAccent.shade700,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),

                      const SizedBox(height: 80), // Extra padding at bottom
                    ],
                  ),
                ),
              ),
    );
  }
}
