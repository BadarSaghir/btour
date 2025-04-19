import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:btour/models/person.dart'; // Need for report tab person lookup
import 'package:btour/models/tour.dart';
import 'package:btour/providers/tour_provider.dart';
import 'package:btour/screens/add_edit_expense_screen.dart';
import 'package:btour/screens/add_edit_tour_screen.dart';
import 'package:btour/widgets/expense_list_item.dart';
import 'package:collection/collection.dart'; // Import for firstWhereOrNull

class TourDetailScreen extends StatelessWidget {
  const TourDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Listen to provider changes to update the UI
    final tourProvider = Provider.of<TourProvider>(context);
    final tour = tourProvider.currentTour; // Get the currently loaded tour
    final currencyFormat = NumberFormat.currency(locale: 'en_US', symbol: "\$");

    // Handle loading state managed by the provider
    if (tourProvider.isLoading && tour == null) {
      // Initial loading state when navigating here
      return Scaffold(
        appBar: AppBar(title: const Text('Loading Tour...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Handle case where tour loading finished but resulted in null (e.g., tour deleted)
    if (tour == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: const Center(
          child: Text('Tour not found or could not be loaded.'),
        ),
      );
    }

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
              icon: const Icon(Icons.edit_note), // Different icon maybe?
              tooltip: 'Edit Tour Details',
              // Disable if tour is ended
              onPressed:
                  tour.status == TourStatus.Ended
                      ? null
                      : () {
                        // Navigate to edit screen, passing the current tour object
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
            _buildStatusActionButton(context, tourProvider, tour),

            // Delete Tour Button (use with confirmation)
            IconButton(
              icon: Icon(
                Icons.delete_forever_outlined,
                color: Colors.red.shade700,
              ),
              tooltip: 'Delete Tour Permanently',
              onPressed:
                  () => _confirmDeleteTour(context, tourProvider, tour.id!),
            ),
          ],
          bottom: const TabBar(
            labelColor: Colors.blue, // Color for selected tab text
            unselectedLabelColor: Colors.grey, // Color for unselected tab text
            indicatorColor: Colors.blue, // Color of the underline indicator
            tabs: [
              Tab(text: 'Overview', icon: Icon(Icons.info_outline)),
              Tab(text: 'Expenses', icon: Icon(Icons.receipt_long_outlined)),
              Tab(
                text: 'Report',
                icon: Icon(Icons.assessment_outlined),
              ), // Changed icon
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // --- Overview Tab ---
            _buildOverviewTab(
              context,
              tourProvider,
              tour,
              remainingAmount,
              currencyFormat,
            ),

            // --- Expenses Tab ---
            _buildExpensesTab(context, tourProvider, tour),

            // --- Report Tab ---
            _buildReportTab(context, tourProvider, tour, currencyFormat),
          ],
        ),
        // Show FAB to add expenses only if tour is not ended
        floatingActionButton:
            tour.status == TourStatus.Ended
                ? null
                : FloatingActionButton(
                  onPressed: () {
                    // Ensure participants are loaded before navigating
                    if (tourProvider.currentTourParticipants.isEmpty) {
                      // This shouldn't happen if fetchTourDetails worked, but as a safeguard:
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Participants not loaded. Cannot add expense.',
                          ),
                        ),
                      );
                      return;
                    }
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder:
                            (context) => AddEditExpenseScreen(
                              tour: tour,
                            ), // Pass current tour object
                      ),
                    );
                  },
                  tooltip: 'Add New Expense',
                  child: const Icon(Icons.add_shopping_cart), // Different Icon
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
    switch (tour.status) {
      case TourStatus.Created:
        return IconButton(
          icon: const Icon(Icons.play_circle_outline, color: Colors.green),
          tooltip: 'Start Tour',
          onPressed: () async {
            // Show confirmation?
            await tourProvider.changeTourStatus(tour.id!, TourStatus.Started);
            if (context.mounted) {
              // Check mounted after async gap
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Tour Started!'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          },
        );
      case TourStatus.Started:
        return IconButton(
          icon: const Icon(Icons.stop_circle_outlined, color: Colors.redAccent),
          tooltip: 'End Tour',
          onPressed:
              () => _confirmEndTour(
                context,
                tourProvider,
                tour,
              ), // Use confirmation dialog
        );
      case TourStatus.Ended:
        return IconButton(
          icon: const Icon(Icons.refresh_outlined, color: Colors.orange),
          tooltip: 'Reopen Tour',
          onPressed: () async {
            // Show confirmation?
            await tourProvider.changeTourStatus(
              tour.id!,
              TourStatus.Started,
            ); // Reopen to 'Started' status
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Tour Reopened!'),
                  backgroundColor: Colors.orange,
                ),
              );
            }
          },
        );
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
                  Navigator.of(ctx).pop(); // Close dialog
                  await tourProvider.changeTourStatus(
                    tour.id!,
                    TourStatus.Ended,
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Tour Ended! Final report available.'),
                        backgroundColor: Colors.green,
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
                    // Navigate back to list screen after successful deletion
                    if (context.mounted) {
                      // Check if the current screen is still mounted before popping.
                      if (Navigator.canPop(context)) {
                        Navigator.of(context).pop(); // Pop detail screen
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Tour deleted successfully.'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } catch (e) {
                    print("Error deleting tour: $e");
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

  // --- Tab Builders ---

  Widget _buildOverviewTab(
    BuildContext context,
    TourProvider tourProvider,
    Tour tour,
    double remainingAmount,
    NumberFormat currencyFormat,
  ) {
    final participants = tourProvider.currentTourParticipants;
    final holder = tourProvider.currentTourAdvanceHolder;

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
              _buildInfoRow(
                context,
                null,
                'Advance Holder:',
                holder?.name ?? 'Loading...',
              ),
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
              if (participants.isEmpty)
                const Text('No participants listed.')
              else
                Padding(
                  padding: const EdgeInsets.only(
                    top: 8.0,
                  ), // Add padding above chips
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
                                          color: Colors.orangeAccent,
                                        )
                                        : null, // Mark holder
                                label: Text(person.name),
                                visualDensity: VisualDensity.compact,
                              ),
                            )
                            .toList(),
                  ),
                ),
            ],
          ),
          // Add more overview details if needed
        ],
      ),
    );
  }

  // Helper for creating consistent info cards
  Widget _buildInfoCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Theme.of(context).primaryColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  // Helper for creating consistent info rows within cards
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
      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
        color: valueColor,
        fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
      ),
      overflow: TextOverflow.ellipsis,
    );

    // Use chip for specific values like status
    if (chipColor != null) {
      valueWidget = Chip(
        label: Text(value),
        backgroundColor: chipColor,
        labelStyle: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start, // Align label top if value wraps
        children: [
          if (icon != null) ...[
            Icon(icon, color: Colors.grey.shade600, size: 18),
            const SizedBox(width: 8),
          ],
          SizedBox(
            width: 110, // Fixed width for label column
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(color: Colors.grey.shade700),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: valueWidget), // Value takes remaining space
        ],
      ),
    );
  }

  Color _getStatusColor(TourStatus status) {
    switch (status) {
      case TourStatus.Created:
        return Colors.grey.shade500;
      case TourStatus.Started:
        return Colors.blue.shade600;
      case TourStatus.Ended:
        return Colors.green.shade600;
    }
  }

  Widget _buildExpensesTab(
    BuildContext context,
    TourProvider tourProvider,
    Tour tour,
  ) {
    // Get expenses from provider (which should be up-to-date)
    final expenses = tourProvider.currentTourExpenses;

    // Check if data is loading (e.g., after adding/deleting an expense)
    if (tourProvider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (expenses.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            // Use Column for better alignment
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
              if (tour.status !=
                  TourStatus.Ended) // Show hint only if tour active
                Text(
                  'Tap the "+" button to add the first one!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, color: Colors.grey.shade500),
                ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh:
          () => tourProvider.fetchTourDetails(
            tour.id!,
          ), // Refresh all details on pull
      child: ListView.builder(
        padding: const EdgeInsets.only(
          top: 8,
          bottom: 80,
        ), // Padding for FAB and top space
        itemCount: expenses.length,
        itemBuilder: (context, index) {
          final expense = expenses[index];
          // Find category name (safe lookup)
          final category = tourProvider.categories.firstWhereOrNull(
            (c) => c.id == expense.categoryId,
          );
          final categoryName = category?.name ?? 'Unknown Category';

          return ExpenseListItem(
            expense: expense,
            categoryName: categoryName, // Pass category name
            tourStatus: tour.status, // Pass status to enable/disable actions
            onTap:
                tour.status == TourStatus.Ended
                    ? null
                    : () {
                      // Disable tap if ended
                      // Navigate to edit expense screen
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
    // Avoid showing dialog if context is no longer valid (e.g., screen already popped)
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
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Expense deleted.'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } catch (e) {
                    print("Error deleting expense: $e");
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error deleting expense: $e'),
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

  Widget _buildReportTab(
    BuildContext context,
    TourProvider tourProvider,
    Tour tour,
    NumberFormat currencyFormat,
  ) {
    // Data from provider
    final paymentsByPerson =
        tourProvider.currentTourPaymentsByPerson; // Map<personId, amountPaid>
    final peopleMap =
        tourProvider.peopleMap; // Map<personId, Person> for name lookup
    final participants =
        tourProvider.currentTourParticipants; // Full list of participants
    final expenses =
        tourProvider.currentTourExpenses; // List of Expense objects
    final categories = tourProvider.categories; // List of Category objects
    final totalSpent = tourProvider.currentTourTotalSpent;
    final advance = tour.advanceAmount;
    final remaining = advance - totalSpent;

    if (tourProvider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // --- Calculate Payments by Person (for display) ---
    final paymentReportEntries =
        paymentsByPerson.entries
            .map((entry) {
              final personId = entry.key;
              final amountPaid = entry.value;
              final personName =
                  peopleMap[personId]?.name ?? 'Unknown Person [$personId]';
              return MapEntry(personName, amountPaid);
            })
            .where(
              (entry) => entry.value > 0.001,
            ) // Only show people who actually paid
            .toList();
    paymentReportEntries.sort(
      (a, b) => b.value.compareTo(a.value),
    ); // Sort by amount paid desc

    // --- Calculate Expenses by Category ---
    final Map<int, double> categoryTotals = {};
    for (var expense in expenses) {
      categoryTotals[expense.categoryId] =
          (categoryTotals[expense.categoryId] ?? 0.0) + expense.amount;
    }

    final categoryReportEntries =
        categoryTotals.entries
            .map((entry) {
              final categoryId = entry.key;
              final totalAmount = entry.value;
              final categoryName =
                  categories
                      .firstWhereOrNull((cat) => cat.id == categoryId)
                      ?.name ??
                  'Unknown Category [$categoryId]';
              return MapEntry(categoryName, totalAmount);
            })
            .where(
              (entry) => entry.value > 0.001,
            ) // Only show categories with spending
            .toList();
    categoryReportEntries.sort(
      (a, b) => b.value.compareTo(a.value),
    ); // Sort by amount spent desc

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
            currencyFormat.format(remaining.abs()), // Show absolute value
            remaining >= 0 ? Colors.blue.shade800 : Colors.orange.shade900,
            isBold: true,
          ),

          const Divider(height: 30, thickness: 1),

          // --- Expenses by Category Section ---
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
                    ), // Category Name
                    trailing: Text(
                      '${currencyFormat.format(entry.value)} (${percentage.toStringAsFixed(1)}%)', // Amount Spent (% of total)
                      style: const TextStyle(fontSize: 14),
                    ),
                    // Optional: Add a simple progress bar indicator?
                    // subtitle: LinearProgressIndicator(
                    //   value: percentage / 100,
                    //   minHeight: 3,
                    //   backgroundColor: Colors.grey.shade200,
                    // ),
                  );
                },
              ),
            ),

          const Divider(height: 30, thickness: 1),

          // --- Payments by Individuals Section ---
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
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Text(
                  'No individual payments were recorded.',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            Card(
              // Put the list in a card
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
                    ), // Person Name
                    trailing: Text(
                      currencyFormat.format(entry.value), // Amount Paid
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
