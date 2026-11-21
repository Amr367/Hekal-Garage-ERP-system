# Progress

## Current phase

Delivery hardening — backup/restore, close-to-backup, integrity check, and release guards: **in progress / completed**. All operational phases 0–9 plus invoicing, reports, and services are in the codebase.

## Completed

### Phase 0 — Environment and bootstrap
- Git repository at `D:\Hekal` (ASCII path, no spaces).
- Flutter stable 3.47.8 / Dart 3.13.7 installed at `C:\dev\flutter` and added to the user PATH.
- Visual Studio 2022 Build Tools with VCTools and Windows 11 SDK 10.0.26100.
- Windows desktop enabled; project created with `--platforms=windows`.
- Allowed packages, Cairo font assets, lint rules, feature-first folders, RTL placeholder app, and docs added.
- `flutter analyze` is clean, widget tests pass, `flutter build windows --debug` succeeds.

### Phase 1 — Arabic printing spike
- Created `PdfFontLoader` caching Cairo Regular, SemiBold, and Bold from assets.
- Built `A4InvoiceBuilder` with 25 line items verifying multi-page pagination, page numbers ("صفحة 1 من 2"), totals, and RTL tables.
- Built `ReceiptBuilder` for 80mm thermal receipts with continuous height and compact layout.
- Added comprehensive torture-test strings (mixed Arabic/English, lam-alef ligature, diacritics, parentheses, unbroken wrapping, Western & Arabic-Indic numbers).
- Built `/dev/print-test` debug-only screen with preview, print dialog, direct print, and save PDF actions.
- Added unit tests in `test/printing_test.dart` for money formatting and PDF document generation.
- Verified `flutter analyze` clean with 0 warnings/errors.
- Verified all unit and widget tests pass.
- Verified Windows desktop debug build succeeds.

### Phase 2 — Database layer
- Authored authoritative Drift schema in `lib/core/db/database.dart` with 17 tables, integer enums, and PRAGMAs (`foreign_keys = ON`, `synchronous = FULL`, `journal_mode = WAL`).
- Generated Drift code via `build_runner` into `lib/core/db/database.g.dart`.
- Exported Drift schema dump for version 1 to `drift_schemas/drift_schema_v1.json`.
- Implemented `MoneyUtils` with parsing of Arabic-Indic digits, thousands/decimal separators, 2-decimal enforcement, overflow checks, and formatting round-trips.
- Implemented `Formatters` with Rule R13 plate normalizer and quantity formatting without trailing zeros.
- Implemented typed `AppException` hierarchy carrying user-facing Arabic messages.
- Implemented repositories: Customers, Vehicles, Services, Categories, Items, Suppliers, Settings.
- Implemented `StockService` strictly observing Rule R2 (SUM movements), Rule R3 (single service), and Rule R4 (negative stock block with missing items list).
- Implemented `NumberingService` for sequential invoice and work-order numbering without gaps.
- Implemented `SeedData` offering 15 common maintenance services and 10 categories, loading only once.
- Implemented database connection with application support directory persistence (`garage.sqlite`), in-memory test mode, path logging on startup, and explorer opener.
- Configured Riverpod providers with automatic database closing on dispose.
- Added comprehensive unit tests in `test/db_test.dart` (22/22 tests passing across whole suite).
- Verified `flutter analyze` clean with 0 warnings/errors.
- Verified Windows desktop debug build succeeds.

### Phase 3 — App shell and design system
- Authored design tokens in `lib/core/theme/app_colors.dart` (Deep Slate Teal `#1F4E5F`, Semantic Success `#2E7D32`, Danger `#D32F2F`, Warning `#ED6C02`).
- Built Material 3 light theme in `lib/core/theme/app_theme.dart` with Cairo font, high contrast, and >= 44px minimum height for all interactive targets (Buttons, TextFields, Table Rows).
- Centralized all UI strings in `lib/core/strings.dart` (no hard-coded Arabic in widgets).
- Built reusable core UI components in `lib/core/widgets/`:
  - `AppScaffold`: Standard desktop header bar (title, subtitle, actions) and flexible/scrollable content.
  - `SearchField`: Desktop search field with 250ms debounce and clear button.
  - `AppDataTable`: Virtualized high-performance table using `ListView.builder` with sorting, hover effects, empty and loading states.
  - `MoneyField`: Input for Egyptian Pounds strictly backed by integer piasters, converting Arabic-Indic digits and validating formats.
  - `QtyField`: Input for quantities supporting up to 3 decimal places (Rule R4) and digit normalization.
  - `ConfirmDialog`: Modal confirmation dialog with Enter/Esc keyboard shortcuts and destructive action styling.
  - `PinDialog`: 4-digit masked PIN modal with Arabic-Indic digit normalization.
  - `AppFormDialog`: Standard dialog container with title, scrollable form, actions, and Esc shortcut.
  - `StateViews`: `EmptyState`, `ErrorState`, and `AppSnackbar` notification helpers.
- Built navigation architecture in `lib/core/navigation/`:
  - `AppShell`: Right-side RTL sidebar, responsive scrollable navigation, branding, version footer, and desktop keyboard shortcuts (Ctrl+P, Ctrl+1..9).
  - `GoRouter`: ShellRoute hosting all 9 main feature routes plus `/dev/print-test`.
- Implemented feature placeholder pages in `lib/features/`:
  - `DashboardPage`: 4 KPI metric cards, quick actions bar, and recent orders table.
  - `WorkOrdersPage`, `InvoicesPage`, `CustomersPage`, `InventoryPage`, `PurchasesPage`, `StockCountPage`, `ReportsPage`, `SettingsPage`.
- Updated `lib/main.dart` with `MaterialApp.router` using `appRouter`, Cairo font, and RTL directionality.
- Added comprehensive unit and widget tests across `test/widgets_test.dart` and `test/widget_test.dart`.
- Verified `flutter analyze` clean with 0 warnings/errors.
- Verified all 38 tests pass across the entire suite.

### Phase 4 — Settings, auth/PIN, and garage profile
- Implemented `PinAuthService` strictly enforcing Domain Rule **R12**:
  - Cryptographically secure 32-character random hex salt (`Random.secure()`).
  - SHA-256 salted PIN hashing (`sha256("$salt:$pin")`). PIN is never stored in plain text.
  - Normalization of Arabic-Indic digits (`٠-٩` -> `0-9`).
  - PIN setup, update with current PIN verification, disable/enable, and permission gatekeeper (`checkPermission`).
- Implemented domain models:
  - `GarageProfile`: Name, subtitle, phone numbers, address, tax number, commercial reg, invoice footer note, logo path.
  - `PrinterSettings`: Default A4 printer, default 80mm thermal receipt printer, paper size, auto-print on save.
  - `SecuritySettings`: PIN status, sensitive operation flags (manual discount, cost price reveal, stock adjustments, voiding invoices).
- Implemented Riverpod AsyncNotifiers and providers in `settings_controller.dart`:
  - `garageProfileProvider` with offline logo file copying to application support directory.
  - `printerSettingsProvider` and `installedPrintersProvider` (dynamically scanning Windows printers via `Printing.listPrinters()`).
  - `securitySettingsProvider` and `pinAuthServiceProvider`.
  - `databaseInfoProvider` displaying live database path and file size.
- Implemented Settings UI components in `lib/features/settings/presentation/widgets/`:
  - `ProfileSettingsCard`: Branding, contact info, logo picker with image preview and delete action.
  - `PrinterSettingsCard`: Dropdowns for connected printers, paper size chips, auto-print switch, direct A4 and 80mm test print buttons.
  - `SecuritySettingsCard`: PIN status banner, setup/change PIN modal dialog (`SetPinDialog`), operation toggles, PIN verification test.
  - `DatabaseSettingsCard`: SQLite path display, file size, explorer folder opener, and seed data loader.
- Implemented full `SettingsPage` with 4 desktop tabs (بيانات المركز، إعدادات الطابعات، الأمان ورمز PIN، قاعدة البيانات والصيانة).
- Added comprehensive unit and widget tests in `test/settings_test.dart` (11 tests).
- Verified `flutter analyze` clean with 0 warnings/errors.
- Verified all 49 tests pass across the full test suite.
- Verified Windows desktop debug build succeeds.

### Phase 5 — Customers and vehicles
- Enhanced `CustomersRepository` with:
  - Smart search matching customer name, phone (supporting Arabic-Indic digits `٠-٩`), and vehicle plate numbers (returning owning customer).
  - Phone normalization and uniqueness check against duplicate phone numbers.
  - Account statement and balance calculation in piasters (`totalAmount - paidAmount` for issued invoices, excluding cancelled).
  - `CustomerSummary` and `CustomerDetails` retrieval.
  - Deletion guard per Domain Rule **R10** (blocking deletion if customer has work orders or invoices).
- Enhanced `VehiclesRepository` with:
  - Plate normalization per Domain Rule **R13** (`Formatters.normalizePlateNumber`).
  - Uniqueness check for plate numbers.
  - Ownership transfer per Domain Rule **R14** (`transferOwnership`), updating customer link while preserving entire maintenance and invoice history, plus logging the transfer in `AppSettings` audit log.
  - `getOwnershipHistory` and `getVehicleWorkOrders`.
  - Deletion guard per Domain Rule **R10** (blocking deletion if vehicle has work orders).
- Implemented domain models in `lib/features/customers/domain/`:
  - `CustomerSummary`: Customer, vehicle count, net balance, total invoiced, total paid, invoices count, work orders count.
  - `CustomerDetails`: Customer, summary, vehicles list, work orders list, invoices list.
- Implemented Riverpod controllers in `lib/features/customers/presentation/customers_controller.dart`:
  - `customersListProvider` (managing search query with debounce, active-only filter, and customer list).
  - `selectedCustomerIdProvider` and `selectedCustomerDetailsProvider`.
  - `VehiclesController` for adding, updating, deleting, and transferring vehicles.
- Implemented UI components and dialogs in `lib/features/customers/presentation/widgets/`:
  - `CustomerFormDialog`: Creating and editing customers with name, phone, notes/national ID, and active toggle.
  - `VehicleFormDialog`: Creating and editing vehicles with live Rule R13 plate normalization preview, make, model, year, color, chassis/VIN, and odometer.
  - `TransferVehicleDialog`: Enforcing Rule R14 with target customer picker, advisory warning, and audit notes.
  - `CustomerStatementDialog`: Account statement modal showing invoice breakdown, amounts, paid, remaining, and status.
  - `CustomerDetailsPane`: Desktop master-detail pane with customer profile, balance badge, vehicles list with quick actions, and maintenance history.
- Implemented full `CustomersPage` with responsive split layout (wide table + detail side pane).
- Added comprehensive unit and widget tests in `test/customers_test.dart` (16 tests).
- Verified `flutter analyze` clean with 0 warnings/errors.
- Verified all 65 tests pass across the entire test suite.

### Phase 6 — Inventory, categories, and stock service
- Authored Arabic UI strings in `lib/core/strings.dart` for all inventory items, stock movements, ledger cards, KPI cards, and category operations.
- Implemented domain models in `lib/features/inventory/domain/`:
  - `ItemWithStock`: Aggregates item entity, category name, stock on hand, min quantity, cost/sale valuation in piasters, profit margin percentage, and `isLowStock`/`isOutOfStock` status getters.
  - `StockMovementEntry`: Wraps individual stock movement with its calculated cumulative running balance after the transaction (`balanceAfter`) and formatted Arabic quantity strings.
  - `InventorySummary`: Holds warehouse statistics (`totalItemsCount`, `lowStockCount`, `outOfStockCount`, `totalCostValuePiasters`, `totalSaleValuePiasters`, `potentialProfitPiasters`).
- Enhanced `CategoriesRepository` with delete protection (blocking category deletion when containing registered items).
- Enhanced `ItemsRepository` with:
  - `getItemsWithStock`: Joins items with categories and calculates real-time on-hand stock via `StockService.getStockOnHand()`.
  - `getItemLedger`: Retrieves chronological immutable movement history with forward running balances.
  - `getInventorySummary`: Aggregates warehouse valuation at cost and sale.
  - Deletion guard per Domain Rule **R10** (blocking deletion if item has historical stock movements).
- Implemented Riverpod controllers in `lib/features/inventory/presentation/inventory_controller.dart`:
  - `inventoryListProvider`: Live async notifier with search query filtering, category dropdown filtering, and low-stock filter toggle.
  - `inventorySummaryProvider`, `categoriesListProvider`, `selectedInventoryItemIdProvider`, and `selectedItemWithStockProvider`.
  - `costPriceRevealedProvider`: State provider for cost visibility gated by PIN.
  - `InventoryActionsController`: Orchestrating item creation with initial opening stock, updating items, deleting items, recording stock adjustments with Rule R4 and R12 verification, adding/renaming/merging/deleting categories.
- Implemented UI widgets and desktop dialogs in `lib/features/inventory/presentation/widgets/`:
  - `InventoryKpiCards`: 4 warehouse metric cards (إجمالي الأصناف، نواقص المخزن، قيمة المخزن بسعر البيع، قيمة التكلفة المحمية برمز PIN مع زر الإظهار/الإخفاء).
  - `ItemFormDialog`: Create and edit items with category selection, SKU, barcode, unit, cost price, sale price, min quantity, and optional opening stock on creation.
  - `CategoriesManagementDialog`: Category management dialog supporting adding new categories, renaming existing categories, merging categories, and safely deleting empty categories.
  - `StockAdjustmentDialog`: Manual stock adjustments (إضافة / خصم) with reason note, PIN verification gate (Rule R12), and negative stock prevention (Rule R4).
  - `ItemLedgerDialog`: Desktop stock card (كارت حركة الصنف) displaying date, movement type badge, change quantity, running balance, and notes in an RTL table.
  - `ItemDetailsPane`: Desktop right-side master-detail panel with item specs, live stock counter badge, pricing cards, and quick action buttons.
- Implemented full `InventoryPage` with KPI summary banner, search and filter toolbar, virtualized data table (`rowHeight: 52`), and master-detail split layout.
- Added comprehensive unit and widget tests in `test/inventory_test.dart` (15 tests: SKU uniqueness, opening stock, manual adjustments, negative stock block, movement ledger, category merge/delete rules, warehouse summary, and UI widget flows).
- Verified `flutter analyze` clean with 0 warnings/errors.
- Verified all 80 tests pass across the entire test suite.
- Verified Windows desktop debug build succeeds (`garage_erp.exe`).

### Phase 7 — Work Orders (أوامر الشغل)
- Authored comprehensive Arabic UI strings in `lib/core/strings.dart` for Work Orders lifecycle (order creation, complaints, assigned mechanics, line items, status progression, KPI metrics, cancellation reasons, and deletion alerts).
- Implemented domain models in `lib/features/work_orders/domain/`:
  - `WorkOrderLineItem`: Line entity representing labor/services or warehouse spare parts with calculated totals in integer piasters (Rule R1) and formatted Arabic quantity/currency displays.
  - `WorkOrderWithDetails`: Complete aggregate model holding work order entity, customer, vehicle, lines list, status badges, subtotals, grand total, and normalized license plate.
  - `WorkOrderSummary`: Desktop metric aggregate holding active work orders, in-progress count, ready count, today count, and estimated valuation.
- Implemented `WorkOrdersRepository` and `DriftWorkOrdersRepository` in `lib/core/db/repositories/work_orders_repository.dart`:
  - Sequential gap-free order numbering via `_db.nextWorkOrderNumber()` (Rule R6).
  - Multi-table joins (`workOrders` join `customers` join `vehicles`) with real-time detail grouping.
  - Multi-field smart search matching customer name, phone number, vehicle plate number, and exact order number (supporting `#` prefix e.g. `#1`).
  - Automatic vehicle odometer updating (`lastOdometer`) if the entered reading is higher than existing record.
  - Status progression workflow (`open` -> `inProgress` -> `ready` -> `delivered`, `cancelled`) with automatic `closedAt` recording.
  - Deletion guard strictly enforcing Domain Rule **R10** (blocking deletion if an invoice has already been issued for the work order).
  - Live aggregated KPI metrics calculation.
- Registered `workOrdersRepositoryProvider` in `lib/core/db/providers.dart`.
- Built printable Arabic A4 Job Card in `lib/features/work_orders/presentation/printing/job_card_builder.dart`:
  - 100% offline PDF vector rendering with Cairo TTF font via `PdfFontLoader`.
  - Professional workshop card containing garage branding, customer/vehicle info box with chassis number and odometer, customer complaint box, services/spare parts table, totals summary, and mechanic/reception signature blocks.
- Implemented Riverpod 3 notifiers and providers in `lib/features/work_orders/presentation/work_orders_controller.dart`:
  - `WorkOrderSearchQueryNotifier`, `WorkOrderStatusFilterNotifier`, `SelectedWorkOrderIdNotifier`, `workOrdersListProvider`, `workOrdersSummaryProvider`, `selectedWorkOrderProvider`, and `WorkOrdersActionsController`.
- Implemented desktop UI widgets and dialogs in `lib/features/work_orders/presentation/widgets/`:
  - `WorkOrdersKpiCards`: 4 desktop summary cards (أوامر قيد العمل، جاهزة للاستلام، استُلمت اليوم، القيمة التقديرية للأوامر الجارية).
  - `WorkOrderFormDialog`: Comprehensive creation/edit dialog with customer/vehicle selection, odometer tracking, complaint specs, mechanic assignment, and an interactive lines editor for adding labor services and warehouse spare parts (with live stock-on-hand availability checks).
  - `ChangeStatusDialog`: Interactive status transition modal enforcing cancellation reason input on cancellation and routing to delivery dialog when transitioning to delivered.
  - `DeliverWorkOrderDialog`: Dedicated desktop vehicle handover dialog verifying invoice items and grand total, capturing payment methods (خزنة الفرع كاش، فودافون كاش، إنستاباي، فيزا), paid/remaining amounts, and wallet/InstaPay transfer reference numbers.
  - `WorkOrderDetailsPane`: Desktop master-detail pane with one-click status advancement button, direct Job Card printing via `Printing.layoutPdf`, customer complaint box, financial summary (invoice number, payment method, reference, paid and remaining amounts), and safe deletion.
- Implemented full `WorkOrdersPage` in `lib/features/work_orders/work_orders_page.dart` with KPI summary banner, search and status chips toolbar, virtualized data table (`rowHeight: 54`), and split master-detail view.
- Added comprehensive unit and widget tests in `test/work_orders_test.dart` (16 tests covering sequential numbering, money totals, odometer tracking, line updates, status transitions, cancellation reason rules, invoice deletion guards, multi-field search, KPI summary metrics, UI page rendering, form validation, details pane actions, status dialogs, delivery invoice & payment execution, and PDF bytes generation).
- Verified `flutter analyze` clean with 0 warnings/errors.
- Verified all 96 tests pass across the entire project test suite (100% pass rate).
- Verified Windows desktop debug build succeeds (`garage_erp.exe`).

### Phase 8 — Purchases & Suppliers (المشتريات والموردين)
- Authored comprehensive Arabic UI strings in `lib/core/strings.dart` for purchases and suppliers operations (purchases management, supplier profiles, debts, payments, line items, and invoice creation).
- Implemented domain models in `lib/features/purchases/domain/`:
  - `SupplierWithBalance`: Supplier entity with invoices count, total purchases, total paid, and balance due in integer piasters (Rule R1).
  - `PurchaseLineItem`: Single line in a purchase invoice with item metadata, quantity, unit purchase cost, and formatted currency/qty displays.
  - `PurchaseInvoiceWithDetails`: Purchase invoice aggregate holding supplier, lines list, payment status (paid, partial, unpaid), total, paid, and remaining debt.
  - `PurchasesSummary`: Desktop summary metric aggregate (total purchases, total debt owed to suppliers, active suppliers count, this month's purchases).
- Enhanced `SuppliersRepository` in `lib/core/db/repositories/suppliers_repository.dart`:
  - `getSuppliersWithBalances`: Joins and aggregates purchase invoices per supplier to compute real-time balances.
  - `recordPayment`: Atomically distributes supplier payments across oldest unpaid purchase invoices.
  - `deactivate` / `reactivate` lifecycle management.
- Implemented `PurchasesRepository` and `DriftPurchasesRepository` in `lib/core/db/repositories/purchases_repository.dart`:
  - `createPurchaseInvoice`: In a single atomic SQLite transaction, inserts purchase invoice, creates lines, records inbound stock movements via `StockService.addMovement` with `StockMovementType.purchaseIn` (Rules R2, R3), and updates the item's latest cost price in the `items` table (Rule R8).
  - Multi-field smart search matching supplier name, phone, supplier invoice number, or internal ID.
  - `getPurchasesSummary`: Computes live financial summary metrics.
- Registered `purchasesRepositoryProvider` in `lib/core/db/providers.dart`.
- Implemented Riverpod providers and action controller in `lib/features/purchases/presentation/purchases_controller.dart`.
- Implemented desktop UI widgets and dialogs in `lib/features/purchases/presentation/widgets/`:
  - `PurchasesKpiCards`: 4 desktop summary KPI cards (إجمالي المشتريات، مديونية الموردين، الموردين النشطين، مشتريات الشهر).
  - `PurchaseDetailsPane`: Desktop master-detail pane with supplier contact info, financial breakdown, and line items table.
  - `PurchaseInvoiceFormDialog`: Purchase invoice creation modal with supplier selection, date picker, interactive line items picker with live inventory stock, grand total calculation, and paid/debt tracking.
  - `SuppliersDialog` & `SupplierFormDialog`: Dedicated supplier management modal with balance cards, add/edit actions, and `SupplierPaymentDialog` for recording supplier debt payments.
- Implemented full `PurchasesPage` in `lib/features/purchases/purchases_page.dart` with KPI summary banner, search & supplier filter toolbar, virtualized data table (`rowHeight: 52`), and split master-detail view.
- Added comprehensive unit and widget tests in `test/purchases_test.dart` (9 tests covering supplier validation, deactivation/reactivation, debt calculation, payment distribution, stock movements, cost price updating, summary metrics, page rendering, supplier form, and purchase creation dialog).
- Verified `flutter analyze` clean with 0 warnings/errors.
- Verified all 105 tests pass across the entire project test suite (100% pass rate).
- Verified Windows desktop debug build succeeds (`garage_erp.exe`).

### Phase 9 — Invoicing, Stock Count, Reports, Employees, Expenses & Delivery Hardening
- **Invoicing & Sales (الفواتير والمبيعات):**
  - Direct sales and work-order linked invoices with gap-free sequential numbering (Rule R6).
  - Snapshot pricing for items and services (Rule R8) and stock deductions via `StockService.addMovement` (Rule R2, R3, R4).
  - Payment methods support: خزنة الفرع (كاش), فودافون كاش (محفظة), إنستاباي (InstaPay), وفيزا/بطاقة.
  - A4 and 80mm thermal receipt vector printing with Cairo font (`InvoicePrintBuilder`, `A4InvoiceBuilder`, `ReceiptBuilder`).
- **Stock Count (الجرد السنوي والمخزني):**
  - Sessions management (مسودة قيد العد، معتمد ومحفوظ).
  - Scopes: جرد شامل، جرد حسب التصنيف، جرد الأصناف النشطة.
  - Automatic discrepancy recording as explicit `countDiff` stock movements through `StockService`.
- **Financial Reports & Analytics (التقارير المالية):**
  - Sales, inventory valuation, debts, and comprehensive profit/loss reports.
  - Excel workbook export (`excel_export_service.dart`) with multi-sheet reports.
- **Employees & Payroll (الموظفين والرواتب):**
  - Staff management, monthly/daily salary schemes, salary advances ledger, and disbursement records.
- **Operating Expenses (مصروفات المركز):**
  - Categorized expense recording, daily and monthly aggregates.
- **Purchase Invoices Printing (طباعة فواتير وإذن التوريد):**
  - Dedicated A4 vector PDF generation via `PurchasePrintBuilder` with Cairo TTF fonts, garage branding, supplier details, itemized lines table, financial summary, Tafqeet Arabic words conversion, and signature blocks.
  - Interactive preview dialog (`PurchasePreviewDialog`) in `PurchaseDetailsPane`.
- **Delivery Hardening:**
  - Robust SQLite backup using `VACUUM INTO` for consistent offline snapshots.
  - Automatic backup on window close (keeping the latest 14 snapshots).
  - SQLite `integrity_check` for corruption detection.
  - Starting document numbering configuration.
  - Release build verification (`flutter build windows --release`).

## Decisions made this phase

See `docs/DECISIONS.md`.

### Delivery hardening (post Phase 9)

- Backup/restore from Settings with `VACUUM INTO`, PIN-gated restore, and WAL sidecar cleanup.
- Automatic backup on window close (last 14 files in the `backups` folder).
- SQLite `integrity_check` action and starting invoice/work-order numbers.
- `/dev/print-test` and Ctrl+P print-test route restricted to debug builds.
- Profit report Excel export.
- Company-facing `README.md` for install, data location, and backup.

## Current status

- All operational and business modules (Phases 0–9) fully implemented and tested.
- 164/164 tests passing across unit, repository, service, and UI widget suites (100% pass rate).
- `flutter analyze` reports 0 issues / 0 warnings.
- Production-ready offline Flutter Windows desktop application.


