import 'package:flutter/material.dart';
import 'package:jariyo_frontend/main.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xffF3F4F5),
        title: Row(
          children: [
            Text('Jariyo', style: TextStyle(color: primaryColor, fontSize: 20, fontWeight: .w600)),
            Spacer(),
            // Icon(Icons.)
          ],
        ),
      ),
      body: Column(
        children: [

        ],
      ),
    );
  }
}
