const bookingTimeSlots = [
  '9 صباحاً',
  '10 صباحاً',
  '11 صباحاً',
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

const _bookingSlotHours = {
  '9 صباحاً': 9,
  '10 صباحاً': 10,
  '11 صباحاً': 11,
  '4 مساءً': 16,
  '5 مساءً': 17,
  '6 مساءً': 18,
  '7 مساءً': 19,
  '8 مساءً': 20,
  '9 مساءً': 21,
  '10 مساءً': 22,
  '11 مساءً': 23,
  '12 مساءً': 24,
};

DateTime? bookingSlotDateTime(DateTime date, String slot) {
  final hour = _bookingSlotHours[slot];
  if (hour == null) return null;
  final selectedDay = DateTime(date.year, date.month, date.day);
  if (hour == 24) return selectedDay.add(const Duration(days: 1));
  return DateTime(date.year, date.month, date.day, hour);
}

bool isBookingSlotPast(DateTime date, String slot, {DateTime? now}) {
  final slotDateTime = bookingSlotDateTime(date, slot);
  if (slotDateTime == null) return false;
  return !slotDateTime.isAfter(now ?? DateTime.now());
}
