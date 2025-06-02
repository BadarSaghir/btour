import 'package:btour/screens/backup_restore_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:btour/models/tour.dart';
import 'package:btour/providers/tour_provider.dart';
import 'package:btour/screens/add_edit_tour_screen.dart';
import 'package:btour/screens/tour_detail_screen.dart';
import 'package:btour/widgets/tour_card.dart'; // Ensure this uses the improved design

// Enum for sorting options
enum TourSortOption { dateDesc, dateAsc, nameAsc, nameDesc }

class TourListScreen extends StatefulWidget {
  const TourListScreen({super.key});

  @override
  State<TourListScreen> createState() => _TourListScreenState();
}

class _TourListScreenState extends State<TourListScreen> {
  // State
  TourStatus? _selectedStatusFilter;
  String _searchQuery = '';
  TourSortOption _currentSortOption = TourSortOption.dateDesc;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  // --- Filtering and Sorting Logic (Keep as is) ---
  List<Tour> _getFilteredAndSortedTours(TourProvider tourProvider) {
    List<Tour> filteredTours = tourProvider.tours;
    // 1. Filter by Status
    if (_selectedStatusFilter != null) {
      filteredTours =
          filteredTours
              .where((tour) => tour.status == _selectedStatusFilter)
              .toList();
    }
    // 2. Filter by Search Query
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase().trim();
      if (query.isNotEmpty) {
        filteredTours =
            filteredTours
                .where((tour) => tour.name.toLowerCase().contains(query))
                .toList();
      }
    }
    // 3. Sort
    switch (_currentSortOption) {
      case TourSortOption.dateAsc:
        filteredTours.sort((a, b) => a.startDate.compareTo(b.startDate));
        break;
      case TourSortOption.nameAsc:
        filteredTours.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
        break;
      case TourSortOption.nameDesc:
        filteredTours.sort(
          (a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()),
        );
        break;
      case TourSortOption.dateDesc:
        filteredTours.sort((a, b) {
          final statusA = a.status != TourStatus.Ended;
          final statusB = b.status != TourStatus.Ended;
          if (statusA && !statusB) return -1;
          if (!statusA && statusB) return 1;
          return b.startDate.compareTo(a.startDate);
        });
        break;
    }
    return filteredTours;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Listen for changes
    final tourProvider = context.watch<TourProvider>();
    // Compute the list to display *once* per build
    final toursToShow = _getFilteredAndSortedTours(tourProvider);

    return GestureDetector(
      // Dismiss keyboard when tapping outside fields
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: theme.colorScheme.surfaceBright.withValues(
          alpha: 1,
        ), // Subtle background
        appBar: _buildAppBar(context, theme),
        body: Column(
          children: [
            _buildFilterArea(
              theme,
            ), // Filter Chips area with background/padding
            // Divider might be too harsh, let FilterArea background provide separation
            // const Divider(height: 1, thickness: 0.5),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => tourProvider.fetchAllTours(),
                child: _buildTourListBody(
                  context,
                  tourProvider,
                  toursToShow,
                ), // Use LayoutBuilder here
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _navigateToAddTour(context, tourProvider),
          tooltip: 'Add Tour',
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  // --- AppBar Builder ---
  AppBar _buildAppBar(BuildContext context, ThemeData theme) {
    final appBarBrightness = ThemeData.estimateBrightnessForColor(
      theme.appBarTheme.backgroundColor ?? theme.primaryColor,
    );
    final isDarkAppBar = appBarBrightness == Brightness.dark;
    final Color iconColor =
        theme.appBarTheme.iconTheme?.color ??
        (isDarkAppBar ? Colors.white : Colors.black87);
    final Color searchTextColor =
        isDarkAppBar
            ? const Color.fromARGB(255, 167, 173, 247)
            : Colors.black87;
    final Color searchHintColor =
        isDarkAppBar ? Colors.white70 : Colors.black54;

    return AppBar(
      // elevation: _isSearching ? 0 : (theme.appBarTheme.elevation ?? 4.0), // Flat when searching
      title:
          _isSearching
              ? TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search Tours...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(
                    color: searchHintColor,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                style: TextStyle(color: searchTextColor, fontSize: 18),
                cursorColor: searchTextColor,
                onChanged:
                    (query) => setState(() {
                      _searchQuery = query;
                    }),
              )
              : const Text('Btour'),
      actions: [
        IconButton(
          icon: AnimatedSwitcher(
            // Smooth transition between icons
            duration: const Duration(milliseconds: 300),
            transitionBuilder:
                (child, animation) =>
                    ScaleTransition(scale: animation, child: child),
            child: Icon(
              _isSearching ? Icons.close : Icons.search,
              key: ValueKey(_isSearching), // Key for AnimatedSwitcher
            ),
          ),
          tooltip: _isSearching ? 'Close Search' : 'Search Tours',
          onPressed: () {
            setState(() {
              _isSearching = !_isSearching;
              if (!_isSearching) {
                _searchQuery = '';
                _searchController.clear();
                _searchFocusNode.unfocus();
              } else {
                _searchFocusNode.requestFocus();
              }
            });
          },
        ),
        PopupMenuButton<TourSortOption>(
          icon: const Icon(Icons.sort_by_alpha), // Different Icon
          tooltip: 'Sort Tours',
          onSelected:
              (TourSortOption result) => setState(() {
                _currentSortOption = result;
              }),
          itemBuilder:
              (BuildContext context) => <PopupMenuEntry<TourSortOption>>[
                _buildSortMenuItem(
                  TourSortOption.dateDesc,
                  'Date (Newest First)',
                ),
                _buildSortMenuItem(
                  TourSortOption.dateAsc,
                  'Date (Oldest First)',
                ),
                _buildSortMenuItem(TourSortOption.nameAsc, 'Name (A-Z)'),
                _buildSortMenuItem(TourSortOption.nameDesc, 'Name (Z-A)'),
              ],
        ),
        IconButton(
          icon: const Icon(Icons.settings_backup_restore_outlined),
          tooltip: 'Backup / Restore Data',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const BackupRestoreScreen(),
              ),
            );
          },
        ),
      ],
    );
  }

  PopupMenuItem<TourSortOption> _buildSortMenuItem(
    TourSortOption option,
    String text,
  ) {
    return PopupMenuItem<TourSortOption>(
      value: option,
      child: ListTile(
        // Use ListTile for better structure and padding
        contentPadding: EdgeInsets.zero,
        title: Text(
          text,
          style: TextStyle(fontSize: 14),
        ), // Slightly smaller text
        trailing:
            _currentSortOption == option
                ? Icon(
                  Icons.check,
                  color: Theme.of(context).primaryColor,
                  size: 20,
                )
                : null,
      ),
    );
  }

  // --- Filter Chips Area Builder ---
  Widget _buildFilterArea(ThemeData theme) {
    final Map<String, TourStatus?> filters = {
      'All': null,
      'Created': TourStatus.Created,
      'Started': TourStatus.Started,
      'Ended': TourStatus.Ended,
    };

    return Container(
      margin: EdgeInsets.only(top: 8),
      child: Material(
        // Add Material for elevation and background color
        elevation: 1.0, // Subtle elevation

        color: theme.canvasColor, // Use card color for background
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
          // margin: const EdgeInsets.only(top: 54),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: 4.0,
            ), // Padding for scroll ends
            child: Row(
              children:
                  filters.entries.map((entry) {
                    final label = entry.key;
                    final statusValue = entry.value;
                    final isSelected = _selectedStatusFilter == statusValue;

                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5.0,
                      ), // Spacing between chips
                      child: FilterChip(
                        // Sticking with FilterChip for deselection behavior
                        label: Text(label),
                        selected: isSelected,
                        onSelected: (bool selected) {
                          setState(() {
                            _selectedStatusFilter =
                                selected ? statusValue : null;
                          });
                        },
                        shape: StadiumBorder(
                          side: BorderSide(
                            color:
                                isSelected
                                    ? theme.primaryColor
                                    : Colors.grey.shade300,
                            width: isSelected ? 1.5 : 1.0,
                          ),
                        ),
                        selectedColor: theme.primaryColor.withOpacity(0.15),
                        checkmarkColor: theme.primaryColor,
                        backgroundColor:
                            theme
                                .canvasColor, // Use canvas color for unselected background
                        labelStyle: TextStyle(
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                          color:
                              isSelected
                                  ? theme.primaryColorDark
                                  : theme.textTheme.bodyLarge?.color,
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                    );
                  }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  // --- Body Builder with Layout Logic ---
  Widget _buildTourListBody(
    BuildContext context,
    TourProvider tourProvider,
    List<Tour> toursToShow,
  ) {
    // Loading State
    if (tourProvider.isLoading && toursToShow.isEmpty) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }

    // Empty State
    if (toursToShow.isEmpty) {
      String message = "No tours available."; // Default
      if (_searchQuery.isNotEmpty) {
        message = 'No tours match your search "$_searchQuery".';
      } else if (_selectedStatusFilter != null) {
        String statusName = _selectedStatusFilter.toString().split('.').last;
        message = 'No "$statusName" tours found.';
      } else if (!tourProvider.isLoading && tourProvider.tours.isEmpty) {
        message =
            'No tours yet.\nTap the "+" button to create your first tour!';
      }
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.explore_off_outlined,
                size: 70,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 20),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    // Use LayoutBuilder to switch between ListView and GridView
    return LayoutBuilder(
      builder: (context, constraints) {
        // Define breakpoint for switching to GridView
        const double gridBreakpoint = 800.0; // Adjust as needed
        final bool useGridView = constraints.maxWidth >= gridBreakpoint;

        if (useGridView) {
          // --- Grid View for Larger Screens ---
          // Calculate cross axis count based on width, or use max extent
          final double cardWidth = 450; // Max desired width for a card
          // final int crossAxisCount = (constraints.maxWidth / cardWidth).floor();
          return GridView.builder(
            padding: const EdgeInsets.all(
              16.0,
            ).copyWith(bottom: 80), // Grid padding
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: cardWidth, // Max width for each item
              childAspectRatio:
                  2, // Adjust aspect ratio based on your TourCard height (Width / Height) - TRIAL & ERROR NEEDED
              crossAxisSpacing: 16.0, // Spacing between columns
              mainAxisSpacing: 16.0, // Spacing between rows
            ),
            // gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            //   crossAxisCount: crossAxisCount > 1 ? crossAxisCount : 2, // Ensure at least 2 columns
            //   childAspectRatio: 1.8, // Adjust aspect ratio
            //   crossAxisSpacing: 16.0,
            //   mainAxisSpacing: 16.0,
            // ),
            itemCount: toursToShow.length,
            itemBuilder: (context, index) {
              final tour = toursToShow[index];
              return TourCard(
                // Your improved card
                tour: tour,
                onTap: () => _navigateToTourDetail(context, tour.id!),
              );
            },
          );
        } else {
          // --- List View for Smaller Screens ---
          return ListView.builder(
            padding: const EdgeInsets.symmetric(
              vertical: 8.0,
              horizontal: 12.0,
            ).copyWith(bottom: 80.0),
            itemCount: toursToShow.length,
            itemBuilder: (context, index) {
              final tour = toursToShow[index];
              // Add vertical padding around each card in the list
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 5.0),
                child: TourCard(
                  tour: tour,
                  onTap: () => _navigateToTourDetail(context, tour.id!),
                ),
              );
            },
          );
        }
      },
    );
  }

  // --- Navigation Helpers (Keep as is) ---
  void _navigateToAddTour(BuildContext context, TourProvider tourProvider) {
    // ... (existing logic with mounted checks) ...
    if (tourProvider.people.isEmpty && !tourProvider.isLoading) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Loading people list first...'),
          duration: Duration(seconds: 1),
        ),
      );
      tourProvider
          .fetchAllPeople()
          .then((_) {
            if (context.mounted) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const AddEditTourScreen(),
                ),
              );
            }
          })
          .catchError((e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error loading people: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          });
    } else if (tourProvider.isLoading) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please wait, data is loading...'),
          duration: Duration(seconds: 1),
        ),
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => const AddEditTourScreen()),
      );
    }
  }

  void _navigateToTourDetail(BuildContext context, int tourId) {
    // ... (existing logic with loading dialog and mounted checks) ...
    final tourProvider = Provider.of<TourProvider>(context, listen: false);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (BuildContext context) =>
              const Center(child: CircularProgressIndicator.adaptive()),
    );

    tourProvider
        .fetchTourDetails(tourId)
        .then((_) {
          Navigator.of(context).pop(); // Close loading dialog
          if (context.mounted) {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const TourDetailScreen()),
            );
          }
        })
        .catchError((error) {
          Navigator.of(context).pop(); // Close loading dialog on error
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error loading tour details: $error'),
                backgroundColor: Colors.red,
              ),
            );
          }
        });
  }
}
