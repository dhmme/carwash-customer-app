import 'package:carwash_app/booking_time.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('hides slots that have started today', () {
    final date = DateTime(2026, 9, 12);
    final now = DateTime(2026, 9, 12, 10, 1);

    expect(isBookingSlotPast(date, '9 صباحاً', now: now), isTrue);
    expect(isBookingSlotPast(date, '10 صباحاً', now: now), isTrue);
    expect(isBookingSlotPast(date, '11 صباحاً', now: now), isFalse);
  });

  test('keeps every slot on a future day', () {
    final futureDate = DateTime(2026, 9, 13);
    final now = DateTime(2026, 9, 12, 23, 30);

    for (final slot in bookingTimeSlots) {
      expect(isBookingSlotPast(futureDate, slot, now: now), isFalse);
    }
  });

  test('treats twelve at night as the end of the selected day', () {
    final date = DateTime(2026, 9, 12);

    expect(
      bookingSlotDateTime(date, '12 مساءً'),
      DateTime(2026, 9, 13),
    );
  });
}
