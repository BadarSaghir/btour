import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:btour/models/tour.dart'; // Needed for TourStatus enum access
import 'package:btour/providers/tour_provider.dart';
import 'package:btour/screens/add_edit_expense_screen.dart';
import 'package:btour/screens/add_edit_tour_screen.dart';
import 'package:btour/widgets/expense_list_item.dart';
import 'package:collection/collection.dart'; // For firstWhereOrNull if needed elsewhere

class TourDetailScreen extends StatelessWidget {
  // Removed tourId constructor - we rely on the provider's _currentTour
  const TourDetailScreen({super.key});

  // If you were fetching based on ID passed via constructor, you'd do this:
  // @override
  // void initState() {
  //   super.initState();
  //   // Fetch details when the screen initializes if using route arguments
  //   // Use addPostFrameCallback to avoid calling provider during build
  //   WidgetsBinding.instance.addPostFrameCallback((_) {
  //     Provider.of<TourProvider>(context, listen: false).fetchTourDetails(widget.tourId);
  //   });
  // }

  @override
  Widget build(BuildContext context) {
    // Listen to provider changes to update the UI
    // Use watch for automatic rebuilding when notifyListeners is called
    final tourProvider = Provider.of<TourProvider>(context);
    final tour = tourProvider.currentTour; // Get the currently loaded tour
    final currencyFormat = NumberFormat.currency(locale: 'en_US', symbol: "\$");

    // Handle loading state BEFORE accessing tour details
    // Check if we are loading AND currentTour is still null (initial load for this detail screen)
    if (tourProvider.isLoading && tour == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Loading Tour...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Handle case where loading finished but tour is still null (e.g., deleted or error)
    if (tour == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Error'),
          leading: IconButton(
            // Add back button manually if needed
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Tour not found or could not be loaded. It might have been deleted.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
          ),
        ),
      );
    }

    // --- Tour object is available, build the main UI ---

    // Calculate remaining amount based on current provider state
    final remainingAmount =
        tour.advanceAmount - tourProvider.currentTourTotalSpent;

    return DefaultTabController(
      length: 3, // Overview, Expenses, Report
      child: Scaffold(
        appBar: AppBar(
          title: Text(tour.name, overflow: TextOverflow.ellipsis),
          actions: [
            // Edit Tour Button - Enabled only if tour is not Ended
            IconButton(
              icon: const Icon(Icons.edit_outlined), // Standard edit icon
              tooltip: 'Edit Tour Details',
              onPressed:
                  tour.status == TourStatus.Ended
                      ? null // Disable if tour is ended
                      : () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder:
                                (context) =>
                                    AddEditTourScreen(tourToEdit: tour),
                          ),
                        );
                      },
            ),
            // Tour Status Actions (Start/End/Reopen)
            // Use Consumer or Selector if only the button needs to rebuild on status change
            // For simplicity here, the whole AppBar rebuilds which is often acceptable
            _buildStatusActionButton(context, tourProvider, tour),

            // Delete Tour Button (use with confirmation)
            IconButton(
              icon: const Icon(
                Icons.delete_forever_outlined,
                color: Colors.redAccent,
              ),
              tooltip: 'Delete Tour Permanently',
              onPressed:
                  () => _confirmDeleteTour(context, tourProvider, tour.id!),
            ),
          ],
          bottom: const TabBar(
            // labelColor: Theme.of(context).indicatorColor, // Use theme color
            // indicatorColor: Theme.of(context).indicatorColor,
            tabs: [
              Tab(text: 'Overview', icon: Icon(Icons.info_outline)),
              Tab(text: 'Expenses', icon: Icon(Icons.receipt_long_outlined)),
              Tab(text: 'Report', icon: Icon(Icons.assessment_outlined)),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Pass necessary data from provider to tab builders
            _buildOverviewTab(
              context,
              tourProvider,
              tour,
              remainingAmount,
              currencyFormat,
            ),
            _buildExpensesTab(context, tourProvider, tour),
            _buildReportTab(context, tourProvider, tour, currencyFormat),
          ],
        ),
        // Show FAB to add expenses only if tour is not ended
        floatingActionButton:
            tour.status == TourStatus.Ended
                ? null
                : FloatingActionButton(
                  onPressed: () {
                    // Check if participants are available (they should be if tour loaded)
                    if (tourProvider.currentTourParticipants.isEmpty &&
                        tourProvider.people.isNotEmpty) {
                      // Might indicate a state inconsistency, maybe show warning/refetch?
                      print(
                        "Warning: currentTourParticipants is empty, but people list is not. Proceeding anyway.",
                      );
                      // You could potentially fetch participants again here if needed:
                      // tourProvider.fetchTourDetails(tour.id!);
                    }
                    if (tourProvider.currentTour == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Error: Current tour data missing.'),
                        ),
                      );
                      return;
                    }
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => AddEditExpenseScreen(tour: tour),
                      ),
                    );
                  },
                  tooltip: 'Add New Expense',
                  child: const Icon(Icons.add),
                ),
      ),
    );
  }

  // --- Status Action Button Logic ---
  Widget _buildStatusActionButton(
    BuildContext context,
    TourProvider tourProvider,
    Tour tour,
  ) {
    // This widget rebuilds whenever the TourDetailScreen rebuilds.
    // It reads the status directly from the 'tour' object passed in.
    print("Building Status Action Button for status: ${tour.status}");
    switch (tour.status) {
      case TourStatus.Created:
        return IconButton(
          icon: const Icon(Icons.play_circle_outline, color: Colors.green),
          tooltip: 'Start Tour',
          onPressed: () async {
            // Optional: Confirmation Dialog
            try {
              await tourProvider.changeTourStatus(tour.id!, TourStatus.Started);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Tour Started!'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            } catch (e) {
              print("Error starting tour: $e");
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error starting tour: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          },
        );
      case TourStatus.Started:
        return IconButton(
          icon: const Icon(Icons.stop_circle_outlined, color: Colors.redAccent),
          tooltip: 'End Tour',
          onPressed: () => _confirmEndTour(context, tourProvider, tour),
        );
      case TourStatus.Ended:
        return IconButton(
          icon: const Icon(Icons.refresh_outlined, color: Colors.orange),
          tooltip: 'Reopen Tour',
          onPressed: () async {
            // Optional: Confirmation Dialog
            try {
              await tourProvider.changeTourStatus(
                tour.id!,
                TourStatus.Started,
              ); // Reopen to 'Started'
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Tour Reopened!'),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            } catch (e) {
              print("Error reopening tour: $e");
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error reopening tour: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          },
        );
      // Default case if enum expands unexpectedly
      default:
        return const SizedBox.shrink();
    }
  }

  // --- Confirmation Dialogs ---

  void _confirmEndTour(
    BuildContext context,
    TourProvider tourProvider,
    Tour tour,
  ) {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('End Tour?'),
            content: const Text(
              'Are you sure you want to mark this tour as ended? You can reopen it later if needed.',
            ),
            actions: <Widget>[
              TextButton(
                child: const Text('Cancel'),
                onPressed: () => Navigator.of(ctx).pop(),
              ),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('End Tour'),
                onPressed: () async {
                  Navigator.of(ctx).pop(); // Close dialog first
                  try {
                    await tourProvider.changeTourStatus(
                      tour.id!,
                      TourStatus.Ended,
                    );
                    // Check mounted before showing Snackbar
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Tour Ended! Final report available.'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } catch (e) {
                    print("Error ending tour: $e");
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error ending tour: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
              ),
            ],
          ),
    );
  }

  void _confirmDeleteTour(
    BuildContext context,
    TourProvider tourProvider,
    int tourId,
  ) {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Delete Tour Permanently?'),
            content: const Text(
              'WARNING: This will delete the tour and ALL associated expenses. This action cannot be undone.',
              style: TextStyle(color: Colors.redAccent),
            ),
            actions: <Widget>[
              TextButton(
                child: const Text('Cancel'),
                onPressed: () {
                  Navigator.of(ctx).pop();
                },
              ),
              TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('DELETE PERMANENTLY'),
                onPressed: () async {
                  Navigator.of(ctx).pop(); // Close dialog
                  try {
                    await tourProvider.deleteTour(tourId);
                    // Use mounted check *before* Navigator.pop
                    if (context.mounted) {
                      // Pop the detail screen
                      Navigator.of(context).pop();
                      // Show confirmation
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Tour deleted successfully.'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } catch (e) {
                    print("Error deleting tour: $e");
                    // Use mounted check *before* showing Snackbar
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error deleting tour: $e'),
                          backgroundColor: Colors.redAccent,
                        ),
                      );
                    }
                  }
                },
              ),
            ],
          ),
    );
  }

  // --- Tab Builders (Keep these mostly as they were, ensure they read from provider) ---

  Widget _buildOverviewTab(
    BuildContext context,
    TourProvider tourProvider,
    Tour tour,
    double remainingAmount,
    NumberFormat currencyFormat,
  ) {
    // Access data directly from the provider's state
    final participants = tourProvider.currentTourParticipants;
    final holder = tourProvider.currentTourAdvanceHolder;

    // Handle case where holder might still be loading (though unlikely if fetchTourDetails worked)
    final holderName =
        holder?.name ?? (tourProvider.isLoading ? 'Loading...' : 'N/A');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoCard(
            context,
            title: 'Tour Details',
            icon: Icons.info_outline,
            children: [
              _buildInfoRow(
                context,
                null,
                'Dates:',
                '${tour.formattedStartDate} - ${tour.formattedEndDate}',
              ),
              _buildInfoRow(
                context,
                null,
                'Status:',
                tour.statusString,
                chipColor: _getStatusColor(tour.status),
              ),
              _buildInfoRow(context, null, 'Advance Holder:', holderName),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoCard(
            context,
            title: 'Financials',
            icon: Icons.account_balance_wallet_outlined,
            children: [
              _buildInfoRow(
                context,
                null,
                'Advance:',
                currencyFormat.format(tour.advanceAmount),
                valueColor: Colors.green.shade700,
              ),
              _buildInfoRow(
                context,
                null,
                'Total Spent:',
                currencyFormat.format(tourProvider.currentTourTotalSpent),
                valueColor: Colors.red.shade700,
              ),
              _buildInfoRow(
                context,
                null,
                'Remaining:',
                currencyFormat.format(remainingAmount),
                valueColor:
                    remainingAmount >= 0
                        ? Colors.blue.shade800
                        : Colors.orange.shade900,
                isBold: true,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoCard(
            context,
            title: 'Participants (${participants.length})',
            icon: Icons.people_outline,
            children: [
              if (participants.isEmpty && !tourProvider.isLoading)
                const Padding(
                  padding: EdgeInsets.only(top: 8.0),
                  child: Text('No participants listed.'),
                )
              else if (tourProvider.isLoading && participants.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 8.0),
                  child: Text('Loading participants...'),
                ) // Indicate loading
              else
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Wrap(
                    spacing: 8.0,
                    runSpacing: 4.0,
                    children:
                        participants
                            .map(
                              (person) => Chip(
                                avatar:
                                    person.id == holder?.id
                                        ? const Icon(
                                          Icons.star,
                                          size: 16,
                                          color: Colors.amber,
                                        )
                                        : null,
                                label: Text(person.name),
                                visualDensity: VisualDensity.compact,
                              ),
                            )
                            .toList(),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 2,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Theme.of(context).primaryColor, size: 22),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 20, thickness: 0.5),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    IconData? icon,
    String label,
    String value, {
    Color? valueColor,
    Color? chipColor,
    bool isBold = false,
  }) {
    Widget valueWidget = Text(
      value,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        // Use bodyMedium for consistency
        color:
            valueColor ??
            Theme.of(
              context,
            ).textTheme.bodyMedium?.color, // Use default color if null
        fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
      ),
      overflow: TextOverflow.ellipsis,
      maxLines: 2, // Allow wrapping slightly
    );

    if (chipColor != null) {
      valueWidget = Chip(
        label: Text(value),
        backgroundColor: chipColor.withOpacity(0.8),
        labelStyle: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 0,
        ), // Adjust padding
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        side: BorderSide.none, // Remove border
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center, // Center vertically
        children: [
          if (icon != null) ...[
            Icon(icon, color: Colors.grey.shade600, size: 18),
            const SizedBox(width: 8),
          ],
          SizedBox(
            width: 120, // Adjust width as needed
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade700),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: valueWidget),
        ],
      ),
    );
  }

  Color _getStatusColor(TourStatus status) {
    switch (status) {
      case TourStatus.Created:
        return Colors.grey.shade600;
      case TourStatus.Started:
        return Colors.blue.shade700;
      case TourStatus.Ended:
        return Colors.green.shade700;
    }
  }

  Widget _buildExpensesTab(
    BuildContext context,
    TourProvider tourProvider,
    Tour tour,
  ) {
    final expenses = tourProvider.currentTourExpenses;

    // Show loading indicator *while* expenses might be refetching
    if (tourProvider.isLoading && expenses.isEmpty) {
      // Use a more subtle loading indicator if expenses were previously present
      // but are being refetched (e.g., after delete)
      return const Center(child: CircularProgressIndicator());
    }

    if (expenses.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.receipt_long_outlined,
                size: 60,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                'No expenses added yet.',
                style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
              ),
              if (tour.status != TourStatus.Ended)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    'Tap the "+" button to add the first one!',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, color: Colors.grey.shade500),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    // Use RefreshIndicator for manual refresh
    return RefreshIndicator(
      onRefresh: () => tourProvider.fetchTourDetails(tour.id!),
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 8, bottom: 80), // Padding for FAB
        itemCount: expenses.length,
        itemBuilder: (context, index) {
          final expense = expenses[index];
          // Use provider's helper for category name for consistency
          final categoryName = tourProvider.getCategoryNameById(
            expense.categoryId,
          );

          return ExpenseListItem(
            expense: expense,
            categoryName: categoryName,
            tourStatus: tour.status,
            onTap:
                tour.status == TourStatus.Ended
                    ? null
                    : () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder:
                              (context) => AddEditExpenseScreen(
                                tour: tour,
                                expenseToEdit: expense,
                              ),
                        ),
                      );
                    },
            onDelete:
                () => _confirmDeleteExpense(context, tourProvider, expense.id!),
          );
        },
      ),
    );
  }

  void _confirmDeleteExpense(
    BuildContext context,
    TourProvider tourProvider,
    int expenseId,
  ) {
    if (!context.mounted) return;
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Delete Expense?'),
            content: const Text(
              'Are you sure you want to delete this expense record?',
            ),
            actions: <Widget>[
              TextButton(
                child: const Text('Cancel'),
                onPressed: () => Navigator.of(ctx).pop(),
              ),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Delete'),
                onPressed: () async {
                  Navigator.of(ctx).pop(); // Close dialog first
                  try {
                    await tourProvider.deleteExpenseFromCurrentTour(expenseId);
                    // Check mounted before showing Snackbar
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Expense deleted.'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } catch (e) {
                    print("Error deleting expense: $e");
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error deleting expense: $e'),
                        backgroundColor: Colors.redAccent,
                      ),
                    );
                  }
                },
              ),
            ],
          ),
    );
  }

  Widget _buildReportTab(
    BuildContext context,
    TourProvider tourProvider,
    Tour tour,
    NumberFormat currencyFormat,
  ) {
    // Access data directly from provider state
    final paymentsByPerson = tourProvider.currentTourPaymentsByPerson;
    final peopleMap = tourProvider.peopleMap;
    // final participants = tourProvider.currentTourParticipants; // Not directly used, but available
    final expenses = tourProvider.currentTourExpenses;
    final categories = tourProvider.categories;
    final totalSpent = tourProvider.currentTourTotalSpent;
    final advance = tour.advanceAmount;
    final remaining = advance - totalSpent;

    // Show loading if necessary (e.g., data still being calculated/fetched)
    if (tourProvider.isLoading &&
        paymentsByPerson.isEmpty &&
        expenses.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    // Process data for reporting
    final paymentReportEntries =
        paymentsByPerson.entries
            .map(
              (entry) => MapEntry(
                tourProvider.getPersonNameById(entry.key), // Use helper
                entry.value,
              ),
            )
            .where((entry) => entry.value > 0.001)
            .toList()
          ..sort((a, b) => b.value.compareTo(a.value)); // Sort desc

    final Map<int, double> categoryTotals = {};
    for (var expense in expenses) {
      categoryTotals[expense.categoryId] =
          (categoryTotals[expense.categoryId] ?? 0.0) + expense.amount;
    }
    final categoryReportEntries =
        categoryTotals.entries
            .map(
              (entry) => MapEntry(
                tourProvider.getCategoryNameById(entry.key), // Use helper
                entry.value,
              ),
            )
            .where((entry) => entry.value > 0.001)
            .toList()
          ..sort((a, b) => b.value.compareTo(a.value)); // Sort desc

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Financial Summary',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildReportSummaryItem(
            'Total Advance:',
            currencyFormat.format(advance),
            Colors.green.shade700,
          ),
          _buildReportSummaryItem(
            'Total Expenses:',
            currencyFormat.format(totalSpent),
            Colors.red.shade700,
          ),
          _buildReportSummaryItem(
            remaining >= 0 ? 'Remaining Balance:' : 'Overspent By:',
            currencyFormat.format(remaining.abs()),
            remaining >= 0 ? Colors.blue.shade800 : Colors.orange.shade900,
            isBold: true,
          ),

          const Divider(height: 30, thickness: 1),

          Text(
            'Expenses by Category',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          if (categoryReportEntries.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16.0),
                child: Text(
                  'No expenses recorded yet.',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: categoryReportEntries.length,
                separatorBuilder:
                    (context, index) =>
                        const Divider(height: 1, indent: 16, endIndent: 16),
                itemBuilder: (context, index) {
                  final entry = categoryReportEntries[index];
                  final percentage =
                      totalSpent > 0 ? (entry.value / totalSpent * 100) : 0.0;
                  return ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 2,
                    ),
                    title: Text(
                      entry.key,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    trailing: Text(
                      '${currencyFormat.format(entry.value)} (${percentage.toStringAsFixed(1)}%)',
                      style: const TextStyle(fontSize: 14),
                    ),
                  );
                },
              ),
            ),

          const Divider(height: 30, thickness: 1),

          Text(
            'Payments by Individuals',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            '(Who contributed cash towards expenses)',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),

          if (paymentReportEntries.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16.0),
                child: Text(
                  'No individual payments were recorded.',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: paymentReportEntries.length,
                separatorBuilder:
                    (context, index) =>
                        const Divider(height: 1, indent: 16, endIndent: 16),
                itemBuilder: (context, index) {
                  final entry = paymentReportEntries[index];
                  return ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 2,
                    ),
                    title: Text(
                      entry.key,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    trailing: Text(
                      currencyFormat.format(entry.value),
                      style: const TextStyle(fontSize: 14),
                    ),
                  );
                },
              ),
            ),

          const SizedBox(height: 20), // Bottom padding
        ],
      ),
    );
  }

  Widget _buildReportSummaryItem(
    String label,
    String value,
    Color valueColor, {
    bool isBold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16)),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              color: valueColor,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
