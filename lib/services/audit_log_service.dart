import 'package:cloud_firestore/cloud_firestore.dart';

class AuditLogService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<void> log({
    required String role,
    required String userName,
    required String action,
    String? entityType,
    String? entityId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      await _firestore.collection('historyLogs').add({
        'timestamp': FieldValue.serverTimestamp(),
        'role': role,
        'userName': userName,
        'action': action,
        if ((entityType ?? '').isNotEmpty) 'entityType': entityType,
        if ((entityId ?? '').isNotEmpty) 'entityId': entityId,
        if (metadata != null) 'metadata': metadata,
      });
    } catch (_) {
      return;
    }
  }
}
