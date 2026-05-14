import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

/// Centralized Firestore service to handle database configuration.
///
/// If your Firestore database is NOT "(default)", update the [databaseId] below.
/// To check your database ID:
/// 1. Go to Firebase Console → Firestore Database
/// 2. Look at the database name at the top
/// 3. If it says "(default)" → leave this as is
/// 4. If it says "aifitdbex" or any other name → update [databaseId] below
class FirestoreService {
  /// Database ID for your Firestore database.
  ///
  /// - Use "(default)" if your database is the default one (most common)
  /// - Use "aifitdbex" if you created a custom database with that ID
  ///
  /// **Important**: This is the database ID, not the display name in Firebase Console.
  /// To find your database ID, check Firebase Console → Firestore Database → Database name
  static const String databaseId = "aifitdbex";

  /// Get the Firestore instance for the configured database.
  ///
  /// Automatically uses the correct method based on whether the database is "(default)" or custom.
  static FirebaseFirestore get instance {
    // If using the default database, use the standard instance
    if (databaseId == "(default)") {
      return FirebaseFirestore.instance;
    }

    // If using a custom database, use instanceFor with the database ID
    return FirebaseFirestore.instanceFor(
      app: Firebase.app(),
      databaseId: databaseId,
    );
  }
}
