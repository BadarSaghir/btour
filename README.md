
# Btour
## Requirements

1.  **Core Entities:**
    *   **Tour:** Represents a trip or event.
    *   **Person:** Represents an individual involved in tours.
    *   **Category:** Represents types of expenses (e.g., Food, Travel, Accommodation).
    *   **Expense:** Represents a specific spending instance within a tour and category.

2.  **Tour Functionality:**
    *   **Creation:** Create a new tour with a Name, Start Date, list of Participants (People), an Advance Amount, and an assigned Person responsible for the advance (Advance Holder).
    *   **Status:** Tours can have statuses: `Created`, `Started`, `Ended`.
    *   **Modification:** Ability to edit tour details (perhaps before it's ended). Ability to start/end a tour.
    *   **Participants:** Manage the list of people participating in the tour.
    *   **Display:**
        *   Active tours listed separately or clearly marked.
        *   Finished tours displayed as distinct cards showing essential summary info: Name, Date Range (From-To, if applicable), Participants list (or count), Advance Amount, Total Spent, Remaining Amount.

3.  **Person Functionality:**
    *   **Management:** Ability to add new people (globally or per tour). Names should likely be unique for easier selection.
    *   **Association:** Link people to tours as participants and as the advance holder. Link people to expenses as attendees and payers.

4.  **Category Functionality:**
    *   **Management:** Ability to define expense categories (e.g., 'Food', 'Travel'). These could be global or per tour (global seems simpler to start).
    *   **Association:** Link expenses to a specific category.

5.  **Expense Functionality:**
    *   **Creation:** Add a new expense associated with a specific `Tour`.
    *   **Details:** Each expense needs:
        *   `Category` (selected from predefined list).
        *   `Amount` (total cost of the expense).
        *   `Date` (defaults to today, but user can select a past date).
        *   `Description` (optional text).
        *   `Attendees`: Select people (from the tour participants) who benefited from or attended this specific expense event. Use autocomplete/dropdown based on previous interactions or tour participants. Allow adding a new person if necessary (should probably add them to the tour participants list too).
        *   `Payers`: Record who paid for *this specific* expense.
            *   Defaults to the Tour's Advance Holder paying the full amount.
            *   Allows specifying multiple people paying portions of the *expense amount*.
            *   **Crucially:** The *total expense amount* is always deducted from the *Tour's advance amount* for reporting purposes, regardless of who physically paid using their own cash at the time.
    *   **Modification:** Ability to edit existing expenses.

6.  **Reporting:**
    *   **Tour Summary:** For each tour (especially finished ones), calculate and display: Total Advance, Total Spent (sum of all expense amounts for the tour), Remaining Advance.
    *   **Individual Spending Report:** For a given tour, show a breakdown of how much cash each person *physically paid out* across all expenses (summing their contributions from the `Payers` section of each expense). This helps settle debts *if* people used their own money beyond the advance. *Note: The primary deduction is always from the advance pool.*

7.  **Persistence:**
    *   All data (Tours, People, Categories, Expenses, relationships) must be stored locally using `sqflite`.

8.  **User Interface (Flutter):**
    *   Simple, functional UI.
    *   List view for tours.
    *   Detail view for a selected tour (possibly using Tabs for Overview/Expenses/People/Reports).
    *   Forms for creating/editing Tours and Expenses.
    *   Use appropriate widgets for selection (Dropdowns, Autocomplete, Date Pickers, Chips).

9.  **Automation (Node.js Script):**
    *   A script that reads the Flutter code provided within Markdown code blocks.
    *   Identifies target file paths (using a convention like `// FILE: path/to/your/file.dart` on the first line of the code block).
    *   Creates necessary directories.
    *   Writes the code content into the specified files.

---

Now, let's structure the Flutter application and provide the code.

**Project Setup:**

1.  Create a new Flutter project: `flutter create tour_expense_app`
2.  Open the project in your IDE (like VS Code).
3.  Add dependencies to `pubspec.yaml`:
    ```yaml
    dependencies:
      flutter:
        sdk: flutter
      sqflite: ^2.3.0 # Check for latest version
      path: ^1.8.3   # Usually included with flutter, but good to be explicit
      intl: ^0.18.1  # For date formatting (check latest)
      provider: ^6.1.1 # Simple state management (optional but recommended)

    dev_dependencies:
      flutter_test:
        sdk: flutter
      flutter_lints: ^2.0.0 # Or newer
    ```
4.  Run `flutter pub get`.

---
