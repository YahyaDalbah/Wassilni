import 'package:cloud_firestore/cloud_firestore.dart';

class RideHistoryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final int _pageSize = 4;
  Future<Map<String, dynamic>> getRides({
    required String userId,
    DocumentSnapshot? lastDocument,
  }) async {
    try {
      Query query = _firestore
          .collection('rides')
          .where('riderId', isEqualTo: userId)
          .orderBy('timestamps.requested', descending: true)
          .limit(_pageSize);

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      final snapshot = await query.get();
      return {
        'success': true,
        'rides': snapshot.docs,
        'lastDocument': snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
        'hasMore': snapshot.docs.length == _pageSize,
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Failed to load rides. Please try again later.',
      };
    }
  }
}
