import "package:flutter_test/flutter_test.dart";

class ReminderScheduler {
  final List<DateTime> _reminders = [];
  void schedule(DateTime date) => _reminders.add(date);
  bool isScheduled(DateTime date) => _reminders.contains(date);
  int get count => _reminders.length;
}

void main() {
  test("schedules a reminder for tomorrow", () {
    final s = ReminderScheduler();
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    s.schedule(tomorrow);
    expect(s.isScheduled(tomorrow), true);
    expect(s.count, 1);
  });
}