import 'local_receivable_payment_record.dart';
import 'local_receivable_record.dart';

class LocalReceivableDetail {
  const LocalReceivableDetail({
    required this.record,
    required this.payments,
    this.customerPhoneNumber,
  });

  final LocalReceivableRecord record;
  final List<LocalReceivablePaymentRecord> payments;
  final String? customerPhoneNumber;

  int get paymentCount => payments.length;
}
