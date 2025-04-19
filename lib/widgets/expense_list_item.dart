// FILE: lib/widgets/expense_list_item.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
// REMOVED: import 'package:provider/provider.dart'; // No longer needed here
import 'package:btour/models/expense.dart';
import 'package:btour/models/tour.dart'; // To check tour status
// REMOVED: import 'package:btour/providers/tour_provider.dart'; // No longer needed here

class ExpenseListItem extends StatelessWidget {
  final Expense expense;
  final TourStatus tourStatus; // To disable actions if tour ended
  final String categoryName; // RE-ADDED: Explicitly pass the category name
  final VoidCallback? onTap; // Nullable if disabled
  final VoidCallback onDelete;

  const ExpenseListItem({
    super.key,
    required this.expense,
    required this.tourStatus,
    required this.categoryName, // RE-ADDED
    this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    // REMOVED: Internal provider lookup
    // final tourProvider = context.read<TourProvider>();
    // final categoryName = tourProvider.getCategoryNameById(expense.categoryId);

    final bool isTapEnabled = onTap != null;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: InkWell(
        onTap: isTapEnabled ? onTap : null,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Row(
            children: [
              // Left side: Category details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      categoryName, // Use the passed categoryName
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    if (expense.description != null &&
                        expense.description!.isNotEmpty) ...[
                      Text(
                        expense.description!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                    ],
                    Text(
                      expense.formattedDate,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade600,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(
                width: 16,
              ), // Space between details and amount/actions
              // Right side: Amount and Delete button
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    currencyFormat.format(expense.amount),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.teal,
                    ),
                  ),
                  SizedBox(
                    height: 30,
                    child:
                        (tourStatus != TourStatus.Ended)
                            ? IconButton(
                              icon: Icon(
                                Icons.delete_outline,
                                color: Colors.grey.shade500,
                              ),
                              iconSize: 20,
                              tooltip: 'Delete Expense',
                              onPressed: onDelete,
                              padding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                            )
                            : const SizedBox(height: 30),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
