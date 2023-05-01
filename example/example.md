
## Example
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
    await Login();
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

save(x) {i
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
