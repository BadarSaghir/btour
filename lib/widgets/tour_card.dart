import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'package:btour/models/tour.dart'; // Import your Tour model
import 'package:btour/providers/tour_provider.dart'; // To get status color potentially
import 'package:provider/provider.dart'; // To access provider for status color

class TourCard extends StatelessWidget {
  final Tour tour;
  final VoidCallback onTap;

  const TourCard({super.key, required this.tour, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Use provider only for consistent status color lookup if desired
    // final tourProvider = Provider.of<TourProvider>(context, listen: false);
    final statusColor = _getStatusColor(
      tour.status,
      theme,
    ); // Pass theme for fallback colors
    final currencyFormat = NumberFormat.currency(locale: 'en_US', symbol: "\$");

    return Card(
      elevation: 3.0,
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      clipBehavior: Clip.antiAlias, // Clip content to rounded borders
      child: InkWell(
        onTap: onTap,
        splashColor: theme.primaryColor.withValues(alpha: 0.1),
        highlightColor: theme.primaryColor.withValues(alpha: 0.05),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tour Name (allow wrapping)
                  Expanded(
                    child: Text(
                      tour.name,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        // color: theme.colorScheme.primary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Status Chip
                  Chip(
                    label: Text(tour.statusString.toUpperCase()),
                    labelStyle: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    backgroundColor: statusColor,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    side: BorderSide.none,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Divider(color: Colors.grey.shade300, height: 1),
              const SizedBox(height: 12),
              // Dates and Financials Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Dates Column
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoRow(
                        theme,
                        Icons.date_range_outlined,
                        '${tour.formattedStartDate} - ${tour.formattedEndDate}',
                      ),
                      const SizedBox(height: 4),
                      _buildInfoRow(
                        theme,
                        Icons.person_pin_circle_outlined,
                        'Adv Holder: ${context.select((TourProvider p) => p.getPersonNameById(tour.advanceHolderPersonId))}', // Get name via provider
                      ),
                    ],
                  ),
                  // Financials Column
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _buildInfoRow(
                        theme,
                        Icons.account_balance_wallet_outlined,
                        'Adv: ${currencyFormat.format(tour.advanceAmount)}',
                        color: Colors.green.shade700,
                      ),
                      const SizedBox(height: 4),
                      // FutureBuilder for Total Expenses (prevents fetching for all cards upfront)
                      FutureBuilder<double>(
                        // Use the provider's method to fetch expense total for THIS tour
                        future: Provider.of<TourProvider>(
                          context,
                          listen: false,
                        ).getTotalExpensesForTour(tour.id!),
                        builder: (context, snapshot) {
                          String spentText = 'Spent: ...';
                          Color spentColor = Colors.grey;
                          if (snapshot.connectionState ==
                                  ConnectionState.done &&
                              snapshot.hasData) {
                            spentText =
                                'Spent: ${currencyFormat.format(snapshot.data)}';
                            spentColor = Colors.red.shade700;
                          } else if (snapshot.hasError) {
                            spentText = 'Spent: Error';
                          }
                          return _buildInfoRow(
                            theme,
                            Icons.receipt_long,
                            spentText,
                            color: spentColor,
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    ThemeData theme,
    IconData icon,
    String text, {
    Color? color,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min, // Prevent row from taking full width
      children: [
        Icon(icon, size: 14, color: color ?? Colors.grey.shade600),
        const SizedBox(width: 5),
        Text(
          text,
          style: theme.textTheme.bodySmall?.copyWith(
            color: color ?? Colors.grey.shade700,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(TourStatus status, ThemeData theme) {
    switch (status) {
      case TourStatus.Created:
        return Colors.grey.shade500;
      case TourStatus.Started:
        return Colors.blue.shade600;
      case TourStatus.Ended:
        return Colors.green.shade600;
      default:
        return theme.disabledColor; // Fallback
    }
  }
}
