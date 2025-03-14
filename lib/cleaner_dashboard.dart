import 'package:cleaning_app/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart'; // For kIsWeb check
import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(); // Initialize Firebase
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const CleanerDashboard(),
    );
  }
}

class CleanerDashboard extends StatefulWidget {
  const CleanerDashboard({super.key});

  @override
  State<CleanerDashboard> createState() => _CleanerDashboardState();
}

class _CleanerDashboardState extends State<CleanerDashboard> {
  int _currentIndex = 0;

  final List<Widget> _pages = [HomePage(), BookingsPage(), ProfilePage()];

  void _onItemTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cleaner Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: _pages[_currentIndex],
      bottomNavigationBar: ReusableBottomNavBar(
        currentIndex: _currentIndex,
        onTap: _onItemTapped,
      ),
    );
  }

  void _logout(BuildContext context) async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Logout'),
          content: const Text('Are you sure you want to log out?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                Navigator.of(context).pop();
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );
              },
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );
  }
}

// Reusable Bottom Navigation Bar
class ReusableBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const ReusableBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: onTap,
      selectedItemColor: Colors.blue,
      unselectedItemColor: Colors.grey,
      showUnselectedLabels: true,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
        BottomNavigationBarItem(
          icon: Icon(Icons.calendar_today),
          label: 'Bookings',
        ),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
      ],
    );
  }
}

// HomePage - Display pending cleaning requests and accepted requests for the current cleaner
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Fetch pending cleaning requests (visible to all cleaners)
  Stream<QuerySnapshot> getCleaningRequests() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Stream.empty();
    }

    return _firestore
        .collection('cleaning_requests')
        .where('status', isEqualTo: 'pending')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // Fetch accepted cleaning requests for the current cleaner (Fixed syntax error here)
  Stream<QuerySnapshot> getAcceptedRequests() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Stream.empty();
    }

    return _firestore
        .collection('cleaning_requests')
        .where('status', isEqualTo: 'accepted') // Fixed: Added colon (:)
        .where('cleaner_id', isEqualTo: user.uid)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pending Cleaning Requests',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Expanded(
            flex: 1,
            child: StreamBuilder<QuerySnapshot>(
              stream: getCleaningRequests(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text('No pending cleaning requests available.'),
                  );
                }

                return ListView.builder(
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    var request =
                        snapshot.data!.docs[index].data()
                            as Map<String, dynamic>;
                    var docId = snapshot.data!.docs[index].id;

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: ListTile(
                        title: Text(
                          'Request from ${request['name'] ?? 'Unknown'}',
                        ),
                        subtitle: Text(
                          'Service Date: ${request['date'] ?? 'N/A'}',
                        ),
                        trailing: Text(request['status'] ?? 'Pending'),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) => RequestDetailsPage(
                                    docId: docId,
                                    request: request,
                                  ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
          const Text(
            'My Accepted Requests',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Expanded(
            flex: 1,
            child: StreamBuilder<QuerySnapshot>(
              stream: getAcceptedRequests(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No accepted requests.'));
                }

                return ListView.builder(
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    var request =
                        snapshot.data!.docs[index].data()
                            as Map<String, dynamic>;
                    var docId = snapshot.data!.docs[index].id;

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: ListTile(
                        title: Text(
                          'Request from ${request['name'] ?? 'Unknown'}',
                        ),
                        subtitle: Text(
                          'Service Date: ${request['date'] ?? 'N/A'}',
                        ),
                        trailing: Text(request['status'] ?? 'Accepted'),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) => RequestDetailsPage(
                                    docId: docId,
                                    request: request,
                                  ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// Cancel Reason Dialog Widget
class CancelReasonDialog extends StatefulWidget {
  final Function(String) onConfirm;

  const CancelReasonDialog({super.key, required this.onConfirm});

  @override
  _CancelReasonDialogState createState() => _CancelReasonDialogState();
}

class _CancelReasonDialogState extends State<CancelReasonDialog> {
  final TextEditingController _reasonController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Cancel Request'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Please provide a reason for cancellation:'),
          TextField(
            controller: _reasonController,
            decoration: const InputDecoration(hintText: 'Enter reason'),
            maxLines: 3,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            if (_reasonController.text.isNotEmpty) {
              widget.onConfirm(_reasonController.text);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please provide a reason')),
              );
            }
          },
          child: const Text('Confirm'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }
}

// Request Details Page
class RequestDetailsPage extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> request;

  const RequestDetailsPage({
    super.key,
    required this.docId,
    required this.request,
  });

  Future<void> _updateStatus(BuildContext context, String newStatus) async {
    try {
      final cleaner = FirebaseAuth.instance.currentUser;
      if (cleaner == null) {
        throw Exception('Cleaner not logged in.');
      }

      final cleanerDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(cleaner.uid)
              .get();
      final cleanerName = cleanerDoc.data()?['name'] ?? 'Unknown Cleaner';

      await FirebaseFirestore.instance
          .collection('cleaning_requests')
          .doc(docId)
          .update({
            'status': newStatus,
            'cleaner_id': cleaner.uid,
            'cleaner_name': cleanerName,
          });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Status updated to $newStatus')));
      Navigator.pop(context); // Back to HomePage
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error updating status: $e')));
    }
  }

  Future<void> _cancelRequest(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return CancelReasonDialog(
          onConfirm: (reason) async {
            try {
              final cleaner = FirebaseAuth.instance.currentUser;
              if (cleaner == null) {
                throw Exception('Cleaner not logged in.');
              }

              // Update Firestore to cancel the request
              await FirebaseFirestore.instance
                  .collection('cleaning_requests')
                  .doc(docId)
                  .update({
                    'status': 'pending',
                    'cleaner_id': null,
                    'cleaner_name': null,
                    'cancellation_reason': reason,
                    'cancelled_by': cleaner.uid,
                    'cancellation_timestamp': FieldValue.serverTimestamp(),
                  });

              // Close the dialog
              Navigator.pop(dialogContext);

              // Show confirmation message
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Request cancelled successfully'),
                  duration: Duration(seconds: 2),
                ),
              );

              // Redirect to Cleaner Home Page
              Navigator.pop(context); // Back to HomePage
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error cancelling request: $e')),
              );
            }
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Request Details')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Customer Info',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Text('Name: ${request['name'] ?? 'N/A'}'),
              Text('Address: ${request['address'] ?? 'N/A'}'),
              Text('Rooms: ${request['rooms'] ?? 'N/A'}'),
              Text('Service Date: ${request['date'] ?? 'N/A'}'),
              Text('Status: ${request['status'] ?? 'N/A'}'),
              const SizedBox(height: 16),
              const Text(
                'House Images',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              request['images'] != null &&
                      (request['images'] as List).isNotEmpty
                  ? SizedBox(
                    height: 120,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: (request['images'] as List).length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: Image.network(
                            request['images'][index],
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return const Text('Error loading image');
                            },
                          ),
                        );
                      },
                    ),
                  )
                  : const Text('No images available.'),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  if (request['status'] == 'pending')
                    ElevatedButton(
                      onPressed: () => _updateStatus(context, 'accepted'),
                      child: const Text('Accept'),
                    ),
                  if (request['status'] == 'accepted') ...[
                    ElevatedButton(
                      onPressed: () => _updateStatus(context, 'completed'),
                      child: const Text('Mark as Completed'),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      onPressed: () => _cancelRequest(context),
                      child: const Text('Cancel Request'),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Bookings Page
class BookingsPage extends StatelessWidget {
  const BookingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Manage your bookings here.'));
  }
}

// Profile Page
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _name;
  String? _email;
  String? _role;
  String? _profileImageUrl;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final user = _auth.currentUser;
    if (user != null) {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        final data = userDoc.data();
        setState(() {
          _name = data?['name'] ?? 'Unknown';
          _email = data?['email'] ?? 'No Email';
          _role = data?['role'] ?? 'Cleaner';
          _profileImageUrl = data?['profileImageUrl'];
        });
      }
    }
  }

  Future<void> _uploadImage() async {
    final picker = ImagePicker();
    XFile? pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile == null) return;

    try {
      String imageUrl = '';

      if (kIsWeb) {
        final bytes = await pickedFile.readAsBytes();
        imageUrl = await _uploadToCloudinaryWeb(bytes);
      } else {
        final file = File(pickedFile.path);
        imageUrl = await _uploadToCloudinaryMobile(file);
      }

      await _updateFirestore(imageUrl);
      setState(() {
        _profileImageUrl = imageUrl;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile image updated successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error uploading image: $e')));
    }
  }

  Future<String> _uploadToCloudinaryWeb(List<int> imageBytes) async {
    const cloudinaryUrl =
        'https://api.cloudinary.com/v1_1/dk1thw6tq/image/upload';
    final request =
        http.MultipartRequest('POST', Uri.parse(cloudinaryUrl))
          ..fields['upload_preset'] = 'profile_images'
          ..files.add(
            http.MultipartFile.fromBytes(
              'file',
              imageBytes,
              filename: 'upload.jpg',
            ),
          );

    final response = await request.send();
    if (response.statusCode == 200) {
      final responseData = json.decode(await response.stream.bytesToString());
      return responseData['secure_url'];
    } else {
      throw Exception('Failed to upload image on web');
    }
  }

  Future<String> _uploadToCloudinaryMobile(File file) async {
    const cloudinaryUrl =
        'https://api.cloudinary.com/v1_1/dk1thw6tq/image/upload';
    final request =
        http.MultipartRequest('POST', Uri.parse(cloudinaryUrl))
          ..fields['upload_preset'] = 'profile_images'
          ..files.add(await http.MultipartFile.fromPath('file', file.path));

    final response = await request.send();
    if (response.statusCode == 200) {
      final responseData = json.decode(await response.stream.bytesToString());
      return responseData['secure_url'];
    } else {
      throw Exception('Failed to upload image on mobile');
    }
  }

  Future<void> _updateFirestore(String imageUrl) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update(
        {'profileImageUrl': imageUrl},
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile Page')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundImage:
                        _profileImageUrl != null
                            ? NetworkImage(_profileImageUrl!)
                            : const AssetImage('assets/default_profile.png')
                                as ImageProvider,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: IconButton(
                      icon: const Icon(Icons.camera_alt, size: 30),
                      onPressed: _uploadImage,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _buildProfileField('Full Name', _name ?? 'Loading...'),
            _buildProfileField('Email', _email ?? 'Loading...'),
            _buildProfileField('Role', _role ?? 'Loading...'),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
