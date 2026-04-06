import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'firebase_options.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Gagal inisialisasi Firebase (cek firebase_options.dart): $e');
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
      home: const MainScreen(),
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

  @override
  Widget build(BuildContext context) {
    if (!widget.isActive) {
      return const Center(child: Icon(Icons.qr_code_scanner, size: 64, color: Colors.grey));
    }

    return Stack(
      children: [
        MobileScanner(
          controller: _scannerController,
          onDetect: (capture) {
            if (_isProcessing) return; // Mencegah scan ganda (Spam)
            final List<Barcode> barcodes = capture.barcodes;
            for (final barcode in barcodes) {
              if (barcode.rawValue != null) {
                _isProcessing = true;
                widget.onScanSuccess(barcode.rawValue!);
                break;
              }
            }
          },
        ),
        // Overlay Kotak (Potongan Scanner UI)
        ColorFiltered(
          colorFilter: const ColorFilter.mode(Colors.black54, BlendMode.srcOut),
          child: Container(
            decoration: const BoxDecoration(color: Colors.transparent),
            child: Center(
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(24)),
              ),
            ),
          ),
        ),
        const Positioned(
          bottom: 80, left: 0, right: 0,
          child: Center(
            child: Text('Arahkan QR Code Pesanan ke kotak', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
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
  final _weightController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime? _pickupDate;
  bool _isLoading = false;

  String _formatDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Ags', 'Sep', 'Okt', 'Nov', 'Des'];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  Future<void> _submitOrder() async {
    final name = _nameController.text.trim();
    final weightStr = _weightController.text.trim().replaceAll(',', '.');
    final weight = double.tryParse(weightStr);

    if (name.isEmpty || weight == null || weight <= 0 || _pickupDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mohon lengkapi semua data dengan benar.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Simpan ke database Firestore
      final docRef = await FirebaseFirestore.instance.collection('orders').add({
        'customerName': name,
        'orderDate': DateTime.now().toIso8601String(),
        'pickupDate': _pickupDate!.toIso8601String(),
        'weightKg': weight,
        'isPickedUp': false,
        'notes': _notesController.text.trim(),
      });

      // 2. Tembak API Vercel agar Admin dapat Push Notif
      try {
        await http.post(
          Uri.parse('https://pesan-keranjang-backend.vercel.app/api/notify'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'customerName': name, 'weightKg': weight}),
        );
      } catch (e) {
        debugPrint('Gagal mengirim notif ke admin: $e');
      }

      // 3. Tampilkan Resi Sukses
      if (mounted) {
        _nameController.clear();
        _weightController.clear();
        _notesController.clear();
        setState(() => _pickupDate = null);
        _showSuccessDialog(docRef.id);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Terjadi kesalahan: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSuccessDialog(String resi) {
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
            FilledButton(
              onPressed: () => Navigator.pop(context),
              style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
              child: const Text('Tutup'),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 550),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.deepOrange.shade50,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.add_shopping_cart, color: Colors.deepOrange, size: 28),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Input Order Baru',
                            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Tambahkan data pesanan Anda',
                            style: TextStyle(fontSize: 14, color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade100),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                      const SizedBox(width: 12),
                      Text(
                        'Harga saat ini: Rp 45.000 / kg',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.blue.shade800),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Nama Anda',
                    hintText: 'Masukkan nama pemesan',
                    prefixIcon: const Icon(Icons.person_outline),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
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
                    if (picked != null) setState(() => _pickupDate = picked);
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Tgl Pengambilan',
                      prefixIcon: const Icon(Icons.event_available),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                    child: Text(
                      _pickupDate == null ? 'Pilih tanggal' : _formatDate(_pickupDate!),
                      style: TextStyle(color: _pickupDate == null ? Colors.black54 : Colors.black87),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _weightController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Bobot Kue (kg)',
                    hintText: 'Contoh: 1 atau 2.5',
                    prefixIcon: const Icon(Icons.scale_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _notesController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Catatan (Opsional)',
                    hintText: 'Contoh: Kemasan dipisah, boks warna merah, dll.',
                    alignLabelWithHint: true,
                    prefixIcon: const Padding(
                      padding: EdgeInsets.only(bottom: 24),
                      child: Icon(Icons.notes),
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: Colors.grey.shade300),
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
                      elevation: 2,
                    ),
                    onPressed: _isLoading ? null : _submitOrder,
                    icon: _isLoading 
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.save_alt, size: 24),
                    label: Text(
                      _isLoading ? 'Menyimpan...' : 'Simpan Order',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
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

  String _formatCurrency(double amount) {
    return 'Rp ${amount.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
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
                        hintText: 'Contoh: 8A2F...',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onSubmitted: (val) => setState(() => _searchedResi = val.trim()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    height: 56,
                    child: FilledButton(
                      onPressed: () => setState(() => _searchedResi = _resiController.text.trim()),
                      style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                      child: const Text('Cari'),
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
                              const Text('Pastikan nomor resi sudah benar.', style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                        );
                      }

                      final data = snapshot.data!.data() as Map<String, dynamic>;
                      final isPickedUp = data['isPickedUp'] ?? false;
                      final pickupDate = DateTime.tryParse(data['pickupDate'] ?? '') ?? DateTime.now();
                      final orderDate = DateTime.tryParse(data['orderDate'] ?? '') ?? DateTime.now();
                      final weight = (data['weightKg'] as num?)?.toDouble() ?? 0.0;
                      final totalPrice = weight * 45000;

                      return Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                          side: BorderSide(color: Colors.grey.shade200)
                        ),
                        color: Colors.white,
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Status Pesanan', style: TextStyle(color: Colors.black54)),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: isPickedUp ? Colors.green.shade50 : Colors.orange.shade50,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(isPickedUp ? Icons.check_circle : Icons.pending, size: 16, color: isPickedUp ? Colors.green : Colors.orange),
                                        const SizedBox(width: 6),
                                        Text(
                                          isPickedUp ? 'Sudah Diambil' : 'Sedang Diproses',
                                          style: TextStyle(fontWeight: FontWeight.bold, color: isPickedUp ? Colors.green.shade700 : Colors.orange.shade800),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(height: 1)),
                              Text(data['customerName'] ?? 'Tanpa Nama', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 16),
                              _buildDetailRow(Icons.calendar_today, 'Tanggal Pesan', _formatDate(orderDate)),
                              const SizedBox(height: 12),
                              _buildDetailRow(Icons.event, 'Jadwal Ambil', _formatDate(pickupDate)),
                              const SizedBox(height: 12),
                              _buildDetailRow(Icons.scale, 'Bobot Kue', '${weight.toStringAsFixed(1)} kg'),
                              const SizedBox(height: 12),
                              _buildDetailRow(Icons.payments, 'Total Tagihan', _formatCurrency(totalPrice), valueColor: Colors.deepOrange),
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
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade500),
        const SizedBox(width: 12),
        Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 15)),
        const Spacer(),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: valueColor ?? Colors.black87)),
      ],
    );
  }
}
