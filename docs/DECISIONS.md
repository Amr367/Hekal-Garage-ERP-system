# Decisions

## Phase 0

### Project location

The app lives in `D:\Hekal`, not `C:\dev\garage_erp`. The path is plain ASCII with no spaces. Flutter Windows builds break or lock when the path contains Arabic characters or the folder is synced by OneDrive. Confirm this drive is not a OneDrive/Desktop synced folder before relying on daily builds.

### Flutter SDK location

Flutter is installed at `C:\dev\flutter` (stable 3.47.8, Dart 3.13.7). The SDK is kept outside the app repo so upgrades do not mix with project history.

### Visual Studio vs Build Tools

The machine had no Visual Studio. Phase 0 installed **Visual Studio 2022 Build Tools 17.14.42** with the `VCTools` workload, MSVC 14.44, CMake, and Windows 11 SDK 10.0.26100. That is enough for Flutter Windows. The full Community IDE is not required. Android SDK was not installed on purpose.

### No database in Phase 0

There was no attached `database.dart`. The Drift schema, `garage.sqlite`, repositories, and seed data are authored in **Phase 2** from the master prompt data model. Phase 0 only reserves `lib/core/db/`.

### Packages

Only packages listed in the master prompt are used. `cupertino_icons` from `flutter create` was removed. Versions are the latest compatible with Flutter 3.47 / Dart 3.13 at the time of bootstrap.

### Fonts

Google currently ships Cairo as one variable TTF (`Cairo[slnt,wght].ttf` from `google/fonts`). Static Regular/SemiBold/Bold files are not published on that tree. The variable file is copied to `assets/fonts/Cairo-Regular.ttf`, `Cairo-SemiBold.ttf`, and `Cairo-Bold.ttf` and registered at weights 400, 600, and 700 so the UI and later PDFs stay offline. Phase 1 will confirm joining and mixed Arabic/English in print.

### Offline rule

The app does not call the network, load Google Fonts at runtime, or send telemetry.

---

## Phase 1 — Arabic Printing Spike

### Arabic PDF Rendering Approach

The `pdf` package natively supports RTL layout and Arabic text reshaping when:
1. `pw.MultiPage` or `pw.Page` specifies `textDirection: pw.TextDirection.rtl`.
2. A true Arabic Unicode font is loaded (`Cairo-Regular.ttf`, `Cairo-SemiBold.ttf`, `Cairo-Bold.ttf`) and configured on the `pw.ThemeData`.
3. In `pdf`, `pw.Row` automatically inherits RTL directionality from the enclosing page context (`Directionality.of(context)`). Calling `textDirection` on `pw.Row` is invalid as `Flex` checks context.

### Evaluation of Arabic Rendering

| Test Item | Status | Notes |
| :--- | :--- | :--- |
| **Letter joining (تشبيك الحروف)** | سليم 100% | حزم الحروف متصلة بشكل طبيعي مع خط Cairo |
| **Directionality (RTL)** | سليم 100% | الجداول والمحاذاة تبدأ من اليمين لليسار |
| **Lam-Alef Ligature (لا)** | سليم | تظهر متصلة ومضبوطة |
| **Mixed Arabic + English runs** | سليم | مصطلحات مثل `MANN` و `5W-30` تظهر في مكانها الصحيح |
| **Western Numbers** | سليم | الأرقام إنجليزية (0-9) مع فواصل آلاف دون انقلاب الترتيب |
| **Arabic-Indic Numbers** | سليم | تظهر كما هي بدون تشويه |
| **Parentheses in RTL** | سليم | الأقواس تحيط بالكلمة بشكل صحيح |
| **Unbroken Word Wrapping** | سليم | الكلمات الطويلة تلتف بدون قطع غير منطقي |
| **Multi-page Pagination** | سليم | الفاتورة 25 سطر ترحل للصفحة 2 مع ترقيم "صفحة 1 من 2" |
| **80mm Receipt Continuous Height** | سليم | إيصال مدمج بعرض 80 مم بدون فواصل صفحات عشوائية |

### Printer Integration Decision

- **Interactive printing:** Use `Printing.layoutPdf` which invokes the native Windows Print dialog, allowing printer selection and scale verification (100% actual size).
- **Direct thermal receipt printing:** Use `Printing.directPrintPdf` when a thermal printer is selected in settings, avoiding annoying dialog popups for counter receipts.
- **Save as PDF fallback:** Exporting raw bytes directly to the user's `Documents` directory guarantees an offline paper trail even if printers run out of paper or disconnect.
- **RepaintBoundary fallback:** Rendering Flutter widgets to 300 DPI images was evaluated as fallback (d), but not needed because the Cairo TTF vector pipeline produced 100% sharp, selectable Arabic text directly.

---

## Phase 2 — Database Layer

### SQLite PRAGMA Choices: Durability over Raw Speed

1. **`PRAGMA foreign_keys = ON;`**:
   Guarantees relational integrity at the database engine level. Prevents orphan records across customers, vehicles, work orders, invoices, and payments.
2. **`PRAGMA synchronous = FULL;`**:
   In Egyptian workshops and commercial areas, sudden electrical power cuts or unplugging laptops without proper shutdown can corrupt database files. While `NORMAL` is faster for micro-benchmarks, `FULL` ensures that every SQLite commit is physically flushed to disk before the transaction completes. Durability is non-negotiable for business data and money.
3. **`PRAGMA journal_mode = WAL;` (Write-Ahead Logging)**:
   Provides high concurrent read performance while writes are occurring and substantially reduces write amplification compared to the rollback journal mode.

### Money Representation

- Complies with Domain Rule **R1**: Money is strictly integer piasters (`int`) across all database columns, domain entities, and calculations. Never `double` or `float` to avoid IEEE 754 floating-point rounding errors.
- `MoneyUtils` parses user inputs supporting Egyptian currency specifics:
  - Western digits `0-9` and Arabic-Indic digits `٠-٩`.
  - Arabic comma `،`, Arabic decimal separator `٫`, and English `.`.
  - Arabic thousands separator `٬` and English `,`.
  - Enforces at most 2 decimal places (piasters) and rejects 3+ decimals.

### Stock Ledger Immutability

- Complies with Domain Rules **R2, R3, and R4**:
  - `StockMovements` records are insert-only and never updated or deleted.
  - On-hand stock is strictly computed via `SUM(stock_movements.qty)`.
  - Corrections and counts are recorded as new explicit movements (`adjustment` or `countDiff`).
  - All stock adjustments flow through `StockService`, ensuring single-point auditing and negative-stock prevention.

### Sequential Document Numbering

- Complies with Domain Rule **R6**:
  - `nextInvoiceNumber()` and `nextWorkOrderNumber()` are computed inside transactions using `MAX(number) + 1` (or initial starting number).
  - Cancelled documents retain their sequence numbers and are never deleted, ensuring zero gaps and zero duplicates.

---

## Phase 3 — App Shell and Design System

### RTL Desktop Sidebar Navigation

- In Arabic RTL mode, the primary navigation sidebar naturally lives on the right edge of the screen, providing familiar eye-tracking for right-to-left readers.
- To prevent layout overflow on Windows desktop environments with high DPI display scaling (e.g., 125% or 150% scaling where effective window height is constrained), sidebar navigation items are housed in a scrollable `ListView.separated`. This eliminates any risk of `RenderFlex` overflow even at the minimum supported window size of 1100×700.

### Virtualized Desktop Data Tables

- Enterprise and warehouse inventory tables often display thousands of items. Standard `DataTable` or `Column` layouts inflate every row widget into memory, creating visible frame drops and UI freezes.
- `AppDataTable<T>` was implemented using a virtualized `ListView.builder` with fixed item extent (`rowHeight = 48px`). Only visible rows are rendered to the compositor, ensuring sustained 60fps scrolling performance even across 10,000+ stock ledger records.

### Touch and Click Target Ergonomics

- All interactive controls enforce a minimum height of 44px (`ElevatedButton`, `OutlinedButton`, `FilledButton`, `TextButton`, `TextFormField`, and `MoneyField`).
- This ergonomic baseline satisfies industrial workshop conditions where service advisors or warehouse staff operate on touch-screen laptops or use mice with coarse tracking.

### Digit and Currency Input Processing

- Egyptian workshop users frequently type Arabic numbers using standard keyboard layouts or Arabic-Indic numerals (`٠-٩`).
- `MoneyField` and `QtyField` automatically normalize all input characters (`٠-٩`, `۰-۹`, `٫`, `،`) to standard decimal formats on the fly and store values strictly as integer piasters and 3-decimal floating quantities, guaranteeing domain integrity without user frustration.

---

## Phase 4 — Settings, Auth/PIN, and Garage Profile

### Salted PIN Hashing (Domain Rule R12)

- Under Rule R12, secret 4-digit PINs are never stored in plain text.
- Security architecture:
  1. A 32-character random hex salt is generated per installation/update using `Random.secure()`.
  2. The raw PIN is normalized to Western digits (`MoneyUtils.normalizeDigits`) to avoid mismatches between Arabic-Indic and Western keyboards.
  3. The normalized PIN is concatenated with the salt (`$salt:$normalizedPin`) and hashed with SHA-256 (`package:crypto`).
  4. Only the salt and the SHA-256 hex digest are stored in the `app_settings` SQLite table.
- Permission gating (`checkPermission`):
  Sensitive operations (manual discount, cost price visibility, stock adjustment, voiding invoices) invoke `PinAuthService.checkPermission(context)`. If PIN protection is enabled, a modal `PinDialog` is displayed. If verified, the operation proceeds; otherwise, an alert snackbar is raised and the action is blocked.

### Offline Logo Durability

- When the user selects a logo image via `file_picker`, referencing the original path (e.g., in `Downloads` or `Desktop`) exposes the application to broken image links if the user moves or deletes the source file.
- The system automatically copies the selected logo file into the local application support directory (`getApplicationSupportDirectory()`) as `garage_logo.ext` and saves this internal path. This guarantees that invoices and receipts always have access to the logo completely offline.

### Reactive State Management with Riverpod AsyncNotifier

- Settings are managed using Riverpod 3's `AsyncNotifier` pattern (`garageProfileProvider`, `printerSettingsProvider`, `securitySettingsProvider`).
- Updates are written to the database asynchronously while maintaining optimistic in-memory state. Any component in the app (such as invoice printing or the navigation header) automatically reacts to profile or printer updates without requiring manual refresh or app restart.

---

## Phase 5 — Customers and Vehicles

### Multi-Field Smart Search
- Searching customer records in an automotive service context requires finding customers by customer name, phone number, or vehicle license plate.
- The smart search engine normalizes digits and whitespace, performs direct substring matching on `customers.name` and `customers.phone`, and simultaneously queries `vehicles.plateNumber`. Any vehicle matching the plate returns its owning customer, unifying customer discovery into a single fast search bar without requiring separate tabs or search modes.

### Vehicle Ownership Transfer and Preservation of History (Rule R14)
- Domain Rule R14 requires that when a vehicle is transferred from customer A to customer B, the complete historical record of past work orders, repairs, and invoices remains attached to the vehicle.
- `VehiclesRepository.transferOwnership` updates the `vehicles.customerId` foreign key while leaving all existing `WorkOrders` records pointing to `vehicleId`. Historical work orders thus remain visible under the vehicle's maintenance log.
- An immutable audit entry is recorded in the `app_settings` key-value store with timestamp, vehicle plate, previous owner, new owner, and optional transfer notes.

### Real-Time Financial Statement & Debt Calculation
- Customer balances are calculated dynamically from non-cancelled issued invoices: `balance = SUM(totalAmount) - SUM(paidAmount)`. Cancelled invoices are automatically excluded.
- Positive balances (debt owed by customer) are highlighted in high-contrast red (`AppColors.error`), while settled accounts (0 EGP) are styled in green (`AppColors.success`).
- The `CustomerStatementDialog` provides an instant ledger breakdown of all invoices, amounts, payments, remaining debts, and statuses.

---

## Phase 6 — Inventory, Categories, and Stock Service

### Immutable Stock Ledger & Running Balances (Rules R2 & R3)
- Rather than maintaining a mutable `current_stock` column on the items table, `StockService` computes on-hand stock via `SUM(stock_movements.qty)`. This prevents drift, race conditions, and untracked discrepancies.
- The `getItemLedger` method evaluates the chronological sequence of all movements for an item (`ORDER BY created_at ASC, id ASC`) and computes the cumulative forward running balance (`balanceAfter`) for each movement.
- The `ItemLedgerDialog` presents this as a traditional warehouse stock card (كارت حركة صنف) showing every in/out movement with timestamp, type badge, quantity change, running balance, and notes.

### Negative Stock Prevention (Rule R4)
- Domain Rule R4 strictly forbids stock deductions that would reduce on-hand balance below zero.
- In `StockService.recordMovement` and `StockAdjustmentDialog`, any negative adjustment checks `currentStock + qty < 0`. If violated, a typed `BusinessRuleException` is thrown carrying an informative Arabic error message (`AppStrings.negativeStockNotAllowed`), blocking the transaction before SQLite commit.

### Protected Cost Price & Valuation Visibility (Rule R12)
- Cost prices and total warehouse purchase valuations are commercially sensitive in service centers and workshops where walk-in customers or front-desk staff might see the screen.
- Cost values in the KPI cards and data table are masked by default (`*** ج.م`).
- Revealing cost prices requires pressing the reveal toggle button (`إظهار التكلفة`), which invokes `PinAuthService.checkPermission()`. If a PIN is configured, the action is gated by `PinDialog`.

### Safe Category Merge and Deletion Guard (Rule R10)
- `CategoriesRepository.deleteCategory` strictly checks for existing items assigned to the category. Deletion is blocked if items exist, presenting an actionable error advising the user to reassign or merge items first.
- The category merge workflow (`CategoriesRepository.mergeCategories`) allows bulk reassigning all items from a source category to a target category within a single atomic transaction before removing the source category.

### Table Layout & Desktop Sizing Ergonomics
- To avoid horizontal crowding in desktop headers, search fields and category filter chips are placed in a dedicated toolbar row inside the page body above `AppDataTable`.
- `AppDataTable` row height for inventory items is set to `52px` to comfortably display two lines of text (bold item name + category subtitle) across varied display scalings without vertical overflow.

---

## Phase 7 — Work Orders (أوامر الشغل)

### Gap-Free Sequential Work Order Numbering (Rule R6)
- Sequential numbering for work orders uses `_db.nextWorkOrderNumber()`, which computes `COALESCE(MAX(order_number), 0) + 1` inside an atomic transaction.
- Cancelled work orders retain their order numbers and are never deleted, ensuring there are zero gaps and zero duplicates in the business sequence.
- Formatters provide human-readable display with `#` prefix (e.g. `#1`, `#0012`).

### Isolated Order Number Search via `#` Prefix
- Egyptian mobile numbers start with `01...` containing `'1'`. A generic text search with `'1'` naturally matches almost every Egyptian phone number.
- To provide instant lookup by work order number without collisions with phone numbers or plate numbers, smart search supports an explicit `#` prefix (e.g. `#1`, `#15`). When present, the query strictly filters `workOrders.orderNumber == X`.
- General text queries without `#` continue to search across customer name, customer phone, license plate number, normalized plate, and order number simultaneously.

### Automatic Odometer Tracking
- When a work order is saved (created or updated), the entered odometer reading is compared against `vehicles.lastOdometer`.
- If the new reading is greater than the recorded reading, `vehicles.lastOdometer` is automatically updated in the database.
- Lower readings are preserved without error to allow historical entries or correction of clerical mistakes while ensuring the latest mileage is tracked for maintenance intervals.

### Work Order Deletion Protection (Rule R10)
- Domain Rule R10 forbids deleting operational documents once downstream financial documents exist.
- `WorkOrdersRepository.deleteWorkOrder` checks if any invoice points to the work order (`invoices.workOrderId == id`). If found, deletion is blocked and a `BusinessRuleException` is thrown (`AppStrings.cannotDeleteWorkOrderInvoiced`).
- For orders without invoices, the order and all its line items are deleted inside a single atomic transaction.

### Printable Workshop Job Card (كارت الورشة الداخلي)
- Service technicians require a physical work order (كارت الورشة) detailing vehicle specifications, chassis number, customer complaint, labor lines, and required spare parts.
- `JobCardBuilder` generates an A4 Arabic document using vector PDF rendering with Cairo TTF fonts:
  - Header with garage branding and order metadata.
  - Two-column vehicle & customer identification panel.
  - Prominent customer complaint box.
  - Multi-line table separating services and parts.
  - Totals box with labor subtotal, parts subtotal, and estimated total.
  - Receptionist and technician signature boxes.
- Direct printing is wired through `Printing.layoutPdf`, providing native Windows printing support.

### Vehicle Intake with Customer Complaint (استلام السيارة وشكوى العميل)
- Upon vehicle intake at the workshop reception, the customer complaint (`complaint`) is captured alongside the odometer reading (`odometerIn`), vehicle ID, and assigned mechanic.
- The complaint is given first-class prominence on the master-detail panel, the editable intake form, and the printed workshop Job Card so workshop technicians and service advisors are fully aligned on the customer's issues.

### Vehicle Delivery, Invoice Verification, and Payment Methods (تسليم السيارة وتأكيد الفاتورة وطرق الدفع)
- Per user specification (*"في امر الشغل عند استلام عربيه تعمل امر الشغل بي شكوي العميل تسليم تتاكد من فاتوره و تعرف طريقه دفع فودفون كاش او انستا باي او خزنه فرع"*):
  1. **Invoice Verification (التأكد من الفاتورة):**
     - Before or during vehicle handover, the system verifies whether an invoice has already been issued for the work order.
     - If not already issued, the delivery process issues a sequential invoice (Rule R6) reflecting services and spare parts lines.
     - Warehouse spare parts are atomically deducted via `StockService.addMovement` using `StockMovementType.saleOut` (Rules R2, R3, R4) and the current unit cost price is captured as a snapshot on each invoice line (Rule R8).
  2. **Payment Method Capture (طرق الدفع):**
     - Supports the three primary Egyptian automotive workshop channels plus card payments:
       - **خزنة الفرع (نقدي / كاش):** `PaymentMethod.cash`
       - **فودافون كاش (محفظة إلكترونية):** `PaymentMethod.wallet`
       - **إنستاباي (InstaPay):** `PaymentMethod.instapay`
       - **بطاقة / فيزا:** `PaymentMethod.card`
  3. **Payment Reference & Balance Accounting:**
     - A dedicated payment reference field (`paymentReference`) records the wallet transfer number (e.g., Vodafone Cash sender phone number) or InstaPay reference code.
     - Paid amount and remaining balance are recorded as integer piasters (Rule R1). If partial payment is made, remaining customer debt is tracked.
  4. **Atomic SQLite Transaction:**
     - The entire handover (invoice creation, stock deduction, payment recording, and status transition to `WorkOrderStatus.delivered`) executes in a single database transaction, guaranteeing 100% data and inventory consistency even during unexpected app crashes or power interruptions.


