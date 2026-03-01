import 'package:flutter/material.dart';
import 'pages/worker_bookings_page.dart';

void main() {
  runApp(const WorkerApp());
}

class WorkerApp extends StatelessWidget {
  const WorkerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: WorkerBookingsPage(),
    );
  }
}