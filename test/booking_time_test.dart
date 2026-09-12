import 'package:carwash_app/booking_time.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const morningNine = {'label': '9 صباحاً', 'start_time': '09:00:00', 'day_offset': 0};
  const morningTen = {'label': '10 صباحاً', 'start_time': '10:00:00', 'day_offset': 0};
  const morningEleven = {'label': '11 صباحاً', 'start_time': '11:00:00', 'day_offset': 0};
  const midnight = {'label': '12 منتصف الليل', 'start_time': '00:00:00', 'day_offset': 1};

  test('hides slots that have started today', () {
    final date = DateTime(2026, 9, 12);
    final now = DateTime(2026, 9, 12, 10, 1);

    expect(isBookingSlotPast(date, morningNine, now: now), isTrue);
    expect(isBookingSlotPast(date, morningTen, now: now), isTrue);
    expect(isBookingSlotPast(date, morningEleven, now: now), isFalse);
  });

  test('keeps every slot on a future day', () {
    final futureDate = DateTime(2026, 9, 13);
    final now = DateTime(2026, 9, 12, 23, 30);

    for (final slot in [morningNine, morningTen, morningEleven, midnight]) {
      expect(isBookingSlotPast(futureDate, slot, now: now), isFalse);
    }
  });

  test('treats twelve at night as the end of the selected day', () {
    final date = DateTime(2026, 9, 12);

    expect(
      bookingSlotDateTime(date, midnight),
      DateTime(2026, 9, 13),
    );
  });
}
