// driver_rides_history.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:wassilni/models/user_model.dart';
import 'package:wassilni/providers/user_provider.dart';
import 'package:wassilni/services/rider_history_service.dart';

class DriverHistory extends StatefulWidget {
  const DriverHistory({super.key});

  @override
  _DriverRidesHistoryState createState() => _DriverRidesHistoryState();
}

class _DriverRidesHistoryState extends State<DriverHistory>
    with WidgetsBindingObserver {
  final RideHistoryService _rideService = RideHistoryService();
  List<QueryDocumentSnapshot> _rides = [];
  DocumentSnapshot? _lastDocument;
  bool _isLoading = false;
  bool _hasMore = true;
  String? _errorMessage;
  late UserModel _user;

  @override
  void initState() {
    super.initState();
    _user = Provider.of<UserProvider>(context, listen: false).currentUser!;
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

    final result = await _rideService.getDriverRides(userId: _user.id);

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

    final result = await _rideService.getDriverRides(
      userId: _user.id,
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
        title: const Text('Driver Ride History'),
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
          "You haven't completed any rides yet",
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
          padding: const EdgeInsets.all(8),
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
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  status,
                  style: TextStyle(
                    color: _getStatusColor(status),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  '${ride['fare']?.toStringAsFixed(2) ?? '0.00'} \$',
                  style: TextStyle(
                    color: Colors.blue[200],
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildRideDetails(ride, timestamps),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard(String message) {
    return Card(
      color: Colors.red[900],
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.error, color: Colors.red),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Error loading ride: $message',
                style: TextStyle(color: Colors.red[100]),
              ),
            ),
          ],
        ),
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
        /* _buildDetailRow('Passenger:', ride['riderName'] ?? 'Unknown'),
        const SizedBox(height: 8),*/
        _buildDetailRow('From:', ride['pickup']['address'] ?? 'Unknown'),
        const SizedBox(height: 8),
        _buildDetailRow('To:', ride['destination']['address'] ?? 'Unknown'),
        const SizedBox(height: 8),
        _buildDetailRow(
          'Requested:',
          _formatTimestamp(timestamps['requested']),
        ),
        if (timestamps['completed'] != null) ...[
          const SizedBox(height: 8),
          _buildDetailRow(
            'Completed:',
            _formatTimestamp(timestamps['completed']),
          ),
        ],
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[400],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(value, style: TextStyle(color: Colors.grey[300]))),
      ],
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'Unknown';
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
