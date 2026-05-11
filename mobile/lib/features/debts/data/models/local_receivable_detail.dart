import 'local_debt_customer.dart';
import 'local_receivable_payment_record.dart';
import 'local_receivable_record.dart';

class LocalReceivableDetail {
  const LocalReceivableDetail({
    required this.receivable,
    required this.customer,
    required this.payments,
  });

  final LocalReceivableRecord receivable;
  final LocalDebtCustomer customer;
  final List<LocalReceivablePaymentRecord> payments;
}
