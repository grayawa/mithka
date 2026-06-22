//
//  login_view.dart
//
//  Reference-styled multi-step login that adapts to AuthManager.step:
//  phone → code → password → (registration). Port of the Swift `LoginView`.
//

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../components/sf_symbols.dart';
import '../theme/app_theme.dart';
import 'auth_manager.dart';
import 'country_picker.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _phone = TextEditingController(text: '+');
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();

  String get _phoneDigits => _phone.text.replaceAll(RegExp(r'[^0-9]'), '');
  Country? get _detectedCountry => Country.match(_phoneDigits);

  @override
  void dispose() {
    for (final c in [_phone, _code, _password, _firstName, _lastName]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Reduces input to `+<digits>` and groups the national part for readability.
  static String _formatAsYouType(String input) {
    final digits = input.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return '+';
    final country = Country.match(digits);
    if (country == null) return '+$digits';
    final national = digits.substring(country.dial.length);
    final buf = StringBuffer('+${country.dial}');
    if (national.isNotEmpty) {
      buf.write(' ');
      // group 3-4-4-4
      var i = 0;
      final sizes = [3, 4, 4, 4, 4];
      var s = 0;
      while (i < national.length) {
        final size = s < sizes.length ? sizes[s] : 4;
        final end = (i + size).clamp(0, national.length);
        buf.write(national.substring(i, end));
        if (end < national.length) buf.write(' ');
        i = end;
        s++;
      }
    }
    return buf.toString();
  }

  void _selectCountry(Country country) {
    final digits = _phoneDigits;
    final current = _detectedCountry;
    final national = current != null
        ? digits.substring(current.dial.length)
        : '';
    setState(() => _phone.text = _formatAsYouType('+${country.dial}$national'));
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthManager>();
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.background,
      body: Column(
        children: [
          _header(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _stepFor(auth),
                  if (auth.errorMessage != null) ...[
                    const SizedBox(height: 18),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        auth.errorMessage!,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.unreadBadge,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepFor(AuthManager auth) {
    return switch (auth.step) {
      AuthMissingCredentials() => _credentialsNotice(),
      AuthWaitCode(:final info) => _codeStep(auth, info),
      AuthWaitPassword(:final hint) => _passwordStep(auth, hint),
      AuthWaitRegistration() => _registrationStep(auth),
      _ => _phoneStep(auth),
    };
  }

  Widget _header() {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(top: 96, bottom: 28),
      child: Column(
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              gradient: AppTheme.brandGradient,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(
              Icons.send_rounded,
              size: 44,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Mithkal',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: c.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '登录 Telegram 账号',
            style: TextStyle(fontSize: 15, color: c.textSecondary),
          ),
        ],
      ),
    );
  }

  // MARK: Steps

  Widget _phoneStep(AuthManager auth) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: c.card,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => _showCountrySheet(),
                child: SizedBox(
                  width: 42,
                  height: 42,
                  child: Center(
                    child: _detectedCountry != null
                        ? Text(
                            _detectedCountry!.flag,
                            style: const TextStyle(fontSize: 30),
                          )
                        : Icon(
                            sfIcon('globe'),
                            size: 26,
                            color: c.textTertiary,
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  style: TextStyle(fontSize: 22, color: c.textPrimary),
                  decoration: const InputDecoration(
                    hintText: '手机号（含国家区号）',
                    border: InputBorder.none,
                  ),
                  onChanged: (v) {
                    final formatted = _formatAsYouType(v);
                    if (formatted != v) {
                      _phone.value = TextEditingValue(
                        text: formatted,
                        selection: TextSelection.collapsed(
                          offset: formatted.length,
                        ),
                      );
                    }
                    setState(() {});
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _primaryButton(
          auth,
          '获取验证码',
          _phoneDigits.length >= 7,
          () => auth.submitPhone('+$_phoneDigits'),
        ),
        const SizedBox(height: 20),
        Text(
          '我们会向该号码发送一次性登录验证码',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: c.textTertiary),
        ),
      ],
    );
  }

  void _showCountrySheet() {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => CountryPickerView(onSelect: _selectCountry),
      ),
    );
  }

  Widget _codeStep(AuthManager auth, String info) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            info,
            style: TextStyle(fontSize: 13, color: c.textSecondary),
          ),
        ),
        const SizedBox(height: 16),
        InputField(
          systemImage: 'lock.shield.fill',
          placeholder: '验证码',
          controller: _code,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        _primaryButton(
          auth,
          '登录',
          _code.text.isNotEmpty,
          () => auth.submitCode(_code.text),
        ),
        const SizedBox(height: 16),
        Center(
          child: TextButton(
            onPressed: auth.resendCode,
            child: Text(
              '重新发送验证码',
              style: TextStyle(fontSize: 13, color: AppTheme.brand),
            ),
          ),
        ),
      ],
    );
  }

  Widget _passwordStep(AuthManager auth, String hint) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hint.isNotEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '密码提示：$hint',
              style: TextStyle(fontSize: 13, color: c.textSecondary),
            ),
          ),
        const SizedBox(height: 16),
        InputField(
          systemImage: 'lock.fill',
          placeholder: '两步验证密码',
          controller: _password,
          secure: true,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        _primaryButton(
          auth,
          '验证',
          _password.text.isNotEmpty,
          () => auth.submitPassword(_password.text),
        ),
      ],
    );
  }

  Widget _registrationStep(AuthManager auth) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            '这是一个新账号，请填写昵称',
            style: TextStyle(fontSize: 13, color: c.textSecondary),
          ),
        ),
        const SizedBox(height: 16),
        InputField(
          systemImage: 'person.crop.circle.fill',
          placeholder: '名字',
          controller: _firstName,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        InputField(
          systemImage: 'person.crop.circle',
          placeholder: '姓氏（可选）',
          controller: _lastName,
        ),
        const SizedBox(height: 16),
        _primaryButton(
          auth,
          '完成注册',
          _firstName.text.isNotEmpty,
          () => auth.register(_firstName.text, _lastName.text),
        ),
      ],
    );
  }

  Widget _credentialsNotice() {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        children: [
          Icon(Icons.warning_rounded, size: 40, color: AppTheme.unreadBadge),
          const SizedBox(height: 12),
          Text(
            '尚未配置 Telegram API 凭证',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: c.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '请在 lib/config/secrets.dart 中填入你的 api_id 与 api_hash'
            '（在 my.telegram.org 获取），然后重新运行。',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: c.textSecondary),
          ),
        ],
      ),
    );
  }

  // MARK: Building blocks

  Widget _primaryButton(
    AuthManager auth,
    String title,
    bool enabled,
    VoidCallback action,
  ) {
    final on = enabled && !auth.isWorking;
    return GestureDetector(
      onTap: on ? action : null,
      child: Container(
        height: 50,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: enabled ? AppTheme.brandGradient : null,
          color: enabled ? null : context.colors.textTertiary,
          borderRadius: BorderRadius.circular(25),
        ),
        child: auth.isWorking
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              )
            : Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }
}

/// A pill-shaped reference text field with a leading glyph. Secure fields get a
/// full (alphanumeric) keyboard and a show/hide eye toggle — Telegram 2-step
/// passwords are NOT numeric.
class InputField extends StatefulWidget {
  const InputField({
    super.key,
    required this.systemImage,
    required this.placeholder,
    required this.controller,
    this.secure = false,
    this.keyboardType,
    this.inputFormatters,
    this.onChanged,
  });

  final String systemImage;
  final String placeholder;
  final TextEditingController controller;
  final bool secure;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;

  @override
  State<InputField> createState() => _InputFieldState();
}

class _InputFieldState extends State<InputField> {
  late bool _obscure = widget.secure;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(25),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 22,
            child: Icon(
              sfIcon(widget.systemImage),
              size: 20,
              color: AppTheme.brand,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: widget.controller,
              obscureText: _obscure,
              // Force a full keyboard for secure fields so they're never numeric.
              keyboardType:
                  widget.keyboardType ??
                  (widget.secure ? TextInputType.visiblePassword : null),
              inputFormatters: widget.inputFormatters,
              onChanged: widget.onChanged,
              autocorrect: false,
              enableSuggestions: false,
              style: TextStyle(color: c.textPrimary, fontSize: 16),
              decoration: InputDecoration(
                hintText: widget.placeholder,
                border: InputBorder.none,
                isCollapsed: true,
              ),
            ),
          ),
          if (widget.secure)
            GestureDetector(
              onTap: () => setState(() => _obscure = !_obscure),
              child: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Icon(
                  _obscure ? Icons.visibility_off : Icons.visibility,
                  size: 20,
                  color: c.textTertiary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
