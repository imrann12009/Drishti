import 'package:flutter/material.dart';

import '../../../core/payments/google_play_payment_service.dart';
import '../../../core/theme/app_theme.dart';

class SubscriptionScreen extends StatelessWidget {
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('DRISHTI PRO সাবস্ক্রিপশন')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Card(
            color: AppTheme.sky,
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Google Play billing-এর app-side catalog প্রস্তুত করা হয়েছে।\n'
                'Play Console product এবং secure verification backend তৈরি না হওয়া পর্যন্ত live purchase চালু হবে না।',
              ),
            ),
          ),
          const SizedBox(height: 16),
          ...GooglePlayPaymentService.catalog.map(
            (product) => Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: const Icon(Icons.workspace_premium_outlined),
                title: Text(product.displayName),
                subtitle: Text('${product.priceLabel}\nProduct ID: ${product.id}'),
                isThreeLine: true,
                trailing: const Chip(label: Text('Setup বাকি')),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Card(
            color: AppTheme.warningSurface,
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Payment নিরাপত্তা: Google Play purchase token trusted backend-এ verify না হওয়া পর্যন্ত Pro feature unlock হবে না। Client-only entitlement ব্যবহার করা হবে না।',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
