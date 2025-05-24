import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:wassilni/models/user_model.dart';
import 'package:wassilni/providers/user_provider.dart';

class RidesHistory extends StatefulWidget {
  const RidesHistory({super.key});

  @override
  _RidesHistoryState createState() => _RidesHistoryState();
}

class _RidesHistoryState extends State<RidesHistory>
    with WidgetsBindingObserver {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<QueryDocumentSnapshot> _rides = [];
  DocumentSnapshot? _lastDocument;
  bool _isLoading = false;
  bool _hasMore = true;
  late UserModel user;

  @override
  void initState() {
    user = Provider.of<UserProvider>(context, listen: false).currentUser!;
    if (Provider.of<UserProvider>(context, listen: false).currentUser == null) {
      throw Exception("user is not logged in");
    }
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadInitialRides();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkVisibility();
  }

  void _checkVisibility() {
    final isVisible = ModalRoute.of(context)?.isCurrent ?? false;
    if (isVisible) {
      _refreshRides();
    }
  }

  Future<void> _refreshRides() async {
    if (!mounted) return;

    setState(() {
      _rides.clear();
      _lastDocument = null;
      _hasMore = true;
    });
    await _loadInitialRides();
  }

  Future<void> _loadInitialRides() async {
    setState(() => _isLoading = true);
    final query = _firestore
        .collection('rides')
        .where('riderId', isEqualTo: user.id)
        .orderBy('timestamps.requested', descending: true)
        .limit(5);

    final snapshot = await query.get();
    if (snapshot.docs.isNotEmpty) {
      _lastDocument = snapshot.docs.last;
    }

    setState(() {
      _rides = snapshot.docs;
      _isLoading = false;
      _hasMore = snapshot.docs.length == 5;
    });
  }

  Future<void> _loadMoreRides() async {
    if (!_hasMore || _isLoading) return;

    setState(() => _isLoading = true);
    final query = _firestore
        .collection('rides')
        .where('riderId', isEqualTo: user.id)
        .orderBy('timestamps.requested', descending: true)
        .startAfterDocument(_lastDocument!)
        .limit(5);

    final snapshot = await query.get();
    if (snapshot.docs.isNotEmpty) {
      _lastDocument = snapshot.docs.last;
    }

    setState(() {
      _rides.addAll(snapshot.docs);
      _isLoading = false;
      _hasMore = snapshot.docs.length == 5;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ride History'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      backgroundColor: Colors.black,
      body: NotificationListener<ScrollEndNotification>(
        onNotification: (scrollEnd) {
          final metrics = scrollEnd.metrics;
          if (metrics.atEdge && metrics.pixels != 0) {
            _loadMoreRides();
          }
          return true;
        },
        child: ListView.builder(
          itemCount: _rides.length + (_hasMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == _rides.length) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: CircularProgressIndicator(color: Colors.blue[200]),
                ),
              );
            }

            final ride = _rides[index].data() as Map<String, dynamic>;
            final timestamps = ride['timestamps'] as Map<String, dynamic>;
            final status = ride['status']?.toString().toUpperCase() ?? '';

            return Card(
              color: Colors.grey[800],
              margin: const EdgeInsets.all(8.0),
              child: ListTile(
                title: Text(
                  status,
                  style: TextStyle(
                    color: _getStatusColor(status),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'From: ${ride['pickup']['address']}',
                      style: TextStyle(color: Colors.grey[300]),
                    ),
                    Text(
                      'To: ${ride['destination']['address']}',
                      style: TextStyle(color: Colors.grey[300]),
                    ),
                    Text(
                      'Fare: ${ride['fare']}',
                      style: TextStyle(
                        color: Colors.blue[200],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Requested: ${DateFormat('MMM dd, yyyy - HH:mm').format((timestamps['requested'] as Timestamp).toDate())}',
                      style: TextStyle(color: Colors.grey[400]),
                    ),
                  ],
                ),
                leading: Icon(Icons.directions_car, color: Colors.blue[200]),
              ),
            );
          },
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green[300]!;
      case 'canceled':
        return Colors.red[300]!;
      case 'in_progress':
        return Colors.orange[300]!;
      default:
        return Colors.grey[300]!;
    }
  }
}
