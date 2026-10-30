import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

import 'update_configuration.dart';

abstract interface class UpdateConfigurationSource {
  Future<UpdateConfiguration?> fetch();
}

/// Firestore is intentionally read-only from the mobile app. Publishing is
/// performed by a trusted release workflow, never by this client.
final class FirestoreUpdateConfigurationSource
    implements UpdateConfigurationSource {
  FirestoreUpdateConfigurationSource({FirebaseFirestore? firestore})
      : _firestore = firestore;

  FirebaseFirestore? _firestore;

  @override
  Future<UpdateConfiguration?> fetch() async {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
    final firestore = _firestore ??= FirebaseFirestore.instance;
    final document = await firestore
        .collection('public_config')
        .doc('app_update')
        .get(const GetOptions(source: Source.server));
    final data = document.data();
    return data == null ? null : UpdateConfiguration.fromJson(data);
  }
}

final class InMemoryUpdateConfigurationSource
    implements UpdateConfigurationSource {
  const InMemoryUpdateConfigurationSource(this.value);

  final UpdateConfiguration? value;

  @override
  Future<UpdateConfiguration?> fetch() async => value;
}
