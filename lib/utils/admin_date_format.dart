String _twoDigits(int value) => value.toString().padLeft(2, '0');

/// Formats a date as `dd/MM/yyyy`.
String formatAdminDate(DateTime value) {
  return '${_twoDigits(value.day)}/${_twoDigits(value.month)}/${value.year}';
}

/// Formats a date and time as `dd/MM/yyyy - HH:mm`.
String formatAdminDateTime(DateTime value) {
  return '${formatAdminDate(value)} - ${_twoDigits(value.hour)}:${_twoDigits(value.minute)}';
}
