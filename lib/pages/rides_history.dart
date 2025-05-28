// rides_history.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:wassilni/models/user_model.dart';
import 'package:wassilni/providers/user_provider.dart';
import 'package:wassilni/services/ride_history_service.dart';

class RidesHistory extends StatefulWidget {
  const RidesHistory({super.key});

  @override
  _RidesHistoryState createState() => _RidesHistoryState();
}

class _RidesHistoryState extends State<RidesHistory>
    with WidgetsBindingObserver {
  final RideHistoryService _rideService = RideHistoryService();
  List<QueryDocumentSnapshot> _rides = [];
  DocumentSnapshot? _lastDocument;
  bool _isLoading = false;
  bool _hasMore = true;
  String? _errorMessage;
  late UserModel user;

  @override
  void initState() {
    super.initState();
    user = Provider.of<UserProvider>(context, listen: false).currentUser!;
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
    if (isVisible && _errorMessage != null) _refreshRides();
  }

  Future<void> _refreshRides() async {
    if (!mounted) return;
    setState(() {
      _rides.clear();
      _lastDocument = null;
      _hasMore = true;
      _errorMessage = null;
    });
    await _loadInitialRides();
  }

  Future<void> _loadInitialRides() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final result = await _rideService.getRides(userId: user.id);

    if (!mounted) return;
    if (result['success'] == true) {
      _updateState(result);
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = result['error'];
      });
      _showErrorSnackbar(result['error']);
    }
  }

  Future<void> _loadMoreRides() async {
    if (!_hasMore || _isLoading || _errorMessage != null) return;
    setState(() => _isLoading = true);

    final result = await _rideService.getRides(
      userId: user.id,
      lastDocument: _lastDocument,
    );

    if (!mounted) return;
    if (result['success'] == true) {
      _updateState(result);
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = result['error'];
      });
      _showErrorSnackbar(result['error']);
    }
  }

  void _updateState(Map<String, dynamic> result) {
    setState(() {
      _rides.addAll(result['rides']);
      _lastDocument = result['lastDocument'];
      _isLoading = false;
      _hasMore = result['hasMore'];
      _errorMessage = null;
    });
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 6),
      ),
    );
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
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_errorMessage != null && _rides.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_errorMessage!, style: TextStyle(color: Colors.red[300])),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _refreshRides,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[200],
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    } else if (_rides.isEmpty) {
      return Center(
        child: Text(
          "You haven't taken a ride yet, request a ride now!",
          style: TextStyle(fontSize: 16, color: Colors.white),
        ),
      );
    }

    return NotificationListener<ScrollEndNotification>(
      onNotification: (scrollEnd) {
        final metrics = scrollEnd.metrics;
        if (metrics.atEdge && metrics.pixels != 0) _loadMoreRides();
        return true;
      },
      child: RefreshIndicator(
        onRefresh: _refreshRides,
        color: Colors.blue[200],
        child: ListView.builder(
          itemCount: _rides.length + (_hasMore ? 1 : 0),
          itemBuilder: (context, index) => _buildListItem(index),
        ),
      ),
    );
  }

  Widget _buildListItem(int index) {
    if (index == _rides.length) {
      return _buildLoadingIndicator();
    }

    try {
      final ride = _rides[index].data() as Map<String, dynamic>;
      final timestamps = ride['timestamps'] as Map<String, dynamic>;
      final status = ride['status']?.toString().toUpperCase() ?? 'UNKNOWN';

      return _buildRideCard(ride, timestamps, status);
    } catch (e) {
      return _buildErrorCard('Invalid ride data format');
    }
  }

  Widget _buildLoadingIndicator() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child:
            _errorMessage == null
                ? CircularProgressIndicator(color: Colors.blue[200])
                : Text(
                  _errorMessage!,
                  style: TextStyle(color: Colors.red[300]),
                ),
      ),
    );
  }

  Widget _buildRideCard(
    Map<String, dynamic> ride,
    Map<String, dynamic> timestamps,
    String status,
  ) {
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
        subtitle: _buildRideDetails(ride, timestamps),
        leading: Icon(Icons.directions_car, color: Colors.blue[200]),
      ),
    );
  }

  Widget _buildErrorCard(String message) {
    return Card(
      color: Colors.red[900],
      margin: const EdgeInsets.all(8.0),
      child: ListTile(
        title: Text(
          'Error loading ride',
          style: TextStyle(color: Colors.red[100]),
        ),
        subtitle: Text(message, style: TextStyle(color: Colors.red[100])),
        leading: const Icon(Icons.error, color: Colors.red),
      ),
    );
  }

  Widget _buildRideDetails(
    Map<String, dynamic> ride,
    Map<String, dynamic> timestamps,
  ) {
    return Column(
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
          'Requested: ${_formatTimestamp(timestamps['requested'])}',
          style: TextStyle(color: Colors.grey[400]),
        ),
      ],
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    return DateFormat(
      'MMM dd, yyyy - HH:mm',
    ).format((timestamp as Timestamp).toDate());
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
