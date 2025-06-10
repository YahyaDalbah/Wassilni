import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wassilni/models/user_model.dart';
import 'package:wassilni/providers/user_provider.dart';

class DriverProfilePage extends StatelessWidget {
  const DriverProfilePage({super.key});

  Future<double> _getFareTotal(String period, String userId) async {
    try {
      final now = DateTime.now();
      DateTime startDate;

      switch (period) {
        case 'weekly':
          startDate = now.subtract(const Duration(days: 7));
          break;
        case 'monthly':
          startDate = DateTime(now.year, now.month, 1);
          break;
        case 'yearly':
          startDate = DateTime(now.year, 1, 1);
          break;
        default:
          startDate = now;
      }

      final query =
          await FirebaseFirestore.instance
              .collection('rides')
              .where('driverId', isEqualTo: userId)
              .where('status', isEqualTo: 'completed')
              .where(
                'timestamps.requested',
                isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
              )
              .orderBy('timestamps.requested')
              .orderBy('__name__')
              .get();

      return query.docs.fold<double>(0.0, (sum, doc) {
        final data = doc.data();
        final fare = data['fare'];
        if (fare is num) {
          return sum + fare.toDouble();
        }
        return sum;
      });
    } catch (e) {
      debugPrint('Error calculating fare total: $e');
      return 0.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final user = userProvider.currentUser;

    return Scaffold(
      backgroundColor: Colors.black,
      body:
          user == null
              ? const Center(
                child: CircularProgressIndicator(color: Colors.blue),
              )
              : CustomScrollView(
                slivers: [
                  SliverAppBar(
                    expandedHeight: 200.0,
                    floating: false,
                    pinned: true,
                    backgroundColor: Colors.transparent,
                    leading: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    flexibleSpace: FlexibleSpaceBar(
                      background: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.black, Colors.black87],
                          ),
                        ),
                        child: Center(
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.grey[850],
                              border: Border.all(color: Colors.blue, width: 2),
                            ),
                            child: Icon(
                              user.type == UserType.driver
                                  ? Icons.directions_car
                                  : Icons.person,
                              size: 60,
                              color: Colors.blue,
                            ),
                          ),
                        ),
                      ),
                      title: Text(
                        user.phone,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color.fromARGB(255, 236, 236, 236),
                        ),
                      ),
                      centerTitle: true,
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionTitle('Earnings'),
                          FutureBuilder<List<double>>(
                            future: Future.wait([
                              _getFareTotal('weekly', user.id),
                              _getFareTotal('monthly', user.id),
                              _getFareTotal('yearly', user.id),
                            ]),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(16.0),
                                    child: CircularProgressIndicator(
                                      color: Colors.blue,
                                    ),
                                  ),
                                );
                              }

                              if (snapshot.hasError) {
                                return _buildInfoCard(
                                  children: [
                                    Center(
                                      child: Text(
                                        'Error loading earnings',
                                        style: TextStyle(
                                          color: Colors.red[400],
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }

                              final fares = snapshot.data ?? [0.0, 0.0, 0.0];
                              return _buildEarningsCards(fares);
                            },
                          ),

                          const SizedBox(height: 20),
                          _buildSectionTitle('Account Information'),

                          _buildInfoCard(
                            children: [
                              _buildInfoRow(
                                'Status',
                                user.isOnline ? 'Online' : 'Offline',
                                statusColor:
                                    user.isOnline ? Colors.green : Colors.red,
                              ),
                              _buildInfoRow(
                                'Location',
                                '${user.location.latitude.toStringAsFixed(4)}, '
                                    '${user.location.longitude.toStringAsFixed(4)}',
                              ),
                            ],
                          ),
                          if (user.type == UserType.driver) ...[
                            const SizedBox(height: 20),
                            _buildSectionTitle('Vehicle Information'),
                            _buildInfoCard(
                              children: [
                                _buildInfoRow(
                                  'Make',
                                  user.vehicle['make'] ?? 'Not set',
                                ),
                                _buildInfoRow(
                                  'Model',
                                  user.vehicle['model'] ?? 'Not set',
                                ),
                                _buildInfoRow(
                                  'License Plate',
                                  user.vehicle['licensePlate'] ?? 'Not set',
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
    );
  }

  Widget _buildEarningsCards(List<double> fares) {
    return Column(
      children: [
        _buildEarningCard('Weekly Earnings', fares[0]),
        const SizedBox(height: 12),
        _buildEarningCard('Monthly Earnings', fares[1]),
        const SizedBox(height: 12),
        _buildEarningCard('Yearly Earnings', fares[2]),
      ],
    );
  }

  Widget _buildEarningCard(String title, double amount) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withOpacity(0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.withOpacity(0.3)),
            ),
            child: Text(
              '\$${amount.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  Widget _buildInfoCard({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(children: children),
    );
  }

  Widget _buildInfoRow(String title, String value, {Color? statusColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: statusColor ?? Colors.white,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
