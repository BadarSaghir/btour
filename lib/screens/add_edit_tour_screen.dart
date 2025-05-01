// FILE: lib/screens/add_edit_tour_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:btour/models/person.dart';
import 'package:btour/models/tour.dart';
import 'package:btour/providers/tour_provider.dart';
import 'package:btour/widgets/person_multi_selector.dart';
import 'package:collection/collection.dart'; // Needed for firstWhereOrNull
import 'package:btour/database/database_helper.dart'; // Needed for DB access in initState

class AddEditTourScreen extends StatefulWidget {
  final Tour? tourToEdit; // Pass tour if editing

  const AddEditTourScreen({super.key, this.tourToEdit});

  bool get isEditing => tourToEdit != null;

  @override
  State<AddEditTourScreen> createState() => _AddEditTourScreenState();
}

class _AddEditTourScreenState extends State<AddEditTourScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _advanceAmountController;
  DateTime _startDate = DateTime.now();
  DateTime? _endDate; // Nullable for ongoing tours
  Person? _selectedAdvanceHolder;
  List<Person> _selectedParticipants = [];
  List<Person> _allPeople = []; // To populate dropdowns/selectors

  bool _isLoading = false; // Local loading state for form submission
  bool _isDataLoading = true; // Separate state for initial data loading

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.tourToEdit?.name);
    _advanceAmountController = TextEditingController(
      text: widget.tourToEdit?.advanceAmount.toStringAsFixed(2) ?? '0.00',
    ); // Default to 0.00
    _startDate = widget.tourToEdit?.startDate ?? DateTime.now();
    _endDate = widget.tourToEdit?.endDate; // Can be null

    // Fetch available people and set initial selections if editing
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isDataLoading = true);
    final tourProvider = Provider.of<TourProvider>(context, listen: false);
    final dbHelper = DatabaseHelper.instance; // Use instance

    try {
      // Ensure people list is up-to-date, fetch if needed
      if (tourProvider.people.isEmpty) {
        await tourProvider.fetchAllPeople();
      }
      _allPeople = tourProvider.people;

      if (widget.isEditing && widget.tourToEdit != null) {
        // Pre-select advance holder safely using firstWhereOrNull
        _selectedAdvanceHolder = _allPeople.firstWhereOrNull(
          (p) => p.id == widget.tourToEdit!.advanceHolderPersonId,
        );
        if (_selectedAdvanceHolder == null && _allPeople.isNotEmpty) {
          print(
            "Warning: Advance holder ID ${widget.tourToEdit!.advanceHolderPersonId} not found in people list.",
          );
        }

        // Pre-select participants directly from DB
        final participants = await dbHelper.getTourParticipants(
          widget.tourToEdit!.id!,
        );
        // Ensure uniqueness in case of data issues
        _selectedParticipants = participants.toSet().toList();

        // Ensure holder is in the list *after* loading both
        if (_selectedAdvanceHolder != null &&
            !_selectedParticipants.any(
              (p) => p.id == _selectedAdvanceHolder!.id,
            )) {
          _selectedParticipants.add(_selectedAdvanceHolder!);
          _selectedParticipants.sort(
            (a, b) => a.name.compareTo(b.name),
          ); // Keep sorted
        }
      } else {
        // Defaults for new tour handled by initial state values
      }
    } catch (e) {
      print("Error loading initial tour data: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading data: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isDataLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _advanceAmountController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime initial =
        isStartDate
            ? _startDate
            : (_endDate ??
                _startDate.add(
                  const Duration(days: 1),
                )); // Suggest end date after start
    final DateTime first =
        isStartDate
            ? DateTime(2000)
            : _startDate; // End date cannot be before start date
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
          // If end date is before new start date, reset end date
          if (_endDate != null && _endDate!.isBefore(_startDate)) {
            _endDate = null;
          }
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedAdvanceHolder == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select an Advance Holder.'),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }
      // Use a temporary list derived from state for validation
      List<Person> currentParticipants = List.from(_selectedParticipants);
      if (currentParticipants.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select at least one Participant.'),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }
      // Ensure Advance Holder is included in the final list sent to DB
      // This acts as a final safeguard, though the onChanged logic should handle it.
      if (!currentParticipants.any((p) => p.id == _selectedAdvanceHolder!.id)) {
        currentParticipants.add(_selectedAdvanceHolder!);
      }

      setState(() => _isLoading = true);

      final tourProvider = Provider.of<TourProvider>(context, listen: false);
      final participantIds =
          currentParticipants
              .map((p) => p.id!)
              .toList(); // Use the validated list
      final advanceAmount =
          double.tryParse(_advanceAmountController.text) ?? 0.0;

      try {
        if (widget.isEditing) {
          // Update existing tour
          final updatedTour = widget.tourToEdit!.copy(
            name: _nameController.text.trim(),
            startDate: _startDate,
            endDate: _endDate,
            clearEndDate:
                _endDate == null && widget.tourToEdit!.endDate != null,
            advanceAmount: advanceAmount,
            advanceHolderPersonId: _selectedAdvanceHolder!.id!,
          );
          await tourProvider.updateTour(updatedTour, participantIds);
          if (mounted)
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Tour Updated Successfully!'),
                backgroundColor: Colors.green,
              ),
            );
        } else {
          // Create new tour
          final newTour = Tour(
            name: _nameController.text.trim(),
            startDate: _startDate,
            endDate: _endDate,
            advanceAmount: advanceAmount,
            advanceHolderPersonId: _selectedAdvanceHolder!.id!,
            status: TourStatus.Created,
          );
          await tourProvider.addTour(newTour, participantIds);
          if (mounted)
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Tour Created Successfully!'),
                backgroundColor: Colors.green,
              ),
            );
        }
        // Pop only after successful operation
        if (mounted) {
          Navigator.of(context).pop();
        }
      } catch (e) {
        print("Error saving tour: $e");
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error saving tour: ${e.toString()}'),
              backgroundColor: Colors.redAccent,
            ),
          );
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    } else {
      // Form validation failed
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fix the errors above.'),
          backgroundColor: Colors.orangeAccent,
        ),
      );
    }
  }

  // Function to add a new person (used by PersonMultiSelector callback)
  Future<Person?> _addNewPerson(String name) async {
    if (name.trim().isEmpty) return null;
    setState(
      () => _isLoading = true,
    ); // Show loading indicator while adding person
    final tourProvider = Provider.of<TourProvider>(context, listen: false);
    try {
      final newPerson = await tourProvider.addPerson(name.trim());
      // Update the list of all people available for selection IN THIS SCREEN
      setState(() {
        _allPeople = tourProvider.people; // Refresh local copy of all people
      });
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${newPerson.name} added.'),
            backgroundColor: Colors.green,
          ),
        );
      return newPerson; // Return the created/found person to the selector
    } catch (e) {
      print("Error adding person: $e");
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding person: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      return null;
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy-MM-dd');

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit Tour' : 'Add New Tour'),
        actions: [
          if (_isLoading || _isDataLoading)
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
          if (!_isLoading && !_isDataLoading)
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _submitForm,
              tooltip: 'Save Tour',
            ),
        ],
      ),
      body:
          _isDataLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Tour Name *',
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter a tour name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // --- Start & End Dates ---
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => _selectDate(context, true),
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Start Date *',
                                  border: OutlineInputBorder(),
                                ),
                                child: Text(dateFormat.format(_startDate)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: InkWell(
                              onTap: () => _selectDate(context, false),
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText: 'End Date (Optional)',
                                  border: const OutlineInputBorder(),
                                  suffixIcon:
                                      _endDate != null
                                          ? IconButton(
                                            icon: const Icon(
                                              Icons.clear,
                                              size: 20,
                                            ),
                                            onPressed:
                                                () => setState(
                                                  () => _endDate = null,
                                                ),
                                            tooltip: 'Clear End Date',
                                          )
                                          : null,
                                ),
                                child: Text(
                                  _endDate != null
                                      ? dateFormat.format(_endDate!)
                                      : 'Set End Date...',
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _advanceAmountController,
                        decoration: const InputDecoration(
                          labelText: 'Advance Amount *',
                          prefixText: "\$",
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            _advanceAmountController.text = '0.00';
                          }
                          final amount = double.tryParse(value ?? '');
                          if (amount == null) {
                            return 'Please enter a valid number';
                          }
                          if (amount < 0) {
                            return 'Please enter a non-negative amount';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // --- Advance Holder Dropdown ---
                      DropdownButtonFormField<Person>(
                        value: _selectedAdvanceHolder,
                        items:
                            _allPeople.map((Person person) {
                              return DropdownMenuItem<Person>(
                                value: person,
                                child: Text(person.name),
                              );
                            }).toList(),
                        // **FIXED onChanged:**
                        onChanged: (Person? newValue) {
                          setState(() {
                            _selectedAdvanceHolder = newValue;
                            // --- Add holder to participants immediately ---
                            if (newValue != null &&
                                !_selectedParticipants.any(
                                  (p) => p.id == newValue.id,
                                )) {
                              _selectedParticipants.add(newValue);
                              // Optionally sort participants after adding
                              _selectedParticipants.sort(
                                (a, b) => a.name.toLowerCase().compareTo(
                                  b.name.toLowerCase(),
                                ),
                              );
                            }
                            // --------------------------------------------
                          });
                        },
                        decoration: const InputDecoration(
                          labelText: 'Advance Holder *',
                          hintText: 'Select who holds the cash',
                          border: OutlineInputBorder(),
                        ),
                        validator:
                            (value) =>
                                value == null
                                    ? 'Please select an advance holder'
                                    : null,
                      ),
                      const SizedBox(height: 20),

                      // --- Participants Multi-Selector ---
                      Text(
                        'Participants *',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      PersonMultiSelector(
                        // Use a key derived from selected participants count + holder ID
                        // to help ensure it rebuilds correctly when state changes.
                        key: ValueKey(
                          '${_selectedParticipants.length}-${_selectedAdvanceHolder?.id}',
                        ),
                        allPeople: _allPeople,
                        initialSelectedPeople:
                            _selectedParticipants, // Pass current state
                        advanceHolder:
                            _selectedAdvanceHolder, // Pass current holder
                        onSelectionChanged: (selected) {
                          // Update local state when selector changes
                          setState(() {
                            _selectedParticipants = selected;
                          });
                        },
                        onAddPerson: _addNewPerson,
                      ),
                      if (_selectedParticipants.isEmpty && !_isDataLoading)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0, left: 8.0),
                          child: Text(
                            'Select at least one participant.',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                              fontSize: 12,
                            ),
                          ),
                        ),

                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
    );
  }
}
