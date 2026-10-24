import '../../../core/db/database.dart';
import 'customer_summary.dart';

/// Full customer profile including vehicles, recent work orders, and invoices.
class CustomerDetails {
  const CustomerDetails({
    required this.customer,
    required this.summary,
    required this.vehicles,
    required this.workOrders,
    required this.invoices,
  });

  final Customer customer;
  final CustomerSummary summary;
  final List<Vehicle> vehicles;
  final List<WorkOrder> workOrders;
  final List<Invoice> invoices;
}
