import 'dart:async';

import 'package:flutter/material.dart';

typedef SafetyTimeStateCallback = void Function(SafetyTimeState state);

/// [SafetyTime] is a time lock which designed to block method invocations multiple times within an interval.
/// It works like a synchronized mutex ([lock]and[unlock]).
/// [SafetyTime] is suitable for flutter. It avoids `Nested` and `state management`.
///
/// onTap: {
///   if([SafetyTime.unavailable]) return;
///   selectItem();
/// }
///
/// [SafetyTime] provides two core functions:
/// The first is to block users from repeated clicks, repeated network requests, etc.
/// For example, The user taped multiple buttons before the new page was pushed.
/// As another example, when the network requests, the user clicks again to request.
/// Specifically, [SafetyTime] will compare the interval between two times,
/// and if it is less than the safe interval [SafetyTime], the event will be discarded.
/// The second is a pair of methods similar to [lock] and [unlock], they are [tryLockForever] and [unlockForever].
/// Specifically, [SafetyTime] will lock a indefinitely [key] until the user manually calls [unlockForever] to unlock the lock.
class SafetyTime {
  /// Usually, [SafetyTime.unavailable] decide whether to return immediately at the beginning of the business code.
  ///
  /// onTap: {
  ///   if([SafetyTime.unavailable]) return;
  ///   ... ...
  /// }
  ///
  /// also see [available], [unavailableOf]
  static bool get unavailable => SafetyTime.unavailableOf(key: _globalKey);

  /// see [unavailable]
  static bool get available => !unavailable;

  /// Set default time interval.
  /// After mobile phone and mouse tests, 800 milliseconds is a safe slow interaction interval.
  static Duration defaultInterval = const Duration(milliseconds: 800);

  /// Usually, [SafetyTime.unavailableOf] can decide whether to return immediately at the beginning of the business code.
  /// onTap: {
  ///   if(SafetyTime.unavailableOf(key: 'loginRequest')) return;
  ///   ... ...
  /// }
  ///
  /// In [SafetyTime], use [key] to name a specific event, object, task, or business.
  /// [key] is the unique identifier that can be recognized by [SafetyTime].
  /// If `Null` is passed, [SafetyTime._globalKey] will be passed by default.
  /// You can use [String], [Key] or other types.
  /// It is not recommended to use [State] which will be rebuilt to call `dispose()`.
  ///
  /// [interval] determines how [SafetyTime] blocks an event,
  /// In two calls with an interval of less than [interval], the latter will be rejected,
  /// If you pass `Null`, use the value of [SafetyTime.defaultInterval] instead.
  ///
  /// [update] determines whether to set current date to [SafetyTime], Default is `true`.
  /// Passing `false` means only get the current state, not as a business event.
  ///
  /// [SafetyTimeState.userInfo] is an object that can be shared at different pages,
  /// You can get and set it in [onAvailable] and [onUnavailable].
  ///
  /// Returning a new value in [onAvailable] can reset [SafetyTimeState.userInfo],
  /// also see [onUnavailable], [SafetyTimeState.userInfo].
  static bool unavailableOf<T>({
    required dynamic key,
    Duration? interval,
    bool update = true,
    SafetyTimeStateCallback? onAvailable,
    SafetyTimeStateCallback? onUnavailable,
  }) {
    key ??= _globalKey;
    interval ??= SafetyTime.defaultInterval;
    final stateMap = SafetyTime()._stateMap;
    var now = DateTime.now();
    SafetyTimeState? state = stateMap[key];
    if (state == null) {
      state = SafetyTimeState(date: now);
      stateMap[key] = state;
      return false;
    } else if (state._lock) {
      return true;
    }
    final prev = state._date;
    if (update) {
      state._date = now;
    }
    final isUnavailable = now.difference(prev) < interval;
    if (!isUnavailable && null != onAvailable) {
      onAvailable.call(state);
    } else if (isUnavailable && null != onUnavailable) {
      onUnavailable.call(state);
    }
    return isUnavailable;
  }

  /// See [onAvailable]
  static bool availableOf({
    required dynamic key,
    Duration? interval,
    bool update = true,
    SafetyTimeStateCallback? onAvailable,
    SafetyTimeStateCallback? onUnavailable,
  }) {
    return !unavailableOf(
        key: key,
        interval: interval,
        update: update,
        onAvailable: onAvailable,
        onUnavailable: onUnavailable);
  }

  /// [SafetyTime.get] makes the code easy to read,
  /// It determines whether you get [value] or [or].
  ///
  /// Request? updateUserInfo = SafetyTime.get(new UpdateUserInfo(), Duration(seconds: 1));
  ///
  static T? get<T>(T value, {T? or, Duration? interval, dynamic key}) {
    return SafetyTime.availableOf(key: key, interval: interval) ? value : or;
  }

  /// [SafetyTime.tryLockForever] can lock [key] for a long time.
  /// When [key] is locked, both [unavailable] and [unavailableOf] return true,
  /// but [synchronizedKey] is not affected.
  /// updateUserInfo() async {
  ///     if(SafetyTime.tryLockForever('UpdateUserInfo')) {
  ///       await doSomething();
  ///       SafetyTime.unlockForever('UpdateUserInfo');
  ///     }
  /// }
  ///
  /// InPageA {
  ///     updateUserInfo();
  /// }
  ///
  /// InPageB {
  ///     updateUserInfo();
  /// }
  ///
  /// [timeout] allows you to remove the current [tryLockForever] after some time
  ///
  /// also see: [SafetyTime.unlockForever]
  static bool tryLockForever(dynamic key, {Duration? timeout}) {
    var state = SafetyTime()._stateMap[key];
    if (state == null) {
      state = SafetyTimeState(date: DateTime.now());
      SafetyTime()._stateMap[key] = state;
    }
    if (!state._lock) {
      if (null != timeout) {
        Future.delayed(timeout).then((value) {
          unlockForever(key);
        });
      }
      state._lock = true;
      return true;
    }
    return false;
  }

  /// See: [SafetyTime.tryLockForever]
  static void unlockForever(dynamic key) =>
      SafetyTime()._stateMap[key]?._lock = false;

  /// Thanks `synchronized`
  ///
  /// Synchronous [key](non-reentrant)
  /// Executes [computation] when lock is available.
  /// 
  /// Only one asynchronous block can run while the key is retained.
  /// 
  /// If [timeout] is specified, it will try to grab the lock and will not
  /// call the computation callback and throw a [TimeoutExpection] is the lock
  /// cannot be grabbed in the given duration.
  /// 
  /// save(x) {
  ///   await SafetyTime.synchronizedKey('WritToFile', (userInfo) async {
  ///     writToFile(x);
  ///   });
  /// }
  ///
  /// InPageA {
  ///   ... ...
  ///   save(A);
  ///   ... ...
  /// }
  ///
  /// InPageB {
  ///   ... ...
  ///   save(B);
  ///   ... ...
  /// }
  ///
  static Future<T> synchronizedKey<T>(
      dynamic key, FutureOr<T> Function(dynamic userInfo) computation,
      {dynamic userInfo, Duration? timeout}) async {
    var state = SafetyTime()._stateMap[key];
    if (state == null) {
      state = SafetyTimeState(date: DateTime.now());
      SafetyTime()._stateMap[key] = state;
    }
    state.userInfo = userInfo;
    getCurrentLocker() {
      return state?._locker;
    }

    setCurrentLocker(Future<dynamic>? locker) {
      state?._locker = locker;
    }

    final oldLocker = getCurrentLocker();
    final completer = Completer.sync();
    setCurrentLocker(completer.future);
    try {
      if (oldLocker != null) {
        if (timeout != null) {
          await oldLocker.timeout(timeout);
        } else {
          await oldLocker;
        }
      }
      var x = computation(state.userInfo);
      if (x is Future) {
        return await x;
      } else {
        return x;
      }
    } finally {
      void complete() {
        if (identical(getCurrentLocker(), completer.future)) {
          setCurrentLocker(null);
        }
        completer.complete();
      }

      if (oldLocker != null && timeout != null) {
        // ignore: unawaited_futures
        oldLocker.then((_) {
          complete();
        });
      } else {
        complete();
      }
    }
  }

  /// Manually delete a [key], In general, there is no need to call [disposeKey].
  static void disposeKey(dynamic key) {
    SafetyTimeState? state = SafetyTime()._stateMap[key];
    if (state == null) return;
    state.userInfo = null;
    state._locker = null;
    SafetyTime()._stateMap.remove(key);
  }

  /// Clear to go back to initialization.
  static clear() => SafetyTime()._stateMap.clear();

  /// Singleton
  factory SafetyTime() => _shared;

  static final SafetyTime _shared = SafetyTime._init();

  SafetyTime._init();

  /// A collection used to hold `User-generated content`
  final Map<dynamic, SafetyTimeState> _stateMap = {};

  /// [key] for global interaction.
  static const String _globalKey = '';

  /// [Duration(days: 30000)] is a fairly long time.
  static const Duration forever = Duration(days: 30000);
}


class SafetyTimeState {
  SafetyTimeState({required DateTime date, this.userInfo}) : _date = date;
  
  dynamic userInfo;

  DateTime _date;

  Future<dynamic>? _locker;

  bool _lock = false;
}
