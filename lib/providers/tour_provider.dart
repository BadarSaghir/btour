import 'package:flutter/material.dart';
import 'package:btour/database/database_helper.dart';
import 'package:btour/models/category.dart';
import 'package:btour/models/expense.dart';
import 'package:btour/models/person.dart';
import 'package:btour/models/tour.dart';

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

  List<Tour> get tours => [..._tours]; // Return copies
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
    _fetchAllData();
  }

  Future<void> _fetchAllData() async {
    _setLoading(true);
    await fetchAllPeople(); // Fetch people first
    await fetchAllCategories();
    await fetchAllTours();
    _setLoading(false);
  }

  void _setLoading(bool value) {
    // Avoid unnecessary notifications if state hasn't changed
    if (_isLoading == value) return;
    _isLoading = value;
    notifyListeners();
  }

  // --- People Methods ---
  Future<void> fetchAllPeople() async {
    _people = await _dbHelper.getAllPeople();
    // Update people map cache
    _peopleMap = {for (var p in _people) p.id!: p};
    notifyListeners();
  }

  Future<Person> addPerson(String name) async {
    final existing = await _dbHelper.getPersonByName(name.trim());
    if (existing != null) {
      // Optionally update local list if somehow out of sync, but usually just return existing
      if (!_people.any((p) => p.id == existing.id)) {
        _people.add(existing);
        _peopleMap[existing.id!] = existing; // Update cache
        notifyListeners();
      }
      return existing; // Return existing person
    }

    // Create new person
    final newPerson = Person(name: name.trim());
    final createdPerson = await _dbHelper.createPerson(newPerson);
    _people.add(createdPerson);
    _peopleMap[createdPerson.id!] = createdPerson; // Update cache
    notifyListeners();
    return createdPerson;
  }

  // --- Category Methods ---
  Future<void> fetchAllCategories() async {
    _categories = await _dbHelper.getAllCategories();
    notifyListeners();
  }

  Future<Category> addCategory(String name) async {
    final existing = await _dbHelper.getCategoryByName(name.trim());
    if (existing != null) {
      if (!_categories.any((c) => c.id == existing.id)) {
        _categories.add(existing);
        notifyListeners();
      }
      return existing;
    }
    final newCategory = Category(name: name.trim());
    final createdCategory = await _dbHelper.createCategory(newCategory);
    _categories.add(createdCategory);
    notifyListeners();
    return createdCategory;
  }

  // --- Tour Methods ---
  Future<void> fetchAllTours() async {
    _setLoading(true); // Indicate loading started
    _tours = await _dbHelper.getAllTours();
    // Ensure list is sorted (e.g., active first, then by date)
    _tours.sort((a, b) {
      if (a.status != TourStatus.Ended && b.status == TourStatus.Ended)
        return -1;
      if (a.status == TourStatus.Ended && b.status != TourStatus.Ended)
        return 1;
      return b.startDate.compareTo(
        a.startDate,
      ); // Sort by date descending otherwise
    });
    _setLoading(false); // Indicate loading finished (this notifies listeners)
  }

  Future<Tour> addTour(Tour tour, List<int> participantIds) async {
    _setLoading(true);
    final newTour = await _dbHelper.createTour(tour, participantIds);
    // Fetch again to maintain sort order and reflect DB state
    await fetchAllTours();
    // _tours.insert(0, newTour); // Add to beginning might break sort order
    _setLoading(false);
    return newTour;
  }

  Future<void> updateTour(Tour tour, List<int> participantIds) async {
    _setLoading(true);
    await _dbHelper.updateTour(tour, participantIds);
    final index = _tours.indexWhere((t) => t.id == tour.id);
    if (index != -1) {
      _tours[index] = tour; // Update local list immediately for responsiveness
      // Re-sort potentially needed if status/date changed affecting order
      _tours.sort((a, b) {
        if (a.status != TourStatus.Ended && b.status == TourStatus.Ended)
          return -1;
        if (a.status == TourStatus.Ended && b.status != TourStatus.Ended)
          return 1;
        return b.startDate.compareTo(a.startDate);
      });
    }
    // If this is the current tour, update its details too
    if (_currentTour?.id == tour.id) {
      await fetchTourDetails(tour.id!); // Refetch details
    } else {
      _setLoading(
        false,
      ); // Ensure loading state is reset if details weren't refetched
    }
    // fetchTourDetails calls setLoading(false) at the end, so no need here if called
  }

  Future<void> deleteTour(int tourId) async {
    _setLoading(true);
    await _dbHelper.deleteTour(tourId);
    _tours.removeWhere((t) => t.id == tourId);
    // If the deleted tour was the current one, clear details
    if (_currentTour?.id == tourId) {
      _clearCurrentTourDetails();
    }
    _setLoading(false);
  }

  Future<void> changeTourStatus(
    int tourId,
    TourStatus newStatus, {
    DateTime? endDate,
  }) async {
    _setLoading(true); // Indicate loading
    final tourIndex = _tours.indexWhere((t) => t.id == tourId);
    if (tourIndex == -1) {
      _setLoading(false);
      return;
    }

    Tour currentTourState = _tours[tourIndex];
    Tour updatedTour = currentTourState.copy(
      status: newStatus,
      // Only set endDate if status is Ended AND it wasn't already set (or use provided)
      endDate:
          newStatus == TourStatus.Ended
              ? (endDate ?? currentTourState.endDate ?? DateTime.now())
              : currentTourState.endDate,
      // Explicitly clear end date if moving away from Ended status
      clearEndDate:
          currentTourState.status == TourStatus.Ended &&
          newStatus != TourStatus.Ended,
    );

    // Fetch participants to pass to updateTour (DB method requires it)
    List<Person> participants = await _dbHelper.getTourParticipants(tourId);
    List<int> participantIds = participants.map((p) => p.id!).toList();

    // Update using the general update method which handles DB and local state
    await updateTour(updatedTour, participantIds);
    // updateTour handles setLoading(false) and notifications
  }

  // --- Current Tour Detail Methods ---
  void _clearCurrentTourDetails() {
    _currentTour = null;
    _currentTourParticipants = [];
    _currentTourAdvanceHolder = null;
    _currentTourExpenses = [];
    _currentTourTotalSpent = 0.0;
    _currentTourPaymentsByPerson = {};
    // Don't notify here, let the caller decide (e.g., fetchTourDetails or deleteTour)
  }

  Future<void> fetchTourDetails(int tourId) async {
    _setLoading(true);
    _clearCurrentTourDetails(); // Clear previous details first

    _currentTour = await _dbHelper.getTour(tourId);

    if (_currentTour != null) {
      // Fetch related data in parallel for efficiency
      final results = await Future.wait([
        _dbHelper.getTourParticipants(tourId),
        _dbHelper.getPerson(_currentTour!.advanceHolderPersonId),
        _dbHelper.getExpensesForTour(tourId),
        _dbHelper.getTotalExpensesForTour(tourId),
        _dbHelper.getPaymentsPerPersonForTour(tourId),
        // Removed pre-loading expense details here for simplicity
      ]);

      _currentTourParticipants = results[0] as List<Person>;
      _currentTourAdvanceHolder = results[1] as Person?;
      _currentTourExpenses = results[2] as List<Expense>;
      _currentTourTotalSpent = results[3] as double;
      _currentTourPaymentsByPerson = results[4] as Map<int, double>;
    }
    // Don't clear again if not found, _clearCurrentTourDetails was called at start
    _setLoading(false); // Notifies listeners
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
    _setLoading(true);
    // Ensure the expense has the correct tourId
    final expenseToAdd = expense.copy(tourId: _currentTour!.id);
    final newExpense = await _dbHelper.createExpense(
      expenseToAdd,
      attendeeIds,
      payments,
    );

    // Refresh current tour data silently (don't show global loading indicator again)
    await _refreshCurrentTourDataOnExpenseChange();
    _setLoading(false); // Set loading false after refresh is done

    // Find the newly added expense in the refreshed list to return it
    final addedExpense = _currentTourExpenses.firstWhere(
      (e) => e.id == newExpense.id,
      orElse: () => newExpense,
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
    _setLoading(true);
    await _dbHelper.updateExpense(expense, attendeeIds, payments);
    // Refresh current tour data silently
    await _refreshCurrentTourDataOnExpenseChange();
    _setLoading(false);
  }

  Future<void> deleteExpenseFromCurrentTour(int expenseId) async {
    if (_currentTour == null) {
      throw Exception("No current tour selected to delete expense from.");
    }
    _setLoading(true);
    await _dbHelper.deleteExpense(expenseId);
    // Refresh current tour data silently
    await _refreshCurrentTourDataOnExpenseChange();
    _setLoading(false);
  }

  // Helper to refresh necessary tour details after expense CRUD without full page reload indicator
  Future<void> _refreshCurrentTourDataOnExpenseChange() async {
    if (_currentTour == null) return;
    // Refetch only data affected by expense changes
    final results = await Future.wait([
      _dbHelper.getExpensesForTour(_currentTour!.id!),
      _dbHelper.getTotalExpensesForTour(_currentTour!.id!),
      _dbHelper.getPaymentsPerPersonForTour(_currentTour!.id!),
    ]);
    _currentTourExpenses = results[0] as List<Expense>;
    _currentTourTotalSpent = results[1] as double;
    _currentTourPaymentsByPerson = results[2] as Map<int, double>;
    // No need to notify here, the main methods (add/update/delete expense) will handle it
  }

  // --- Helper to get Person Name from ID ---
  String getPersonNameById(int personId) {
    return _peopleMap[personId]?.name ?? 'Unknown Person [$personId]';
  }

  // **FIX:** Add this public method for TourCard to use
  Future<double> getTotalExpensesForTour(int tourId) async {
    return await _dbHelper.getTotalExpensesForTour(tourId);
  }

  // --- Helper to get Category Name from ID ---
  String getCategoryNameById(int categoryId) {
    final category = _categories.firstWhere(
      (cat) => cat.id == categoryId,
      orElse: () => const Category(id: -1, name: 'Unknown'),
    );
    return category.name;
  }
}
