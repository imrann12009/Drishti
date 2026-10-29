enum DemoEventSeverity { info, warning, critical }

/// Local-only events used to make Demo Mode representative and repeatable.
/// These events must never be presented as live sensor or camera output.
final class DemoEvent {
  const DemoEvent({
    required this.id,
    required this.message,
    required this.severity,
  });

  final String id;
  final String message;
  final DemoEventSeverity severity;
}

abstract final class DemoScenario {
  static const List<DemoEvent> events = [
    DemoEvent(
      id: 'scan-ready',
      message: 'ডেমো স্ক্যান প্রস্তুত। চারপাশের তথ্য সিমুলেট করা হচ্ছে।',
      severity: DemoEventSeverity.info,
    ),
    DemoEvent(
      id: 'path-open',
      message: 'সামনে চলার জায়গা খোলা দেখানো হচ্ছে। এটি নিরাপদ পথের নিশ্চয়তা নয়।',
      severity: DemoEventSeverity.info,
    ),
    DemoEvent(
      id: 'person-ahead',
      message: 'ডেমো ইভেন্ট: সামনে আনুমানিক ৩ মিটার দূরে একজন মানুষ।',
      severity: DemoEventSeverity.warning,
    ),
    DemoEvent(
      id: 'side-obstacle',
      message: 'ডেমো ইভেন্ট: ডান পাশে সম্ভাব্য বাধা দেখানো হচ্ছে। সতর্ক থাকুন।',
      severity: DemoEventSeverity.warning,
    ),
    DemoEvent(
      id: 'stairs-ahead',
      message: 'ডেমো ইভেন্ট: সামনে সিঁড়ির মতো অংশ। থামুন এবং নিজস্ব চলাচল-পদ্ধতি অনুসরণ করুন।',
      severity: DemoEventSeverity.critical,
    ),
  ];
}
