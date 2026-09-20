import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';

/// Wraps the Android phone-book access (flutter_contacts + permission_handler).
class ContactsService {
  const ContactsService();

  /// Requests the READ_CONTACTS permission (explains why when needed).
  /// Returns true when granted.
  Future<bool> ensurePermission() async {
    var status = await Permission.contacts.status;
    if (status.isGranted) return true;

    // If the user permanently denied before, jump straight to Settings.
    if (status.isPermanentlyDenied) return false;

    status = await Permission.contacts.request();
    return status.isGranted;
  }

  /// Loads every contact (with phone numbers). Call only after
  /// [ensurePermission] returned true.
  Future<List<Contact>> loadContacts() async {
    return FlutterContacts.getContacts(withProperties: true);
  }

  /// Fallback native picker — needs NO READ_CONTACTS permission on Android
  /// (uses the system contacts picker activity).
  Future<Contact?> pickWithSystemPicker() async {
    return FlutterContacts.openExternalPick();
  }

  /// Display name — falls back to the first phone number.
  static String displayName(Contact c) {
    if (c.displayName.trim().isNotEmpty) return c.displayName.trim();
    return phoneOf(c) ?? 'Liên hệ';
  }

  /// First phone number of a contact, or null.
  static String? phoneOf(Contact c) {
    if (c.phones.isEmpty) return null;
    return c.phones.first.number.trim();
  }
}
