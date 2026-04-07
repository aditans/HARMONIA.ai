class AppSession {
  AppSession({
    required this.type,
    required this.metricLabel,
    required this.metricValue,
    required this.dateLabel,
  });

  final String type;
  final String metricLabel;
  final String metricValue;
  final String dateLabel;
}
