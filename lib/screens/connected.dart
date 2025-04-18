import 'package:flutter/material.dart';

class ConnectedPage extends StatelessWidget {
  final Map<String, dynamic> userData;

  const ConnectedPage({super.key, required this.userData});

  @override
  Widget build(BuildContext context) {
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDarkMode ? Colors.grey[900] : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final secondaryTextColor = isDarkMode ? Colors.grey[400] : Colors.grey[600];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Connection Details'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      backgroundColor: isDarkMode ? Colors.black : Colors.grey[100],
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: isDarkMode
                ? []
                : [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const CircleAvatar(
                    radius: 30,
                    child: Icon(Icons.person, size: 30),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userData['fullName'] ?? 'No Name',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          userData['email'] ?? 'No Email',
                          style: TextStyle(color: secondaryTextColor),
                        ),
                      ],
                    ),
                  )
                ],
              ),
              const SizedBox(height: 30),
              Text(
                'Details',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 10),
              Text('Custom UID: ${userData['customUid'] ?? 'N/A'}',
                  style: TextStyle(color: secondaryTextColor)),
              const SizedBox(height: 5),
              Text('Phone: ${userData['phone'] ?? 'N/A'}',
                  style: TextStyle(color: secondaryTextColor)),
              const SizedBox(height: 5),
              Text('Joined On: ${userData['createdAt'] ?? 'N/A'}',
                  style: TextStyle(color: secondaryTextColor)),
            ],
          ),
        ),
      ),
    );
  }
}
