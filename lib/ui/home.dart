import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: Icon(
          Icons.remove_red_eye_sharp,
          color: Colors.white
        ),
        backgroundColor: Colors.blueAccent,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              // Handle menu item selection
              print('Selected: $value');
            },
            itemBuilder: (BuildContext context) {
              return [
                const PopupMenuItem(
                  value: 'Option 1',
                  child: Text('Option 1'),
                ),
                const PopupMenuItem(
                  value: 'Option 2',
                  child: Text('Option 2'),
                ),
                const PopupMenuItem(
                  value: 'Option 3',
                  child: Text('Option 3'),
                ),
              ];
            },
            icon: const Icon(Icons.more_vert, color: Colors.white,),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              height: 100,
                child: Card(
                  elevation: 4,
                  child: ListTile(
                    title: const Text('Visual Assistance'),
                    onTap: () {
                      // Handle Visual Assistance button tap
                      print('Visual Assistance tapped');
                    },
                  ),
                )
            ),
            const SizedBox(height: 16),
            Container(
              height: 100,
              child: Card(
                elevation: 4,
                child: ListTile(
                  title: const Text('Social Assistance'),
                  onTap: () {
                    // Handle Social Assistance button tap
                    print('Social Assistance tapped');
                  },
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}