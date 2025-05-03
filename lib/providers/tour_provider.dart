import 'package:flutter/material.dart';
import 'package:btour/database/database_helper.dart'; // Adjusted import if needed
import 'package:btour/models/category.dart';
import 'package:btour/models/expense.dart';
import 'package:btour/models/person.dart';
import 'package:btour/models/tour.dart';
import 'package:flutter/scheduler.dart';

// Basic provider using ChangeNotifier for simplicity
class TourProvider with ChangeNotifier {
  List<Tour> _tours = [];
  List<Person> _people = [];
  List<Category> _categories = [];
  bool _isLoading = false;

  // Keep track of data for the currently viewed tour detail
  Tour? _currentTour;
  List<Person> _currentTourParticipants = [];
  Person? _currentTourAdvanceHolder;
  List<Expense> _currentTourExpenses = [];
  double _currentTourTotalSpent = 0.0;
  Map<int, double> _currentTourPaymentsByPerson =
      {}; // Map<personId, totalPaid>
  Map<int, Person> _peopleMap = {}; // Cache people for quicker lookup by ID

  // --- Getters ---
  List<Tour> get tours => [..._tours]; // Return copies for immutability
  List<Person> get people => [..._people];
  List<Category> get categories => [..._categories];
  bool get isLoading => _isLoading;

  Tour? get currentTour => _currentTour;
  List<Person> get currentTourParticipants => _currentTourParticipants;
  Person? get currentTourAdvanceHolder => _currentTourAdvanceHolder;
  List<Expense> get currentTourExpenses => _currentTourExpenses;
  double get currentTourTotalSpent => _currentTourTotalSpent;
  Map<int, double> get currentTourPaymentsByPerson =>
      _currentTourPaymentsByPerson;
  Map<int, Person> get peopleMap => _peopleMap; // Expose map for lookups

  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  TourProvider() {
    // Load initial data when the provider is created
    print("TourProvider initialized. Fetching all data...");
    _fetchAllData();
  }

  // --- Initialization ---
  Future<void> _fetchAllData() async {
    // Use a single loading indicator for the initial fetch
    _setLoading(true);
    try {
      // Fetch foundational data first
      await Future.wait([
        fetchAllPeople(), // Updates _people and _peopleMap
        fetchAllCategories(), // Updates _categories
      ]);
      // Then fetch tours which might rely on the above
      await fetchAllTours(); // Updates _tours
    } catch (error) {
      print("Error during initial data fetch: $error");
      // Handle error appropriately, maybe set an error state
    } finally {
      _setLoading(false);
    }
  }

  // --- Loading State Management ---
  void _setLoading(bool value) {
    if (_isLoading == value) return; // Avoid redundant notifications
    _isLoading = value;
    // Use addPostFrameCallback to ensure notifyListeners is called safely
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Check state again in case it changed very quickly
      if (WidgetsBinding.instance.schedulerPhase != SchedulerPhase.idle) {
        // If we're somehow still in a frame, wait a microtask
        Future.microtask(() {
          if (_isLoading == value)
            notifyListeners(); // Check again before notifying
        });
      } else {
        // Safe to notify directly
        if (_isLoading == value)
          notifyListeners(); // Check again before notifying
      }
    });
    print("Loading state set to: $_isLoading");
  }

  // --- People Methods ---
  Future<void> fetchAllPeople() async {
    // Usually called during init, no separate loading indicator needed
    _people = await _dbHelper.getAllPeople();
    _peopleMap = {for (var p in _people) p.id!: p};
    print("Fetched ${_people.length} people. Map updated.");
    // Notify if called outside of initial _fetchAllData sequence
    // notifyListeners(); // Covered by _fetchAllData's final setLoading(false)
  }

  Future<Person> addPerson(String name) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError("Person name cannot be empty.");
    }
    // Check if person already exists locally first (more efficient)
    final existingLocal = _people.firstWhere(
      (p) => p.name.toLowerCase() == trimmedName.toLowerCase(),
      orElse: () => Person(id: -1, name: ''),
    ); // Dummy value for not found

    if (existingLocal.id != -1) {
      print("Person '$trimmedName' found locally, returning existing.");
      return existingLocal;
    }

    // Check DB just in case local list is stale
    final existingDb = await _dbHelper.getPersonByName(trimmedName);
    if (existingDb != null) {
      if (!_people.any((p) => p.id == existingDb.id)) {
        _people.add(existingDb);
        _peopleMap[existingDb.id!] = existingDb;
        notifyListeners(); // Notify if added to local list
      }
      print("Person '$trimmedName' found in DB, returning existing.");
      return existingDb;
    }

    // Create new person
    print("Creating new person '$trimmedName'...");
    final newPerson = Person(name: trimmedName);
    final createdPerson = await _dbHelper.createPerson(newPerson);
    _people.add(createdPerson);
    _peopleMap[createdPerson.id!] = createdPerson;
    notifyListeners(); // Notify after adding
    print("Created and added new person: ${createdPerson.id}");
    return createdPerson;
  }

  // --- Category Methods ---
  Future<void> fetchAllCategories() async {
    _categories = await _dbHelper.getAllCategories();
    print("Fetched ${_categories.length} categories.");
    // notifyListeners(); // Covered by _fetchAllData's final setLoading(false)
  }

  Future<Category> addCategory(String name) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError("Category name cannot be empty.");
    }
    // Check local first
    final existingLocal = _categories.firstWhere(
      (c) => c.name.toLowerCase() == trimmedName.toLowerCase(),
      orElse: () => Category(id: -1, name: ''),
    );

    if (existingLocal.id != -1) {
      print("Category '$trimmedName' found locally, returning existing.");
      return existingLocal;
    }
    // Check DB
    final existingDb = await _dbHelper.getCategoryByName(trimmedName);
    if (existingDb != null) {
      if (!_categories.any((c) => c.id == existingDb.id)) {
        _categories.add(existingDb);
        notifyListeners();
      }
      print("Category '$trimmedName' found in DB, returning existing.");
      return existingDb;
    }

    // Create new
    print("Creating new category '$trimmedName'...");
    final newCategory = Category(name: trimmedName);
    final createdCategory = await _dbHelper.createCategory(newCategory);
    _categories.add(createdCategory);
    notifyListeners();
    print("Created and added new category: ${createdCategory.id}");
    return createdCategory;
  }

  // --- Tour Methods ---
  Future<void> fetchAllTours() async {
    // Don't set loading here, let _fetchAllData handle global loading
    _tours = await _dbHelper.getAllTours();
    _sortTours(); // Use helper for sorting
    print("Fetched and sorted ${_tours.length} tours.");
    // notifyListeners(); // Covered by _fetchAllData's final setLoading(false)
  }

  // Helper to sort tours consistently
  void _sortTours() {
    _tours.sort((a, b) {
      // Active tours come first
      if (a.status != TourStatus.Ended && b.status == TourStatus.Ended)
        return -1;
      if (a.status == TourStatus.Ended && b.status != TourStatus.Ended)
        return 1;
      // Within same status group, sort by start date descending
      return b.startDate.compareTo(a.startDate);
    });
  }

  Future<Tour> addTour(Tour tour, List<int> participantIds) async {
    _setLoading(true);
    print("Adding new tour: ${tour.name}");
    final newTour = await _dbHelper.createTour(tour, participantIds);
    // Add locally and re-sort
    _tours.add(newTour);
    _sortTours();
    print("Tour added and list re-sorted.");
    _setLoading(false); // Notifies listeners
    return newTour;
  }

  // General update method (e.g., used by edit screen)
  Future<void> updateTour(Tour tour, List<int> participantIds) async {
    if (tour.id == null) throw ArgumentError("Tour must have an ID to update.");
    _setLoading(true);
    print("Updating tour ID: ${tour.id}");
    await _dbHelper.updateTour(tour, participantIds);

    // Update local list
    final index = _tours.indexWhere((t) => t.id == tour.id);
    if (index != -1) {
      _tours[index] = tour; // Replace with the updated object
      _sortTours(); // Re-sort as status or date might have changed
      print("Updated tour in _tours list and re-sorted.");
    } else {
      print("Warning: Updated tour ${tour.id} not found in _tours list.");
    }

    // If this is the currently viewed tour, refresh its details fully
    if (_currentTour?.id == tour.id) {
      print("Updated tour is the current one. Refreshing details...");
      // Update _currentTour immediately so the UI can potentially reflect
      // basic changes even before full refresh completes.
      _currentTour = tour;
      // Must notify here if we want the UI to potentially update before fetchTourDetails finishes
      notifyListeners();
      // Now fetch all associated data again. fetchTourDetails handles setLoading(false)
      await fetchTourDetails(tour.id!);
    } else {
      // If not the current tour, just turn off loading and notify
      _setLoading(false);
    }
  }

  Future<void> deleteTour(int tourId) async {
    _setLoading(true);
    print("Deleting tour ID: $tourId");
    await _dbHelper.deleteTour(tourId);
    _tours.removeWhere((t) => t.id == tourId);
  

    // If the deleted tour was the current one, clear details
    if (_currentTour?.id == tourId) {
      print("Deleted tour was the current one. Clearing details.");
      _clearCurrentTourDetails(); // Clear state but don't notify yet
    }
    _setLoading(false); // This will notify listeners
  }

  // --- Corrected Status Change Method ---
  Future<void> changeTourStatus(
    int tourId,
    TourStatus newStatus, {
    DateTime? endDate, // Optional end date if setting to Ended
  }) async {
    _setLoading(true);
    print("Attempting to change status for tour $tourId to $newStatus");

    // Find the tour in the main list or use currentTour if available
    final tourIndex = _tours.indexWhere((t) => t.id == tourId);
    Tour? tourToUpdate =
        (tourIndex != -1)
            ? _tours[tourIndex]
            : ((_currentTour?.id == tourId) ? _currentTour : null);

    if (tourToUpdate == null) {
      print("Error: Tour with ID $tourId not found for status change.");
      _setLoading(false);
      return;
    }
    print(
      "Found tour to update: ${tourToUpdate.name}, Current Status: ${tourToUpdate.status}",
    );

    // Determine the end date based on the new status
    DateTime? finalEndDate;
    bool clearEndDateFlag =
        false; // Needed if DB schema expects null for clearing
    if (newStatus == TourStatus.Ended) {
      // Set end date if ending: use provided, existing, or now
      finalEndDate = endDate ?? tourToUpdate.endDate ?? DateTime.now();
      print("Setting finalEndDate to: $finalEndDate");
    } else if (tourToUpdate.status == TourStatus.Ended &&
        newStatus != TourStatus.Ended) {
      // If moving away from Ended status, explicitly clear the end date
      clearEndDateFlag =
          true; // Flag might be needed for DB helper if it doesn't auto-null
      finalEndDate = null; // Set to null for the updated object state
      print("Clearing finalEndDate (reopening).");
    } else {
      // Keep existing end date if not ending or reopening from non-ended state
      finalEndDate = tourToUpdate.endDate;
      print("Keeping existing finalEndDate: $finalEndDate");
    }

    // Create the updated tour object for state and DB
    Tour updatedTourObject = tourToUpdate.copy(
      status: newStatus,
      endDate: finalEndDate,
      // Pass clearEndDate flag if your DB method needs it, otherwise it's just for the object state
      // clearEndDate: clearEndDateFlag,
    );
    print(
      "Created updatedTourObject with status: ${updatedTourObject.status}, endDate: ${updatedTourObject.endDate}",
    );

    try {
      // Fetch participant IDs (still required by DB helper update method)
      // This could be optimized if updateTour didn't always require them
      print("Fetching participants for update call...");
      List<Person> participants = await _dbHelper.getTourParticipants(tourId);
      List<int> participantIds = participants.map((p) => p.id!).toList();
      print("Fetched ${participantIds.length} participant IDs.");

      // --- Call DB Helper Directly ---
      print("Calling _dbHelper.updateTour...");
      await _dbHelper.updateTour(updatedTourObject, participantIds);
      print("DB update successful for tour $tourId status to $newStatus");

      // --- Update Local State ---
      // 1. Update the main list (_tours)
      if (tourIndex != -1) {
        _tours[tourIndex] = updatedTourObject;
        _sortTours(); // Re-sort the main list
        print("Updated tour in _tours list at index $tourIndex and re-sorted.");
      } else {
        print(
          "Warning: Tour $tourId not found in _tours list after DB update.",
        );
        // Consider fetching all tours again if this happens unexpectedly
        // await fetchAllTours();
      }

      // 2. Update the _currentTour if it's the one being modified
      if (_currentTour?.id == tourId) {
        _currentTour =
            updatedTourObject; // Update the detailed view object *directly*
        print("Updated _currentTour object directly with new status.");
      }

      _setLoading(false); // This calls notifyListeners
    } catch (e) {
      print("Error changing tour status for $tourId: $e");
      _setLoading(false); // Ensure loading is turned off on error
      // Rethrow or handle as needed
      // throw Exception("Failed to change tour status: $e");
    }
  }

  // --- Current Tour Detail Methods ---
  void _clearCurrentTourDetails() {
    _currentTour = null;
    _currentTourParticipants = [];
    _currentTourAdvanceHolder = null;
    _currentTourExpenses = [];
    _currentTourTotalSpent = 0.0;
    _currentTourPaymentsByPerson = {};
    print("Cleared current tour details.");
  }

  Future<void> fetchTourDetails(int tourId) async {
    _setLoading(true);
    print("Fetching details for tour ID: $tourId");
    // It's often better to clear *before* fetching to avoid briefly showing old data
    // Only clear if the ID is different from the current tour, maybe?
    if (_currentTour?.id != tourId) {
      _clearCurrentTourDetails();
      // Don't notify here, wait for final setLoading
    }

    Tour? fetchedTour;
    List<Person> fetchedParticipants = [];
    Person? fetchedHolder;
    List<Expense> fetchedExpenses = [];
    double fetchedTotalSpent = 0.0;
    Map<int, double> fetchedPayments = {};

    try {
      fetchedTour = await _dbHelper.getTour(tourId);
      print("Fetched main tour data: ${fetchedTour?.name ?? 'Not Found'}");

      if (fetchedTour != null) {
        print("Fetching associated details...");
        // Fetch related data in parallel
        final results = await Future.wait([
          _dbHelper.getTourParticipants(tourId),
          _dbHelper.getPerson(fetchedTour.advanceHolderPersonId),
          _dbHelper.getExpensesForTour(tourId),
          _dbHelper.getTotalExpensesForTour(tourId),
          _dbHelper.getPaymentsPerPersonForTour(tourId),
        ]);

        fetchedParticipants = results[0] as List<Person>;
        fetchedHolder = results[1] as Person?;
        fetchedExpenses = results[2] as List<Expense>;
        fetchedTotalSpent = results[3] as double;
        fetchedPayments = results[4] as Map<int, double>;
        print(
          "Fetched Details: ${fetchedParticipants.length} participants, holder: ${fetchedHolder?.name}, ${fetchedExpenses.length} expenses, total spent: $fetchedTotalSpent, payments map size: ${fetchedPayments.length}",
        );
      } else {
        print("Tour with ID $tourId not found in database.");
        _clearCurrentTourDetails(); // Ensure details are cleared if tour not found
      }
    } catch (e) {
      print("Error fetching tour details for $tourId: $e");
      _clearCurrentTourDetails(); // Clear details on error
      // Optionally set an error state
    } finally {
      // Update state *after* all async operations, inside finally
      _currentTour = fetchedTour;
      _currentTourParticipants = fetchedParticipants;
      _currentTourAdvanceHolder = fetchedHolder;
      _currentTourExpenses = fetchedExpenses;
      _currentTourTotalSpent = fetchedTotalSpent;
      _currentTourPaymentsByPerson = fetchedPayments;
      print(
        "Finished fetching details for tour $tourId. Setting loading false.",
      );
      _setLoading(false); // Notifies listeners
    }
  }

  // --- Expense Methods (relative to current tour) ---
  Future<Expense> addExpenseToCurrentTour(
    Expense expense,
    List<int> attendeeIds,
    List<ExpensePayment> payments,
  ) async {
    if (_currentTour == null) {
      throw Exception("No current tour selected to add expense to.");
    }
    print("Adding expense to tour ${_currentTour!.id}: ${expense.description}");
    _setLoading(true);
    final expenseToAdd = expense.copy(tourId: _currentTour!.id);
    final newExpense = await _dbHelper.createExpense(
      expenseToAdd,
      attendeeIds,
      payments,
    );
    print(
      "Expense created in DB (ID: ${newExpense.id}). Refreshing tour data...",
    );

    await _refreshCurrentTourDataOnExpenseChange();
    print("Tour data refreshed after adding expense.");

    _setLoading(false); // Notify *after* refresh is complete

    // Find the newly added expense in the refreshed list to return it
    final addedExpense = _currentTourExpenses.firstWhere(
      (e) => e.id == newExpense.id,
      orElse:
          () => newExpense, // Fallback (shouldn't be needed if refresh works)
    );
    return addedExpense;
  }

  Future<void> updateExpenseInCurrentTour(
    Expense expense,
    List<int> attendeeIds,
    List<ExpensePayment> payments,
  ) async {
    if (_currentTour == null || expense.id == null) {
      throw Exception(
        "Cannot update expense without a current tour or expense ID.",
      );
    }
    print("Updating expense ${expense.id} for tour ${_currentTour!.id}");
    _setLoading(true);
    await _dbHelper.updateExpense(expense, attendeeIds, payments);
    print("Expense updated in DB. Refreshing tour data...");

    await _refreshCurrentTourDataOnExpenseChange();
    print("Tour data refreshed after updating expense.");

    _setLoading(false); // Notify *after* refresh
  }

  Future<void> deleteExpenseFromCurrentTour(int expenseId) async {
    if (_currentTour == null) {
      throw Exception("No current tour selected to delete expense from.");
    }
    print("Deleting expense $expenseId from tour ${_currentTour!.id}");
    _setLoading(true);
    await _dbHelper.deleteExpense(expenseId);
    print("Expense deleted from DB. Refreshing tour data...");

    await _refreshCurrentTourDataOnExpenseChange();
    print("Tour data refreshed after deleting expense.");

    _setLoading(false); // Notify *after* refresh
  }

  // Helper to refresh necessary tour details after expense CRUD
  // This should NOT call setLoading or notifyListeners itself.
  Future<void> _refreshCurrentTourDataOnExpenseChange() async {
    if (_currentTour == null) return;
    print("Refreshing expense-related data for tour ${_currentTour!.id}...");
    try {
      // Refetch only data potentially affected by expense changes
      final results = await Future.wait([
        _dbHelper.getExpensesForTour(_currentTour!.id!),
        _dbHelper.getTotalExpensesForTour(_currentTour!.id!),
        _dbHelper.getPaymentsPerPersonForTour(_currentTour!.id!),
      ]);
      // Update the provider's state directly
      _currentTourExpenses = results[0] as List<Expense>;
      _currentTourTotalSpent = results[1] as double;
      _currentTourPaymentsByPerson = results[2] as Map<int, double>;
      print(
        "Refreshed: ${_currentTourExpenses.length} expenses, total spent: $_currentTourTotalSpent, payments map size: ${_currentTourPaymentsByPerson.length}",
      );
    } catch (e) {
      print(
        "Error during _refreshCurrentTourDataOnExpenseChange for tour ${_currentTour!.id}: $e",
      );
      // Decide how to handle errors - maybe clear the fields?
      // _currentTourExpenses = [];
      // _currentTourTotalSpent = 0.0;
      // _currentTourPaymentsByPerson = {};
    }
  }

  // --- Helper Methods ---
  String getPersonNameById(int personId) {
    return _peopleMap[personId]?.name ?? 'Unknown [$personId]';
  }

  String getCategoryNameById(int categoryId) {
    // More efficient lookup using map if categories are numerous, otherwise firstWhere is fine
    final category = _categories.firstWhere(
      (cat) => cat.id == categoryId,
      orElse: () => const Category(id: -1, name: 'Unknown'), // Default fallback
    );
    return category.name;
  }

  // Method used by TourCard or other places needing total expenses without full detail fetch
  Future<double> getTotalExpensesForTour(int tourId) async {
    // If it's the currently viewed tour, return the cached value for efficiency
    if (_currentTour?.id == tourId) {
      return _currentTourTotalSpent;
    }
    // Otherwise, fetch fresh from DB
    return await _dbHelper.getTotalExpensesForTour(tourId);
  }
}
