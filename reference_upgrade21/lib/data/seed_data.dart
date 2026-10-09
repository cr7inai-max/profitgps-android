import '../models/entities.dart';

/// Upgrade 16 starts with a clean business database.
/// No products, customers, suppliers, sales, employees, branches or feedback
/// are inserted automatically. Real records are created only by the user.
AppData makeSeedData() => AppData(
      products: <Product>[],
      customers: <Customer>[],
      employees: <Employee>[],
      branches: <Branch>[],
      sales: <Sale>[],
      feedback: <FeedbackEntry>[],
      suppliers: <Supplier>[],
      cashClosings: <CashClosing>[],
      purchases: <PurchaseRecord>[],
      purchaseReturns: <PurchaseReturnRecord>[],
      ledger: <CustomerLedgerEntry>[],
      quotations: <Quotation>[],
      supplierLedger: <SupplierLedgerEntry>[],
      business: BusinessProfile(),
      dataVersion: 16,
    );
