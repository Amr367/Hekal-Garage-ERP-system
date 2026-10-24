/// Typed application exceptions carrying user-facing Arabic messages.
///
/// Repositories and domain services throw these instead of raw exceptions.
/// Widgets catch them and display the localized [message] to the user.
abstract class AppException implements Exception {
  const AppException(this.message, {this.details});

  /// User-facing message in Arabic.
  final String message;

  /// Optional debug details (not shown to end users).
  final String? details;

  @override
  String toString() => details == null ? message : '$message ($details)';
}

/// Thrown when user input fails business validation.
class ValidationException extends AppException {
  const ValidationException(super.message, {super.details});
}

/// Thrown when an entity cannot be found by ID, plate, SKU, or key.
class NotFoundException extends AppException {
  const NotFoundException(super.message, {super.details});
}

/// Thrown when an invoice or movement would cause stock to go negative
/// while negative stock is disallowed.
class InsufficientStockException extends AppException {
  const InsufficientStockException(
    super.message, {
    this.shortItems = const <String>[],
    super.details,
  });

  /// Names or codes of items that do not have enough stock on hand.
  final List<String> shortItems;
}

/// Thrown when an action violates non-negotiable domain rules
/// (e.g. deleting an entity with history, editing an issued invoice,
/// or cancelling an invoice twice).
class BusinessRuleException extends AppException {
  const BusinessRuleException(super.message, {super.details});
}
