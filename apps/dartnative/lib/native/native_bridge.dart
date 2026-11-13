// Small FFI bridges to the platform for the two things DartNative has no
// API for: writing to the iOS unified log in a release build, and setting
// UIKit accessibility identifiers for UI automation.
//
// Both go through the Objective-C runtime and Foundation, which are always
// loaded in the process, and DartNative's own exported view registry
// (DNViewRegistryGetView, the lookup its plugins use).

import 'dart:convert' show utf8;
import 'dart:ffi';
import 'dart:io' show Platform;

typedef _Ptr = Pointer<Void>;

class _IOSRuntime {
  _IOSRuntime._(DynamicLibrary lib)
    : _getClass = lib
          .lookupFunction<_Ptr Function(Pointer<Uint8>), _Ptr Function(Pointer<Uint8>)>(
            'objc_getClass',
          ),
      _sel = lib
          .lookupFunction<_Ptr Function(Pointer<Uint8>), _Ptr Function(Pointer<Uint8>)>(
            'sel_registerName',
          ),
      _msgSendPtr = lib
          .lookupFunction<_Ptr Function(_Ptr, _Ptr, _Ptr), _Ptr Function(_Ptr, _Ptr, _Ptr)>(
            'objc_msgSend',
          ),
      _malloc = lib.lookupFunction<_Ptr Function(IntPtr), _Ptr Function(int)>('malloc'),
      _free = lib.lookupFunction<Void Function(_Ptr), void Function(_Ptr)>('free'),
      _nsLog = lib.lookupFunction<Void Function(_Ptr), void Function(_Ptr)>('NSLog'),
      _getView = lib.providesSymbol('DNViewRegistryGetView')
          ? lib.lookupFunction<Int64 Function(Int64), int Function(int)>(
              'DNViewRegistryGetView',
            )
          : null;

  static _IOSRuntime? _instance;
  static _IOSRuntime? get instance {
    if (!Platform.isIOS) return null;
    return _instance ??= _IOSRuntime._(DynamicLibrary.process());
  }

  final _Ptr Function(Pointer<Uint8>) _getClass;
  final _Ptr Function(Pointer<Uint8>) _sel;
  final _Ptr Function(_Ptr, _Ptr, _Ptr) _msgSendPtr;
  final _Ptr Function(int) _malloc;
  final void Function(_Ptr) _free;
  final void Function(_Ptr) _nsLog;
  final int Function(int)? _getView;

  final Map<String, _Ptr> _selectors = {};
  _Ptr? _nsStringClass;

  Pointer<Uint8> _cString(String s) {
    final units = utf8.encode(s);
    final p = _malloc(units.length + 1).cast<Uint8>();
    for (var i = 0; i < units.length; i++) {
      p[i] = units[i];
    }
    p[units.length] = 0;
    return p;
  }

  _Ptr _selector(String name) => _selectors.putIfAbsent(name, () {
    final c = _cString(name);
    final s = _sel(c);
    _free(c.cast());
    return s;
  });

  /// An autoreleased NSString.
  _Ptr _nsString(String s) {
    _nsStringClass ??= () {
      final c = _cString('NSString');
      final cls = _getClass(c);
      _free(c.cast());
      return cls;
    }();
    final c = _cString(s);
    final str = _msgSendPtr(
      _nsStringClass!,
      _selector('stringWithUTF8String:'),
      c.cast(),
    );
    _free(c.cast());
    return str;
  }

  void log(String message) => _nsLog(_nsString(message));

  void setAccessibilityIdentifier(int viewId, String identifier) {
    final getView = _getView;
    if (getView == null) return;
    final address = getView(viewId);
    if (address == 0) return;
    _msgSendPtr(
      Pointer<Void>.fromAddress(address),
      _selector('setAccessibilityIdentifier:'),
      _nsString(identifier),
    );
  }
}

/// Writes one line to the iOS unified log (NSLog), in release builds too.
void unifiedLog(String message) {
  // The message is used as the NSLog format string; keep '%' out of it.
  assert(!message.contains('%'));
  _IOSRuntime.instance?.log(message);
}

/// Sets the UIKit accessibilityIdentifier of the native view [viewId].
void setNativeAccessibilityIdentifier(int viewId, String identifier) {
  _IOSRuntime.instance?.setAccessibilityIdentifier(viewId, identifier);
}
