<!--
This README describes the package. If you publish this package to pub.dev,
this README's contents appear on the landing page for your package.

For information about how to write a good package README, see the guide for
[writing package pages](https://dart.dev/guides/libraries/writing-package-pages).

For general information about developing packages, see the Dart guide for
[creating packages](https://dart.dev/guides/libraries/create-library-packages)
and the Flutter guide for
[developing packages and plugins](https://flutter.dev/developing-packages).
-->



## Features
- [SafetyTime] is a timelock which designed to block multiple calls within an interval. It works like a synchronized mutex ([lock] and [unlock]).

- [SafetyTime] provides two cor functions:
    - The first is to block users from repeated clicks, repeated network requests, etc.For example, in a multi-select list, the user touches multiple options at the same time.As another example, when the network requests, the user clicks again to request.
Specifically, [SafetyTime] will compare the interval between two times,and if it is less than the safe interval [SafetyTime], the event will be discarded.
    - The second is a pair of methods similar to [lock] and [unlock], they are [tryLockForever] and [unlockForever]. Specifically, [SafetyTime] will lock a indefinitely [key] until the user manually calls [unlockForever] to unlock the lock.

## Getting started
### Add dependency

You can use the command to add flutter_safety_time as a dependency with the latest stable version:

```console
$ dart pub add flutter_safety_time
```

Or you can manually add flutter_safety_time into the dependencies section in your pubspec.yaml:

```yaml
dependencies:
  flutter_safety_time:
```

## Usage
The user taped multiple buttons before the new page was pushed.
```dart
onATap: {
  if(SafetyTime.unavailable) return;
  ... ...
  Navigator.push(context, PageA());
}

onBTap: {
  if(SafetyTime.unavailable) return;
  ... ...
  Navigator.push(context, PageB());
}
```

Limit onece login in 1 minute.
```dart
loginRequest() async {
    if(SafetyTime.unavailableOf('Login', Duration(minutes: 1))) {
        alert('Limit onece login in 1 minute.');
        return;
    }
    await login();
    alert('success');
}
```

[SafetyTime.tryLockForever] can lock [key] for a long time. When [key] is locked, both [unavailable] and [unavailableOf] return true, but [synchronizedKey] is not affected.
```dart
updateUserInfo() async {
    // Make calls to "updateUserInfo" unique within the same time period.
    if(SafetyTime.tryLockForever('UpdateUserInfo')) {
      await doSomething();
      SafetyTime.unlockForever('UpdateUserInfo');
    }
}

InPageA {
  ... ...
  updateUserInfo(); // Called at any time
  ... ...
}

InPageB {
  ... ...
  updateUserInfo(); // Called at any time
  ... ...
}
```

Synchronous [key](non-reentrant)
Executes [computation] when lock is available.
Only one asynchronous block can run while the key is retained.
If [timeout] is specified, it will try to grab the lock and will not call the computation callback and throw a [TimeoutExpection] is the lock cannot be grabbed in the given duration.
```dart

save(x) {
  await SafetyTime.synchronizedKey('WritToFile', (userInfo) async {
    writToFile(x);
  });
}

InPageA {
  ... ...
  save(A); // Called at any time
  ... ...
}

InPageB {
  ... ...
  save(B); // Called at any time
  ... ...
}
```

## Additional information
- 2023.
- Click 'Star👍' to bookmark this library, which you can find in your profile.
- [Github](https://github.com/Meterwhite/flutter_safety_time)
