import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:btour/models/tour.dart';
import 'package:btour/providers/tour_provider.dart';
import 'package:btour/screens/add_edit_tour_screen.dart';
import 'package:btour/screens/tour_detail_screen.dart';
import 'package:btour/widgets/tour_card.dart'; // Create this widget

class TourListScreen extends StatefulWidget {
  const TourListScreen({super.key});

  @override
  State<TourListScreen> createState() => _TourListScreenState();
}

class _TourListScreenState extends State<TourListScreen> {
  // No initState needed as Provider handles initial loading

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tour Expense Tracker'),
        actions: [
          // Optional: Add actions like managing people globally
          // IconButton(
          //   icon: Icon(Icons.people),
          //   onPressed: () { /* Navigate to manage people screen */ },
          // ),
        ],
      ),
      body: Consumer<TourProvider>(
        builder: (context, tourProvider, child) {
          // Show loading indicator only during the very initial load
          if (tourProvider.isLoading && tourProvider.tours.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          // Separate tours based on status AFTER checking for empty list
          final activeTours =
              tourProvider.tours
                  .where((tour) => tour.status != TourStatus.Ended)
                  .toList();
          final finishedTours =
              tourProvider.tours
                  .where((tour) => tour.status == TourStatus.Ended)
                  .toList();

          // Handle case where there are tours, but all might be filtered out (unlikely here but good practice)
          if (tourProvider.tours.isEmpty && !tourProvider.isLoading) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'No tours yet. Tap the "+" button to create your first tour!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh:
                () =>
                    tourProvider
                        .fetchAllTours(), // Refresh only tours on pull-down
            child: ListView(
              padding: const EdgeInsets.all(8.0),
              children: [
                if (activeTours.isNotEmpty)
                  _buildSectionTitle(
                    context,
                    'Active Tours (${activeTours.length})',
                  ),
                ...activeTours
                    .map(
                      (tour) => TourCard(
                        tour: tour,
                        onTap: () => _navigateToTourDetail(context, tour.id!),
                      ),
                    )
                    .toList(),

                if (finishedTours.isNotEmpty) ...[
                  if (activeTours.isNotEmpty)
                    const SizedBox(
                      height: 16,
                    ), // Add space only if active tours exist
                  _buildSectionTitle(
                    context,
                    'Finished Tours (${finishedTours.length})',
                  ),
                  ...finishedTours
                      .map(
                        (tour) => TourCard(
                          tour: tour,
                          onTap: () => _navigateToTourDetail(context, tour.id!),
                        ),
                      )
                      .toList(),
                ],

                // Add some bottom padding if needed
                const SizedBox(height: 80),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Ensure necessary data (like people) is available before navigating
          final tourProvider = Provider.of<TourProvider>(
            context,
            listen: false,
          );
          if (tourProvider.people.isEmpty) {
            // Optionally fetch people again or show a message
            tourProvider.fetchAllPeople().then((_) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const AddEditTourScreen(),
                ),
              );
            });
          } else {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const AddEditTourScreen(),
              ),
            );
          }
        },
        tooltip: 'Add Tour',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
      child: Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }

  void _navigateToTourDetail(BuildContext context, int tourId) {
    // Fetch details *before* navigating to ensure the detail screen has data
    // Show loading indicator potentially
    final tourProvider = Provider.of<TourProvider>(context, listen: false);

    // Show a loading dialog while fetching details
    showDialog(
      context: context,
      barrierDismissible: false, // Prevent closing while loading
      builder: (BuildContext context) {
        return const Center(child: CircularProgressIndicator());
      },
    );

    tourProvider
        .fetchTourDetails(tourId)
        .then((_) {
          Navigator.of(context).pop(); // Close the loading dialog
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const TourDetailScreen()),
          );
        })
        .catchError((error) {
          Navigator.of(context).pop(); // Close the loading dialog on error too
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error loading tour details: $error')),
          );
        });
  }
}
