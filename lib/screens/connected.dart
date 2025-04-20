import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ConnectedPage extends StatefulWidget {
  final Map<String, dynamic> partnerData;
  final String currentUserCustomUid;
  final String currentUserName;
  
  const ConnectedPage({
    super.key,
    required this.partnerData,
    required this.currentUserCustomUid,
    required this.currentUserName,
  });

  @override
  State<ConnectedPage> createState() => _ConnectedPageState();
}

class _ConnectedPageState extends State<ConnectedPage> {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  final TextEditingController _itemController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  List<Map<String, dynamic>> transactions = [];
  double netBalance = 0.0;

  @override
  void initState() {
    super.initState();
    _setupTransactionListener();
  }

  void _setupTransactionListener() {
    // Create sorted channel ID
    List<String> uids = [
      widget.currentUserCustomUid,
      widget.partnerData['customUid']
    ];
    uids.sort();
    final channelId = uids.join('_');

    _database.child('transactions/$channelId').onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data != null) {
        final List<Map<String, dynamic>> loadedTransactions = [];
        double balance = 0.0;

        data.forEach((key, value) {
          loadedTransactions.add({
            'id': key,
            'item': value['item'],
            'amount': value['amount'],
            'paidBy': value['paidBy'],
            'timestamp': value['timestamp'],
          });

          // Calculate net balance
          if (value['paidBy'] == widget.currentUserCustomUid) {
            balance += (value['amount'] as num).toDouble();
          } else {
            balance -= (value['amount'] as num).toDouble();
          }
        });

        // Sort by timestamp (newest first)
        loadedTransactions.sort((a, b) => (b['timestamp'] ?? 0).compareTo(a['timestamp'] ?? 0));

        setState(() {
          transactions = loadedTransactions;
          netBalance = balance;
        });
      } else {
        setState(() {
          transactions = [];
          netBalance = 0.0;
        });
      }
    });
  }

  Future<void> _addTransaction() async {
    if (_itemController.text.isEmpty || _amountController.text.isEmpty) return;

    final amount = double.tryParse(_amountController.text) ?? 0.0;
    if (amount <= 0) return;

    // Create sorted channel ID
    List<String> uids = [
      widget.currentUserCustomUid,
      widget.partnerData['customUid']
    ];
    uids.sort();
    final channelId = uids.join('_');

    try {
      await _database.child('transactions/$channelId').push().set({
        'item': _itemController.text,
        'amount': amount,
        'paidBy': widget.currentUserCustomUid,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      _itemController.clear();
      _amountController.clear();
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding transaction: $e')),
      );
    }
  }

  Future<void> _deleteTransaction(String transactionId) async {
    List<String> uids = [
      widget.currentUserCustomUid,
      widget.partnerData['customUid']
    ];
    uids.sort();
    final channelId = uids.join('_');

    try {
      await _database.child('transactions/$channelId/$transactionId').remove();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting transaction: $e')),
      );
    }
  }

  void _showAddTransactionDialog() {
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final backgroundColor = isDarkMode ? Colors.grey[900] : Colors.white;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: backgroundColor,
          title: Text('Add Transaction', style: TextStyle(color: textColor)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _itemController,
                decoration: const InputDecoration(
                  labelText: 'Item',
                  hintText: 'e.g., Dinner, Movie tickets',
                ),
                style: TextStyle(color: textColor),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _amountController,
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  hintText: 'Enter amount',
                ),
                keyboardType: TextInputType.number,
                style: TextStyle(color: textColor),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.red)),
            ),
            ElevatedButton(
              onPressed: _addTransaction,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTransactionContainer(String title, List<Map<String, dynamic>> items) {
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDarkMode ? Colors.grey[900] : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final secondaryTextColor = isDarkMode ? Colors.grey[400] : Colors.grey[600];

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          if (!isDarkMode)
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
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Center(
                child: Text(
                  'No transactions yet',
                  style: TextStyle(color: secondaryTextColor),
                ),
              ),
            )
          else
            ...items.map((transaction) {
              final isCurrentUser = transaction['paidBy'] == widget.currentUserCustomUid;
              final paidByName = isCurrentUser ? 'You' : widget.partnerData['fullName'];
              final dateTime = DateTime.fromMillisecondsSinceEpoch(
                  transaction['timestamp'] ?? 0);
              final formattedDate = DateFormat('MMM d, h:mm a').format(dateTime);

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: secondaryTextColor!.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                ),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isCurrentUser ? Colors.green.withOpacity(0.2) : Colors.blue.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isCurrentUser ? Icons.arrow_upward : Icons.arrow_downward,
                      color: isCurrentUser ? Colors.green : Colors.blue,
                    ),
                  ),
                  title: Text(
                    transaction['item'],
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  subtitle: Text(
                    '$paidByName • $formattedDate',
                    style: TextStyle(color: secondaryTextColor),
                  ),
                  trailing: Text(
                    '₹${(transaction['amount'] as num).toStringAsFixed(2)}',
                    style: TextStyle(
                      color: isCurrentUser ? Colors.green : Colors.blue,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  onLongPress: () => _showDeleteDialog(transaction['id']),
                ),
              );
            }).toList(),
        ],
      ),
    );
  }

  void _showDeleteDialog(String transactionId) {
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final backgroundColor = isDarkMode ? Colors.grey[900] : Colors.white;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: backgroundColor,
          title: Text('Delete Transaction', style: TextStyle(color: textColor)),
          content: Text(
            'Are you sure you want to delete this transaction?',
            style: TextStyle(color: textColor),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.red)),
            ),
            ElevatedButton(
              onPressed: () {
                _deleteTransaction(transactionId);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete'),
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

    // Separate transactions
    final myTransactions = transactions.where((t) => t['paidBy'] == widget.currentUserCustomUid).toList();
    final partnerTransactions = transactions.where((t) => t['paidBy'] != widget.currentUserCustomUid).toList();

    return Scaffold(
      backgroundColor: isDarkMode ? Colors.black : Colors.grey[100],
      appBar: AppBar(
        title: Text(widget.partnerData['fullName']),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Net Balance Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    if (!isDarkMode)
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      'NET BALANCE',
                      style: TextStyle(
                        color: secondaryTextColor,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '₹${netBalance.abs().toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: netBalance > 0 ? Colors.green : Colors.red,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      netBalance > 0
                          ? '${widget.partnerData['fullName']} owes you'
                          : netBalance < 0
                              ? 'You own ${widget.partnerData['fullName']}'
                              : 'All settled up',
                      style: TextStyle(color: secondaryTextColor),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Add Transaction Button
              ElevatedButton.icon(
                onPressed: _showAddTransactionDialog,
                icon: const Icon(Icons.add),
                label: const Text('Add Transaction'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),
              const SizedBox(height: 20),
              // Transactions List
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildTransactionContainer('Your Transactions', myTransactions),
                      _buildTransactionContainer(
                        '${widget.partnerData['fullName']}\'s Transactions', 
                        partnerTransactions,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _itemController.dispose();
    _amountController.dispose();
    super.dispose();
  }
}