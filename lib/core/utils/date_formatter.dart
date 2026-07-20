import 'package:intl/intl.dart';

class DateFormatter {
  DateFormatter._();

  static String short(DateTime date) => DateFormat('dd MMM yyyy', 'id_ID').format(date.toLocal());

  static String dateTime(DateTime date) => DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(date.toLocal());

  static String time(DateTime date) => DateFormat('HH:mm', 'id_ID').format(date.toLocal());
}
