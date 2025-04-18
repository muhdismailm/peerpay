// ignore_for_file: use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:expense_tracker/screens/profile.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String fullName = 'User';
  String customUid = '';
  List<String> connections = [];

  @override
  void initState() {
    super.initState();
    initializeUser();
  }

  Future<void> initializeUser() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('uid', isEqualTo: currentUser.uid)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final data = snapshot.docs.first.data();
        customUid = data['customUid'] ?? '';
        await fetchUserData();
      }
    }
  }

  Future<void> fetchUserData() async {
    if (customUid.isEmpty) return;

    try {
      final docSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('customUid', isEqualTo: customUid)
          .limit(1)
          .get();

      if (docSnapshot.docs.isNotEmpty) {
        final data = docSnapshot.docs.first.data();
        setState(() {
          fullName = data['fullName'] ?? 'User';
          connections = List<String>.from(data['connections'] ?? []);
        });
      } else {
        setState(() {
          fullName = 'User';
        });
      }
    } catch (e) {
      print("Error fetching user data: $e");
    }
  }

  Future<void> showAddConnectionDialog() async {
    final TextEditingController uidController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
        final textColor = isDarkMode ? Colors.white : Colors.black;
        final backgroundColor = isDarkMode ? Colors.grey[900] : Colors.white;

        return AlertDialog(
          backgroundColor: backgroundColor,
          title: Text("Add Connection", style: TextStyle(color: textColor)),
          content: TextField(
            controller: uidController,
            decoration: const InputDecoration(hintText: "Enter user's custom UID"),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel", style: TextStyle(color: Colors.red)),
            ),
            ElevatedButton(
              onPressed: () async {
                final enteredCustomUid = uidController.text.trim();

                if (enteredCustomUid.isEmpty || customUid.isEmpty) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Invalid UID")),
                  );
                  return;
                }

                if (enteredCustomUid == customUid) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Cannot connect to self")),
                  );
                  return;
                }

                final targetUserQuery = await FirebaseFirestore.instance
                    .collection('users')
                    .where('customUid', isEqualTo: enteredCustomUid)
                    .limit(1)
                    .get();

                if (targetUserQuery.docs.isEmpty) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("User not found")),
                  );
                  return;
                }

                final targetUserDoc = targetUserQuery.docs.first;
                final targetUserId = targetUserDoc.id;

                final currentUserQuery = await FirebaseFirestore.instance
                    .collection('users')
                    .where('customUid', isEqualTo: customUid)
                    .limit(1)
                    .get();

                if (currentUserQuery.docs.isEmpty) return;

                final currentUserId = currentUserQuery.docs.first.id;

                if (connections.contains(targetUserId)) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Connection already exists")),
                  );
                  return;
                }

                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(currentUserId)
                    .update({
                  'connections': FieldValue.arrayUnion([targetUserId]),
                });

                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(targetUserId)
                    .update({
                  'connections': FieldValue.arrayUnion([currentUserId]),
                });

                setState(() {
                  connections.add(targetUserId);
                });

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Connection added")),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text("Add"),
            ),
          ],
        );
      },
    );
  }

  Future<void> removeConnection(String targetUserId) async {
    final currentUserQuery = await FirebaseFirestore.instance
        .collection('users')
        .where('customUid', isEqualTo: customUid)
        .limit(1)
        .get();

    if (currentUserQuery.docs.isEmpty) return;

    final currentUserId = currentUserQuery.docs.first.id;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserId)
        .update({
      'connections': FieldValue.arrayRemove([targetUserId]),
    });

    await FirebaseFirestore.instance
        .collection('users')
        .doc(targetUserId)
        .update({
      'connections': FieldValue.arrayRemove([currentUserId]),
    });

    setState(() {
      connections.remove(targetUserId);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Connection removed')),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDarkMode ? Colors.grey[900] : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final secondaryTextColor = isDarkMode ? Colors.grey[400] : Colors.grey[600];

    return Scaffold(
      backgroundColor: isDarkMode ? Colors.black : Colors.grey[100],
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.grey[850] : Colors.green,
              ),
              currentAccountPicture: const CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(Icons.person, size: 40),
              ),
              accountName: Text(
                fullName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              accountEmail: Text('UID: $customUid'),
            ),
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text('Home'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Profile'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfilePage()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () async {
                await FirebaseAuth.instance.signOut();
                Navigator.pop(context);
                // Navigate to login or welcome screen if needed
              },
            ),
          ],
        ),
      ),
      appBar: AppBar(
        title: Text('Home', style: TextStyle(color: textColor)),
        backgroundColor: backgroundColor,
        iconTheme: IconThemeData(color: textColor),
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
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
                    Text('Total Balance',
                        style: TextStyle(fontSize: 16, color: secondaryTextColor)),
                    const SizedBox(height: 8),
                    Text('\$20,340.98',
                        style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: textColor)),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              Expanded(
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
                      Text('Connections',
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: textColor)),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: showAddConnectionDialog,
                        icon: const Icon(Icons.person_add),
                        label: const Text('Add Connection'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 15),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Expanded(
                        child: ListView.builder(
                          itemCount: connections.length,
                          itemBuilder: (context, index) {
                            final targetUserId = connections[index];
                            return FutureBuilder<DocumentSnapshot>(
                              future: FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(targetUserId)
                                  .get(),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return const CircularProgressIndicator();
                                }

                                if (!snapshot.hasData ||
                                    !snapshot.data!.exists) {
                                  return const SizedBox.shrink();
                                }

                                final userData = snapshot.data!.data()
                                    as Map<String, dynamic>;
                                return GestureDetector(
                                  onLongPress: () async {
                                    final shouldDelete = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text('Remove Connection'),
                                        content: const Text(
                                            'Are you sure you want to remove this connection?'),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, false),
                                            child: const Text('Cancel'),
                                          ),
                                          ElevatedButton(
                                            onPressed: () =>
                                                Navigator.pop(context, true),
                                            child: const Text('Remove'),
                                          ),
                                        ],
                                      ),
                                    );

                                    if (shouldDelete == true) {
                                      await removeConnection(targetUserId);
                                    }
                                  },
                                  child: ListTile(
                                    leading: const Icon(Icons.person),
                                    title:
                                        Text(userData['fullName'] ?? 'No Name'),
                                    subtitle: Text(userData['email'] ?? ''),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: backgroundColor,
        type: BottomNavigationBarType.fixed,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        selectedItemColor: const Color(0xFF5FBB62),
        unselectedItemColor: secondaryTextColor,
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.home_rounded), label: 'Home'),
          BottomNavigationBarItem(
              icon: Icon(Icons.credit_card), label: 'Cards'),
          BottomNavigationBarItem(
              icon: Icon(Icons.pie_chart), label: 'Stats'),
          BottomNavigationBarItem(
              icon: Icon(Icons.settings), label: 'Settings'),
        ],
        currentIndex: 0,
      ),
    );
  }
}
