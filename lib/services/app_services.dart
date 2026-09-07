import '../data/analytics_repo.dart';
import '../data/local_store.dart';
import '../data/products_repo.dart';
import '../data/purchases_repo.dart';
import '../data/payments_repo.dart';
import '../data/suppliers_repo.dart';
import '../data/sync_service.dart';
import 'contacts_service.dart';

/// Simple composition root: everything a screen needs, constructed once
/// in `main()` and exposed through a Provider<AppServices>.
class AppServices {
  AppServices({required LocalStore store})
      : store = store,
        suppliers = SupplierRepository(store),
        products = ProductRepository(store),
        purchases = PurchaseRepository(store),
        payments = const PaymentRepository() {
    syncService = SyncService(
      store: store,
      suppliers: suppliers,
      products: products,
    );
    analytics = AnalyticsRepository(purchases);
    contacts = const ContactsService();
  }

  final LocalStore store;
  final SupplierRepository suppliers;
  final ProductRepository products;
  final PurchaseRepository purchases;
  final PaymentRepository payments;
  late final AnalyticsRepository analytics;
  late final SyncService syncService;
  late final ContactsService contacts;
}
