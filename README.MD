# 🧳 Btour – Tour Expense Tracker

**Btour** is a simple yet powerful Flutter app to manage shared expenses for group tours and trips. Track expenses, manage participants, and generate transparent reports to settle costs fairly.

---

## ✨ Features

### 🗺️ Tour Management
- Create and manage tours with:
  - Name
  - Start Date
  - Participants
  - Advance Amount and Advance Holder
- Statuses: `Created`, `Started`, `Ended`
- View active and finished tours with summary cards

### 👥 Person Management
- Add and manage people globally or per tour
- Unique names for easy selection
- Assign people as:
  - Tour Participants
  - Advance Holder
  - Expense Attendees
  - Expense Payers

### 📦 Expense Tracking
- Record expenses per tour with:
  - Category (e.g., Food, Travel, Accommodation)
  - Amount, Date, Description
  - Attendees (who benefited)
  - Payers (who paid how much)
- Supports multiple payers with individual amounts
- Expense total always deducted from tour’s advance for consistency

### 🧾 Categories
- Define global expense categories
- Link each expense to a category for better reporting

### 📊 Reporting
- **Tour Summary**: Advance vs. Total Spent vs. Remaining
- **Individual Contributions**:
  - See who paid how much from their own pocket
  - Helps track debt settlement among group members

### 💾 Offline Persistence
- All data is stored **locally** using `sqflite`
- No internet required

### 📱 User Interface
- Clean, intuitive Flutter UI
- Tour list view with filters
- Tour detail view with tabs:
  - Overview
  - Expenses
  - Participants
  - Reports
- Forms for adding/editing tours and expenses
- Smart UI controls:
  - Autocomplete, Dropdowns, Date Pickers, Chips

---

## 🧱 Core Entities

| Entity     | Description |
|------------|-------------|
| **Tour**   | A group trip/event with participants, expenses, and advance tracking |
| **Person** | A participant in one or more tours |
| **Category** | Global list of expense types |
| **Expense** | A specific payment event with category, payers, and attendees |

---

## 🗂️ Folder Structure (Planned)

lib/
├── models/ # Data models (Tour, Person, Expense, etc.)
├── screens/ # UI screens (TourList, TourDetail, Forms)
├── widgets/ # Reusable UI components
├── db/ # Sqflite DB helpers and DAOs
├── providers/ # State management (e.g., Riverpod/Provider)
└── main.dart # Entry point


---

## 🛠️ Tech Stack

- **Flutter** – UI framework
- **Sqflite** – Local persistent storage
- **Dart** – Programming language
- **Material Design** – UI components and behavior

---

## 🚀 Getting Started

### Prerequisites

- Flutter SDK
- A device/emulator to run the app

### Installation

```bash
git clone https://github.com/badarsaghir/btour.git
cd btour
flutter pub get
flutter run
```

## 📌 Future Enhancements
- Google Drive Sync
- PDF Report Export
- Shared Expenses Summary Across Tours
- Themes & Dark Mode

## 🧑‍💻 Contributing

Contributions are welcome! Please open an issue or submit a pull request for features, bug fixes, or ideas.

