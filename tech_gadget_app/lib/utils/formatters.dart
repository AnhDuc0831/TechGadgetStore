/// Định dạng tiền VND, vd: 19990000 -> "19.990.000 ₫"
String formatVnd(double amount) {
  final digits = amount.round().abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
    buffer.write(digits[i]);
  }
  return '${amount < 0 ? '-' : ''}$buffer ₫';
}
