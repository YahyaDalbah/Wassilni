import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:wassilni/pages/rider_screen.dart';
import 'package:wassilni/providers/user_provider.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

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
              .where('riderId', isEqualTo: userId)
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
      return 0.0; // Return 0 if there's an error
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final user = userProvider.currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Rider Profile',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.black,
      ),
      backgroundColor: Colors.black,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              color: Colors.grey,
              child: ListTile(
                title: Text(
                  'Phone: ${user.phone}',
                  style: TextStyle(color: Colors.white),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Status: ${user.isOnline ? "Online" : "Offline"}',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            FutureBuilder<List<double>>(
              future: Future.wait([
                _getFareTotal('weekly', user.id),
                _getFareTotal('monthly', user.id),
                _getFareTotal('yearly', user.id),
              ]),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Text('Error: ${snapshot.error}');
                }

                final fares = snapshot.data ?? [0.0, 0.0, 0.0];
                return Column(
                  children: [
                    _buildFareCard('Weekly Total', fares[0]),
                    _buildFareCard('Monthly Total', fares[1]),
                    _buildFareCard('Yearly Total', fares[2]),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFareCard(String title, double amount) {
    return Card(
      color: Colors.grey,
      child: ListTile(
        title: Text(title, style: TextStyle(color: Colors.white)),
        trailing: Text(
          '\$${amount.toStringAsFixed(2)}',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
