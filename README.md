# Hekal Garage ERP & Auto Service Center System

<p align="center">
  <img src="assets/logos/chevrolet.svg" height="48" alt="Brands" />
  &nbsp;&nbsp;&nbsp;&nbsp;
  <img src="assets/logos/mg.svg" height="48" alt="MG" />
  &nbsp;&nbsp;&nbsp;&nbsp;
  <img src="assets/logos/opel.svg" height="48" alt="Opel" />
</p>

<p align="center">
  <strong>Comprehensive, Offline-First Windows Desktop ERP tailored for Automotive Repair Centers, Garages, and Spare Parts Warehouses.</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.47+-02569B?logo=flutter&logoColor=white" alt="Flutter" />
  <img src="https://img.shields.io/badge/Platform-Windows%20x64-0078D6?logo=windows&logoColor=white" alt="Windows x64" />
  <img src="https://img.shields.io/badge/Database-SQLite%20via%20Drift-003B57?logo=sqlite&logoColor=white" alt="SQLite" />
  <img src="https://img.shields.io/badge/Architecture-Clean%20%26%20Riverpod-5B5B5B" alt="Architecture" />
  <img src="https://img.shields.io/badge/Localization-Arabic%20RTL%20Native-brightgreen" alt="Arabic RTL" />
</p>

---

## 📖 Overview

**Hekal Garage ERP** is a modern, high-performance desktop system developed with **Flutter** and **Drift (SQLite)**. Built specifically to handle everyday operational and financial workflows in Egyptian and Arab automotive service centers—from car intake and technical inspection, to parts cataloging, invoice generation, supplier management, and executive financial reporting.

The system is designed with an **offline-first philosophy**: it operates 100% locally with zero internet dependency, zero external cloud fees, and includes built-in **Local Network (LAN) synchronization** to connect multiple computers across the workshop.

---

## ✨ Key Features

### 🚗 1. Work Orders & Workshop Job Cards
- **Vehicle & Customer Intake**: Instant vehicle lookup by plate number, chassis number, make/model/year, and customer contact.
- **Printable A4 Job Cards (كارت أمر شغل ومقايسة)**: Professional printable sheet featuring:
  - Technical diagnostic space for technicians to handwrite findings with a pen.
  - Ticked quick inspection checklist (OBD computer scan, suspension, cooling, brakes, electrics, fluids).
  - Parts and labor requested without disclosing financial invoice totals to the workshop floor.
  - Dedicated returned old parts section (*قسم المرتجعات وقطع الغيار القديمة المستبدلة*).
  - Customizable customer reception disclaimer and garage branding.
- **Lifecycle Tracking**: Workflow stages (*Open ➔ In Progress ➔ Ready ➔ Delivered*).

### 🧾 2. Point of Sale & Invoicing
- **One-Click Invoicing**: Convert completed work orders directly into formal customer invoices.
- **Direct Counter Sales**: Issue quick invoices for retail parts and counter services without a formal work order.
- **Multiple Payment Methods**: Supports Cash, Visa/Debit Card, InstaPay, Mobile Wallets, and Bank Transfers.
- **Dual Printing Formats**: Instant printout in **A4 Full Invoice** and **80mm Thermal Receipt** formats.
- **Arabic Number Speller (Tafqeet)**: Automatically converts total amounts into written Arabic currency text (e.g., *فقط خمسة آلاف وثلاثمائة جنيه مصري لا غير*).

### 📦 3. Spare Parts & Inventory Warehouse
- **Stock Movement Ledger**: Complete audit trail for opening stock, purchases, sales, customer returns, supplier returns, and manual adjustments.
- **Low Stock Warnings**: Real-time KPI indicators when critical parts fall below threshold.
- **Physical Stock Count (الجرد الدوري)**: Dedicated stock counting module with automated variance calculation and reconciliation.
- **Excel Import / Export**: Mass-import parts catalogs and export inventory audit reports via `.xlsx`.

### 🤝 4. Suppliers & Purchasing Management
- Record supplier purchase invoices, track payment history, monitor credit balances, and manage supplier payment vouchers.

### 👥 5. Employees & Payroll
- Technicians and receptionists directory, monthly salary management, advance payments (سلف), and commission tracking.

### 📊 6. Executive & Financial Reports
- Interactive charts and date-filtered tables for:
  - **Sales & Revenue**: Breakdown by parts vs. labor services.
  - **Net Profit & Cost Analysis**: Profit margins based on actual inventory purchase costs.
  - **Customer & Supplier Debts**: Outstanding receivables and payables.
  - **Inventory Valuation**: Current total cost and expected retail value.

### 🌐 7. Local Network (LAN) Multi-Device Sync
- Connect multiple computers inside the workshop (Reception, Management, Warehouse, Workshop floor) to **share the exact same database simultaneously**.
- **Embedded Server**: Master PC runs an embedded local server via WebSockets and Drift Remote Protocol.
- **No Internet Required**: Communicates directly through the local router (Ethernet / Wi-Fi).
- **Auto IP Discovery**: Settings page displays the local IP address for simple 10-second client configuration.

### 🔒 8. Security & Automated Backups
- **Supervisor PIN Protection**: Protect sensitive operations (discounts, cost viewing, record deletion, invoice cancellation, and stock adjustments).
- **Automated Backup on Exit**: Generates automated `.sqlite` snapshots upon application exit (keeps rolling 14-day history).
- **One-Click Manual Backup & Restore**: Export database directly to USB drives or secondary hard disks.

---

## 🛠️ Technology Stack

| Layer | Technology |
| :--- | :--- |
| **Framework** | [Flutter Desktop](https://flutter.dev/) (Windows 10 / 11 x64) |
| **Language** | [Dart](https://dart.dev/) 3.13+ |
| **Database** | [Drift](https://drift.simonbinder.eu/) (Typed SQLite) + `sqlite3_flutter_libs` |
| **State Management** | [Flutter Riverpod](https://riverpod.dev/) 3.x |
| **Navigation** | [GoRouter](https://pub.dev/packages/go_router) |
| **PDF & Printing** | `pdf` + `printing` (Custom Cairo typography & Vector Arabic rendering) |
| **Networking** | Drift Remote Protocol over `dart:io` WebSocket Channels |
| **Window Management**| `window_manager` (Frameless control, min-size enforcement) |

---

## 🚀 Getting Started

### Prerequisites
- Windows 10 or 11 (64-bit)
- [Flutter SDK](https://docs.flutter.dev/get-started/install/windows) (v3.47 or later)
- Visual Studio 2022 Build Tools (with "Desktop development with C++")

### Run from Source
```powershell
# Clone the repository
git clone https://github.com/Amr367/Hekal-Garage-ERP-system.git
cd Hekal-Garage-ERP-system

# Fetch dependencies
flutter pub get

# Run database code generator (if schema changes)
dart run build_runner build --delete-conflicting-outputs

# Launch the app
flutter run -d windows
```

### Build Production Release Executable
```powershell
flutter build windows --release
```
The compiled self-contained release package will be located at:
`build\windows\x64\runner\Release\`

---

## 📦 Deployment & Multi-PC Installation

### Package into Installer
Run the included packaging script to create a standalone distribution ZIP:
```powershell
.\create_package.ps1
```
This generates **`Hekal_Garage_ERP_v1.0.zip`** containing:
1. Complete self-contained application binaries (no Flutter or developer tools needed on client machines).
2. `تثبيت_البرنامج_على_هذا_الجهاز.bat` (Automated 1-click Windows installer script).
3. Automatic Desktop shortcut creation and Windows Firewall rule configuration.

### Multi-PC Setup Guide
1. **Master PC (Server)**:
   - Run the app, navigate to **Settings ➔ Network & LAN (الربط والشبكة)**.
   - Note the displayed local IP (e.g. `192.168.1.50`).
2. **Client PCs**:
   - Extract the package and run `تثبيت_البرنامج_على_هذا_الجهاز.bat` as Administrator.
   - Open the app, navigate to **Settings ➔ Network & LAN**, choose **Client (جهاز فرعي)**, and input the Server's IP address.
   - Click **Test Connection (فحص الاتصال)**, save, and restart. All changes now sync across all screens in real-time!

---

## 📄 License

This software is developed and maintained for automotive service centers. All rights reserved.
