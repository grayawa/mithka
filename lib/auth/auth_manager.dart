//
//  auth_manager.dart
//
//  Owns app startup and TDLib's authorization flow. Subscribes to the update
//  stream, reacts to updateAuthorizationState, and exposes a simple `step` that
//  the UI gates on. Port of the Swift `AuthManager`.
//

import 'package:flutter/foundation.dart';

import '../config/secrets.dart';
import '../tdlib/json_helpers.dart';
import '../tdlib/td_client.dart';

sealed class AuthStep {
  const AuthStep();
}

class AuthInitializing extends AuthStep {
  const AuthInitializing();
}

class AuthWaitPhoneNumber extends AuthStep {
  const AuthWaitPhoneNumber();
}

class AuthWaitCode extends AuthStep {
  const AuthWaitCode(this.info);
  final String info;
}

class AuthWaitPassword extends AuthStep {
  const AuthWaitPassword(this.hint);
  final String hint;
}

class AuthWaitRegistration extends AuthStep {
  const AuthWaitRegistration();
}

class AuthReady extends AuthStep {
  const AuthReady();
}

class AuthLoggingOut extends AuthStep {
  const AuthLoggingOut();
}

class AuthClosed extends AuthStep {
  const AuthClosed();
}

class AuthMissingCredentials extends AuthStep {
  const AuthMissingCredentials();
}

class AuthManager extends ChangeNotifier {
  final TdClient _client = TdClient.shared;
  bool _started = false;

  AuthStep _step = const AuthInitializing();
  String? _errorMessage;
  bool _isWorking = false;

  AuthStep get step => _step;
  String? get errorMessage => _errorMessage;
  bool get isWorking => _isWorking;

  void start() {
    if (_started) return;
    _started = true;

    if (!Secrets.isConfigured) {
      _set(const AuthMissingCredentials());
      return;
    }

    // Subscribe before start so no early update is missed.
    final updates = _client.subscribe();
    updates.listen((update) {
      if (update.type != 'updateAuthorizationState') return;
      final state = update.obj('authorization_state');
      if (state != null) _handle(state);
    });
    _client.start();
  }

  // MARK: - Authorization state machine

  void _handle(Map<String, dynamic> state) {
    debugPrint('🔑 [Mithkal] authorizationState → ${state.type ?? 'nil'}');
    switch (state.type) {
      case 'authorizationStateWaitTdlibParameters':
        break; // parameters sent by TdClient (per-account bootstrap)
      case 'authorizationStateWaitPhoneNumber':
        _set(const AuthWaitPhoneNumber());
      case 'authorizationStateWaitCode':
        final info = state.obj('code_info');
        _set(AuthWaitCode(_codeDeliveryLabel(info?.obj('type'))));
      case 'authorizationStateWaitPassword':
        _set(AuthWaitPassword(state.str('password_hint') ?? ''));
      case 'authorizationStateWaitRegistration':
        _set(const AuthWaitRegistration());
      case 'authorizationStateReady':
        _errorMessage = null;
        _set(const AuthReady());
      case 'authorizationStateLoggingOut':
        _set(const AuthLoggingOut());
      case 'authorizationStateClosing':
        break;
      case 'authorizationStateClosed':
        _set(const AuthClosed());
      default:
        break;
    }
  }

  /// Re-reads the active account's authorization state (after an account
  /// switch) and updates `step` so the UI gates on the right account.
  void reloadAuthState() {
    _set(const AuthInitializing());
    _errorMessage = null;
    _client
        .query({'@type': 'getAuthorizationState'})
        .then((state) {
          _handle(state);
        })
        .catchError((_) {});
  }

  // MARK: - User actions

  void submitPhone(String phone) => _run({
    '@type': 'setAuthenticationPhoneNumber',
    'phone_number': phone.trim(),
  });

  void submitCode(String code) =>
      _run({'@type': 'checkAuthenticationCode', 'code': code.trim()});

  void submitPassword(String password) =>
      _run({'@type': 'checkAuthenticationPassword', 'password': password});

  void register(String firstName, String lastName) => _run({
    '@type': 'registerUser',
    'first_name': firstName,
    'last_name': lastName,
  });

  void resendCode() => _run({'@type': 'resendAuthenticationCode'});

  void logOut() => _run({'@type': 'logOut'});

  // MARK: - Helpers

  void _set(AuthStep step) {
    _step = step;
    notifyListeners();
  }

  void _run(Map<String, dynamic> request) {
    _isWorking = true;
    _errorMessage = null;
    notifyListeners();
    _client
        .query(request)
        .then((_) {
          _isWorking = false;
          notifyListeners();
        })
        .catchError((error) {
          _report(error);
          _isWorking = false;
          notifyListeners();
        });
  }

  void _report(Object error) {
    if (error is TdError) {
      _errorMessage = _friendly(error);
    } else {
      _errorMessage = error.toString();
    }
  }

  String _friendly(TdError error) {
    switch (error.message) {
      case 'PHONE_NUMBER_INVALID':
        return '手机号格式不正确';
      case 'PHONE_CODE_INVALID':
        return '验证码错误';
      case 'PHONE_CODE_EXPIRED':
        return '验证码已过期，请重新获取';
      case 'PASSWORD_HASH_INVALID':
        return '密码错误';
      default:
        return error.message;
    }
  }

  String _codeDeliveryLabel(Map<String, dynamic>? type) {
    switch (type?.type) {
      case 'authenticationCodeTypeTelegramMessage':
        return '验证码已发送至你的其他 Telegram 设备';
      case 'authenticationCodeTypeSms':
        return '验证码已通过短信发送';
      case 'authenticationCodeTypeCall':
        return '你将接到一个电话告知验证码';
      case 'authenticationCodeTypeFlashCall':
        return '你将接到一个闪信电话';
      default:
        return '验证码已发送';
    }
  }
}
