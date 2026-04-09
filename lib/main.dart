import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'firebase_options.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:url_launcher/url_launcher.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
    // 1. Inisialisasi Firebase
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (e) {
      debugPrint('Gagal inisialisasi Firebase: $e');
    }

    // 2. Beri sedikit delay (misal 2 detik) agar tulisan dan loading icon sempat terlihat
    await Future.delayed(const Duration(seconds: 2));

    // 3. Pindah ke MainScreen
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const MainScreen()),
      );
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
            _buildNavItem(2, Icons.search_outlined, Icons.search, 'Lacak Pesanan'),
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
          const OrderFormTab(),
          QRScannerTab(
            isActive: _selectedIndex == 1,
            onScanSuccess: (resi) {
              setState(() {
                _scannedResi = resi;
                _selectedIndex = 2; // Pindah otomatis ke Lacak Pesanan
              });
            },
          ),
          TrackingTab(initialResi: _scannedResi),
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
      autoStart: false, // Mencegah crash kamera akibat auto-start yang bentrok saat pindah tab
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
            // Ambil teks, hilangkan spasi tak terlihat, dan pastikan huruf besar
            final String? rawValue = barcode.rawValue?.trim().toUpperCase();
            if (rawValue != null) {
              // Validasi Pintar: Ekstrak hanya bagian yang berformat RS-XXXXXXXX
              if (rawValue.contains('RS-')) {
                final match = RegExp(r'RS-[A-Z0-9]{8}').firstMatch(rawValue);
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
  const OrderFormTab({super.key});

  @override
  State<OrderFormTab> createState() => _OrderFormTabState();
}

class _OrderFormTabState extends State<OrderFormTab> {
  final _nameController = TextEditingController();
  DateTime? _pickupDate;

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
                    TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'Nama Pemesan',
                        prefixIcon: const Icon(Icons.person_outline),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                    const SizedBox(height: 16),
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
                          if (_nameController.text.trim().isEmpty || _pickupDate == null) {
                            // Memunculkan Peringatan di atas pop-up
                            setModalState(() {
                              errorMessage = 'Nama dan Tanggal Pengambilan wajib diisi!';
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
    for (var entry in _cart.entries) {
      final item = _menuItems.firstWhere((m) => m['id'] == entry.key);
      final prefix = item['unit'] == 'kg' ? '${entry.value}kg' : '${entry.value}x';
      summaryList.add('- $prefix ${item['name']}');
    }
    final String orderSummaryNotes = summaryList.join('\n'); // Menggunakan enter (\n) ke bawah

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

    try {
      // 1. Simpan ke database Firestore dengan Document ID = noResi
      await FirebaseFirestore.instance.collection('orders').doc(noResi).set({
        'resi': noResi, // Simpan juga di dalam field dokumen agar mudah dibaca Admin
        'customerName': name,
        'orderDate': DateTime.now().toIso8601String(),
        'pickupDate': _pickupDate!.toIso8601String(),
        'items': _cart, // Simpan isi keranjang
        'totalPrice': _totalPrice, // Simpan total tagihan
        'weightKg': _totalItems.toDouble(), // Data dummy agar Tab Tracking lama tidak error
        'isPickedUp': false,
        'notes': orderSummaryNotes, // Masukkan ringkasan pesanan ke field notes
      });

      // 2. Tembak API Vercel agar Admin dapat Push Notif
      try {
        await http.post(
          Uri.parse('https://pesan-keranjang-backend.vercel.app/api/notify'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'customerName': name, 'weightKg': _totalItems}),
        );
      } catch (e) {
        debugPrint('Gagal mengirim notif ke admin: $e');
      }

      // 3. Tampilkan Resi Sukses
      if (mounted) {
        Navigator.pop(context); // Tutup loading screen
        _nameController.clear();
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
              icon: const Icon(Icons.chat_bubble),
              label: const Text('Kirim Notif via WhatsApp'),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () => Navigator.pop(context),
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
        // List Menu
        ListView.separated(
          padding: const EdgeInsets.only(top: 16, left: 16, right: 16, bottom: 100), // Spasi bawah agar tidak tertimpa bar keranjang
          itemCount: _menuItems.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final item = _menuItems[index];
            final id = item['id'] as String;
            final qty = _cart[id] ?? 0;
            
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 4)),
                ],
              ),
              child: Row(
                children: [
                  // Gambar Item dengan Fallback Otomatis
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      'assets/items/$id.png', // Harus berekstensi .png
                      width: 70,
                      height: 70,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            color: Colors.deepOrange.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.cake, color: Colors.deepOrange, size: 32),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Info Item (Nama & Harga)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item['name'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(
                          'Rp ${(item['price'] as int).toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')} / ${item['unit']}', 
                          style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  // Tombol Tambah & +/-
                  if (qty == 0)
                    OutlinedButton(
                      onPressed: () => _updateCart(id, 1),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        side: const BorderSide(color: Colors.deepOrange),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      child: const Text('Tambah', style: TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold)),
                    )
                  else
                    Row(
                      children: [
                        _buildCircleBtn(Icons.remove, () => _updateCart(id, -1)),
                        Container(
                          width: 36,
                          alignment: Alignment.center,
                          child: Text('$qty', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                        _buildCircleBtn(Icons.add, () => _updateCart(id, 1)),
                      ],
                    ),
                ],
              ),
            );
          },
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

  // Widget Bantuan untuk merender tombol (+) dan (-) 
  Widget _buildCircleBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.deepOrange),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 18, color: Colors.deepOrange),
      ),
    );
  }
}

// ============================================================================
// TAB 2: PELACAKAN PESANAN (REAL-TIME)
// ============================================================================
class TrackingTab extends StatefulWidget {
  final String? initialResi;

  const TrackingTab({super.key, this.initialResi});

  @override
  State<TrackingTab> createState() => _TrackingTabState();
}

class _TrackingTabState extends State<TrackingTab> {
  final _resiController = TextEditingController();
  String _searchedResi = '';

  @override
  void initState() {
    super.initState();
    if (widget.initialResi != null && widget.initialResi!.isNotEmpty) {
      _resiController.text = widget.initialResi!;
      _searchedResi = widget.initialResi!;
    }
  }

  @override
  void didUpdateWidget(TrackingTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Jalankan otomatis ketika resi baru dioper dari Tab Scanner
    if (widget.initialResi != oldWidget.initialResi && widget.initialResi != null && widget.initialResi!.isNotEmpty) {
      setState(() {
        _resiController.text = widget.initialResi!;
        _searchedResi = widget.initialResi!;
      });
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Lacak Pesanan', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87)),
              Text('Masukkan nomor resi untuk melihat status terkini.', style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
              const SizedBox(height: 24),
              
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _resiController,
                      decoration: const InputDecoration(
                        labelText: 'Nomor Resi',
                        hintText: 'Contoh: RS-A1B2C3D4',
                        prefixIcon: Icon(Icons.search, color: Colors.deepOrange),
                      ),
                      onSubmitted: (val) => setState(() => _searchedResi = val.trim()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    height: 56,
                    child: FilledButton(
                      onPressed: () => setState(() => _searchedResi = _resiController.text.trim()),
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        backgroundColor: Colors.deepOrange,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Cari', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              if (_searchedResi.isNotEmpty)
                StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance.collection('orders').doc(_searchedResi).snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (!snapshot.hasData || !snapshot.data!.exists) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_off, size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            Text('Pesanan tidak ditemukan.', style: TextStyle(fontSize: 18, color: Colors.grey.shade600)),
                            const Text('Resi salah, atau pesanan sudah dihapus oleh Admin.', style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      );
                    }

                    final data = snapshot.data!.data() as Map<String, dynamic>;
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
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // --- HEADER: NAMA & STATUS ---
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Nama Pemesan', style: TextStyle(color: Colors.black54, fontSize: 13, fontWeight: FontWeight.w600)),
                                      const SizedBox(height: 4),
                                      Text(data['customerName'] ?? 'Tanpa Nama', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
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
                          ],
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
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
        const Spacer(),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: valueColor ?? Colors.black87), textAlign: TextAlign.right),
      ],
    );
  }
}
