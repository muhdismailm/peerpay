import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:expense_tracker/screens/profile.dart';
import 'package:expense_tracker/screens/connected.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
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
  double grandTotal = 0.0;
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  List<StreamSubscription> _subscriptions = [];

  @override
  void initState() {
    super.initState();
    initializeUser().then((_) {
      calculateGrandTotal();
      _setupRealtimeListeners();
    });
  }

  @override
  void dispose() {
    for (var sub in _subscriptions) {
      sub.cancel();
    }
    super.dispose();
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
        setState(() {
          customUid = data['customUid'] ?? '';
          fullName = data['fullName'] ?? 'User';
          connections = List<String>.from(data['connections'] ?? []);
        });
      }
    }
  }

  void _setupRealtimeListeners() {
    for (String targetUserId in connections) {
      final subscription = FirebaseFirestore.instance
          .collection('users')
          .doc(targetUserId)
          .snapshots()
          .listen((partnerDoc) async {
        if (partnerDoc.exists) {
          final partnerData = partnerDoc.data() as Map<String, dynamic>;
          final partnerCustomUid = partnerData['customUid'];
          
          List<String> uids = [customUid, partnerCustomUid];
          uids.sort();
          final channelId = uids.join('_');

          _database.child('transactions/$channelId').onValue.listen((event) {
            calculateGrandTotal();
          });
        }
      });
      _subscriptions.add(subscription);
    }
  }

  Future<void> calculateGrandTotal() async {
    double total = 0.0;
    
    for (String targetUserId in connections) {
      final partnerDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(targetUserId)
          .get();
      
      if (partnerDoc.exists) {
        final partnerData = partnerDoc.data() as Map<String, dynamic>;
        final partnerCustomUid = partnerData['customUid'];
        
        List<String> uids = [customUid, partnerCustomUid];
        uids.sort();
        final channelId = uids.join('_');
        
        final snapshot = await _database.child('transactions/$channelId').once();
        final data = snapshot.snapshot.value as Map<dynamic, dynamic>?;
        
        if (data != null) {
          data.forEach((key, value) {
            if (value['paidBy'] == customUid) {
              total += (value['amount'] as num).toDouble();
            } else {
              total -= (value['amount'] as num).toDouble();
            }
          });
        }
      }
    }
    
    setState(() {
      grandTotal = total;
    });
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

    await calculateGrandTotal();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Connection removed')),
    );
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

                await calculateGrandTotal();
                _setupRealtimeListeners();

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

  @override
  Widget build(BuildContext context) {
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDarkMode ? Colors.grey[900] : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final secondaryTextColor = isDarkMode ? Colors.grey[400] : Colors.grey[600];
    final redHover = Colors.red.withOpacity(0.1);

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
              },
            ),
          ],
        ),
      ),
      appBar: AppBar(
        title: const Text('Home'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Text(
                fullName.toUpperCase(),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'UID: $customUid',
                style: TextStyle(fontSize: 14, color: secondaryTextColor),
              ),
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
                    Text('Grand Total',
                        style: TextStyle(fontSize: 16, color: secondaryTextColor)),
                    const SizedBox(height: 8),
                    Text(
                      '₹${grandTotal.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: grandTotal > 0 
                            ? Colors.green 
                            : grandTotal < 0 
                                ? Colors.red 
                                : textColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      grandTotal > 0
                          ? 'You are owed overall'
                          : grandTotal < 0
                              ? 'You owe overall'
                              : 'All settled up',
                      style: TextStyle(
                        fontSize: 14,
                        color: secondaryTextColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              Flexible(
                child: Container(
                  constraints: BoxConstraints(
                    maxHeight: 300 + (connections.length * 60),
                  ),
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
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
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
                                if (snapshot.connectionState == ConnectionState.waiting) {
                                  return const Center(child: CircularProgressIndicator());
                                }

                                if (!snapshot.hasData || !snapshot.data!.exists) {
                                  return const SizedBox.shrink();
                                }

                                final userData = snapshot.data!.data() as Map<String, dynamic>;

                                return GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ConnectedPage(
                                          partnerData: userData,
                                          currentUserCustomUid: customUid,
                                          currentUserName: fullName,
                                        ),
                                      ),
                                    );
                                  },
                                  onLongPress: () async {
                                    final shouldDelete = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        backgroundColor: backgroundColor,
                                        title: Text('Remove Connection',
                                            style: TextStyle(color: textColor)),
                                        content: Text(
                                            'Are you sure you want to remove this connection?',
                                            style: TextStyle(color: secondaryTextColor)),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(context, false),
                                            child: const Text('Cancel',
                                                style: TextStyle(color: Colors.red)),
                                          ),
                                          ElevatedButton(
                                            onPressed: () => Navigator.pop(context, true),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.green,
                                              foregroundColor: Colors.white,
                                            ),
                                            child: const Text('Remove'),
                                          ),
                                        ],
                                      ),
                                    );

                                    if (shouldDelete == true) {
                                      await removeConnection(targetUserId);
                                    }
                                  },
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.transparent,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(12),
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => ConnectedPage(
                                                partnerData: userData,
                                                currentUserCustomUid: customUid,
                                                currentUserName: fullName,
                                              ),
                                            ),
                                          );
                                        },
                                        onLongPress: () async {
                                          final shouldDelete = await showDialog<bool>(
                                            context: context,
                                            builder: (context) => AlertDialog(
                                              backgroundColor: backgroundColor,
                                              title: Text('Remove Connection',
                                                  style: TextStyle(color: textColor)),
                                              content: Text(
                                                  'Are you sure you want to remove this connection?',
                                                  style: TextStyle(color: secondaryTextColor)),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(context, false),
                                                  child: const Text('Cancel',
                                                      style: TextStyle(color: Colors.red)),
                                                ),
                                                ElevatedButton(
                                                  onPressed: () =>
                                                      Navigator.pop(context, true),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: Colors.green,
                                                    foregroundColor: Colors.white,
                                                  ),
                                                  child: const Text('Remove'),
                                                ),
                                              ],
                                            ),
                                          );

                                          if (shouldDelete == true) {
                                            await removeConnection(targetUserId);
                                          }
                                        },
                                        splashColor: redHover,
                                        highlightColor: redHover,
                                        child: ListTile(
                                          leading: const Icon(Icons.person),
                                          title: Text(userData['fullName'] ?? 'No Name'),
                                          subtitle: Text(userData['email'] ?? ''),
                                        ),
                                      ),
                                    ),
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
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.category), label: "Categories"),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: "Stats"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
        ],
      ),
    );
  }
}