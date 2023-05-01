import 'package:flutter/material.dart';
import 'dart:async';

typedef SafetyTimeStateCallback<T> = void Function(
  bool unavailable,
  SafetyTimeState<T> state,
);

/// [SafetyTime] is a timelock which designed to block method invocations multiple times within an interval.
/// It works like a synchronized mutex ([lock] and [unlock]).
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
  /// You can get and set it in [callback].
  ///
  /// Returning a new value in [callback] can reset [SafetyTimeState.userInfo],
  /// also see [SafetyTimeState.userInfo].
  static bool unavailableOf<T>({
    required dynamic key,
    Duration? interval,
    bool update = true,
    SafetyTimeStateCallback<T>? callback,
  }) {
    key ??= _globalKey;
    interval ??= SafetyTime.defaultInterval;
    final stateMap = SafetyTime()._stateMap;
    final now = DateTime.now();
    var state = stateMap[key] as SafetyTimeState<T>?;
    if (state == null) {
      state = SafetyTimeState<T>(date: now);
      stateMap[key] = state;
      return false;
    } else if (state._hasNoTime) {
      return true;
    }
    final prev = state._date;
    if (update) {
      state._date = now;
    }
    final isUnavailable = now.difference(prev) < interval;
    if (null != callback) {
      callback(isUnavailable, state);
    }
    return isUnavailable;
  }

  /// See [callback]
  static bool availableOf<T>({
    required dynamic key,
    Duration? interval,
    bool update = true,
    SafetyTimeStateCallback<T>? callback,
  }) {
    return !unavailableOf(
      key: key,
      interval: interval,
      update: update,
      callback: callback,
    );
  }

  /// [SafetyTime.get] makes the code easy to read,
  /// It determines whether you get [value] or [or].
  ///
  /// Request? updateUserInfo = SafetyTime.get(new UpdateUserInfo(), Duration(seconds: 1));
  ///
  static T? get<T>(
    T value, {
    T? or,
    Duration? interval,
    dynamic key,
    SafetyTimeStateCallback<T>? callback,
  }) {
    return SafetyTime.availableOf(
            key: key, interval: interval, callback: callback)
        ? value
        : or;
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
  static bool tryLockForever<T>(
    dynamic key, {
    Duration? timeout,
    SafetyTimeStateCallback<T>? callback,
  }) {
    var state = SafetyTime()._stateMap[key] as SafetyTimeState<T>?;
    if (state == null) {
      state = SafetyTimeState(date: DateTime.now());
      SafetyTime()._stateMap[key] = state;
    }
    if (!state._hasNoTime) {
      if (null != timeout) {
        Future.delayed(timeout).then((value) {
          unlockForever(key);
        });
      }
      state._hasNoTime = true;
      callback?.call(true, state);
      return true;
    }
    callback?.call(false, state);
    return false;
  }

  /// See: [SafetyTime.tryLockForever]
  static void unlockForever(dynamic key) =>
      SafetyTime()._stateMap[key]?._hasNoTime = false;

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
  static Future<R> synchronizedKey<T, R>(
    dynamic key,
    FutureOr<R> Function(SafetyTimeState<T> state) computation, {
    T? userInfo,
    Duration? timeout,
  }) async {
    var state = SafetyTime()._stateMap[key] as SafetyTimeState<T>?;
    if (state == null) {
      state = SafetyTimeState(date: DateTime.now());
      SafetyTime()._stateMap[key] = state;
    }
    state.userInfo = userInfo;
    getCurrentLocked() {
      return state?._locked;
    }

    setCurrentLocked(Future<dynamic>? locked) {
      state?._locked = locked;
    }

    final oldLocked = getCurrentLocked();
    final completer = Completer.sync();
    setCurrentLocked(completer.future);
    try {
      if (oldLocked != null) {
        if (timeout != null) {
          await oldLocked.timeout(timeout);
        } else {
          await oldLocked;
        }
      }
      final value = computation(state);
      return value is Future ? (await value) : value;
    } finally {
      void complete() {
        if (identical(getCurrentLocked(), completer.future)) {
          setCurrentLocked(null);
        }
        completer.complete();
      }

      if (oldLocked != null && timeout != null) {
        // ignore: unawaited_futures
        oldLocked.then((_) {
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
    state._locked = null;
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
  static const String _globalKey = 'SafetyTimeGlobalKey';
}

class SafetyTimeState<T> {
  SafetyTimeState({required DateTime date, this.userInfo}) : _date = date;

  T? userInfo;

  DateTime _date;

  Future<dynamic>? _locked;

  bool _hasNoTime = false;
}
