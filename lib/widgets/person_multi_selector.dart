// FILE: lib/widgets/person_multi_selector.dart
import 'package:flutter/material.dart';
import 'package:btour/models/person.dart';
import 'package:collection/collection.dart'; // Import for firstWhereOrNull and ListEquality

// Simple Multi-selector using Chips and an Add button/dialog
class PersonMultiSelector extends StatefulWidget {
  final List<Person> allPeople;
  final List<Person> initialSelectedPeople;
  final Person? advanceHolder; // To ensure holder chip isn't deletable easily
  final ValueChanged<List<Person>> onSelectionChanged;
  final Future<Person?> Function(String name)?
  onAddPerson; // Callback to add new person

  const PersonMultiSelector({
    super.key,
    required this.allPeople,
    required this.initialSelectedPeople,
    this.advanceHolder,
    required this.onSelectionChanged,
    this.onAddPerson,
  });

  @override
  State<PersonMultiSelector> createState() => _PersonMultiSelectorState();
}

class _PersonMultiSelectorState extends State<PersonMultiSelector> {
  late List<Person> _selectedPeople;
  final TextEditingController _addPersonController =
      TextEditingController(); // For Add dialog
  final FocusNode _addPersonFocusNode = FocusNode(); // To focus text field

  @override
  void initState() {
    super.initState();
    // Copy initial list to allow modification, ensure uniqueness just in case
    _selectedPeople = widget.initialSelectedPeople.toSet().toList();
    // Ensure holder is added initially if provided and not already present
    if (widget.advanceHolder != null &&
        !_selectedPeople.any((p) => p.id == widget.advanceHolder!.id)) {
      _selectedPeople.add(widget.advanceHolder!);
    }
    _sortSelectedPeople();
  }

  // Update selected people if the initial list or advance holder changes externally
  @override
  void didUpdateWidget(PersonMultiSelector oldWidget) {
    super.didUpdateWidget(oldWidget);

    bool initialListChanged =
        !const ListEquality().equals(
          widget.initialSelectedPeople,
          oldWidget.initialSelectedPeople,
        );
    bool holderChanged = widget.advanceHolder != oldWidget.advanceHolder;
    bool allPeopleListChanged =
        !const ListEquality().equals(widget.allPeople, oldWidget.allPeople);

    // If the source list of all people changes, we might need to refresh derived state
    if (allPeopleListChanged) {
      // This might be needed if the available options in the dialog need immediate update,
      // but generally the build method using the new `widget.allPeople` should handle it.
      // Consider adding a setState here if dialog options seem stale after adding a person externally.
      // WidgetsBinding.instance.addPostFrameCallback((_) {
      //    if (mounted) setState(() {});
      // });
    }

    // --- FIX: Use addPostFrameCallback for state changes initiated from didUpdateWidget ---

    if (initialListChanged) {
      // If the initial list from parent changed, update internal state *after* the build phase
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            // Re-evaluate based on the *current* widget props inside the callback
            _selectedPeople = widget.initialSelectedPeople.toSet().toList();
            // Ensure holder is still included after reset if currently set
            if (widget.advanceHolder != null &&
                !_selectedPeople.any((p) => p.id == widget.advanceHolder!.id)) {
              _selectedPeople.add(widget.advanceHolder!);
            }
            _sortSelectedPeople();
            // Do we need to notify parent here? Probably not, as the initial list change came *from* parent.
          });
        }
      });
    }

    // Ensure advance holder chip appears (and is added to state) if holder changes and isn't already selected
    if (holderChanged &&
        widget.advanceHolder != null &&
        !_selectedPeople.any((p) => p.id == widget.advanceHolder!.id)) {
      // Schedule the state update for after the build frame
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          // Check mounted again inside callback
          setState(() {
            _selectedPeople.add(widget.advanceHolder!);
            _sortSelectedPeople();
            // Notify parent about the addition of the holder, as this change was triggered by holder selection
            widget.onSelectionChanged(_selectedPeople);
          });
        }
      });
    }
    // Note: If holder is REMOVED (becomes null), the chip automatically becomes deletable in build().
    // No explicit removal from _selectedPeople needed here unless required by specific logic.
  }

  void _sortSelectedPeople() {
    _selectedPeople.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
  }

  @override
  void dispose() {
    _addPersonController.dispose();
    _addPersonFocusNode.dispose();
    super.dispose();
  }

  void _showAddPersonDialog() {
    // Check mounted before showing dialog
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        Person? selectedPersonFromDropdown; // Person selected from dropdown
        String? errorText; // For validation in dialog

        // Filter list for dropdown: exclude already selected people
        // IMPORTANT: Use widget.allPeople to get the latest list from the parent
        final availablePeople =
            widget.allPeople
                .where(
                  (p) =>
                      p.id != null &&
                      !_selectedPeople.any((sp) => sp.id == p.id),
                ) // Ensure person has ID and not already selected
                .toList();
        availablePeople.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        ); // Sort dropdown list

        return StatefulBuilder(
          // Use StatefulBuilder for dialog state
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add Participant'),
              contentPadding: const EdgeInsets.fromLTRB(
                24.0,
                20.0,
                24.0,
                0.0,
              ), // Adjust padding
              content: SingleChildScrollView(
                // Allow content to scroll if needed
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- Dropdown for existing ---
                    if (availablePeople.isNotEmpty)
                      DropdownButton<Person>(
                        value: selectedPersonFromDropdown,
                        hint: const Text('Select existing person'),
                        isExpanded: true,
                        items:
                            availablePeople.map((Person person) {
                              return DropdownMenuItem<Person>(
                                value: person,
                                child: Text(person.name),
                              );
                            }).toList(),
                        onChanged: (Person? newValue) {
                          setDialogState(() {
                            // Update dialog state
                            selectedPersonFromDropdown = newValue;
                            _addPersonController
                                .clear(); // Clear text field if dropdown used
                            errorText = null; // Clear error on valid selection
                          });
                        },
                      ),
                    if (availablePeople.isNotEmpty &&
                        widget.onAddPerson != null)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: Center(child: Text("OR")),
                      ),

                    // --- Text field for new person ---
                    if (widget.onAddPerson != null)
                      TextField(
                        controller: _addPersonController,
                        focusNode: _addPersonFocusNode, // Assign focus node
                        decoration: InputDecoration(
                          labelText: 'Add New Person Name',
                          errorText: errorText, // Show validation error
                        ),
                        textCapitalization: TextCapitalization.words,
                        onChanged: (value) {
                          // Clear dropdown selection if user starts typing a new name
                          if (value.isNotEmpty &&
                              selectedPersonFromDropdown != null) {
                            setDialogState(() {
                              selectedPersonFromDropdown = null;
                              errorText = null; // Clear error
                            });
                          } else if (value.isEmpty) {
                            setDialogState(() {
                              errorText = null;
                            }); // Clear error if field cleared
                          }
                        },
                      ),
                    // Show message if no options available
                    if (availablePeople.isEmpty && widget.onAddPerson == null)
                      const Text(
                        "All available people are already selected.",
                        style: TextStyle(color: Colors.grey),
                      ),
                    if (availablePeople.isEmpty && widget.onAddPerson != null)
                      const Text(
                        "All existing people selected. Enter a new name above.",
                        style: TextStyle(color: Colors.grey),
                      ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () {
                    _addPersonController.clear(); // Clear controller on cancel
                    Navigator.of(context).pop();
                  },
                ),
                TextButton(
                  child: const Text('Add'),
                  onPressed: () async {
                    final String newName = _addPersonController.text.trim();

                    // --- Validation ---
                    if (selectedPersonFromDropdown == null && newName.isEmpty) {
                      setDialogState(() {
                        errorText = 'Please select or enter a name';
                      });
                      return; // Prevent closing
                    }
                    // Check if new name already exists in allPeople (case-insensitive)
                    // Use widget.allPeople for the check
                    final existingPerson = widget.allPeople.firstWhereOrNull(
                      (p) => p.name.toLowerCase() == newName.toLowerCase(),
                    );

                    if (newName.isNotEmpty && existingPerson != null) {
                      // Name exists, check if they are already selected
                      if (_selectedPeople.any(
                        (p) => p.id == existingPerson.id,
                      )) {
                        setDialogState(() {
                          errorText =
                              '"${existingPerson.name}" is already selected';
                        });
                      } else {
                        // Person exists but isn't selected, add them
                        _addSelectedPerson(existingPerson);
                        _addPersonController.clear();
                        Navigator.of(context).pop(); // Close dialog
                      }
                      return; // Prevent further action
                    }
                    // --- End Validation ---

                    // --- Add Logic ---
                    if (selectedPersonFromDropdown != null) {
                      // Add selected existing person
                      _addSelectedPerson(selectedPersonFromDropdown!);
                      _addPersonController.clear();
                      Navigator.of(context).pop();
                    } else if (newName.isNotEmpty &&
                        widget.onAddPerson != null) {
                      // Try adding the new person via the callback (which handles DB interaction)
                      // Show loading within dialog? Or just close and let screen handle indicator?
                      // For simplicity, close dialog and let screen show loading.
                      Navigator.of(context).pop(); // Close dialog first
                      final addedPerson = await widget.onAddPerson!(newName);
                      if (addedPerson != null) {
                        // Check mounted before calling _addSelectedPerson
                        if (mounted) {
                          _addSelectedPerson(
                            addedPerson,
                          ); // Add the newly created/found person to UI
                        }
                      }
                      // Don't clear controller here, might be needed if add failed and user wants to retry
                      // Error handling for addPerson is done in the callback provider/screen
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    ).then((_) {
      // Ensure text field loses focus when dialog is closed, check mounted
      if (mounted) {
        _addPersonFocusNode.unfocus();
      }
    });
  }

  void _addSelectedPerson(Person person) {
    // Check mounted before setState
    if (!mounted) return;

    // Add person if not already selected
    if (!_selectedPeople.any((p) => p.id == person.id)) {
      setState(() {
        _selectedPeople.add(person);
        _sortSelectedPeople(); // Sort after adding
      });
      widget.onSelectionChanged(_selectedPeople); // Notify parent
    } else {
      // Optionally show message if already added (e.g., from existing check)
      // Check mounted before showing SnackBar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${person.name} is already selected.'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _removeSelectedPerson(Person person) {
    // Check mounted before setState or showing SnackBar
    if (!mounted) return;

    // Prevent removing the designated advance holder
    if (widget.advanceHolder != null && person.id == widget.advanceHolder!.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${person.name} is the Advance Holder and cannot be removed here.',
          ),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }
    setState(() {
      _selectedPeople.removeWhere((p) => p.id == person.id);
      // No need to re-sort on removal
    });
    widget.onSelectionChanged(_selectedPeople); // Notify parent
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 50), // Ensure minimum height
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade400),
        borderRadius: BorderRadius.circular(5.0),
      ),
      child: Wrap(
        spacing: 6.0, // Horizontal space between chips
        runSpacing: 0.0, // Vertical space between lines of chips
        crossAxisAlignment: WrapCrossAlignment.center, // Align chips vertically
        children: [
          ..._selectedPeople.map((person) {
            // Ensure person has an ID before checking against holder
            final bool isHolder =
                widget.advanceHolder != null &&
                person.id != null &&
                person.id == widget.advanceHolder!.id;
            return Chip(
              key: ValueKey(
                'person_chip_${person.id}',
              ), // Add key for stability
              label: Text(person.name),
              // Add visual cue for advance holder? e.g., different color or icon
              backgroundColor: isHolder ? Colors.blue.shade100 : null,
              labelStyle: TextStyle(
                fontWeight: isHolder ? FontWeight.bold : FontWeight.normal,
                // color: isHolder ? Colors.blue.shade900 : null,
              ),
              deleteIconColor:
                  isHolder
                      ? Colors.grey.shade300
                      : Colors.grey.shade700, // Dim delete icon for holder
              onDeleted:
                  isHolder
                      ? null
                      : () => _removeSelectedPerson(
                        person,
                      ), // Disable delete for holder
            );
          }),
          // Only show Add button if callback is provided
          if (widget.onAddPerson != null)
            InkWell(
              // Use InkWell for larger tap area
              onTap: _showAddPersonDialog,
              borderRadius: BorderRadius.circular(
                16,
              ), // Match chip shape for ripple
              child: const Chip(
                // Use a chip for consistent styling
                avatar: Icon(
                  Icons.add_circle_outline,
                  size: 18,
                  color: Colors.blue,
                ),
                label: Text('Add Person'),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
            ),
        ],
      ),
    );
  }
}
