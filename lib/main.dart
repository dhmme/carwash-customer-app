import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'pages/map_picker.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';


// رابط الباك إند
const String baseUrl = 'http://127.0.0.1:8000';

// نموذج بسيط للخدمات (غسيل كامل / غسيل خارجي)
class WashOption {
  final int serviceId;
  final String name;
  final String description;
  final double price;
  final Color color;
  final IconData icon;

  WashOption({
    required this.serviceId,
    required this.name,
    required this.description,
    required this.price,
    required this.color,
    required this.icon,
  });
}

// الخيارات المتاحة
final List<WashOption> washOptions = [
  WashOption(
    serviceId: 4, // تأكد أن Service ID = 1 في Django (غسيل كامل)
    name: 'غسيل كامل',
    description: 'تنظيف داخلي + خارجي + تنشيف وتلميع خارجي بسيط',
    price: 90,
    color: Colors.blue,
    icon: Icons.directions_car,
  ),
  WashOption(
    serviceId: 3, // تأكد أن Service ID = 2 في Django (غسيل خارجي فقط)
    name: 'غسيل خارجي فقط',
    description: 'تنظيف الهيكل الخارجي مع تجفيف سريع',
    price: 50,
    color: Colors.green,
    icon: Icons.local_car_wash,
  ),
];

void main() {
  runApp(const MyApp());
}

// ==========================
// الواجهة الرئيسية
// ==========================
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Car Wash',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Roboto',
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0D47A1), Color(0xFF42A5F5)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'مرحباً 👋',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'اختَر نوع الغسيل اللي يناسبك',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 24),

                // الكروت
                Expanded(
                  child: ListView.builder(
                    itemCount: washOptions.length,
                    itemBuilder: (context, index) {
                      final option = washOptions[index];
                      return _WashOptionCard(option: option);
                    },
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

class _WashOptionCard extends StatelessWidget {
  final WashOption option;

  const _WashOptionCard({required this.option});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // الانتقال لصفحة الحجز
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => BookingPage(option: option),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: option.color.withOpacity(0.1),
              child: Icon(
                option.icon,
                color: option.color,
                size: 32,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    option.description,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${option.price.toStringAsFixed(0)} SAR',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: option.color,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

// ==========================
// صفحة الحجز
// ==========================


class BookingPage extends StatefulWidget {
  final WashOption option;

  const BookingPage({super.key, required this.option});

  @override
  State<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _addressController = TextEditingController();

  bool _isSubmitting = false;
  String? _errorMessage;
  String? _successMessage;

  late final List<DateTime> _availableDates;
  DateTime? _selectedDate;

  final List<String> _morningSlots = [
    '9 صباحاً',
    '10 صباحاً',
    '11 صباحاً',
  ];

  final List<String> _eveningSlots = [
    '4 مساءً',
    '5 مساءً',
    '6 مساءً',
    '7 مساءً',
    '8 مساءً',
    '9 مساءً',
    '10 مساءً',
    '11 مساءً',
    '12 مساءً',
  ];

  String? _selectedTimeSlot;

  // الإحداثيات القادمة من الخريطة
  double? _selectedLat;
  double? _selectedLng;

  // الأوقات المحجوزة لليوم المختار
  Set<String> _bookedSlots = {};

  @override
  void initState() {
    super.initState();
    _availableDates = List.generate(
      5,
      (i) => DateTime.now().add(Duration(days: i)),
    );
    _selectedDate = _availableDates.first;
    _loadBookedSlotsForSelectedDate();
  }

  String _formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String _formatDateShort(DateTime date, int index) {
    if (index == 0) return 'اليوم (${_formatDate(date)})';
    if (index == 1) return 'غداً (${_formatDate(date)})';
    if (index == 2) return 'بعد غد (${_formatDate(date)})';
    return _formatDate(date);
  }

  Future<void> _loadBookedSlotsForSelectedDate() async {
    if (_selectedDate == null) return;
    final dateStr = _formatDate(_selectedDate!);

    try {
      final url = Uri.parse('$baseUrl/api/booked-slots/?date=$dateStr');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> list = data['booked'] ?? [];
        setState(() {
          _bookedSlots = list.map((e) => e.toString()).toSet();
          if (_selectedTimeSlot != null &&
              _bookedSlots.contains(_selectedTimeSlot)) {
            _selectedTimeSlot = null;
          }
        });
      } else {
        debugPrint('Failed to load booked slots: ${response.body}');
      }
    } catch (e) {
      debugPrint('Error loading booked slots: $e');
    }
  }

  Future<void> _submitBooking() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedDate == null) {
      setState(() {
        _errorMessage = 'الرجاء اختيار تاريخ الحجز';
        _successMessage = null;
      });
      return;
    }

    if (_selectedTimeSlot == null) {
      setState(() {
        _errorMessage = 'الرجاء اختيار وقت الحجز';
        _successMessage = null;
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _successMessage = null;
    });

    const int customerId = 1; // مؤقتاً
    const int carId = 1; // مؤقتاً

    final url = Uri.parse('$baseUrl/api/bookings/');
    final body = {
      'customer': customerId,
      'car': carId,
      'service': widget.option.serviceId,
      'address_text': _addressController.text,
      'latitude': _selectedLat,
      'longitude': _selectedLng,
      'date': _formatDate(_selectedDate!),
      'time_slot': _selectedTimeSlot,
      'status': 'pending',
      'total_price': widget.option.price,
    };

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode == 201) {
        setState(() {
          _successMessage = 'تم إنشاء طلب الغسيل بنجاح ✅';
        });
      } else {
        setState(() {
          _errorMessage =
              'فشل إنشاء الطلب (${response.statusCode})\n${response.body}';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'حدث خطأ في الاتصال: $e';
      });
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  Widget _buildDateChips() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'اختر تاريخ الحجز',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(_availableDates.length, (index) {
            final date = _availableDates[index];
            final isSelected =
                _selectedDate != null &&
                _formatDate(_selectedDate!) == _formatDate(date);

            return ChoiceChip(
              label: Text(_formatDateShort(date, index)),
              selected: isSelected,
              onSelected: (_) {
                setState(() {
                  _selectedDate = date;
                  _selectedTimeSlot = null;
                });
                _loadBookedSlotsForSelectedDate();
              },
            );
          }),
        ),
      ],
    );
  }

  Widget _buildTimeChips(String title, List<String> slots) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: slots.map((slot) {
            final isSelected = _selectedTimeSlot == slot;
            final isDisabled = _bookedSlots.contains(slot);

            return ChoiceChip(
              label: Text(
                slot,
                style: TextStyle(
                  color: isDisabled
                      ? Colors.grey.shade600
                      : (isSelected ? Colors.white : Colors.black87),
                ),
              ),
              selected: isSelected,
              onSelected: isDisabled
                  ? null
                  : (_) {
                      setState(() {
                        _selectedTimeSlot = slot;
                      });
                    },
              selectedColor: Colors.blue,
              disabledColor: Colors.grey.shade300,
            );
          }).toList(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final option = widget.option;

    return Scaffold(
      appBar: AppBar(
        title: Text('حجز: ${option.name}'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                option.name,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                option.description,
                style: const TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 8),
              Text(
                'السعر: ${option.price.toStringAsFixed(0)} SAR',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: option.color,
                ),
              ),
              const SizedBox(height: 24),

              // العنوان (اختياري إذا حدد موقع)
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: 'العنوان (اختياري إذا حددت موقع)',
                  border: OutlineInputBorder(),
                ),
                validator: (val) {
                  if ((val == null || val.isEmpty) &&
                      (_selectedLat == null || _selectedLng == null)) {
                    return 'أدخل العنوان أو حدّد الموقع على الخريطة';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // زر تحديد الموقع على الخريطة
              ElevatedButton(
                onPressed: () async {
                  final result = await Navigator.push<LatLng>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MapPickerPage(),
                    ),
                  );

                  if (result != null) {
                    setState(() {
                      _selectedLat = result.latitude;
                      _selectedLng = result.longitude;
                    });
                  }
                },
                child: Text(
                  _selectedLat == null
                      ? 'تحديد الموقع على الخريطة'
                      : 'تغيير الموقع المحدد',
                ),
              ),
              if (_selectedLat != null && _selectedLng != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    'الموقع المحدد: ${_selectedLat!.toStringAsFixed(5)}, ${_selectedLng!.toStringAsFixed(5)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black54,
                    ),
                  ),
                ),

              const SizedBox(height: 24),

              _buildDateChips(),
              const SizedBox(height: 24),

              _buildTimeChips('الفترة الصباحية', _morningSlots),
              const SizedBox(height: 16),
              _buildTimeChips('الفترة المسائية', _eveningSlots),

              const SizedBox(height: 12),
              if (_selectedDate != null)
                Text('التاريخ المختار: ${_formatDate(_selectedDate!)}'),
              if (_selectedTimeSlot != null)
                Text('الوقت المختار: $_selectedTimeSlot'),

              const SizedBox(height: 16),

              if (_errorMessage != null)
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              if (_successMessage != null)
                Text(
                  _successMessage!,
                  style: const TextStyle(color: Colors.green),
                ),

              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitBooking,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: option.color,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _isSubmitting
                      ? const CircularProgressIndicator(
                          color: Colors.white,
                        )
                      : const Text(
                          'تأكيد الحجز',
                          style: TextStyle(fontSize: 16),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


