import 'package:flutter_safety_time/flutter_safety_time.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:async';

void main() {
  test('avaliable', () async {
    if (SafetyTime.available) {
      if (SafetyTime.available) throw Exception();
      await Future.delayed(
          SafetyTime.defaultInterval + const Duration(milliseconds: 1));
      if (SafetyTime.unavailable) throw Exception();
    }
  });

  test('non-reentrant', () async {
    Object? exception;
    await SafetyTime.synchronizedKey('key', (userInfo) async {
      try {
        await SafetyTime.synchronizedKey('key', (userInfo) {},
            timeout: const Duration(seconds: 1));
      } catch (e) {
        exception = e;
      }
    });
    expect(exception, const TypeMatcher<TimeoutException>());
  });

  test('lock forever', () {
    if (SafetyTime.tryLockForever('lock')) {
      if (SafetyTime.availableOf(key: 'lock')) throw Exception();
      if (SafetyTime.tryLockForever('lock')) throw Exception();
      SafetyTime.unlockForever('lock');
      if (SafetyTime.unavailableOf(key: 'lock', interval: Duration.zero)) {
        throw Exception();
      }
      if (!SafetyTime.tryLockForever('lock')) throw Exception();
    } else {
      throw Exception();
    }
  });

  test('generic', () {
    Object? exception;
    try {
      if (SafetyTime.availableOf<String>(key: 'String')) {
        if (SafetyTime.availableOf<int>(key: 'int')) {
          if (SafetyTime.availableOf<String>(key: 'String')) {
            Exception();
          }
        }
      }
      SafetyTime.availableOf<int>(key: 'String'); // throw
    } catch (e) {
      exception = e;
    }
    expect(exception, const TypeMatcher<TypeError>());
  });
}
