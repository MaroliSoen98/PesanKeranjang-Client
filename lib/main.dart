import 'dart:convert';
import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'firebase_options.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Mencegah error "Duplicate Firebase App" jika dijalankan di background
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  }
  debugPrint("Pesan background diterima: ${message.notification?.title}");

  // Tampilkan notifikasi saat pesan diterima di background
  if (message.notification != null) {
    await _showNotification(message);
  }
}

Future<void> _showNotification(RemoteMessage message) async {
  // Inisialisasi plugin notifikasi lokal di sini. Aman untuk dipanggil berulang kali
  // dan akan memastikan plugin siap digunakan baik di foreground maupun background.
  const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
    'order_updates_channel',
    'Notifikasi Pesanan',
    channelDescription: 'Pembaruan status pesanan',
    importance: Importance.max,
    priority: Priority.high,
    icon: '@mipmap/launcher_icon',
  );
  const DarwinInitializationSettings initializationSettingsDarwin = DarwinInitializationSettings();
  const InitializationSettings initializationSettings = InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/launcher_icon'),
    iOS: initializationSettingsDarwin,
  );

  await flutterLocalNotificationsPlugin.initialize(settings: initializationSettings);

  const DarwinNotificationDetails darwinPlatformChannelSpecifics =
      DarwinNotificationDetails();
  const NotificationDetails platformChannelSpecifics = NotificationDetails(
    android: androidPlatformChannelSpecifics,
    iOS: darwinPlatformChannelSpecifics,
  );

  await flutterLocalNotificationsPlugin.show(
    id: (message.hashCode % 100000).abs(), // Batasi nilai agar tidak melebih batas 32-bit Integer Android
    title: message.notification?.title,
    body: message.notification?.body,
    notificationDetails: platformChannelSpecifics,
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Listener onMessage. Inisialisasi notifikasi lokal akan ditangani oleh _showNotification.
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        _showNotification(message);
      }
    });
  } catch (e) {
    debugPrint('Gagal inisialisasi Firebase: $e');
  }

  runApp(const ClientApp());
}

class ClientApp extends StatelessWidget {
  const ClientApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pesan Keranjang',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.deepOrange,
        scaffoldBackgroundColor: const Color(0xFFFFF8F3),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.deepOrange.shade300),
          ),
        ),
      ),
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // 1. Minta Izin Notifikasi Firebase
    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Cek apakah user sudah pernah login (menyimpan nama) sebelumnya
    final prefs = await SharedPreferences.getInstance();
    final bool isLoggedIn = prefs.getString('user_name') != null;

    // 2. Beri sedikit delay (misal 2 detik) agar tulisan dan loading icon sempat terlihat
    await Future.delayed(const Duration(seconds: 2));

    // 3. Pindah ke MainScreen atau LoginScreen
    if (mounted) {
      if (isLoggedIn) {
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => const MainScreen()));
      } else {
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => const LoginScreen()));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F3), // Sama dengan warna background
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo aplikasi
            Image.asset(
              'assets/icon/icon.png',
              width: 100, // Diperkecil lagi agar lebih pas di layar
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 24),
            
            // Teks Nama Aplikasi
            const Text(
              'Pesan Keranjang',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Colors.deepOrange,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 40),
            
            // Loading Icon (Spinner)
            const CircularProgressIndicator(
              color: Colors.deepOrange,
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// SCREEN: LOGIN / ONBOARDING (FIRST TIME ONLY)
// ============================================================================
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isLoading = false;

  Future<void> _login() async {
    final inputName = _nameController.text.trim();
    final inputPhone = _phoneController.text.trim();

    if (inputName.isEmpty || inputPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama dan Nomor WA wajib diisi!')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Cek ke Firestore apakah nomor WA sudah digunakan
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(inputPhone).get();

      if (userDoc.exists) {
        final registeredName = userDoc.data()?['name'] as String? ?? '';
        // Jika nomor sudah ada tapi namanya berbeda, tolak login (ignore besar-kecil huruf)
        if (registeredName.toLowerCase() != inputName.toLowerCase()) {
          setState(() => _isLoading = false);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Nomor $inputPhone sudah terdaftar sebelumnya atas nama customer lain. Gunakan nomor yang valid'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 4),
              ),
            );
          }
          return;
        }
        // Jika nama sama (user lama yang install ulang), biarkan login berlanjut
      } else {
        // 2. Jika nomor WA baru, pastikan NAMANYA belum dipakai oleh orang lain
        final nameQuery = await FirebaseFirestore.instance
            .collection('users')
            .where('name', isEqualTo: inputName)
            .get();

        if (nameQuery.docs.isNotEmpty) {
          setState(() => _isLoading = false);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Nama "$inputName" sudah terdaftar. Silahkan gunakan nama pembeli yang lain'),
                backgroundColor: Colors.orange.shade800,
                duration: const Duration(seconds: 4),
              ),
            );
          }
          return; // Hentikan proses login
        }

        // Jika nomor baru dan nama juga unik, simpan ke koleksi 'users'
        await FirebaseFirestore.instance.collection('users').doc(inputPhone).set({
          'name': inputName,
          'phone': inputPhone,
          'createdAt': DateTime.now().toIso8601String(),
        });
      }

      // 2. Simpan identitas ke penyimpanan lokal HP (Session)
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_name', inputName);
      await prefs.setString('user_phone', inputPhone);

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const MainScreen()),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Terjadi kesalahan koneksi: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // --- HEADER: LOGO & JUDUL (Rata Tengah) ---
                Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.deepOrange.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: Image.asset('assets/icon/icon.png', width: 72, height: 72),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Selamat Datang',
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Silakan lengkapi data diri Anda untuk mempermudah proses pemesanan.',
                      style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
                const SizedBox(height: 48),
                TextField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Nama Lengkap',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Nomor WhatsApp',
                    prefixIcon: Icon(Icons.phone_outlined),
                    hintText: 'Contoh: 081234567890',
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: _isLoading ? null : _login,
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      backgroundColor: Colors.deepOrange,
                    ),
                    child: _isLoading
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Mulai Pesan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  bool _isScanning = false;
  String? _scannedResi;

  Widget _buildCustomBottomNav() {
    return Container(
      padding: const EdgeInsets.only(bottom: 12, top: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _buildNavItem(0, Icons.shopping_bag_outlined, Icons.shopping_bag, 'Pesan Kue'),
            _buildCenterNavItem(1, Icons.qr_code_scanner_outlined, Icons.qr_code_scanner, 'Scan QR'),
            _buildNavItem(2, Icons.receipt_long_outlined, Icons.receipt_long, 'Daftar Pesanan'),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, IconData activeIcon, String label) {
    final isSelected = _selectedIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedIndex = index;
            if (index == 1) _isScanning = true;
          });
        },
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? Colors.deepOrange.shade50 : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                isSelected ? activeIcon : icon,
                color: isSelected ? Colors.deepOrange : Colors.grey.shade400,
                size: 26,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.deepOrange : Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCenterNavItem(int index, IconData icon, IconData activeIcon, String label) {
    final isSelected = _selectedIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedIndex = index;
            if (index == 1) _isScanning = true;
          });
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.deepOrange,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.deepOrange.withOpacity(isSelected ? 0.4 : 0.2),
                    blurRadius: isSelected ? 12 : 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                isSelected ? activeIcon : icon,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.deepOrange : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Pesan Keranjang',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          OrderFormTab(
            onOrderSuccess: (resi) {
              setState(() {
                _scannedResi = resi;
                _selectedIndex = 2; // Pindah otomatis ke Lacak Pesanan
              });
            },
          ),
          QRScannerTab(
            isActive: _selectedIndex == 1,
            onScanSuccess: (resi) {
              setState(() {
                _scannedResi = resi;
                _selectedIndex = 2; // Pindah otomatis ke Lacak Pesanan
              });
            },
          ),
          OrderHistoryTab(initialResi: _scannedResi),
        ],
      ),
      bottomNavigationBar: _buildCustomBottomNav(),
    );
  }
}

class _ScannerOverlayShape extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    return Path()
      ..fillType = PathFillType.evenOdd // Membolongi area yang saling bersinggungan
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(size.width / 2, size.height / 2),
            width: 280,
            height: 280,
          ),
          const Radius.circular(24),
        ),
      );
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

// ============================================================================
// TAB 3: SCAN QR
// ============================================================================
class QRScannerTab extends StatefulWidget {
  final bool isActive;
  final Function(String) onScanSuccess;

  const QRScannerTab({
    super.key,
    required this.isActive,
    required this.onScanSuccess,
  });

  @override
  State<QRScannerTab> createState() => _QRScannerTabState();
}

class _QRScannerTabState extends State<QRScannerTab> {
  late MobileScannerController _scannerController;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
    );
    if (widget.isActive) _scannerController.start();
  }

  @override
  void didUpdateWidget(QRScannerTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Otomatis Matikan/Nyalakan Kamera Saat Tab Berpindah
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _isProcessing = false;
        _scannerController.start();
      } else {
        _scannerController.stop();
      }
    }
  }

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  Widget _buildControlButton({required IconData icon, required VoidCallback onPressed}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black54,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white38, width: 1),
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white),
        onPressed: onPressed,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        MobileScanner(
          controller: _scannerController,
          onDetect: (capture) {
            if (_isProcessing) return; // Mencegah scan ganda (Spam)
            final List<Barcode> barcodes = capture.barcodes;
            for (final barcode in barcodes) {
              // Ambil teks secara aman tanpa peringatan null-aware operator
              final String? rawValue = barcode.rawValue;
              if (rawValue != null) {
                final String cleanValue = rawValue.trim().toUpperCase();
                // Validasi Pintar: Ekstrak hanya bagian yang berformat RS-XXXXXXXX
                if (cleanValue.contains('RS-')) {
                  final match = RegExp(r'RS-[A-Z0-9]{8}').firstMatch(cleanValue);
                  if (match != null) {
                    _isProcessing = true;
                    widget.onScanSuccess(match.group(0)!); // Lempar hanya resi bersihnya
                    break;
                  }
                }
              }
            }
          },
        ),
        // Overlay Kotak (Potongan Scanner UI)
        ClipPath(
          clipper: _ScannerOverlayShape(),
          child: Container(
            color: Colors.black54,
          ),
        ),
        // Frame Kustom
        Center(
          child: Container(
            width: 280,
            height: 280,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.deepOrange, width: 3),
              borderRadius: BorderRadius.circular(24),
            ),
          ),
        ),
        // Tombol Kontrol (Senter & Putar Kamera)
        Positioned(
          top: 24,
          right: 24,
          child: Column(
            children: [
              ValueListenableBuilder<MobileScannerState>(
                valueListenable: _scannerController,
                builder: (context, state, child) {
                  return _buildControlButton(
                    icon: state.torchState == TorchState.on ? Icons.flash_on : Icons.flash_off,
                    onPressed: () => _scannerController.toggleTorch(),
                  );
                },
              ),
              const SizedBox(height: 16),
              _buildControlButton(
                icon: Icons.flip_camera_ios,
                onPressed: () => _scannerController.switchCamera(),
              ),
            ],
          ),
        ),
        // Label Instruksi Bawah
        Positioned(
          bottom: 40,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.white24, width: 1),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.qr_code_scanner, color: Colors.white, size: 20),
                  SizedBox(width: 10),
                  Text(
                    'Arahkan QR Code ke area kotak',
                    style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.5),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Indikator Loading saat QR Berhasil Terbaca
        if (_isProcessing)
          Container(
            color: Colors.black54,
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.deepOrange),
                  SizedBox(height: 16),
                  Text('Memproses Resi...', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// ============================================================================
// TAB 1: FORM PEMESANAN
// ============================================================================
class OrderFormTab extends StatefulWidget {
  final Function(String) onOrderSuccess;

  const OrderFormTab({super.key, required this.onOrderSuccess});

  @override
  State<OrderFormTab> createState() => _OrderFormTabState();
}

class _OrderFormTabState extends State<OrderFormTab> {
  final _nameController = TextEditingController();
  DateTime? _pickupDate;
  String _userPhone = '';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _nameController.text = prefs.getString('user_name') ?? '';
      _userPhone = prefs.getString('user_phone') ?? '';
    });
  }

  // --- TAHAP 1: DATA MENU & KERANJANG ---
  final List<Map<String, dynamic>> _menuItems = [
    {'id': 'kue_cina', 'name': 'Kue Cina', 'price': 45000, 'unit': 'kg'},
    {'id': 'susunan_3', 'name': 'Susunan 3', 'price': 60000, 'unit': 'box'},
    {'id': 'susunan_5', 'name': 'Susunan 5', 'price': 70000, 'unit': 'box'},
    {'id': 'susunan_7', 'name': 'Susunan 7', 'price': 80000, 'unit': 'box'},
    {'id': 'dodol_lapis', 'name': 'Dodol Lapis', 'price': 75000, 'unit': 'kg'},
    {'id': 'dodol_biasa', 'name': 'Dodol Biasa', 'price': 65000, 'unit': 'kg'},
    {'id': 'dodol_duren', 'name': 'Dodol Duren', 'price': 75000, 'unit': 'kg'},
  ];

  final Map<String, int> _cart = {}; // Format: { id_item: jumlah }

  int get _totalItems => _cart.length; // Sekarang hanya menghitung jumlah "variasi" kuenya saja

  double get _totalPrice {
    double total = 0;
    for (var item in _menuItems) {
      int qty = _cart[item['id']] ?? 0;
      total += qty * (item['price'] as int);
    }
    return total;
  }

  void _updateCart(String id, int delta) {
    setState(() {
      int currentQty = _cart[id] ?? 0;
      int newQty = currentQty + delta;
      if (newQty <= 0) {
        _cart.remove(id);
      } else {
        _cart[id] = newQty;
      }
    });
  }

  void _proceedToCheckout() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true, // Menghindari pop-up kepotong tombol home/back bawaan HP
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        String? errorMessage; // Menyimpan status peringatan

        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                  left: 24, right: 24, top: 24,
                ),
                child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Konfirmasi Pesanan', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context))
                      ],
                    ),
                    
                    // --- BANNER PERINGATAN (MUNCUL JIKA KOSONG) ---
                    if (errorMessage != null)
                      Container(
                        margin: const EdgeInsets.only(top: 8, bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                errorMessage!,
                                style: TextStyle(color: Colors.red.shade700, fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 8),

                    // --- TAMPILAN RINGKASAN PESANAN (CLEAN & MINIMALIST) ---
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Rincian Belanja', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black54, fontSize: 13)),
                          const SizedBox(height: 12),
                          ..._cart.entries.map((entry) {
                            final item = _menuItems.firstWhere((m) => m['id'] == entry.key);
                            final subtotal = (item['price'] as int) * entry.value;
                            final prefix = item['unit'] == 'kg' ? '${entry.value}kg' : '${entry.value}x';
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('$prefix ${item['name']}', style: const TextStyle(fontSize: 14, color: Colors.black87, fontWeight: FontWeight.w500)),
                                  Text('Rp ${subtotal.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}', style: const TextStyle(fontSize: 14)),
                                ],
                              ),
                            );
                          }),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Divider(color: Colors.black12, height: 1),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Pemesan', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black54, fontSize: 13)),
                              Text(_nameController.text, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 14)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Total Pembayaran', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                              Text(
                                'Rp ${_totalPrice.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}', 
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange, fontSize: 16)
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // --- INPUT FORM ---
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now().add(const Duration(days: 1)),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) {
                          setModalState(() => _pickupDate = picked);
                          setState(() => _pickupDate = picked);
                        }
                      },
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Tgl Pengambilan',
                          prefixIcon: const Icon(Icons.event_available),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: Text(
                          _pickupDate == null ? 'Pilih tanggal' : _formatDate(_pickupDate!),
                          style: TextStyle(color: _pickupDate == null ? Colors.black54 : Colors.black87),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      backgroundColor: Colors.deepOrange,
                      foregroundColor: Colors.white,
                        ),
                        onPressed: () {
                          if (_pickupDate == null) {
                            // Memunculkan Peringatan di atas pop-up
                            setModalState(() {
                              errorMessage = 'Tanggal Pengambilan wajib dipilih!';
                            });
                          } else {
                            // Validasi sukses
                            setModalState(() => errorMessage = null);
                            Navigator.pop(context); // Tutup pop-up
                            _submitOrder(); // Proses ke Firebase
                          }
                        },
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text(
                          'Buat Pesanan',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ));
          }
        );
      },
    );
  }
  // ----------------------------------------

  // --- FUNGSI UNTUK KIRIM WHATSAPP ---
  final String _sellerPhoneNumber = '6281298158550'; // <-- GANTI DENGAN NOMOR WA PENJUAL

  Future<void> _launchWhatsApp(String resi, String customerName) async {
    final String message = 'Halo, saya *$customerName* baru saja membuat pesanan baru dengan nomor resi: *$resi*.\nMohon dicek dan segera diproses ya, terima kasih!';
    final Uri whatsappUri = Uri.parse(
      'https://wa.me/$_sellerPhoneNumber?text=${Uri.encodeComponent(message)}',
    );

    // Langsung eksekusi launchUrl karena canLaunchUrl sering dicekal
    // oleh sistem keamanan Android 11+ / iOS 14+
    try {
      final launched = await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
      if (!launched) throw Exception('Gagal membuka link');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tidak dapat membuka WhatsApp. Pastikan aplikasi sudah terinstall.')),
        );
      }
    }
  }
  // ------------------------------------

  String _formatDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Ags', 'Sep', 'Okt', 'Nov', 'Des'];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  Future<void> _submitOrder() async {
    final name = _nameController.text.trim();

    if (name.isEmpty || _pickupDate == null) return; // Validasi sudah dialihkan ke dalam Pop-up

    // Buat Ringkasan Pesanan otomatis untuk dikirim sebagai Catatan (Notes)
    final List<String> summaryList = [];
    final List<String> notifItems = [];
    for (var entry in _cart.entries) {
      final item = _menuItems.firstWhere((m) => m['id'] == entry.key);
      final prefix = item['unit'] == 'kg' ? '${entry.value}kg' : '${entry.value}x';
      summaryList.add('- $prefix ${item['name']}');
      notifItems.add('$prefix ${item['name']}');
    }
    final String orderSummaryNotes = summaryList.join('\n'); // Menggunakan enter (\n) ke bawah
    final String itemsSummary = notifItems.join(' & '); // Gabungkan untuk Vercel (cth: 10kg Kue Cina & 5kg Dodol)

    // Munculkan Loading Screen
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: Colors.deepOrange)),
    );

    // Generate nomor resi khusus
    final random = Random();
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final randomString = List.generate(8, (index) => chars[random.nextInt(chars.length)]).join();
    final noResi = 'RS-$randomString';

    // Dapatkan FCM Token perangkat klien untuk dikirim ke database
    String? fcmToken;
    try {
      fcmToken = await FirebaseMessaging.instance.getToken();
    } catch (e) {
      debugPrint('Gagal mendapatkan FCM Token: $e');
    }

    try {
      // 1. Simpan ke database Firestore dengan Document ID = noResi
      await FirebaseFirestore.instance.collection('orders').doc(noResi).set({
        'resi': noResi, // Simpan juga di dalam field dokumen agar mudah dibaca Admin
        'customerName': name,
        'customerPhone': _userPhone, // Identifikasi orderan ini milik siapa
        'orderDate': DateTime.now().toIso8601String(),
        'pickupDate': _pickupDate!.toIso8601String(),
        'items': _cart, // Simpan isi keranjang
        'totalPrice': _totalPrice, // Simpan total tagihan
        'weightKg': _totalItems.toDouble(), // Data dummy agar Tab Tracking lama tidak error
        'isPickedUp': false,
        'notes': orderSummaryNotes, // Masukkan ringkasan pesanan ke field notes
        'fcmToken': fcmToken, // Simpan token agar admin/backend bisa kirim push notif khusus ke HP ini
      });

      // 2. Tembak API Vercel agar Admin dapat Push Notif
      try {
        await http.post(
          Uri.parse('https://pesan-keranjang-backend.vercel.app/api/notify'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'customerName': name, 
            'weightKg': _totalItems,
            'itemsSummary': itemsSummary // Kirim data ringkasan ke Vercel
          }),
        );
      } catch (e) {
        debugPrint('Gagal mengirim notif ke admin: $e');
      }

      // 3. Tampilkan Resi Sukses
      if (mounted) {
        try {
          FirebaseMessaging.instance.subscribeToTopic(noResi); // Berlangganan notif khusus resi ini
        } catch (e) {
          debugPrint('Gagal subscribe topic: $e');
        }
        Navigator.pop(context); // Tutup loading screen
        setState(() {
          _pickupDate = null;
          _cart.clear(); // Kosongkan keranjang
        });
        _showSuccessDialog(noResi, name);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Tutup loading screen
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Terjadi kesalahan: $e')),
        );
      }
    }
  }

  void _showSuccessDialog(String resi, String customerName) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 64),
            const SizedBox(height: 16),
            const Text('Pesanan Berhasil!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Simpan Nomor Resi ini untuk melacak pesanan Anda:', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(resi, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  const SizedBox(width: 12),
                  InkWell(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: resi));
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Resi disalin ke clipboard!')));
                    },
                    child: const Icon(Icons.copy, color: Colors.deepOrange),
                  )
                ],
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => _launchWhatsApp(resi, customerName),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                backgroundColor: const Color(0xFF25D366), // Warna Hijau WhatsApp
                foregroundColor: Colors.white,
              ),
            icon: const FaIcon(FontAwesomeIcons.whatsapp, size: 20),
              label: const Text('Kirim Notif via WhatsApp'),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () {
                Navigator.pop(context); // Tutup pop-up sukses
                widget.onOrderSuccess(resi); // Arahkan ke tab Lacak Pesanan dan auto search
              },
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                backgroundColor: Colors.grey.shade200,
                foregroundColor: Colors.black87,
              ),
              child: const Text('Tutup', style: TextStyle(fontWeight: FontWeight.normal)),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Katalog Menu (Gaya GoFood / GrabFood)
        Container(
          color: Colors.white, // Background katalog putih bersih
          child: CustomScrollView(
            slivers: [
              // Header Toko
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.storefront, color: Colors.deepOrange.shade400, size: 28),
                          const SizedBox(width: 12),
                          const Text(
                            'Katalog Menu',
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Pilih varian kue dan dodol favorit Anda untuk acara spesial.',
                        style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ),
              
              // List Item Menu
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final item = _menuItems[index];
                    final id = item['id'] as String;
                    final qty = _cart[id] ?? 0;
                    
                    return Column(
                      children: [
                        const Divider(height: 1, color: Colors.black12), // Garis pembatas tipis
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Gambar Kiri
                              ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Image.asset(
                                  'assets/items/$id.png',
                                  width: 100,
                                  height: 100,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      width: 100,
                                      height: 100,
                                      decoration: BoxDecoration(
                                        color: Colors.deepOrange.shade50,
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Icon(Icons.cake, color: Colors.deepOrange.shade200, size: 40),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 16),
                              
                              // Info Kanan (Nama, Harga, dan Tombol)
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item['name'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Rp ${(item['price'] as int).toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')} / ${item['unit']}', 
                                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                                    ),
                                    const SizedBox(height: 16),
                                    
                                    // Tombol di pojok kanan
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: qty == 0
                                          ? OutlinedButton(
                                              onPressed: () => _updateCart(id, 1),
                                              style: OutlinedButton.styleFrom(
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                                side: BorderSide(color: Colors.deepOrange.shade400),
                                                padding: const EdgeInsets.symmetric(horizontal: 24),
                                                minimumSize: const Size(0, 36),
                                              ),
                                              child: Text('Tambah', style: TextStyle(color: Colors.deepOrange.shade600, fontWeight: FontWeight.bold, fontSize: 13)),
                                            )
                                          : Container(
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius: BorderRadius.circular(20),
                                                border: Border.all(color: Colors.grey.shade300),
                                                boxShadow: [
                                                  BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 2))
                                                ]
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  _buildActionBtn(Icons.remove, () => _updateCart(id, -1), isAdd: false),
                                                  Container(
                                                    width: 36,
                                                    alignment: Alignment.center,
                                                    child: Text('$qty', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                                                  ),
                                                  _buildActionBtn(Icons.add, () => _updateCart(id, 1), isAdd: true),
                                                ],
                                              ),
                                            ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                  childCount: _menuItems.length,
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 120)), // Jaga-jaga jarak bar melayang
            ],
          ),
        ),
        
        // Cart Bar (Gaya GoFood) Melayang di bawah
        if (_totalItems > 0)
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: GestureDetector(
              onTap: _proceedToCheckout,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.deepOrange,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(color: Colors.deepOrange.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 6)),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('$_totalItems Item', style: const TextStyle(color: Colors.white, fontSize: 12)),
                        Text(
                          'Rp ${_totalPrice.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}', 
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)
                        ),
                      ],
                    ),
                    const Row(
                      children: [
                        Text('Lanjut', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                        SizedBox(width: 8),
                        Icon(Icons.chevron_right, color: Colors.white),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  // Widget Bantuan untuk merender tombol Kuantitas (+) dan (-)
  Widget _buildActionBtn(IconData icon, VoidCallback onTap, {required bool isAdd}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: isAdd ? Colors.deepOrange : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 20, color: isAdd ? Colors.white : Colors.deepOrange),
      ),
    );
  }
}

// ============================================================================
// TAB 2: DAFTAR PESANAN
// ============================================================================
class OrderHistoryTab extends StatefulWidget {
  final String? initialResi;

  const OrderHistoryTab({super.key, this.initialResi});

  @override
  State<OrderHistoryTab> createState() => _OrderHistoryTabState();
}

class _OrderHistoryTabState extends State<OrderHistoryTab> {
  final PageController _pageController = PageController(viewportFraction: 0.88);
  List<String> _savedResis = [];
  int _currentPage = 0;
  bool _isLoadingCache = true;
  StreamSubscription<QuerySnapshot>? _orderStreamSubscription;

  @override
  void initState() {
    super.initState();
    _loadAndSyncOrders();
  }

  Future<void> _loadAndSyncOrders() async {
    final prefs = await SharedPreferences.getInstance();

    // 1. Load from cache first for instant UI
    List<String> cachedResis = prefs.getStringList('saved_resis') ?? [];

    // If coming from another tab, add the new resi to the top for immediate view
    if (widget.initialResi != null && widget.initialResi!.isNotEmpty) {
      cachedResis.remove(widget.initialResi);
      cachedResis.insert(0, widget.initialResi!);
    }
    
    if (mounted) {
      setState(() {
        _savedResis = cachedResis;
        _isLoadingCache = false;
      });
    }
// Not logged in, nothing to sync.
    // 2. Get user phone & name to start real-time sync
    final userPhone = prefs.getString('user_phone') ?? '';
    final userName = prefs.getString('user_name') ?? '';
    if (userPhone.isEmpty && userName.isEmpty) return; // Not logged in, nothing to sync.

    // 3. Start listening to Firestore for real-time updates
    await _orderStreamSubscription?.cancel(); // Cancel previous subscription if any
    _orderStreamSubscription = FirebaseFirestore.instance
        .collection('orders')
        .where('customerPhone', isEqualTo: userPhone)
        .where('customerName', isEqualTo: userName)
        .orderBy('orderDate', descending: true) // Get newest orders first
        .snapshots()
        .listen((snapshot) async {
      final serverResis = snapshot.docs.map((doc) => doc.id).toList();

      // Subscribe to topics for all orders associated with this user
      for (String resi in serverResis) {
        FirebaseMessaging.instance.subscribeToTopic(resi).catchError((e) => debugPrint('Gagal subscribe topic (sync): $e'));
      }

      if (mounted) setState(() => _savedResis = serverResis);

      // Update the cache in the background
      await prefs.setStringList('saved_resis', serverResis);
    }, onError: (error) {
      debugPrint('\n=== 🚨 ERROR SINKRONISASI FIRESTORE ===');
      debugPrint(error.toString());
      debugPrint('=======================================\n');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal sinkronisasi! Cek Debug Console.')),
        );
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _orderStreamSubscription?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(OrderHistoryTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Jalankan otomatis ketika resi baru dioper dari Tab Scanner
    if (widget.initialResi != null && widget.initialResi != oldWidget.initialResi) {
      _addNewResi(widget.initialResi!);
    }
  }

  Future<void> _addNewResi(String resi) async {
    if (resi.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    _savedResis.remove(resi);
    _savedResis.insert(0, resi); // Taruh di paling atas/baru
    await prefs.setStringList('saved_resis', _savedResis);
    try {
      FirebaseMessaging.instance.subscribeToTopic(resi); // Langganan notif resi hasil scan
    } catch (e) {
      debugPrint('Gagal subscribe topic: $e');
    }

    if (mounted) {
      setState(() {
        _currentPage = 0;
      });
      if (_pageController.hasClients) {
        _pageController.jumpToPage(0);
      }
    }
  }

  Future<void> _launchWhatsAppChat(String resi) async {
    final String message = 'Halo Admin Pesan Keranjang, saya ingin bertanya mengenai pesanan saya dengan nomor resi: *$resi*.';
    final Uri whatsappUri = Uri.parse(
      'https://wa.me/6281298158550?text=${Uri.encodeComponent(message)}',
    );

    try {
      final launched = await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
      if (!launched) throw Exception('Gagal membuka link');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tidak dapat membuka WhatsApp. Pastikan aplikasi sudah terinstall.')),
        );
      }
    }
  }

  String _formatDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Ags', 'Sep', 'Okt', 'Nov', 'Des'];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  static final _currencyRegex = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
  String _formatCurrency(double amount) {
    return 'Rp ${amount.toInt().toString().replaceAllMapped(_currencyRegex, (Match m) => '${m[1]}.')}';
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 24, right: 24, top: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Daftar Pesanan', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87)),
                  Text('Riwayat pesanan yang telah Anda buat.', style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
                ],
              ),
            ),
            const SizedBox(height: 24),

            if (_isLoadingCache)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (_savedResis.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history, size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text('Belum ada riwayat pesanan.', style: TextStyle(fontSize: 16, color: Colors.grey.shade500)),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      flex: 10, // Ruang diperbesar agar card lebih panjang ke bawah dan isinya tidak kepotong
                      child: PageView.builder(
                        physics: const BouncingScrollPhysics(),
                        controller: _pageController,
                        onPageChanged: (index) {
                          setState(() {
                            _currentPage = index;
                          });
                        },
                        itemCount: _savedResis.length,
                        itemBuilder: (context, index) {
                          if (index >= _savedResis.length) return const SizedBox();
                          final currentResi = _savedResis[index];

                          return AnimatedBuilder(
                            animation: _pageController,
                            builder: (context, child) {
                              double scale = 1.0;
                              double opacity = 1.0;
                              if (_pageController.position.haveDimensions) {
                                double pageOffset = _pageController.page! - index;
                                scale = (1 - (pageOffset.abs() * 0.1)).clamp(0.9, 1.0);
                                opacity = (1 - (pageOffset.abs() * 0.5)).clamp(0.5, 1.0);
                              } else {
                                scale = _currentPage == index ? 1.0 : 0.9;
                                opacity = _currentPage == index ? 1.0 : 0.5;
                              }
                              return Transform.scale(
                                scale: scale,
                                child: Opacity(opacity: opacity, child: child),
                              );
                            },
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                              child: StreamBuilder<DocumentSnapshot>(
                              stream: FirebaseFirestore.instance.collection('orders').doc(currentResi).snapshots(),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState == ConnectionState.waiting) {
                                  return const Center(child: CircularProgressIndicator());
                                }

                                if (!snapshot.hasData || !snapshot.data!.exists) {
                                  return Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.delete_outline, size: 64, color: Colors.grey.shade400),
                                        const SizedBox(height: 16),
                                        Text('Pesanan telah dihapus.', style: TextStyle(fontSize: 18, color: Colors.grey.shade600)),
                                        const Text('Menunggu sinkronisasi...', style: TextStyle(color: Colors.grey)),
                                      ],
                                    ),
                                  );
                                }

                                  final data = (snapshot.data!.data() as Map<String, dynamic>?) ?? {};
                                final isPickedUp = data['isPickedUp'] ?? false;
                                final pickupDate = DateTime.tryParse(data['pickupDate'] ?? '') ?? DateTime.now();
                                final orderDate = DateTime.tryParse(data['orderDate'] ?? '') ?? DateTime.now();
                                final weight = (data['weightKg'] as num?)?.toDouble() ?? 0.0;
                                final totalPrice = (data['totalPrice'] as num?)?.toDouble() ?? (weight * 45000);
                                final notes = data['notes'] as String? ?? '';

                                return Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(color: Colors.grey.shade200),
                                    boxShadow: [
                                      BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 12, offset: const Offset(0, 6)),
                                    ],
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.only(left: 24, right: 24, top: 24, bottom: 32),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // --- HEADER: RESI & STATUS ---
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  const Text('Nomor Resi', style: TextStyle(color: Colors.black54, fontSize: 13, fontWeight: FontWeight.w600)),
                                                  const SizedBox(height: 4),
                                                  Text(data['resi'] ?? currentResi, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87, letterSpacing: 0.5)),
                                                ],
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                              decoration: BoxDecoration(
                                                color: isPickedUp ? Colors.green.shade50 : Colors.orange.shade50,
                                                borderRadius: BorderRadius.circular(20),
                                                border: Border.all(color: isPickedUp ? Colors.green.shade200 : Colors.orange.shade200),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(isPickedUp ? Icons.check_circle : Icons.pending, size: 16, color: isPickedUp ? Colors.green : Colors.orange),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    isPickedUp ? 'Selesai' : 'Diproses',
                                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isPickedUp ? Colors.green.shade700 : Colors.orange.shade800),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(height: 1, color: Colors.black12)),
                                        
                                        // --- DETAILS ---
                                        _buildDetailRow(Icons.calendar_today, 'Tanggal Pesan', _formatDate(orderDate)),
                                        const SizedBox(height: 12),
                                        _buildDetailRow(Icons.event, 'Jadwal Ambil', _formatDate(pickupDate)),
                                        const SizedBox(height: 12),
                                        
                                        if (notes.isNotEmpty) ...[
                                          Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Icon(Icons.shopping_bag_outlined, size: 20, color: Colors.grey.shade500),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text('Rincian Pesanan', style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                                                    const SizedBox(height: 4),
                                                    Text(notes, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.black87, height: 1.4)),
                                                  ]
                                                )
                                              )
                                            ]
                                          ),
                                          const SizedBox(height: 12),
                                        ] else ...[
                                          _buildDetailRow(Icons.shopping_bag, 'Pesanan', data['items'] != null ? '${weight.toInt()} Macam Item' : '${weight.toStringAsFixed(1)} kg'),
                                          const SizedBox(height: 12),
                                        ],

                                        const Padding(padding: EdgeInsets.only(top: 4, bottom: 16), child: Divider(height: 1, color: Colors.black12)),
                                        
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            const Text('Total Tagihan', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black54, fontSize: 14)),
                                            Text(_formatCurrency(totalPrice), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.deepOrange)),
                                          ],
                                        ),
                                        const SizedBox(height: 24),
                                        // --- TOMBOL WHATSAPP DIPINDAH KE DALAM KARTU ---
                                        SizedBox(
                                          width: double.infinity,
                                          height: 48,
                                          child: FilledButton.icon(
                                            onPressed: () => _launchWhatsAppChat(data['resi'] ?? currentResi),
                                            icon: const FaIcon(FontAwesomeIcons.whatsapp, size: 20),
                                            label: const Text('Hubungi Admin', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                            style: FilledButton.styleFrom(
                                              backgroundColor: const Color(0xFF25D366), // Warna hijau WhatsApp
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                            ),
                          );
                        },
                      ),
                    ),
                    
                    // --- PAGINATION & DELETE BUTTON ---
                    Padding(
                      padding: const EdgeInsets.only(left: 24, right: 24, bottom: 8, top: 0),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              IconButton(
                                onPressed: _currentPage > 0 ? () {
                                  _pageController.previousPage(duration: const Duration(milliseconds: 600), curve: Curves.easeOutCubic);
                                } : null,
                                icon: const Icon(Icons.arrow_back_ios, size: 20),
                                color: Colors.deepOrange,
                              ),
                              Text(
                                'Pesanan ${_currentPage + 1} dari ${_savedResis.length}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              IconButton(
                                onPressed: _currentPage < _savedResis.length - 1 ? () {
                                  _pageController.nextPage(duration: const Duration(milliseconds: 600), curve: Curves.easeOutCubic);
                                } : null,
                                icon: const Icon(Icons.arrow_forward_ios, size: 20),
                                color: Colors.deepOrange,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Spacer(flex: 1), // Ruang kosong tambahan untuk mendorong pagination ke atas
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, {Color? valueColor}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade500),
        const SizedBox(width: 12),
        Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: valueColor ?? Colors.black87), textAlign: TextAlign.right),
        ),
      ],
    );
  }
}
