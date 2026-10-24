import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage_erp/core/strings.dart';
import 'package:garage_erp/main.dart';

void main() {
  testWidgets('bootstrap screen shows RTL Arabic placeholder', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: GarageErpApp()));

    expect(find.text(AppStrings.bootstrapHeadline), findsOneWidget);
    expect(find.text(AppStrings.bootstrapBody), findsOneWidget);
    expect(find.text(AppStrings.rtlProofLabel), findsOneWidget);
  });
}
