import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'pages/map_picker.dart';
import 'pages/worker_bookings_page.dart';  // تأكد أن اسم الملف صحيح


// رابط الباك إند
const String baseUrl = 'http://127.0.0.1:8000';

// IDs الخدمات في Django
const int fullWashServiceId = 4; // غسيل كامل
const int externalWashServiceId = 3; // غسيل خارجي

// -----------------------------
// تشغيل تطبيق العملاء
// -----------------------------
void main() {
  runApp(const CustomerApp());
}

class CustomerApp extends StatelessWidget {
  const CustomerApp({super.key});

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
      // هنا واجهة العملاء (مو العمالة)
      home:  CustomerHomePage(),
    );
  }
}

// -----------------------------
// الصفحة الرئيسية للعميل
// ----------------------------- WorkerBookingsPage , CustomerHomePage
class CustomerHomePage extends StatelessWidget {
  const CustomerHomePage({super.key});

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
                  'اختر الخدمة التي تناسبك',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 24),

                // بطاقة غسيل السيارات
                _ServiceCategoryCard(
                  title: 'غسيل السيارات',
                  description: 'غسيل كامل أو خارجي مع اختيار حجم السيارة',
                  icon: Icons.directions_car,
                  color: Colors.blue.shade300,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const BookingPage(),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 12),

                // بطاقة (قريباً) لغسيل الأثاث
                _ServiceCategoryCard(
                  title: 'غسيل الأثاث (قريباً)',
                  description: 'قريباً سيتم إضافة غسيل الكنب والسجاد',
                  icon: Icons.weekend,
                  color: Colors.grey.shade400,
                  disabled: true,
                ),

                const SizedBox(height: 12),

                // بطاقة (قريباً) لغسيل الأحواش
                _ServiceCategoryCard(
                  title: 'غسيل الأحواش (قريباً)',
                  description: 'قريباً سيتم إضافة خدمة غسيل الأحواش',
                  icon: Icons.house_siding,
                  color: Colors.grey.shade400,
                  disabled: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ServiceCategoryCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final bool disabled;

  const _ServiceCategoryCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    this.onTap,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveOnTap = disabled ? null : onTap;

    return GestureDetector(
      onTap: effectiveOnTap,
      child: Opacity(
        opacity: disabled ? 0.5 : 1,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
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
                backgroundColor: color.withOpacity(0.15),
                child: Icon(icon, color: color, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              if (!disabled)
                const Icon(Icons.arrow_forward_ios,
                    size: 16, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}

// -----------------------------
// صفحة حجز غسيل السيارات
// -----------------------------
class BookingPage extends StatefulWidget {
  const BookingPage({super.key});

  @override
  State<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> {
  final _formKey = GlobalKey<FormState>();

  // بيانات العميل
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  bool _isSubmitting = false;
  String? _errorMessage;
  String? _successMessage;

  // التاريخ والأوقات
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
  Set<String> _bookedSlots = {};

  // الموقع
  double? _selectedLat;
  double? _selectedLng;

  // نوع الغسيل وحجم السيارة
  String _selectedWashType = 'full'; // full أو external
  String _selectedCarSize = 'small'; // small أو big

  // طريقة الدفع
  String _selectedPaymentMethod = 'cash'; // apple_pay / google_pay / mada / cash

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

  // تحميل الأوقات المحجوزة لليوم المحدد
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

  // حساب السعر بناء على نوع الغسيل وحجم السيارة
  double _calculateTotalPrice() {
    if (_selectedWashType == 'external') {
      // غسيل خارجي – سعر ثابت
      return 25.0;
    } else {
      // غسيل كامل – حسب حجم السيارة
      if (_selectedCarSize == 'big') {
        return 45.0;
      } else {
        return 35.0;
      }
    }
  }

  // إرجاع ID الخدمة حسب نوع الغسيل
  int _getServiceId() {
    if (_selectedWashType == 'external') {
      return externalWashServiceId;
    } else {
      return fullWashServiceId;
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

    // مؤقتاً – إلى أن نربط تسجيل الدخول
    const int customerId = 1;
    const int carId = 1;

    final totalPrice = _calculateTotalPrice();

    final url = Uri.parse('$baseUrl/api/bookings/');
    final body = {
      'customer': customerId,
      'car': carId,
      'service': _getServiceId(),
      'customer_name': _nameController.text.trim(),
      'customer_phone': _phoneController.text.trim(),
      'car_size': _selectedCarSize, // small / big
      'address_text': _addressController.text.trim(),
      'latitude': _selectedLat,
      'longitude': _selectedLng,
      'date': _formatDate(_selectedDate!),
      'time_slot': _selectedTimeSlot,
      'status': 'pending',
      'payment_method': _selectedPaymentMethod,
      'total_price': totalPrice,
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
    final totalPrice = _calculateTotalPrice();

    return Scaffold(
      appBar: AppBar(
        title: const Text('حجز غسيل السيارات'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // معلومات العميل
              const Text(
                'معلومات العميل',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'اسم العميل',
                  border: OutlineInputBorder(),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'الرجاء إدخال الاسم';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'رقم الجوال',
                  border: OutlineInputBorder(),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'الرجاء إدخال رقم الجوال';
                  }
                  if (val.length < 8) {
                    return 'رقم الجوال غير صحيح';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 24),

              // نوع الغسيل
              const Text(
                'اختر نوع الغسيل',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              RadioListTile<String>(
                title: const Text('غسيل كامل'),
                value: 'full',
                groupValue: _selectedWashType,
                onChanged: (val) {
                  setState(() {
                    _selectedWashType = val ?? 'full';
                  });
                },
              ),
              RadioListTile<String>(
                title: const Text('غسيل خارجي فقط'),
                value: 'external',
                groupValue: _selectedWashType,
                onChanged: (val) {
                  setState(() {
                    _selectedWashType = val ?? 'external';
                  });
                },
              ),

              const SizedBox(height: 16),

              // حجم السيارة
              const Text(
                'اختر حجم السيارة',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              RadioListTile<String>(
                title: const Text('سيارة صغيرة'),
                value: 'small',
                groupValue: _selectedCarSize,
                onChanged: (val) {
                  setState(() {
                    _selectedCarSize = val ?? 'small';
                  });
                },
              ),
              RadioListTile<String>(
                title: const Text('سيارة كبيرة'),
                value: 'big',
                groupValue: _selectedCarSize,
                onChanged: (val) {
                  setState(() {
                    _selectedCarSize = val ?? 'big';
                  });
                },
              ),

              const SizedBox(height: 16),

              // العنوان
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
              const SizedBox(height: 12),

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

              const SizedBox(height: 16),

              // طريقة الدفع
              const Text(
                'طريقة الدفع',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              RadioListTile<String>(
                title: const Text('Apple Pay'),
                value: 'apple_pay',
                groupValue: _selectedPaymentMethod,
                onChanged: (val) {
                  setState(() {
                    _selectedPaymentMethod = val ?? 'apple_pay';
                  });
                },
              ),
              RadioListTile<String>(
                title: const Text('Google Pay / Android Pay'),
                value: 'google_pay',
                groupValue: _selectedPaymentMethod,
                onChanged: (val) {
                  setState(() {
                    _selectedPaymentMethod = val ?? 'google_pay';
                  });
                },
              ),
              RadioListTile<String>(
                title: const Text('مدى Pay'),
                value: 'mada',
                groupValue: _selectedPaymentMethod,
                onChanged: (val) {
                  setState(() {
                    _selectedPaymentMethod = val ?? 'mada';
                  });
                },
              ),
              RadioListTile<String>(
                title: const Text('كاش عند الوصول'),
                value: 'cash',
                groupValue: _selectedPaymentMethod,
                onChanged: (val) {
                  setState(() {
                    _selectedPaymentMethod = val ?? 'cash';
                  });
                },
              ),

              const SizedBox(height: 8),
              Text(
                'الإجمالي التقريبي: ${totalPrice.toStringAsFixed(0)} SAR',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),

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
                    backgroundColor: Colors.blue,
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
