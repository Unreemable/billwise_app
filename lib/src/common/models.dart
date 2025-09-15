import 'package:flutter/foundation.dart';

/// Simple bill model used by UI routes.
@immutable
class BillDetails {
  final String title;
  final String? product;
  final double? amount;
  final DateTime purchaseDate;
  final DateTime? returnDeadline;
  final DateTime? exchangeDeadline;
  final bool hasWarranty;
  final DateTime? warrantyExpiry;

  const BillDetails({
    required this.title,
    this.product,
    this.amount,
    required this.purchaseDate,
    this.returnDeadline,
    this.exchangeDeadline,
    this.hasWarranty = false,
    this.warrantyExpiry,
  });
}

/// Simple warranty model used by UI routes.
@immutable
class WarrantyDetails {
  final String title;
  final String product;
  final DateTime warrantyStart;
  final DateTime warrantyExpiry;
  final DateTime? returnDeadline; // optional: if you ever store it with bill
  final DateTime? reminderDate;   // kept nullable for future use (unused now)

  const WarrantyDetails({
    required this.title,
    required this.product,
    required this.warrantyStart,
    required this.warrantyExpiry,
    this.returnDeadline,
    this.reminderDate,
  });
}
