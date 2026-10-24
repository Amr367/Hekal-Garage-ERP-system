import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage_erp/core/strings.dart';
import 'package:garage_erp/core/theme/app_theme.dart';
import 'package:garage_erp/core/widgets/app_data_table.dart';
import 'package:garage_erp/core/widgets/confirm_dialog.dart';
import 'package:garage_erp/core/widgets/money_field.dart';
import 'package:garage_erp/core/widgets/pin_dialog.dart';
import 'package:garage_erp/core/widgets/qty_field.dart';
import 'package:garage_erp/core/widgets/search_field.dart';
import 'package:garage_erp/core/widgets/state_views.dart';

Widget _wrapWithApp(Widget child) {
  return MaterialApp(
    theme: AppTheme.light,
    locale: const Locale('ar', 'EG'),
    supportedLocales: const <Locale>[Locale('ar', 'EG')],
    localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Scaffold(
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: child,
        ),
      ),
    ),
  );
}

void main() {
  group('MoneyField Widget Tests', () {
    testWidgets('formats initial piasters and shows EGP currency suffix', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrapWithApp(
          const MoneyField(initialPiasters: 125050),
        ),
      );

      expect(find.text('1250.50'), findsOneWidget);
      expect(find.text(AppStrings.currencySymbol), findsOneWidget);
    });

    testWidgets('converts Arabic-Indic digits to integer piasters', (
      WidgetTester tester,
    ) async {
      int? capturedPiasters;
      await tester.pumpWidget(
        _wrapWithApp(
          MoneyField(
            onChangedPiasters: (val) => capturedPiasters = val,
          ),
        ),
      );

      final textField = find.byType(TextFormField);
      await tester.enterText(textField, '١٢٥٠٫٥٠');
      await tester.pump();

      expect(capturedPiasters, equals(125050));
    });

    testWidgets('rejects negative amounts when allowNegative is false', (
      WidgetTester tester,
    ) async {
      final formKey = GlobalKey<FormState>();
      await tester.pumpWidget(
        _wrapWithApp(
          Form(
            key: formKey,
            child: const MoneyField(allowNegative: false),
          ),
        ),
      );

      final textField = find.byType(TextFormField);
      await tester.enterText(textField, '-50');
      formKey.currentState?.validate();
      await tester.pump();

      expect(find.text(AppStrings.negativeNotAllowed), findsOneWidget);
    });
  });

  group('QtyField Widget Tests', () {
    testWidgets('parses integer and up to 3 decimal places', (
      WidgetTester tester,
    ) async {
      double? capturedQty;
      await tester.pumpWidget(
        _wrapWithApp(
          QtyField(
            onChangedQty: (val) => capturedQty = val,
          ),
        ),
      );

      final textField = find.byType(TextFormField);
      await tester.enterText(textField, '2.750');
      await tester.pump();

      expect(capturedQty, equals(2.75));
    });

    testWidgets('converts Arabic-Indic digits in quantity input', (
      WidgetTester tester,
    ) async {
      double? capturedQty;
      await tester.pumpWidget(
        _wrapWithApp(
          QtyField(
            onChangedQty: (val) => capturedQty = val,
          ),
        ),
      );

      final textField = find.byType(TextFormField);
      await tester.enterText(textField, '١٫٥');
      await tester.pump();

      expect(capturedQty, equals(1.5));
    });

    testWidgets('rejects more than 3 decimal places in quantity', (
      WidgetTester tester,
    ) async {
      final formKey = GlobalKey<FormState>();
      await tester.pumpWidget(
        _wrapWithApp(
          Form(
            key: formKey,
            child: const QtyField(),
          ),
        ),
      );

      final textField = find.byType(TextFormField);
      await tester.enterText(textField, '1.2345');
      formKey.currentState?.validate();
      await tester.pump();

      expect(find.text(AppStrings.invalidQty), findsOneWidget);
    });
  });

  group('SearchField Widget Tests', () {
    testWidgets('debounces query by 250ms', (WidgetTester tester) async {
      String lastQuery = '';
      await tester.pumpWidget(
        _wrapWithApp(
          SearchField(
            onChanged: (val) => lastQuery = val,
          ),
        ),
      );

      final textField = find.byType(TextField);
      await tester.enterText(textField, 'تيل فرامل');

      // Before timer finishes, query is not sent yet
      expect(lastQuery, isEmpty);

      // Fast forward past 250ms debounce
      await tester.pump(const Duration(milliseconds: 300));
      expect(lastQuery, equals('تيل فرامل'));
    });

    testWidgets('shows clear button and clears search text', (
      WidgetTester tester,
    ) async {
      String lastQuery = '';
      await tester.pumpWidget(
        _wrapWithApp(
          SearchField(
            onChanged: (val) => lastQuery = val,
          ),
        ),
      );

      final textField = find.byType(TextField);
      await tester.enterText(textField, 'زيت');
      await tester.pump(const Duration(milliseconds: 300));
      expect(lastQuery, equals('زيت'));

      // Find clear button and tap it
      final clearButton = find.byIcon(Icons.close);
      expect(clearButton, findsOneWidget);
      await tester.tap(clearButton);
      await tester.pump();

      expect(lastQuery, isEmpty);
      expect(find.byIcon(Icons.close), findsNothing);
    });
  });

  group('ConfirmDialog Tests', () {
    testWidgets('returns true on confirm button tap', (WidgetTester tester) async {
      bool? dialogResult;
      await tester.pumpWidget(
        _wrapWithApp(
          Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () async {
                dialogResult = await ConfirmDialog.show(
                  context: ctx,
                  title: 'تأكيد العملية',
                  message: 'هل تريد المتابعة؟',
                );
              },
              child: const Text('افتح'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('افتح'));
      await tester.pumpAndSettle();

      expect(find.text('تأكيد العملية'), findsOneWidget);
      expect(find.text('هل تريد المتابعة؟'), findsOneWidget);

      await tester.tap(find.text(AppStrings.confirm));
      await tester.pumpAndSettle();

      expect(dialogResult, isTrue);
    });

    testWidgets('returns false on cancel button tap', (WidgetTester tester) async {
      bool? dialogResult;
      await tester.pumpWidget(
        _wrapWithApp(
          Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () async {
                dialogResult = await ConfirmDialog.show(
                  context: ctx,
                  title: 'تأكيد العملية',
                  message: 'هل تريد المتابعة؟',
                );
              },
              child: const Text('افتح'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('افتح'));
      await tester.pumpAndSettle();

      await tester.tap(find.text(AppStrings.cancel));
      await tester.pumpAndSettle();

      expect(dialogResult, isFalse);
    });
  });

  group('PinDialog Tests', () {
    testWidgets('submits 4-digit PIN correctly', (WidgetTester tester) async {
      String? enteredPin;
      await tester.pumpWidget(
        _wrapWithApp(
          Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () async {
                enteredPin = await PinDialog.show(context: ctx);
              },
              child: const Text('طلب PIN'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('طلب PIN'));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.enterPinTitle), findsOneWidget);

      final pinInput = find.byType(TextField);
      await tester.enterText(pinInput, '١٢٣٤');
      await tester.pumpAndSettle();

      expect(enteredPin, equals('1234'));
    });
  });

  group('AppDataTable Tests', () {
    testWidgets('renders EmptyState when list is empty', (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrapWithApp(
          SizedBox(
            height: 300,
            child: AppDataTable<String>(
              columns: [
                AppTableColumn<String>(
                  title: 'الاسم',
                  cellBuilder: (_, item, index) => Text(item),
                ),
              ],
              items: const [],
            ),
          ),
        ),
      );

      expect(find.text(AppStrings.noDataAvailable), findsOneWidget);
    });

    testWidgets('renders rows and column headers when populated', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrapWithApp(
          SizedBox(
            height: 300,
            child: AppDataTable<String>(
              columns: [
                AppTableColumn<String>(
                  title: 'الاسم',
                  cellBuilder: (_, item, index) => Text(item),
                ),
              ],
              items: const ['صنف 1', 'صنف 2', 'صنف 3'],
            ),
          ),
        ),
      );

      expect(find.text('الاسم'), findsOneWidget);
      expect(find.text('صنف 1'), findsOneWidget);
      expect(find.text('صنف 2'), findsOneWidget);
      expect(find.text('صنف 3'), findsOneWidget);
    });
  });

  group('StateViews & AppSnackbar Tests', () {
    testWidgets('ErrorState renders error title, message, and triggers retry', (
      WidgetTester tester,
    ) async {
      bool retryClicked = false;
      await tester.pumpWidget(
        _wrapWithApp(
          ErrorState(
            title: 'خطأ في الاتصال',
            message: 'تعذر الوصول لقاعدة البيانات',
            onRetry: () => retryClicked = true,
          ),
        ),
      );

      expect(find.text('خطأ في الاتصال'), findsOneWidget);
      expect(find.text('تعذر الوصول لقاعدة البيانات'), findsOneWidget);

      await tester.tap(find.text(AppStrings.retry));
      expect(retryClicked, isTrue);
    });

    testWidgets('AppSnackbar displays success snackbar', (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrapWithApp(
          Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => AppSnackbar.showSuccess(ctx, 'تم الحفظ بنجاح'),
              child: const Text('إظهار إشعار'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('إظهار إشعار'));
      await tester.pump();

      expect(find.text('تم الحفظ بنجاح'), findsOneWidget);
    });
  });
}
