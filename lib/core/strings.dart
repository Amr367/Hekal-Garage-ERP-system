/// Every user-facing UI string lives here. Widgets must not hard-code Arabic.
abstract final class AppStrings {
  // ── App & Brand ────────────────────────────────────────────────────────
  static const String appTitle = 'نظام مركز هيكل';
  static const String garageNameDefault = 'مركز هيكل';
  static const String garageSubtitleDefault = 'لاصلاح السيارات';
  static const String invoiceFooterNoteDefault =
      'شكراً لتعاملكم معنا. البضاعة المباعة ترد وتستبدل خلال 14 يوماً وفقاً للشروط.';
  static const String jobCardDisclaimerDefault =
      'عزيزي العميل: تم استلام السيارة للفحص والصيانة الموضحة أعلاه. أي عمل إضافي يتم بعد موافقتكم. الأسعار تصدر في فاتورة التسليم.';
  static const String currencySymbol = 'ج.م';
  static const String currencyLabel = 'العملة: الجنيه المصري (ج.م)';
  static const String rtlProofLabel = 'اتجاه النص: من اليمين لليسار';
  static const String appVersion = 'الإصدار 1.0.0 (أوفلاين)';

  // ── Navigation Items ──────────────────────────────────────────────────
  static const String navDashboard = 'لوحة التحكم';
  static const String navWorkOrders = 'أوامر الشغل';
  static const String navInvoices = 'الفواتير';
  static const String navCustomers = 'العملاء والسيارات';
  static const String navInventory = 'المخزن والأصناف';
  static const String navPurchases = 'المشتريات والموردين';
  static const String navStockCount = 'الجرد السنوي';
  static const String navEmployees = 'الموظفين والرواتب';
  static const String navExpenses = 'مصروفات المركز';
  static const String navReports = 'التقارير المالية';
  static const String navSettings = 'الإعدادات';
  static const String navPrintTest = 'اختبار الطباعة';

  // ── Dashboard ─────────────────────────────────────────────────────────
  static const String dashboardTitle = 'لوحة التحكم والمتابعة';
  static const String dashboardSubtitle = 'نظرة سريعة على مؤشرات الأداء والعمليات اليومية';
  static const String metricTodaySales = 'مبيعات اليوم';
  static const String metricOpenWorkOrders = 'أوامر الشغل المفتوحة';
  static const String metricLowStock = 'أصناف تحت حد الطلب';
  static const String metricReceivables = 'مستحقات على العملاء';
  static const String quickActions = 'إجراءات سريعة';
  static const String actionNewWorkOrder = 'أمر شغل جديد';
  static const String actionNewInvoice = 'فاتورة جديدة';
  static const String actionAddCustomer = 'إضافة عميل';
  static const String actionAddItem = 'إضافة صنف';
  static const String recentWorkOrders = 'أحدث أوامر الشغل الجارية';

  // ── Work Orders (Phase 7) ─────────────────────────────────────────────
  static const String workOrdersTitle = 'أوامر الشغل';
  static const String workOrdersSubtitle = 'متابعة مراحل صيانة السيارات وتسجيل الخدمات وقطع الغيار';
  static const String newWorkOrderButton = 'فتح أمر شغل جديد';
  static const String editWorkOrderButton = 'تعديل أمر الشغل';
  static const String cancelWorkOrderButton = 'إلغاء أمر الشغل';
  static const String deleteWorkOrderButton = 'حذف أمر الشغل';
  static const String printJobCardButton = 'طباعة كارت أمر الشغل';
  static const String printReceiptButton = 'طباعة إيصال استلام';
  static const String changeStatusButton = 'تغيير حالة الأمر';

  // Work Order Statuses
  static const String statusOpen = 'مفتوح (انتظار)';
  static const String statusInProgress = 'قيد العمل';
  static const String statusReady = 'جاهز للاستلام';
  static const String statusDelivered = 'تم التسليم';
  static const String statusCancelled = 'ملغي';

  // Quick Status Actions
  static const String startWork = 'بدء العمل بالسيارة';
  static const String markReady = 'جاهزية السيارة للاستلام';
  static const String markDelivered = 'تسليم السيارة للعميل';
  static const String cancelOrder = 'إلغاء أمر الشغل';

  // Form Fields & Labels
  static const String orderNumberLabel = 'رقم أمر الشغل';
  static const String selectCustomer = 'اختيار العميل';
  static const String selectVehicle = 'اختيار سيارة العميل';
  static const String selectVehiclePrompt = 'اختر سيارة العميل أو أضف سيارة جديدة';
  static const String odometerLabel = 'عداد الكيلومتر الحالي';
  static const String complaintLabel = 'شكوى العميل / المطلوب عمله';
  static const String complaintHint = 'اكتب تفاصيل العطل أو الصيانة المطلوبة بناءً على رغبة العميل...';
  static const String mechanicLabel = 'الموظف المستلم للسيارة';
  static const String mechanicHint = 'اختر الموظف المستلم من موظفي المركز';
  static const String orderNotesLabel = 'ملاحظات الفحص والتشخيص الأولي';
  static const String cancellationReasonLabel = 'سبب إلغاء أمر الشغل';
  static const String customerVehicleRequired = 'يرجى اختيار العميل والسيارة للمتابعة';
  static const String complaintRequired = 'يرجى كتابة شكوى العميل أو الأعمال المطلوبة';

  // Work Order Lines (Services & Parts)
  static const String servicesAndParts = 'بنود الصيانة وقطع الغيار';
  static const String addServiceLine = 'إضافة مصنعية / خدمة';
  static const String addPartLine = 'صرف قطع غيار من المخزن';
  static const String lineTypeService = 'مصنعية / خدمة';
  static const String lineTypePart = 'قطعة غيار';
  static const String lineDescription = 'البيان / الخدمة';
  static const String lineQty = 'الكمية';
  static const String lineUnitPrice = 'سعر الوحدة';
  static const String lineTotalPrice = 'الإجمالي';
  static const String servicesSubtotal = 'إجمالي المصنعيات:';
  static const String partsSubtotal = 'إجمالي قطع الغيار:';
  static const String grandTotal = 'الإجمالي التقديري:';
  static const String stockAvailable = 'المتاح بالمخزن:';
  static const String notEnoughStock = 'الكمية المطلوبة غير متوفرة بالكامل بالمخزن';
  static const String selectServiceFromList = 'اختيار من الخدمات المسجلة';
  static const String selectItemFromList = 'اختيار صنف من المخزن';
  static const String serviceNameOrCustom = 'اسم الخدمة أو وصف المصنعية';
  static const String noLinesAdded = 'لم تتم إضافة بنود أو قطع غيار بعد';

  // Work Orders KPI Cards
  static const String kpiInProgressOrders = 'أوامر قيد العمل';
  static const String kpiReadyOrders = 'جاهزة للاستلام';
  static const String kpiTodayOrders = 'أوامر استُلمت اليوم';
  static const String kpiEstimatedOpenValue = 'قيمة الأوامر الجارية';

  // Search & Filter
  static const String searchWorkOrdersHint = 'بحث برقم الأمر، اسم العميل، الهاتف، أو لوحة السيارة...';
  static const String allStatuses = 'جميع الحالات';
  static const String filterByStatus = 'تصفية بالحالة';

  // Details Pane & Warnings
  static const String workOrderDetailsTitle = 'ملف أمر الشغل';
  static const String orderInfo = 'بيانات أمر الشغل';
  static const String vehicleInfo = 'بيانات السيارة';
  static const String customerInfo = 'بيانات العميل';
  static const String inspectionDiagnosis = 'الفحص والتشخيص';
  static const String createdAtLabel = 'تاريخ الاستلام';
  static const String closedAtLabel = 'تاريخ الإغلاق';
  static const String cannotDeleteInvoicedOrder = 'لا يمكن حذف أمر الشغل لأنه مرتبط بفاتورة مسجلة';
  static const String cannotCancelDeliveredOrder = 'لا يمكن إلغاء أمر شغل تم تسليم سيارته بالفعل';
  static const String confirmCancelOrder = 'تأكيد إلغاء أمر الشغل';
  static const String confirmCancelOrderWarning = 'سيتم إلغاء أمر الشغل ونقله لحالة ملغي. هل أنت متأكد؟';

  // Delivery & Handover with Invoice & Payment
  static const String deliverWorkOrderTitle = 'تسليم السيارة وتأكيد الفاتورة';
  static const String deliverWorkOrderSubtitle = 'مراجعة حساب أمر الشغل وإصدار الفاتورة وتحديد طريقة الدفع';
  static const String invoiceSummaryTitle = 'مراجعة وتأكيد الفاتورة';
  static const String paymentMethodLabel = 'طريقة الدفع';
  static const String paymentMethodCash = 'خزنة الفرع (نقدي / كاش)';
  static const String paymentMethodWallet = 'فودافون كاش (محفظة إلكترونية)';
  static const String paymentMethodInstapay = 'إنستاباي (InstaPay)';
  static const String paymentMethodCard = 'بطاقة بنكية / فيزا';
  static const String paymentMethodTransfer = 'تحويل بنكي';
  static const String paymentReferenceLabel = 'رقم العملية / مرجع التحويل';
  static const String paymentReferenceHint = 'رقم المحفظة أو مرجع إنستاباي أو إيصال السداد';
  static const String paidAmountLabel = 'المبلغ المدفوع';
  static const String remainingAmountLabel = 'المبلغ المتبقي على العميل';
  static const String discountAmountLabel = 'قيمة الخصم (إن وُجد)';
  static const String confirmDeliveryAndPayment = 'تأكيد السداد وتسليم السيارة';
  static const String deliverySuccessMessage = 'تم تسليم السيارة للعميل بنجاح وتسجيل الفاتورة والدفع';
  static const String invoiceAlreadyIssued = 'الفاتورة مصدرة مسبقاً لهذا الأمر';
  static const String invoiceWillBeCreated = 'سيتم إصدار فاتورة رسمية وخصم قطع الغيار من المخزن';
  static const String deliverWorkOrderButton = 'تسليم السيارة وتأكيد الفاتورة';

  // ── Invoices Placeholder ──────────────────────────────────────────────
  static const String invoicesTitle = 'الفواتير وعمليات البيع';
  static const String invoicesSubtitle = 'إصدار فواتير الصيانة والمبيعات ومتابعة المدفوعات والديون';
  static const String newInvoiceButton = 'إصدار فاتورة جديدة';

  // ── Customers & Vehicles ──────────────────────────────────────────────
  static const String customersTitle = 'العملاء والسيارات';
  static const String customersSubtitle = 'سجل بيانات العملاء وسياراتهم وتاريخ الصيانات';
  static const String newCustomerButton = 'تسجيل عميل جديد';
  static const String editCustomerButton = 'تعديل بيانات العميل';
  static const String deleteCustomerButton = 'حذف العميل';
  static const String customerDetailsTitle = 'ملف العميل';
  static const String customerNameLabel = 'اسم العميل';
  static const String customerPhoneLabel = 'رقم الهاتف الأساسي';
  static const String customerPhone2Label = 'رقم هاتف بديل (اختياري)';
  static const String customerNotesLabel = 'ملاحظات / الرقم القومي';
  static const String customerStatusActive = 'نشط';
  static const String customerStatusInactive = 'معطل';
  static const String customerStatusLabel = 'حالة الحساب';
  static const String customerBalanceLabel = 'الرصيد الحالي';
  static const String balanceSettled = 'خالص (٠ ج.م)';
  static const String balanceDue = 'مستحق عليه';
  static const String balanceCredit = 'دائن له';
  static const String customerVehiclesTitle = 'السيارات المسجلة';
  static const String addVehicleButton = 'إضافة سيارة';
  static const String editVehicleButton = 'تعديل السيارة';
  static const String deleteVehicleButton = 'حذف السيارة';
  static const String transferVehicleButton = 'نقل الملكية';
  static const String vehiclePlateLabel = 'رقم اللوحة';
  static const String vehiclePlateHint = 'مثال: أ ب ج 1234 أو د هـ و ٥٦٧';
  static const String vehicleMakeLabel = 'الماركة';
  static const String vehicleMakeHint = 'مثال: تويوتا، هيونداي، كيا';
  static const String vehicleModelLabel = 'الموديل';
  static const String vehicleModelHint = 'مثال: كورولا، النترا، سيراتو';
  static const String vehicleYearLabel = 'سنة الصنع';
  static const String vehicleColorLabel = 'اللون';
  static const String vehicleChassisLabel = 'رقم الشاسيه (VIN)';
  static const String vehicleOdometerLabel = 'عداد الكيلومتر الحالي';
  static const String vehicleOdometerUnit = 'كم';
  static const String vehiclePlateNormalized = 'الصيغة المقننة للوحة';
  static const String transferTitle = 'نقل ملكية السيارة';
  static const String transferPrompt = 'اختر العميل الجديد الذي ستنتقل إليه ملكية هذه السيارة:';
  static const String transferTargetCustomerLabel = 'العميل الجديد';
  static const String transferNotesLabel = 'ملاحظات نقل الملكية (اختياري)';
  static const String transferSuccess = 'تم نقل ملكية السيارة بنجاح مع الاحتفاظ بكامل سجل الصيانة والفواتير.';
  static const String transferWarning = 'نقل الملكية سيحدث مالك السيارة مع الاحتفاظ الكامل بسجل أوامر الشغل والفواتير السابقة على السيارة.';
  static const String customerStatementTitle = 'كشف حساب العميل';
  static const String customerSavedSuccess = 'تم حفظ بيانات العميل بنجاح';
  static const String customerDeletedSuccess = 'تم حذف العميل بنجاح';
  static const String vehicleSavedSuccess = 'تم حفظ بيانات السيارة بنجاح';
  static const String vehicleDeletedSuccess = 'تم حذف السيارة بنجاح';
  static const String noVehiclesForCustomer = 'لا توجد سيارات مسجلة لهذا العميل حتى الآن';
  static const String selectCustomerToView = 'اختر عميلاً من القائمة لعرض ملفه وسياراته';
  static const String customerInvoicesCount = 'عدد الفواتير';
  static const String customerWorkOrdersCount = 'أوامر الشغل';
  static const String phoneAlreadyExists = 'رقم الهاتف مسجل بالفعل لعميل آخر';
  static const String plateAlreadyExists = 'رقم اللوحة مسجل بالفعل لسيارة أخرى';
  static const String plateRequired = 'رقم اللوحة مطلوب';
  static const String invalidYear = 'سنة الصنع غير صالحة';
  static const String invalidOdometer = 'عداد الكيلومتر غير صالح';
  static const String filterAllCustomers = 'جميع العملاء';
  static const String filterActiveOnly = 'النشطون فقط';
  static const String customerSearchHint = 'بحث بالاسم، التليفون، أو رقم اللوحة...';
  static const String historyTitle = 'سجل الصيانة والزيارات';
  static const String noHistoryAvailable = 'لا توجد سجلات سابقة مسجلة';
  static const String openWorkOrderForVehicle = 'فتح أمر شغل';
  static const String previousOwnerLabel = 'المالك السابق';
  static const String ownershipTransferLog = 'سجل نقل الملكية';

  // ── Inventory & Stock ─────────────────────────────────────────────────
  static const String inventoryTitle = 'المخزن والأصناف';
  static const String inventorySubtitle = 'إدارة قطع الغيار والكميات وحدود الطلب والتسعير وحركات المخزون';
  static const String newItemButton = 'إضافة صنف جديد';
  static const String editItemButton = 'تعديل بيانات الصنف';
  static const String deleteItemButton = 'حذف الصنف';
  static const String deactivateItemButton = 'تعطيل الصنف';
  static const String activateItemButton = 'تفعيل الصنف';
  static const String manageCategoriesButton = 'إدارة الأقسام';
  static const String stockAdjustmentButton = 'تسوية مخزنية';
  static const String itemLedgerButton = 'كارت الحركة';
  static const String itemNameLabel = 'اسم الصنف';
  static const String itemCategoryLabel = 'القسم';
  static const String itemSkuLabel = 'كود الصنف (SKU)';
  static const String itemBarcodeLabel = 'الباركود الدولي';
  static const String itemUnitLabel = 'وحدة القياس';
  static const String itemCostPriceLabel = 'سعر التكلفة الافتراضي';
  static const String itemSalePriceLabel = 'سعر البيع الافتراضي';
  static const String itemMinQtyLabel = 'حد الطلب (الحد الأدنى)';
  static const String itemOpeningStockLabel = 'الرصيد الافتتاحي الحالي بالمخزن';
  static const String itemCurrentStockLabel = 'الرصيد الحالي بالمخزن';
  static const String itemProfitMarginLabel = 'هامش الربح';
  static const String stockValueCostLabel = 'إجمالي قيمة المخزون (بالتكلفة)';
  static const String stockValueSaleLabel = 'القيمة المتوقعة للبيع';
  static const String lowStockWarning = 'تحت حد الطلب';
  static const String outOfStockWarning = 'رصيد نافد (٠)';
  static const String inStockLabel = 'رصيد كافٍ';
  static const String allCategories = 'جميع الأقسام';
  static const String categoryNameLabel = 'اسم القسم';
  static const String newCategoryButton = 'إضافة قسم';
  static const String renameCategoryButton = 'تعديل اسم القسم';
  static const String mergeCategoryButton = 'دمج القسم';
  static const String deleteCategoryButton = 'حذف القسم';
  static const String sourceCategoryLabel = 'القسم المصدر';
  static const String targetCategoryLabel = 'القسم البديل المنقول إليه';
  static const String itemSavedSuccess = 'تم حفظ بيانات الصنف بنجاح';
  static const String itemDeletedSuccess = 'تم حذف الصنف بنجاح';
  static const String categorySavedSuccess = 'تم حفظ القسم بنجاح';
  static const String categoryMergedSuccess = 'تم دمج ونقل الأصناف بنجاح';
  static const String adjustmentSavedSuccess = 'تم تسجيل حركة التسوية المخزنية بنجاح';
  static const String inventorySearchHint = 'بحث باسم الصنف، كود SKU، أو الباركود...';
  static const String filterLowStockOnly = 'تحت حد الطلب فقط';
  static const String costPriceHidden = '*** (محمي)';
  static const String revealCostPriceTooltip = 'كشف سعر التكلفة (يتطلب رمز PIN)';
  static const String adjustmentTypeAdd = 'إضافة رصيد (زيادة)';
  static const String adjustmentTypeDeduct = 'خصم رصيد (عجز)';
  static const String adjustmentQtyLabel = 'الكمية المراد تسويتها';
  static const String adjustmentReasonLabel = 'سبب التسوية وملاحظات';
  static const String movementTypeOpening = 'رصيد افتتاحي';
  static const String movementTypePurchase = 'شراء / توريد';
  static const String movementTypeSale = 'بيع / فاتورة';
  static const String movementTypeReturn = 'مرتجع بيع';
  static const String movementTypeAdjustment = 'تسوية مخزنية';
  static const String movementTypeCount = 'تسوية جرد';
  static const String stockLedgerTitle = 'كارت حركة الصنف';
  static const String balanceAfterLabel = 'الرصيد بعد الحركة';
  static const String totalItemsCountLabel = 'إجمالي الأصناف';
  static const String itemsWithMovementsWarning = 'لا يمكن حذف الصنف لوجود حركات مخزنية مسجلة له. تم تعطيله بدلاً من ذلك.';

  // ── Purchases & Suppliers (Phase 8) ───────────────────────────────────
  static const String purchasesTitle = 'المشتريات والموردين';
  static const String purchasesSubtitle = 'فواتير المشتريات وحسابات الموردين وتوريد قطع الغيار للمخزن';
  static const String newPurchaseButton = 'تسجيل فاتورة شراء جديدة';
  static const String manageSuppliersButton = 'إدارة الموردين';
  static const String suppliersTitle = 'قائمة الموردين';
  static const String suppliersSubtitle = 'سجل بيانات الموردين وأرقام التواصل وأرصدة المديونية';
  static const String newSupplierButton = 'إضافة مورد جديد';
  static const String editSupplierButton = 'تعديل بيانات المورد';
  static const String deleteSupplierButton = 'تعطيل المورد';
  static const String supplierNameLabel = 'اسم المورد / الشركة';
  static const String supplierPhoneLabel = 'رقم هاتف المورد';
  static const String supplierNotesLabel = 'ملاحظات / العنوان';
  static const String supplierStatusActive = 'نشط';
  static const String supplierStatusInactive = 'معطل';
  static const String supplierBalanceLabel = 'الرصيد الحالي المستحق للمورد';
  static const String supplierSavedSuccess = 'تم حفظ بيانات المورد بنجاح';
  static const String supplierInvoicesCount = 'عدد فواتير الشراء';
  static const String supplierTotalPurchases = 'إجمالي المسحوبات';
  static const String supplierPaidAmount = 'المسدد للمورد';
  static const String supplierRemainingAmount = 'المتبقي للمورد';
  static const String recordSupplierPaymentButton = 'تسجيل دفعة سداد للمورد';
  static const String supplierPaymentAmountLabel = 'المبلغ المسدد';
  static const String supplierPaymentSuccess = 'تم تسجيل الدفعة المسددة للمورد بنجاح';
  static const String selectSupplierPrompt = 'اختر المورد من القائمة';
  static const String supplierRequired = 'يرجى اختيار المورد للمتابعة';

  // Purchase Invoices Form & Details
  static const String purchaseInvoiceTitle = 'تسجيل فاتورة شراء';
  static const String purchaseInvoiceSubtitle = 'إضافة كميات للمخزن وتحديث أسعار التكلفة وحساب المورد';
  static const String supplierInvoiceNumberLabel = 'رقم فاتورة المورد (الدفتري)';
  static const String supplierInvoiceNumberHint = 'مثال: INV-9842 أو رقم الإذن الدفتري';
  static const String invoiceDateLabel = 'تاريخ الشراء';
  static const String purchaseLinesTitle = 'أصناف وقطع غيار الفاتورة';
  static const String addPurchaseLine = 'إضافة صنف للفاتورة';
  static const String lineUnitCost = 'سعر شراء الوحدة';
  static const String invoiceTotalAmount = 'إجمالي الفاتورة';
  static const String invoicePaidAmount = 'المبلغ المسدد حالياً';
  static const String invoiceRemainingAmount = 'المتبقي آجل على المركز';
  static const String purchaseSavedSuccess = 'تم تسجيل فاتورة الشراء وتوريد الأصناف للمخزن بنجاح';
  static const String noPurchaseLines = 'يرجى إضافة صنف واحد على الأقل للفاتورة';
  static const String purchaseDetailsTitle = 'ملف فاتورة الشراء';
  static const String selectPurchaseToView = 'اختر فاتورة شراء من القائمة لعرض تفاصيلها وبنودها';
  static const String printPurchaseButton = 'طباعة إذن التوريد';
  static const String purchasePreviewTitle = 'معاينة إذن التوريد / فاتورة الشراء';
  static const String purchaseDocumentTitle = 'فاتورة توريد وشراء قطع غيار';
  static const String purchaseInvoiceNumberPrefix = 'فاتورة توريد #';
  static const String supplierInvoiceNumPrefix = 'رقم المورد: ';
  static const String purchaseAccountStatus = 'الحساب وحالة السداد';
  static const String storekeeperSignature = 'توقيع أمين المخزن / المستلم';
  static const String supplierReceiptSignature = 'توقيع المورد / المندوب المسلّم';

  // Payment Status
  static const String paymentStatusPaid = 'مدفوعة بالكامل';
  static const String paymentStatusPartial = 'مسددة جزئياً';
  static const String paymentStatusUnpaid = 'آجل بالكامل';

  // Purchases KPI Cards
  static const String kpiTotalPurchases = 'إجمالي المشتريات';
  static const String kpiSuppliersDebt = 'مديونية الموردين';
  static const String kpiActiveSuppliers = 'الموردين النشطين';
  static const String kpiRecentPurchases = 'مشتريات الشهر الحالي';

  // Search & Filter
  static const String purchasesSearchHint = 'بحث برقم الفاتورة، اسم المورد، أو رقم هاتف المورد...';
  static const String filterAllSuppliers = 'جميع الموردين';
  static const String searchSuppliersHint = 'بحث باسم المورد أو رقم الهاتف...';


  // ── Stock Count (Phase 9 — الجرد المخزني) ──────────────────────────────
  static const String stockCountTitle = 'الجرد السنوي والمخزني';
  static const String stockCountSubtitle = 'مطابقة المخزون الفعلي مع المسجل وحساب الفروقات';
  static const String startStockCountButton = 'بدء جرد جديد';

  // Stock Count Scopes
  static const String scopeAll = 'جرد شامل (جميع الأصناف)';
  static const String scopeCategory = 'جرد حسب التصنيف';
  static const String scopeRecent = 'جرد الأصناف النشطة (لها حركة مؤخراً)';

  // Stock Count Statuses
  static const String countStatusDraft = 'مسودة (قيد العد)';
  static const String countStatusFinalized = 'معتمد ومحفوظ';

  // Stock Count Form Dialog
  static const String newStockCountTitle = 'بدء جلسة جرد جديدة';
  static const String stockCountScopeLabel = 'نطاق الجرد';
  static const String stockCountNotesLabel = 'ملاحظات الجرد';
  static const String stockCountCategoryFilterLabel = 'اختر التصنيف';
  static const String stockCountScopeRequired = 'يرجى اختيار نطاق الجرد';

  // Stock Count KPI Cards
  static const String kpiTotalCountSessions = 'إجمالي جلسات الجرد';
  static const String kpiDraftCounts = 'مسودات قيد العد';
  static const String kpiFinalizedCounts = 'جلسات معتمدة';
  static const String kpiTotalDifference = 'قيمة الفروقات';

  // Stock Count Details Pane
  static const String countSessionInfo = 'بيانات جلسة الجرد';
  static const String countNumber = 'رقم الجلسة';
  static const String countScope = 'نطاق الجرد';
  static const String countDate = 'تاريخ الإنشاء';
  static const String countFinalizedDate = 'تاريخ الاعتماد';
  static const String countItemsTotal = 'إجمالي الأصناف';
  static const String countItemsCounted = 'أصناف تم عدها';
  static const String countItemsRemaining = 'أصناف متبقية';
  static const String countDifferences = 'الفروقات';
  static const String columnItemName = 'اسم الصنف';
  static const String columnSystemQty = 'الكمية بالنظام';
  static const String columnCountedQty = 'الكمية الفعلية';
  static const String columnDifference = 'الفرق';
  static const String columnNotes = 'ملاحظات';
  static const String notCounted = 'لم يُعد بعد';

  // Stock Count Actions
  static const String finalizeCountButton = 'اعتماد الجرد';
  static const String deleteCountButton = 'حذف جلسة الجرد';
  static const String editCountedQtyButton = 'تسجيل العد الفعلي';
  static const String printCountReport = 'طباعة تقرير الجرد';

  // Stock Count Dialogs
  static const String finalizeCountTitle = 'اعتماد جلسة الجرد';
  static const String finalizeCountMessage =
      'سيتم تسجيل فروقات الجرد كحركات تسوية في المخزن.\n'
      'هذا الإجراء لا يمكن التراجع عنه.\n'
      'هل تريد المتابعة؟';
  static const String finalizeCountConfirm = 'اعتماد وتسجيل الفروقات';
  static const String finalizeCountCancel = 'تراجع';
  static const String countFinalized = 'تم اعتماد جلسة الجرد وتسجيل الفروقات بنجاح';
  static const String countDeleted = 'تم حذف جلسة الجرد';

  // Stock Count Line Edit Dialog
  static const String editCountLineTitle = 'تسجيل العد الفعلي';
  static const String actualCountLabel = 'الكمية الفعلية بعد العد';
  static const String lineNotesLabel = 'ملاحظات (اختياري)';

  // Errors
  static const String cannotDeleteFinalizedCount = 'لا يمكن حذف جلسة جرد معتمدة';
  static const String cannotFinalizeTwice = 'جلسة الجرد معتمدة بالفعل';
  static const String noItemsToCount = 'لا توجد أصناف ضمن نطاق الجرد المحدد';
  static const String countHasUncountedItems = 'يوجد أصناف لم يتم عدها بعد. هل تريد المتابعة؟';

  // Search
  static const String stockCountSearchHint = 'بحث برقم الجلسة أو الملاحظات...';

  // ── Reports Placeholder ───────────────────────────────────────────────
  static const String reportsTitle = 'التقارير المالية والتحليلية';
  static const String reportsSubtitle = 'تقارير المبيعات والأرباح والمخزون وحركة الخزينة';

  // ── Settings ──────────────────────────────────────────────────────────
  static const String settingsTitle = 'إعدادات النظام';
  static const String settingsSubtitle = 'بيانات المركز، الطابعات، الأمان ورمز PIN، وقاعدة البيانات';

  // Tab / Section headers
  static const String tabProfile = 'بيانات المركز';
  static const String tabServices = 'دليل الخدمات والمصنعيات';
  static const String tabPrinters = 'إعدادات الطابعات';
  static const String tabSecurity = 'الأمان ورمز PIN';
  static const String tabDatabase = 'قاعدة البيانات والصيانة';
  static const String sidebarTagline = 'مركز هيكل لاصلاح السيارات';

  // Garage Profile
  static const String garageProfileTitle = 'بيانات مركز الصيانة';
  static const String garageProfileSubtitle = 'البيانات التي تظهر في ترويسة الفواتير وأوامر الشغل';
  static const String fieldGarageName = 'اسم المركز';
  static const String fieldGarageSubtitle = 'النشاط / الوصف الإضافي';
  static const String fieldPhone = 'رقم الهاتف الأساسي';
  static const String fieldPhone2 = 'رقم هاتف إضافي (اختياري)';
  static const String fieldAddress = 'العنوان بالتفصيل';
  static const String fieldTaxNumber = 'الرقم الضريبي (اختياري)';
  static const String fieldCommercialReg = 'رقم السجل التجاري (اختياري)';
  static const String fieldInvoiceFooter = 'شروط وملاحظات أسفل الفاتورة';
  static const String garageLogo = 'شعار المركز (Logo)';
  static const String selectLogo = 'اختيار صورة الشعار';
  static const String removeLogo = 'حذف الشعار';
  static const String noLogoSelected = 'لم يتم تحديد شعار للمركز حتى الآن';
  static const String logoHint = 'يفضل استخدام صورة مربعة أو أفقية بخلفية شفافة (PNG أو JPEG)';
  static const String profileSavedSuccess = 'تم حفظ بيانات المركز بنجاح';

  // Printers Settings
  static const String printersTitle = 'إعدادات الطباعة والورق';
  static const String printersSubtitle = 'تحديد الطابعة الافتراضية للفواتير وكروت أوامر الشغل';
  static const String invoicePrinterLabel = 'الطابعة الافتراضية لفواتير وكروت الصيانة (A4)';
  static const String receiptPrinterLabel = 'طابعة إيصالات 80mm الافتراضية';
  static const String defaultPaperSizeLabel = 'نوع الورق المعتمد';
  static const String paperSizeA4 = 'ورق كبير A4 (المعتمد)';
  static const String paperSizeReceipt = 'إيصال حراري (80 مم)';
  static const String autoPrintLabel = 'إرسال الفاتورة والمستند للطابعة تلقائياً فور الحفظ';
  static const String noPrinterSelected = 'استخدام طابعة النظام الافتراضية';
  static const String loadingPrinters = 'جاري البحث عن الطابعات المتصلة...';
  static const String testPrintA4 = 'طباعة تجريبية A4';
  static const String testPrintReceipt = 'طباعة تجريبية 80mm';
  static const String printersSavedSuccess = 'تم حفظ إعدادات الطباعة بنجاح';

  // Security & PIN Settings
  static const String securityTitle = 'الأمان ورمز PIN';
  static const String securitySubtitle = 'حماية العمليات الحساسة والمالية برمز سري مكون من 4 أرقام';
  static const String pinStatusLabel = 'حالة الحماية برمز PIN';
  static const String pinEnabled = 'مفعل ومحمي';
  static const String pinDisabled = 'غير مفعل (العمليات متاحة دون كلمة سر)';
  static const String setPinButton = 'تعيين رمز PIN جديد';
  static const String changePinButton = 'تغيير رمز PIN';
  static const String disablePinButton = 'إلغاء تفعيل الـ PIN';
  static const String testPinButton = 'اختبار رمز PIN';
  static const String protectedOperationsTitle = 'العمليات المحمية برمز PIN';
  static const String requirePinDiscountLabel = 'طلب الـ PIN عند عمل خصم يدوي على الفاتورة';
  static const String requirePinCostPriceLabel = 'طلب الـ PIN لكشف سعر التكلفة وهوامش الربح في المخزن';
  static const String requirePinStockAdjustLabel = 'طلب الـ PIN عند تعديل كميات المخزن يدوياً';
  static const String requirePinVoidInvoiceLabel = 'طلب الـ PIN عند إلغاء أو حذف أي فاتورة بيع';
  static const String securitySavedSuccess = 'تم حفظ إعدادات الأمان بنجاح';

  // PIN Dialogs & Inputs
  static const String currentPinLabel = 'رمز PIN الحالي';
  static const String newPinLabel = 'رمز PIN الجديد (4 أرقام)';
  static const String confirmNewPinLabel = 'تأكيد رمز PIN الجديد';
  static const String pinsDoNotMatch = 'الرمزان غير متطابقين، يرجى إعادة الإدخال';
  static const String pinMustBe4Digits = 'يجب أن يتكون رمز PIN من 4 أرقام بالضبط';
  static const String pinSetSuccess = 'تم تعيين رمز PIN الجديد بنجاح';
  static const String pinVerifiedSuccess = 'رمز PIN صحيح! تم التحقق بنجاح';
  static const String pinDisabledSuccess = 'تم إلغاء تفعيل رمز PIN بنجاح';

  // Database & Maintenance Settings
  static const String databaseTitle = 'قاعدة البيانات والصيانة';
  static const String databaseSubtitle = 'مسار ملف قاعدة البيانات والبيانات الأولية والنسخ الاحتياطي';
  static const String databasePathLabel = 'مسار ملف قاعدة البيانات SQLite:';
  static const String databaseSizeLabel = 'حجم قاعدة البيانات:';
  static const String openDatabaseFolder = 'فتح مجلد قاعدة البيانات';
  static const String loadSeedData = 'تحميل البيانات الأولية (أقسام وخدمات)';
  static const String seedDataLoadedSuccess = 'تم تحميل البيانات الأولية بنجاح.';
  static const String seedDataAlreadyLoaded = 'البيانات الأولية محملة مسبقاً.';
  static const String backupSectionTitle = 'النسخ الاحتياطي والاستعادة';
  static const String backupSectionSubtitle =
      'انسخ قاعدة البيانات إلى ملف آمن، أو استعد نسخة سابقة. يُنشأ نسخة تلقائية عند إغلاق البرنامج.';
  static const String backupNowButton = 'إنشاء نسخة احتياطية';
  static const String restoreBackupButton = 'استعادة من ملف';
  static const String openBackupsFolder = 'فتح مجلد النسخ الاحتياطي';
  static const String integrityCheckButton = 'فحص سلامة قاعدة البيانات';
  static const String backupSaveDialogTitle = 'حفظ نسخة قاعدة البيانات';
  static const String restoreOpenDialogTitle = 'اختيار ملف النسخة الاحتياطية';
  static const String backupSuccess = 'تم إنشاء النسخة الاحتياطية بنجاح';
  static const String backupFailed = 'تعذر إنشاء النسخة الاحتياطية';
  static const String restoreConfirmTitle = 'استعادة قاعدة البيانات';
  static const String restoreConfirmMessage =
      'سيتم استبدال البيانات الحالية بالكامل بالنسخة المختارة. أنشئ نسخة احتياطية أولاً إن لم تكن متأكداً. سيُغلق البرنامج بعد الاستعادة.';
  static const String restoreConfirmButton = 'استعادة وإغلاق البرنامج';
  static const String restoreSuccessRestart =
      'تمت الاستعادة. سيتم إغلاق البرنامج الآن، أعد فتحه لتحميل البيانات المستعادة.';
  static const String restoreFailed = 'تعذر استعادة النسخة الاحتياطية';
  static const String backupFileNotFound = 'ملف النسخة الاحتياطية غير موجود';
  static const String backupLivePathMissing = 'مسار قاعدة البيانات غير معروف بعد. أعد فتح البرنامج ثم حاول مرة أخرى.';
  static const String integrityOk = 'فحص السلامة سليم — لا توجد أخطاء في ملف قاعدة البيانات';
  static const String integrityFailed = 'فحص السلامة اكتشف مشكلة في الملف';
  static const String recentBackupsTitle = 'أحدث النسخ التلقائية';
  static const String noRecentBackups = 'لا توجد نسخ تلقائية بعد. ستُنشأ نسخة عند إغلاق البرنامج.';
  static const String restoreThisBackup = 'استعادة هذه النسخة';
  static const String startingNumbersTitle = 'أرقام المستندات الافتتاحية';
  static const String startingNumbersSubtitle =
      'تُستخدم فقط عند إصدار أول فاتورة أو أول أمر شغل (عندما لا يوجد رقم سابق).';
  static const String startingInvoiceNumberLabel = 'رقم أول فاتورة';
  static const String startingWorkOrderNumberLabel = 'رقم أول أمر شغل';
  static const String startingNumbersSaved = 'تم حفظ أرقام البداية بنجاح';
  static const String invalidStartingNumber = 'أدخل رقماً صحيحاً أكبر من صفر';

  // ── Common Actions & Buttons ──────────────────────────────────────────
  static const String searchHint = 'بحث بالاسم، الكود، أو رقم الهاتف...';
  static const String clearSearch = 'مسح البحث';
  static const String confirm = 'تأكيد';
  static const String cancel = 'إلغاء';
  static const String save = 'حفظ';
  static const String delete = 'حذف';
  static const String edit = 'تعديل';
  static const String close = 'إغلاق';
  static const String retry = 'إعادة المحاولة';
  static const String print = 'طباعة';
  static const String exportExcel = 'تصدير Excel';
  static const String exportInventoryExcel = 'تصدير كشف المخزن (Excel)';
  static const String exportComprehensiveFinancialReport = 'التقرير المالي الشامل (Excel)';
  static const String exportComprehensiveFinancialTooltip =
      'تصدير كافة الحسابات والبيانات المالية في ملف إكسيل واحد متعدد الأوراق';
  static const String filter = 'تصفية';
  static const String reset = 'إعادة ضبط';
  static const String submit = 'إرسال';
  static const String refresh = 'تحديث';

  // ── Table Common Strings ──────────────────────────────────────────────
  static const String tableActions = 'إجراءات';
  static const String noDataAvailable = 'لا توجد بيانات مسجلة حتى الآن';
  static const String loadingData = 'جاري تحميل البيانات...';
  static const String totalCount = 'الإجمالي';

  // ── Common Dialogs ────────────────────────────────────────────────────
  static const String confirmOperation = 'تأكيد العملية';
  static const String confirmDelete = 'تأكيد الحذف';
  static const String confirmDeleteWarning =
      'تحذير: هذا الإجراء نهائي ولا يمكن التراجع عنه. هل أنت متأكد؟';
  static const String enterPinTitle = 'التحقق من رمز PIN';
  static const String enterPinPrompt = 'أدخل رمز PIN السري المكون من 4 أرقام للمتابعة';
  static const String pinInvalid = 'رمز PIN غير صحيح، يرجى المحاولة مرة أخرى';
  static const String pinFieldLabel = 'رمز PIN';

  // ── Form Validation & Inputs ──────────────────────────────────────────
  static const String fieldRequired = 'هذا الحقل مطلوب';
  static const String invalidMoney = 'المبلغ المدخل غير صالح';
  static const String invalidQty = 'الكمية غير صحيحة (بحد أقصى 3 أرقام عشرية)';
  static const String negativeNotAllowed = 'القيمة لا يمكن أن تكون سالبة';

  // ── State Messages ────────────────────────────────────────────────────
  static const String genericError = 'حدث خطأ غير متوقع، يرجى المحاولة لاحقاً';
  static const String operationSuccess = 'تمت العملية بنجاح';

  // ── Employees & Payroll Strings ───────────────────────────────────────
  static const String employeesTitle = 'الموظفين ومسيرات الرواتب';
  static const String employeesSubtitle = 'إدارة طاقم العمل، تسجيل السلفيات والمسحوبات، وصرف الرواتب الشهرية';
  static const String addEmployee = 'إضافة موظف جديد';
  static const String editEmployee = 'تعديل بيانات الموظف';
  static const String recordAdvance = 'تسجيل سلفة / مسحوبات';
  static const String paySalary = 'صرف راتب الموظف';
  static const String employeeName = 'اسم الموظف';
  static const String employeeRole = 'المسمى الوظيفي';
  static const String employeePhone = 'رقم الهاتف';
  static const String employeeNationalId = 'الرقم القومي';
  static const String employeeBasicSalary = 'الراتب الأساسي';
  static const String employeeSalaryType = 'نوع الراتب';
  static const String employeeHireDate = 'تاريخ التعيين';
  static const String employeeStatus = 'حالة الموظف';
  static const String employeeActive = 'نشط';
  static const String employeeInactive = 'غير نشط / موقوف';
  static const String tabEmployeesList = 'دليل الموظفين';
  static const String tabAdvances = 'السلف والمسحوبات';
  static const String tabSalaries = 'سجل صرف الرواتب';
  static const String pendingAdvances = 'سلف معلقة لم تخصم';
  static const String currentMonthAdvances = 'سلفيات هذا الشهر';
  static const String totalSalariesPaid = 'إجمالي الرواتب المصروفة';

  // ── Expenses Strings ──────────────────────────────────────────────────
  static const String expensesTitle = 'مصروفات مركز الصيانة';
  static const String expensesSubtitle = 'تسجيل ومتابعة كافة المصاريف التشغيلية والنثريات العامة للمركز';
  static const String addExpense = 'تسجيل مصروف جديد';
  static const String editExpense = 'تعديل المصروف';
  static const String deleteExpense = 'حذف المصروف';
  static const String expenseCategory = 'تصنيف المصروف';
  static const String expenseAmount = 'مبلغ المصروف';
  static const String expenseDate = 'تاريخ الصرف';
  static const String expenseDescription = 'البيان / الوصف';
  static const String expensePaidTo = 'الجهة المستفيدة / المدفوع له';
  static const String expenseReceiptNumber = 'رقم الإيصال / الفاتورة';
  static const String todayExpenses = 'مصروفات اليوم';
  static const String thisMonthExpenses = 'مصروفات هذا الشهر';
  static const String totalExpenses = 'إجمالي المصروفات';

  // ── Phase 1 Print Test Legacy Strings ─────────────────────────────────
  static const String printTestTitle = 'اختبار الطباعة العربي';
  static const String printTestPreviewA4 = 'معاينة فاتورة A4';
  static const String printTestPreviewReceipt = 'معاينة إيصال 80mm';
  static const String printTestButton = 'اختبار الطباعة';
}

