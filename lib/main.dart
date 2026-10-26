import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';

import 'firebase_options.dart';

// NOTE: firebase_storage is no longer used. Photos are stored as small base64
// strings in the product's `imageUrl` field (Firestore documents max out at 1 MB).

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MarketplaceApp());
}
//main is async because Firebase has to be ready before anything else uses it.

class MarketplaceApp extends StatelessWidget {
  const MarketplaceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Marketplace',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1877F2)),
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
      ),
      home: const MarketplaceHome(),
    );
  }
}





/// Shows [builder] only when a user is signed in. Reacts live to sign in / out,
/// so tabs update immediately after the user logs in.
class AuthGate extends StatelessWidget {
  final String message;
  final Widget Function(User user) builder;

  const AuthGate({super.key, required this.message, required this.builder});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final user = snapshot.data;
        if (user == null) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(message),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AccountPage()),
                  ),
                  child: const Text('Sign in'),
                ),
              ],
            ),
          );
        }
        return builder(user);
      },
    );
  }
}
// main screen of the apps
class MarketplaceHome extends StatefulWidget {
  const MarketplaceHome({super.key});

  @override
  State<MarketplaceHome> createState() => _MarketplaceHomeState();
}
class _MarketplaceHomeState extends State<MarketplaceHome> {
  final searchController = TextEditingController();
  String search = '';
  String category = 'All';
  int tab = 0;
  final categories = ['All', 'Electronics', 'Fashion', 'Home', 'Vehicles', 'Other'];
  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text(
          'Marketplace',
          style: TextStyle(
            color: Color(0xFF1877F2),
            fontSize: 25,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Account',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AccountPage()),
            ),
            icon: const Icon(Icons.account_circle_outlined),
          ),
        ],
      ),
      body: IndexedStack(
        index: tab,
        children: [
          buildHome(),
          const MyListingsPage(),
          const OrdersPage(),
        ],
      ),
      floatingActionButton: tab == 0
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SellPage()),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Sell item'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (value) => setState(() => tab = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            selectedIcon: Icon(Icons.storefront),
            label: 'Browse',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            label: 'My listings',
          ),
          NavigationDestination(
            icon: Icon(Icons.shopping_bag_outlined),
            label: 'Orders',
          ),
        ],
      ),
    );
  }

  Widget buildHome() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: searchController,
            onChanged: (value) => setState(() => search = value.toLowerCase()),
            decoration: InputDecoration(
              hintText: 'Search products...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: categories.map((item) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ChoiceChip(
                  label: Text(item),
                  selected: category == item,
                  onSelected: (_) => setState(() => category = item),
                ),
              );
            }).toList(),
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 18, 16, 12),
          child: Text(
            'Discover items',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance.collection('products').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(
                  child: Text(
                    'Could not load products.\nCheck your Firestore setup and rules.',
                    textAlign: TextAlign.center,
                  ),
                );
              }

              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final products = snapshot.data!.docs.where((doc) {
                final data = doc.data();
                final title = (data['title'] ?? '').toString().toLowerCase();
                final itemCategory = (data['category'] ?? 'Other').toString();
                final status = (data['status'] ?? 'available').toString();
                return status != 'sold' &&
                    title.contains(search) &&
                    (category == 'All' || itemCategory == category);
              }).toList();

              if (products.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.storefront, size: 64, color: Colors.blueGrey),
                        SizedBox(height: 12),
                        Text(
                          'No products yet',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 6),
                        Text('Be the first to list an item!'),
                      ],
                    ),
                  ),
                );
              }

              return GridView.builder(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 90),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.68,
                ),
                itemCount: products.length,
                itemBuilder: (context, index) {
                  final doc = products[index];
                  final data = doc.data();
                  final reserved = data['status'] == 'reserved';

                  return Card(
                    clipBehavior: Clip.antiAlias,
                    color: Colors.white,
                    child: InkWell(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProductPage(
                            productId: doc.id,
                            data: data,
                          ),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: SizedBox(
                              width: double.infinity,
                              child: productImage(data['imageUrl']),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '₱${money(data['price'])}',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  data['title'] ?? 'Untitled item',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  reserved
                                      ? '${data['category'] ?? 'Other'} · Reserved'
                                      : (data['category'] ?? 'Other'),
                                  style: TextStyle(
                                    color: reserved ? Colors.orange : Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool register = false;
  bool busy = false;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (email.text.trim().isEmpty || password.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter an email and a password of at least 6 characters.')),
      );
      return;
    }

    setState(() => busy = true);
    try {
      if (register) {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email.text.trim(),
          password: password.text,
        );
      } else {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email.text.trim(),
          password: password.text,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You are signed in!')),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'Authentication failed.')),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Your account')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              children: [
                const Icon(Icons.account_circle, size: 76, color: Color(0xFF1877F2)),
                const SizedBox(height: 12),
                const Text('Welcome to Marketplace', style: TextStyle(fontSize: 22)),
                const SizedBox(height: 24),
                StreamBuilder<User?>(
                  stream: FirebaseAuth.instance.authStateChanges(),
                  builder: (context, snapshot) {
                    final user = snapshot.data;
                    if (user == null) return const SizedBox.shrink();
                    return Column(
                      children: [
                        Text('Signed in as ${user.email ?? user.uid}'),
                        const SizedBox(height: 12),
                        FilledButton.tonal(
                          onPressed: () => FirebaseAuth.instance.signOut(),
                          child: const Text('Sign out'),
                        ),
                        const SizedBox(height: 24),
                      ],
                    );
                  },
                ),
                TextField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email address',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: password,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password (minimum 6 characters)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: busy ? null : submit,
                    child: Text(busy ? 'Please wait...' : register ? 'Create account' : 'Sign in'),
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() => register = !register),
                  child: Text(register
                      ? 'Already registered? Sign in'
                      : 'New here? Create an account'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SellPage extends StatefulWidget {
  const SellPage({super.key});

  @override
  State<SellPage> createState() => _SellPageState();
}

class _SellPageState extends State<SellPage> {
  final formKey = GlobalKey<FormState>();
  final title = TextEditingController();
  final price = TextEditingController();
  final description = TextEditingController();
  String category = 'Electronics';
  Uint8List? imageBytes;
  bool busy = false;

  @override
  void dispose() {
    title.dispose();
    price.dispose();
    description.dispose();
    super.dispose();
  }

  Future<void> pickImage() async {
    // Small + compressed so the base64 string fits in a Firestore document.
    final selected = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 60,
      maxWidth: 800,
      maxHeight: 800,
    );
    if (selected == null) return;
    final bytes = await selected.readAsBytes();
    if (mounted) setState(() => imageBytes = bytes);
  }

  Future<void> publish() async {
    if (!formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Open Account and sign in first.')),
      );
      return;
    }

    String imageData = '';
    if (imageBytes != null) {
      imageData = base64Encode(imageBytes!);
      // Firestore limit is 1 MB per document; keep a safe margin.
      if (imageData.length > 700000) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo is too large. Pick a smaller photo.')),
        );
        return;
      }
    }

    setState(() => busy = true);

    try {
      await FirebaseFirestore.instance.collection('products').add({
        'title': title.text.trim(),
        'price': double.parse(price.text.trim()),
        'description': description.text.trim(),
        'category': category,
        'imageUrl': imageData,
        'sellerId': user.uid,
        'sellerEmail': user.email ?? '',
        'status': 'available',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product published!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not publish: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sell an item')),
      body: Form(
        key: formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            InkWell(
              onTap: pickImage,
              child: Container(
                height: 180,
                color: Colors.white,
                child: imageBytes == null
                    ? const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_a_photo_outlined, size: 44),
                          Text('Select a product photo'),
                        ],
                      )
                    : Image.memory(imageBytes!, fit: BoxFit.cover, width: double.infinity),
              ),
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: title,
              decoration: const InputDecoration(
                labelText: 'Product name',
                border: OutlineInputBorder(),
              ),
              validator: (v) => v == null || v.trim().isEmpty ? 'Enter a product name' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: price,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Price in PHP',
                prefixText: '₱ ',
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                final n = double.tryParse(v ?? '');
                return n == null || !n.isFinite || n <= 0 ? 'Enter a valid price' : null;
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: category,
              decoration: const InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
              ),
              items: categoriesForSale.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (v) {
                if (v != null) setState(() => category = v);
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: description,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
              validator: (v) => v == null || v.trim().isEmpty ? 'Enter a description' : null,
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: busy ? null : publish,
              child: Text(busy ? 'Publishing...' : 'Publish listing'),
            ),
          ],
        ),
      ),
    );
  }
}

const categoriesForSale = ['Electronics', 'Fashion', 'Home', 'Vehicles', 'Other'];

class ProductPage extends StatelessWidget {
  final String productId;
  final Map<String, dynamic> data;

  const ProductPage({super.key, required this.productId, required this.data});

  @override
  Widget build(BuildContext context) {
    final status = (data['status'] ?? 'available').toString();
    final isMine = FirebaseAuth.instance.currentUser?.uid == data['sellerId'];
    final canBuy = status == 'available' && !isMine;

    return Scaffold(
      appBar: AppBar(title: const Text('Product details')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          SizedBox(height: 260, child: productImage(data['imageUrl'])),
          const SizedBox(height: 18),
          Text(
            '₱${money(data['price'])}',
            style: const TextStyle(fontSize: 27, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(data['title'] ?? 'Product', style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 12),
          Text('Category: ${data['category'] ?? 'Other'}'),
          const SizedBox(height: 12),
          Text(data['description'] ?? 'No description'),
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: canBuy
                ? () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CheckoutPage(productId: productId, data: data),
                      ),
                    )
                : null,
            icon: const Icon(Icons.shopping_bag_outlined),
            label: Text(
              isMine
                  ? 'This is your listing'
                  : status != 'available'
                      ? 'Not available'
                      : 'Buy now',
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// SIMULATED PAYMENT GATEWAY
// Mimics how a real gateway (e.g. PayMongo) works, so the app's flow is the
// same as production:
//   1. app creates an order (awaiting_payment)
//   2. backend creates a checkout session  -> createCheckoutSession()
//   3. buyer pays on the gateway's hosted page -> MockCheckoutPage
//   4. gateway sends a webhook, which marks the order paid -> mockWebhook()
// To go live later, only createCheckoutSession() and mockWebhook() are
// replaced by a real backend. The rest of the app stays the same.
// ============================================================================
abstract class PaymentGateway {
  /// Returns a checkout session id.
  Future<String> createCheckoutSession({
    required String orderId,
    required num amount,
    required String description,
  });
}

class MockPaymentGateway implements PaymentGateway {
  @override
  Future<String> createCheckoutSession({
    required String orderId,
    required num amount,
    required String description,
  }) async {
    final ref = FirebaseFirestore.instance.collection('payment_sessions').doc();
    await ref.set({
      'orderId': orderId,
      'buyerId': FirebaseAuth.instance.currentUser!.uid,
      'amount': amount,
      'description': description,
      'status': 'open',
      'method': null,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }
}

final PaymentGateway paymentGateway = MockPaymentGateway();

/// Pretend webhook: in real life the gateway calls YOUR backend, which then
/// updates the order. Here we do that update from the app for testing only.
Future<void> mockWebhook({
  required String sessionId,
  required bool paid,
  String? method,
}) async {
  final db = FirebaseFirestore.instance;
  final sessionRef = db.collection('payment_sessions').doc(sessionId);
  final session = (await sessionRef.get()).data();
  if (session == null) return;

  final orderRef = db.collection('orders').doc(session['orderId'].toString());
  final batch = db.batch();
  if (paid) {
    batch.update(sessionRef, {'status': 'paid', 'method': method});
    batch.update(orderRef, {
      'status': 'pending', // paid, waiting for the seller to hand over the item
      'paymentStatus': 'paid',
      'paymentMethod': method,
    });
  } else {
    batch.update(sessionRef, {'status': 'failed'});
    batch.update(orderRef, {'paymentStatus': 'failed'});
  }
  await batch.commit();
}

/// Looks like a gateway's hosted checkout page (TEST MODE).
/// Pops with true (paid), false (failed) or null (closed without paying).
class MockCheckoutPage extends StatefulWidget {
  final String sessionId;
  final String title;
  final dynamic amount;

  const MockCheckoutPage({
    super.key,
    required this.sessionId,
    required this.title,
    required this.amount,
  });

  @override
  State<MockCheckoutPage> createState() => _MockCheckoutPageState();
}

class _MockCheckoutPageState extends State<MockCheckoutPage> {
  final methods = const ['GCash', 'Maya', 'Credit/Debit card', 'QR Ph'];
  String method = 'GCash';
  bool processing = false;

  Future<void> finish(bool paid) async {
    setState(() => processing = true);
    await Future.delayed(const Duration(seconds: 2)); // pretend network delay
    await mockWebhook(sessionId: widget.sessionId, paid: paid, method: method);
    if (mounted) Navigator.pop(context, paid);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: const Text('Secure checkout'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Chip(
              label: Text('TEST MODE'),
              backgroundColor: Color(0xFFFFE9B5),
            ),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      children: [
                        const Text('Pay Marketplace'),
                        const SizedBox(height: 6),
                        Text(
                          '₱${money(widget.amount)}',
                          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        Text(widget.title, textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Choose a payment method',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: methods.map((m) {
                    return ChoiceChip(
                      label: Text(m),
                      selected: method == m,
                      onSelected: processing ? null : (_) => setState(() => method = m),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: processing ? null : () => finish(true),
                  child: Text(processing ? 'Processing...' : 'Pay ₱${money(widget.amount)}'),
                ),
                TextButton(
                  onPressed: processing ? null : () => finish(false),
                  child: const Text('Simulate failed payment'),
                ),
                TextButton(
                  onPressed: processing ? null : () => Navigator.pop(context),
                  child: const Text('Close and pay later'),
                ),
                const SizedBox(height: 8),
                const Text(
                  'This is a simulation. No real money is charged.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CheckoutPage extends StatefulWidget {
  final String productId;
  final Map<String, dynamic> data;

  const CheckoutPage({super.key, required this.productId, required this.data});

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  final note = TextEditingController();
  String method = 'cash'; // 'cash' or 'online'
  bool busy = false;

  @override
  void dispose() {
    note.dispose();
    super.dispose();
  }

  void toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> placeOrder() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      toast('Open Account and sign in first.');
      return;
    }
    if (widget.data['sellerId'] == user.uid) {
      toast('You cannot buy your own item.');
      return;
    }

    setState(() => busy = true);
    try {
      final online = method == 'online';
      final db = FirebaseFirestore.instance;
      final productRef = db.collection('products').doc(widget.productId);
      final orderRef = db.collection('orders').doc();
      num amount = 0;

      // Step 1: reserve the item and create the order in one transaction.
      await db.runTransaction((tx) async {
        final snap = await tx.get(productRef);
        final product = snap.data();
        if (product == null || product['status'] != 'available') {
          throw 'Sorry, this item is no longer available.';
        }
        amount = (product['price'] ?? 0) as num;
        tx.update(productRef, {'status': 'reserved'});
        tx.set(orderRef, {
          'productId': widget.productId,
          'productTitle': product['title'] ?? 'Product',
          'amount': product['price'],
          'buyerId': user.uid,
          'buyerEmail': user.email ?? '',
          'sellerId': product['sellerId'],
          'paymentMethod': online ? 'online' : 'cash_on_meetup',
          'paymentStatus': online ? 'pending' : 'unpaid',
          'status': online ? 'awaiting_payment' : 'pending',
          'note': note.text.trim(),
          'createdAt': FieldValue.serverTimestamp(),
        });
      });

      if (!online) {
        if (mounted) {
          Navigator.popUntil(context, (route) => route.isFirst);
          toast('Order placed! The seller will contact you.');
        }
        return;
      }

      // Step 2: ask the "backend" for a checkout session.
      final title = (widget.data['title'] ?? 'Product').toString();
      final sessionId = await paymentGateway.createCheckoutSession(
        orderId: orderRef.id,
        amount: amount,
        description: title,
      );
      await orderRef.update({'sessionId': sessionId});

      // Step 3: open the hosted checkout page.
      if (!mounted) return;
      final paid = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => MockCheckoutPage(
            sessionId: sessionId,
            title: title,
            amount: amount,
          ),
        ),
      );

      if (mounted) {
        Navigator.popUntil(context, (route) => route.isFirst);
        toast(paid == true
            ? 'Payment successful! Order placed.'
            : 'Payment not completed. Finish it from Orders > Pay now.');
      }
    } catch (e) {
      if (mounted) toast('Could not place order: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 60, color: Color(0xFF1877F2)),
                const SizedBox(height: 14),
                const Text('Confirm your order', style: TextStyle(fontSize: 24)),
                const SizedBox(height: 12),
                Text(
                  '${data['title'] ?? 'Product'}\n₱${money(data['price'])}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 18),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'cash',
                      icon: Icon(Icons.handshake_outlined),
                      label: Text('Pay on meetup'),
                    ),
                    ButtonSegment(
                      value: 'online',
                      icon: Icon(Icons.phone_android),
                      label: Text('Pay online (test)'),
                    ),
                  ],
                  selected: {method},
                  onSelectionChanged: busy ? null : (s) => setState(() => method = s.first),
                ),
                const SizedBox(height: 8),
                Text(
                  method == 'online'
                      ? 'Simulated gateway: GCash, Maya, card. No real money.'
                      : 'Pay the seller in person or on delivery.',
                  style: const TextStyle(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: note,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Note to seller (meetup place, phone number...)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: busy ? null : placeOrder,
                    child: Text(busy
                        ? 'Please wait...'
                        : method == 'online'
                            ? 'Continue to payment'
                            : 'Place order'),
                  ),
                ),
                TextButton(
                  onPressed: busy ? null : () => Navigator.pop(context),
                  child: const Text('Go back'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MyListingsPage extends StatelessWidget {
  const MyListingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AuthGate(
      message: 'Sign in to see your listings.',
      builder: (user) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('products')
              .where('sellerId', isEqualTo: user.uid)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text('Could not load listings.\n${snapshot.error}'));
            }
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final docs = snapshot.data!.docs;
            if (docs.isEmpty) {
              return const Center(child: Text('You have not listed any products.'));
            }
            return ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: docs.map((doc) {
                final data = doc.data();
                final status = (data['status'] ?? 'available').toString();
                return Card(
                  color: Colors.white,
                  margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: ListTile(
                    leading: SizedBox(
                      width: 55,
                      height: 55,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: productImage(data['imageUrl']),
                      ),
                    ),
                    title: Text(data['title'] ?? 'Product'),
                    subtitle: Text('₱${money(data['price'])} · $status'),
                    trailing: PopupMenuButton<String>(
                      onSelected: (action) async {
                        final ref = doc.reference;
                        if (action == 'delete') {
                          await ref.delete();
                        } else {
                          await ref.update({'status': action});
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'available', child: Text('Mark as available')),
                        PopupMenuItem(value: 'sold', child: Text('Mark as sold')),
                        PopupMenuItem(value: 'delete', child: Text('Delete listing')),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
        );
      },
    );
  }
}

class OrdersPage extends StatelessWidget {
  const OrdersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AuthGate(
      message: 'Sign in to view orders.',
      builder: (user) {
        return DefaultTabController(
          length: 2,
          child: Column(
            children: [
              const TabBar(
                tabs: [
                  Tab(text: 'My purchases'),
                  Tab(text: 'My sales'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    OrderList(field: 'buyerId', uid: user.uid, isSeller: false),
                    OrderList(field: 'sellerId', uid: user.uid, isSeller: true),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class OrderList extends StatelessWidget {
  final String field;
  final String uid;
  final bool isSeller;

  const OrderList({
    super.key,
    required this.field,
    required this.uid,
    required this.isSeller,
  });

  /// Updates the order and keeps the product status in sync.
  Future<void> setStatus(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    String newStatus,
  ) async {
    try {
      final db = FirebaseFirestore.instance;
      final data = doc.data();
      final batch = db.batch();
      batch.update(doc.reference, {
        'status': newStatus,
        if (newStatus == 'completed') 'paymentStatus': 'paid',
      });
      final productId = data['productId'];
      if (newStatus == 'cancelled' && data['sessionId'] != null) {
        batch.update(
          db.collection('payment_sessions').doc(data['sessionId'].toString()),
          {'status': 'cancelled'},
        );
      }
      if (productId != null) {
        batch.update(
          db.collection('products').doc(productId.toString()),
          {'status': newStatus == 'completed' ? 'sold' : 'available'},
        );
      }
      await batch.commit();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update order: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where(field, isEqualTo: uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Could not load orders.\n${snapshot.error}'));
        }
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        final docs = snapshot.data!.docs.toList()
          ..sort((a, b) {
            final ta = a.data()['createdAt'];
            final tb = b.data()['createdAt'];
            if (ta is Timestamp && tb is Timestamp) return tb.compareTo(ta);
            return 0;
          });

        if (docs.isEmpty) {
          return Center(
            child: Text(isSeller ? 'Sales will appear here.' : 'Your orders will appear here.'),
          );
        }

        return ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: docs.map((doc) {
            final data = doc.data();
            final status = (data['status'] ?? 'pending').toString();
                        final note = (data['note'] ?? '').toString();

            return Card(
              color: Colors.white,
              margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data['productTitle'] ?? 'Order',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text('₱${money(data['amount'])} · payment: ${data['paymentStatus'] ?? 'unpaid'} · $status'),
                    if (isSeller && (data['buyerEmail'] ?? '').toString().isNotEmpty)
                      Text('Buyer: ${data['buyerEmail']}'),
                    if (note.isNotEmpty) Text('Note: $note'),
                    if (status == 'pending' || status == 'awaiting_payment') ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        children: [
                          if (!isSeller &&
                              status == 'awaiting_payment' &&
                              data['sessionId'] != null)
                            FilledButton(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => MockCheckoutPage(
                                    sessionId: data['sessionId'].toString(),
                                    title: (data['productTitle'] ?? 'Order').toString(),
                                    amount: data['amount'],
                                  ),
                                ),
                              ),
                              child: const Text('Pay now'),
                            ),
                          if (isSeller && status == 'pending')
                            FilledButton(
                              onPressed: () => setStatus(context, doc, 'completed'),
                              child: const Text('Mark completed'),
                            ),
                          OutlinedButton(
                            onPressed: () => setStatus(context, doc, 'cancelled'),
                            child: const Text('Cancel order'),
                          ),
                        ],
                      ),
                    ],
                    if (isSeller && status == 'awaiting_payment')
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          'Waiting for the buyer to pay.',
                          style: TextStyle(color: Colors.orange),
                        ),
                      ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

/// Shows a product photo. Supports base64 strings (stored in Firestore) and
/// normal http(s) URLs.
Widget productImage(dynamic url) {
  final value = url?.toString() ?? '';
  if (value.isEmpty) return imagePlaceholder();

  if (value.startsWith('http')) {
    return Image.network(
      value,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => imagePlaceholder(),
    );
  }

  try {
    return Image.memory(
      base64Decode(value),
      fit: BoxFit.cover,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) => imagePlaceholder(),
    );
  } catch (_) {
    return imagePlaceholder();
  }
}

Widget imagePlaceholder() {
  return Container(
    color: const Color(0xFFE8EDF5),
    alignment: Alignment.center,
    child: const Icon(Icons.image_outlined, size: 48, color: Colors.blueGrey),
  );
}

String money(dynamic value) {
  final amount = value is num
      ? value.toDouble()
      : double.tryParse(value?.toString() ?? '') ?? 0;
  return amount.toStringAsFixed(2);
}