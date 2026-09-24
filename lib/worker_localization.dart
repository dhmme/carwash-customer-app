import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

enum WorkerLanguage { ar, en, bn }

class WorkerLocalizations {
  WorkerLocalizations(this.language);

  static const _preferenceKey = 'worker_language';
  static const _storage = FlutterSecureStorage();
  final WorkerLanguage language;

  static Future<WorkerLanguage> loadLanguage() async {
    final code = await _storage.read(key: _preferenceKey);
    return WorkerLanguage.values.firstWhere(
      (language) => language.name == code,
      orElse: () => WorkerLanguage.ar,
    );
  }

  static Future<void> saveLanguage(WorkerLanguage language) async {
    await _storage.write(key: _preferenceKey, value: language.name);
  }

  Locale get locale => Locale(language.name);
  TextDirection get textDirection =>
      language == WorkerLanguage.ar ? TextDirection.rtl : TextDirection.ltr;

  String get languageName => languageLabel(language);
  String languageLabel(WorkerLanguage value) => switch (value) {
    WorkerLanguage.ar => 'العربية',
    WorkerLanguage.en => 'English',
    WorkerLanguage.bn => 'বাংলা',
  };

  String get appName =>
      _value('واجهة العامل', 'Worker Portal', 'কর্মী পোর্টাল');
  String get login => _value('تسجيل الدخول', 'Sign in', 'লগইন');
  String get phone => _value('رقم الجوال', 'Mobile number', 'মোবাইল নম্বর');
  String get password => _value('كلمة المرور', 'Password', 'পাসওয়ার্ড');
  String get enterValidPhone => _value(
    'أدخل رقم جوال صحيح',
    'Enter a valid mobile number',
    'সঠিক মোবাইল নম্বর লিখুন',
  );
  String get passwordLength => _value(
    'كلمة المرور يجب ألا تقل عن 8 أحرف',
    'Password must be at least 8 characters',
    'পাসওয়ার্ড কমপক্ষে ৮ অক্ষরের হতে হবে',
  );
  String get unauthorizedWorker => _value(
    'هذا الحساب غير مصرح له بدخول العمال.',
    'This account is not authorized for the worker portal.',
    'এই অ্যাকাউন্টটি কর্মী পোর্টালে প্রবেশের জন্য অনুমোদিত নয়।',
  );
  String get operationFailed => _value(
    'تعذر إكمال العملية.',
    'Unable to complete the request.',
    'অনুরোধটি সম্পন্ন করা যায়নি।',
  );
    String get service => _value('الخدمة', 'Service', 'সেবা');
  String get washType => _value('نوع الغسيل', 'Wash type', 'ওয়াশের ধরন');
  String get additionalServices => _value('الخدمات الإضافية', 'Additional services', 'অতিরিক্ত সেবা');

  String serviceName(String value) {
    final names = <String, List<String>>{
      'غسيل السيارات': ['غسيل السيارات', 'Car wash', 'গাড়ি ধোয়া'],
      'غسيل الأثاث': ['غسيل الأثاث', 'Furniture cleaning', 'আসবাব পরিষ্কার'],
      'غسيل الأحواش': ['غسيل الأحواش', 'Yard cleaning', 'আঙিনা পরিষ্কার'],
      'غسيل كامل': ['غسيل كامل', 'Interior and exterior wash', 'ভিতর ও বাইরে ধোয়া'],
      'غسيل داخلي وخارجي': ['غسيل داخلي وخارجي', 'Interior and exterior wash', 'ভিতর ও বাইরে ধোয়া'],
      'غسيل خارجي': ['غسيل خارجي', 'Exterior wash', 'বাইরের অংশ ধোয়া'],
      'غسيل داخلي': ['غسيل داخلي', 'Interior wash', 'ভেতরের অংশ ধোয়া'],
      'كنب': ['كنب', 'Sofa', 'সোফা'],
      'سجاد': ['سجاد', 'Carpet', 'কার্পেট'],
      'جلسة عربية': ['جلسة عربية', 'Arabic seating', 'আরবি বসার আসন'],
      'غسيل المراتب': ['غسيل المراتب', 'Seat shampoo', 'সিট পরিষ্কার'],
      'معطرات': ['معطرات', 'Air fresheners', 'এয়ার ফ্রেশনার'],
      'الكاوا': ['الكاوا', 'Kawa service', 'কাওয়া সেবা'],
    }[value.trim()];
    if (names == null) return value;
    return names[language == WorkerLanguage.ar ? 0 : language == WorkerLanguage.en ? 1 : 2];
  }

  String serviceLine(String value) {
    final parts = value.split('×');
    return parts.length == 2 ? serviceName(parts.first.trim()) + ' × ' + parts.last.trim() : serviceName(value);
  }

String get serverUnavailable => _value(
    'تعذر الاتصال بالخادم، حاول مرة أخرى.',
    'Unable to connect to the server. Try again.',
    'সার্ভারের সাথে সংযোগ করা যায়নি। আবার চেষ্টা করুন।',
  );
  String get todayBookings =>
      _value('طلبات اليوم', "Today's bookings", 'আজকের বুকিং');
  String get loadFailed => _value(
    'تعذر تحميل حجوزات اليوم',
    "Unable to load today's bookings",
    'আজকের বুকিং লোড করা যায়নি',
  );
  String get updateFailed => _value(
    'تعذر تحديث الحالة',
    'Unable to update the status',
    'স্ট্যাটাস আপডেট করা যায়নি',
  );
  String get noBookings =>
      _value('لا توجد طلبات اليوم', 'No bookings today', 'আজ কোনো বুকিং নেই');
  String get confirmed => _value('مؤكد', 'Confirmed', 'নিশ্চিত');
  String get completed => _value('مكتمل', 'Completed', 'সম্পন্ন');
  String get canceled => _value('ملغي', 'Canceled', 'বাতিল');
  String get vehicle => _value('مركبة', 'Vehicle', 'গাড়ি');
  String get selectedMapLocation => _value(
    'الموقع المحدد على الخريطة',
    'Location selected on the map',
    'মানচিত্রে নির্বাচিত অবস্থান',
  );
  String get cash => _value('كاش', 'Cash', 'নগদ');
  String get card =>
      _value('شبكة عند الوصول', 'Card on arrival', 'পৌঁছানোর পর কার্ড');
  String get bankTransfer =>
      _value('تحويل بنكي', 'Bank transfer', 'ব্যাংক ট্রান্সফার');
  String get online =>
      _value('مدفوع إلكترونيًا', 'Paid online', 'অনলাইনে পরিশোধিত');
  String get currency => _value('ر.س', 'SAR', 'সৌদি রিয়াল');
  String get call => _value('اتصال', 'Call', 'কল করুন');
  String get location => _value('الموقع', 'Location', 'লোকেশন');
  String get completeWash => _value(
    'تم الانتهاء من الغسيل',
    'Mark wash as completed',
    'ওয়াশ সম্পন্ন করুন',
  );
  String get refresh => _value('تحديث', 'Refresh', 'রিফ্রেশ');
  String get logout => _value('تسجيل الخروج', 'Sign out', 'লগআউট');
  String get changeLanguage =>
      _value('تغيير اللغة', 'Change language', 'ভাষা পরিবর্তন করুন');

  String status(String value) => switch (value) {
    'pending' || 'accepted' || 'on_the_way' || 'in_progress' => confirmed,
    'completed' => completed,
    'canceled' => canceled,
    _ => value,
  };

  String paymentMethod(String value) => switch (value) {
    'cash' => cash,
    'card' => card,
    'bank_transfer' => bankTransfer,
    'online' => online,
    _ => value,
  };

  String _value(String arabic, String english, String bengali) =>
      switch (language) {
        WorkerLanguage.ar => arabic,
        WorkerLanguage.en => english,
        WorkerLanguage.bn => bengali,
      };
}
