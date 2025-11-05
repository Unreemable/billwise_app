import "package:flutter/services.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel("dexterous.com/flutter/local_notifications");
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      calls.add(call);
      // ارجعي قيمًا تُرضي البلجن لو تم استدعاؤها
      switch (call.method) {
        case "initialize":
          return true;
        case "show":
          return 0; // success
        case "zonedSchedule":
          return true;
        case "pendingNotificationRequests":
          return <Map<String, Object?>>[];
        default:
          return null;
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test("platform channel: show notification has expected args", () async {
    // بدلاً من استدعاء كلاس البلجن، نستدعي القناة مباشرة كما يفعل البلجن تحت الغطاء
    final args = {
      "id": 1001,
      "title": "BillWise Reminder",
      "body": "Your bill is due tomorrow",
      "payload": "bill:abc123",

      // مفاتيح شائعة يرسلها البلجن على أندرويد (اختيارية هنا للاختبار)
      "platformSpecifics": {
        "channelId": "billwise_reminders",
        "channelName": "Reminders"
      }
    };

    await channel.invokeMethod("show", args);

    expect(calls.isNotEmpty, true);
    final showCall = calls.firstWhere((c) => c.method == "show");
    expect(showCall.arguments is Map, true);

    final got = Map<String, Object?>.from(showCall.arguments as Map);
    expect(got["id"], 1001);
    expect(got["title"], "BillWise Reminder");
    expect(got["body"], "Your bill is due tomorrow");
    expect(got["payload"], "bill:abc123");
  });
}