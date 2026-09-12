DateTime? bookingSlotDateTime(DateTime date, Map<String, dynamic> slot) {
  final rawTime = slot['start_time']?.toString();
  if (rawTime == null) return null;
  final parts = rawTime.split(':');
  if (parts.length < 2) return null;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) return null;
  final offset = int.tryParse(slot['day_offset']?.toString() ?? '0') ?? 0;
  return DateTime(date.year, date.month, date.day, hour, minute)
      .add(Duration(days: offset));
}

bool isBookingSlotPast(
  DateTime date,
  Map<String, dynamic> slot, {
  DateTime? now,
}) {
  final slotDateTime = bookingSlotDateTime(date, slot);
  if (slotDateTime == null) return false;
  return !slotDateTime.isAfter(now ?? DateTime.now());
}
