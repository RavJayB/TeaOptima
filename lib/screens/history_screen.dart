// lib/screens/history_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  /* ─────────── helpers ─────────── */

  String _formatDate(Timestamp? ts) =>
      ts == null ? '--' : DateFormat('d MMM yyyy, hh:mm a').format(ts.toDate());

  String _cleanSuggestion(List<dynamic> milestones) {
    if (milestones.isEmpty) return 'Not good enough to process';

    var rec = milestones.last['recommendation']?.toString() ?? '';
    rec = rec.replaceAll('**', '');

    // "before day 0" → "within today"
    if (rec.toLowerCase().contains('before day 0')) {
      return rec.replaceAll(RegExp(r'before day 0', caseSensitive: false),
          'within today');
    }

    // "before day N" → real date
    final m = RegExp(r'before day (\d+)').firstMatch(rec.toLowerCase());
    if (m != null) {
      final d  = int.parse(m.group(1)!);
      final dt = DateTime.now().add(Duration(days: d));
      final ds = DateFormat('d MMM').format(dt);
      rec = rec.replaceFirst(RegExp(r'before day \d+', caseSensitive: false),
          'before $ds');
    }
    return rec;
  }

  /* ─────────── UI ─────────── */

  @override
  Widget build(BuildContext context) {
    final uid       = FirebaseAuth.instance.currentUser!.uid;
    final green50   = Colors.green.shade50;
    final green900  = Colors.green.shade900;
    final grey700   = Colors.grey.shade700;

    final stream = FirebaseFirestore.instance
        .collection('simulations')
        .where('userId', isEqualTo: uid)
        .orderBy('created_at', descending: true)
        .snapshots();

    return Scaffold(
      appBar: AppBar(title: const Text('Prediction History')),
      body: StreamBuilder<QuerySnapshot>(
        stream: stream,
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('No past predictions found.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc   = docs[index];
              final data  = doc.data() as Map<String, dynamic>;

              final date       = _formatDate(data['created_at'] as Timestamp?);
              final location   = data['location'] ?? 'Unknown';
              final quality    = data['starting_quality'] ?? '--';
              final leafAge    = data['leaf_age'] ?? '--';
              final suggestion = _cleanSuggestion(
                  List<dynamic>.from(data['milestones'] ?? []));

              /* —— Swipe-to-delete wrapper —— */
              return Dismissible(
                key: ValueKey(doc.id),
                direction: DismissDirection.endToStart, // right → left
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),

                onDismissed: (_) async {
                  await doc.reference.delete();
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Entry deleted'),
                      behavior: SnackBarBehavior.floating));
                },

                /* —— Actual card —— */
                child: InkWell(
                  onTap: () {
                    final imageUrl = data['image_url'];
                    if (imageUrl != null && imageUrl is String && imageUrl.isNotEmpty) {
                      showDialog(
                        context: context,
                        builder: (_) => Dialog(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Loading spinner
                                const CircularProgressIndicator(),
                                // The image
                                Image.network(
                                  imageUrl,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) => const Text('Failed to load image.'),
                                  loadingBuilder: (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return const SizedBox.shrink(); // Hide image until loaded
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('No image available for this log.')),
                      );
                    }
                  },
                  child: Card(
                    color: green50,
                    elevation: 1,
                    margin:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // header
                          Row(children: [
                            Icon(Icons.history, color: green900),
                            const SizedBox(width: 8),
                            Text('Leaf Age: $leafAge days',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: green900)),
                            const Spacer(),
                            Text('Quality: $quality',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: green900)),
                          ]),
                          const SizedBox(height: 8),

                          // location & date
                          Row(children: [
                            const Icon(Icons.location_on,
                                size: 16, color: Colors.blue),
                            const SizedBox(width: 4),
                            Expanded(
                                child: Text(location,
                                    style: TextStyle(color: grey700))),
                            const SizedBox(width: 16),
                            const Icon(Icons.calendar_today,
                                size: 16, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(date, style: TextStyle(color: grey700)),
                          ]),
                          const SizedBox(height: 8),

                          // suggestion
                          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const Icon(Icons.notes,
                                size: 16, color: Colors.indigo),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(suggestion,
                                  style:
                                      TextStyle(color: Colors.indigo.shade700)),
                            ),
                          ]),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
