import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // For currency formatting
import 'package:provider/provider.dart';
import 'package:btour/models/tour.dart';
import 'package:btour/providers/tour_provider.dart'; // To get holder name etc.

class TourCard extends StatelessWidget {
  final Tour tour;
  final VoidCallback onTap;

  const TourCard({super.key, required this.tour, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // Use provider for lookups but don't need to listen here
    final tourProvider = Provider.of<TourProvider>(context, listen: false);
    final currencyFormat = NumberFormat.currency(locale: 'en_US', symbol: '\$');

    return Card(
      clipBehavior:
          Clip.antiAlias, // Ensures inkwell ripple stays within bounds
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tour Name and Status Chip row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    // Allow name to take available space
                    child: Text(
                      tour.name,
                      style: Theme.of(context).textTheme.titleLarge,
                      maxLines: 2, // Allow wrapping slightly
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8), // Space before chip
                  Chip(
                    label: Text(tour.statusString),
                    backgroundColor: _getStatusColor(tour.status),
                    labelStyle: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 0,
                    ),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // Date Range
              Text(
                '${tour.formattedStartDate} - ${tour.formattedEndDate}',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 8),

              // Advance Holder
              Text.rich(
                TextSpan(
                  text: 'Holder: ',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade700),
                  children: [
                    TextSpan(
                      text: tourProvider.getPersonNameById(
                        tour.advanceHolderPersonId,
                      ),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),

              // Advance Amount
              Text(
                'Advance: ${currencyFormat.format(tour.advanceAmount)}',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.green.shade700),
              ),

              // Show Spent/Remaining only for Finished tours on the card
              if (tour.status == TourStatus.Ended)
                Padding(
                  padding: const EdgeInsets.only(top: 6.0),
                  child: FutureBuilder<double>(
                    // Fetch total spent specifically for this finished card
                    // This ensures accuracy even if provider state isn't perfectly synced
                    // Could be optimized if performance becomes an issue
                    future: tourProvider.getTotalExpensesForTour(tour.id!),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        // Show a placeholder or small indicator
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              'Calculating...',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        );
                      }
                      if (snapshot.hasError) {
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              'Error',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: Colors.red),
                            ),
                          ],
                        );
                      }

                      final spent = snapshot.data ?? 0.0;
                      final remaining = tour.advanceAmount - spent;
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Spent: ${currencyFormat.format(spent)}',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: Colors.red.shade700),
                          ),
                          Text(
                            'Remaining: ${currencyFormat.format(remaining)}',
                            style: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color:
                                  remaining >= 0
                                      ? Colors.blue.shade800
                                      : Colors.orange.shade900,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),

              // Optionally show participant count asynchronously
              // FutureBuilder<List<Person>>(
              //   future: tourProvider.getTourParticipants(tour.id!),
              //   builder: (context, snapshot) {
              //     if (snapshot.hasData) {
              //       return Text('Participants: ${snapshot.data!.length}', style: Theme.of(context).textTheme.bodySmall);
              //     }
              //     return SizedBox.shrink(); // Or a placeholder
              //   }
              // ),
            ],
          ),
        ),
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
}
