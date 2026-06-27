import 'package:flutter/material.dart';
import 'features/dashboard/presentation/pages/dashboard_page.dart';

void main() {
  runApp(const MontraApp());
}

class MontraApp extends StatelessWidget {
  const MontraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Montra',
      home: const DashboardPage(),
    );
  }
}