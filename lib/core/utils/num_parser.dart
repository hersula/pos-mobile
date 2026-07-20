/// Field uang/desimal dari backend (Prisma `Decimal`) bisa terkirim sebagai
/// String maupun num tergantung versi serializer. Helper ini aman untuk keduanya.
num parseNum(dynamic value, {num fallback = 0}) {
  if (value == null) return fallback;
  if (value is num) return value;
  if (value is String) return num.tryParse(value) ?? fallback;
  return fallback;
}

int parseInt(dynamic value, {int fallback = 0}) {
  if (value == null) return fallback;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}
