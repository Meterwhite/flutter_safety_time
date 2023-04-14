import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_safety_time/flutter_safety_time.dart';

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
}

/// How to use: Specifically, you can replace [State] with [SafetyTimeState],
/// [SafetyTimeState] is a simple widget that automatically manages state, users can use [SafetyTime] in `nested` way.
/// [SafetyTimeState] will work until [dispose] is called.
///
/// Widget build(BuildContext context) {
///   ... ...
///   oneTap : {
///     if([isAvailable]) {
///       loginRequest();
///     }
///   }
///   ... ...
/// }
abstract class SafetyTimeState<T extends StatefulWidget> extends State<T> {
  Duration? interval;

  bool get isAvailable {
    return false == SafetyTime.unavailableOf(key: this, interval: interval);
  }

  bool get isUnavailable => !isAvailable;

  @override
  void initState() {
    super.initState();
    SafetyTime.unavailableOf(key: this, interval: interval);
  }

  @override
  void dispose() {
    super.dispose();
    SafetyTime.disposeKey(this);
  }
}

/**
 * 
 * 
 Use [SafetyTimeState] insted of [State].
[SafetyTimeState] is a simple widget that automatically manages state, users can use [SafetyTime] in `nested` way.
[SafetyTimeState] will work until [dispose] is called.
```dart
class Page extends StatefulWidget {
  @override
  SafetyTimeState<Page> createState() => _PageState();
}

class _PageState extends SafetyTimeState<Page> { // ⬅ 👀
  @override
  void initState() {
    super.initState();
    // interval = const Duration(milliseconds: 800); // ⬅ 👀
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(onTap: () {
      if (isUnavailable) { // ⬅ 👀
        return;
      }
      doSomething();
    });
  }
}

```
 * 
 * 
 */