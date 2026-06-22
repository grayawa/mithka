//
//  edit_profile_view.dart
//
//  编辑资料 — avatar + name / username / bio, loaded from getMe/getUserFullInfo
//  and saved back via setName / setUsername / setBio. Port of the Swift
//  `EditProfileView`, now wired to live TDLib.
//

import 'package:flutter/material.dart';
import '../components/toast.dart';
import 'package:image_picker/image_picker.dart';

import '../components/photo_avatar.dart';
import '../components/sf_symbols.dart';
import '../components/ui_components.dart';
import '../tdlib/json_helpers.dart';
import '../tdlib/td_client.dart';
import '../tdlib/td_models.dart';
import '../theme/app_theme.dart';
import 'edit_field_view.dart';

class EditProfileView extends StatefulWidget {
  const EditProfileView({super.key});

  @override
  State<EditProfileView> createState() => _EditProfileViewState();
}

class _EditProfileViewState extends State<EditProfileView> {
  final TdClient _client = TdClient.shared;
  String _firstName = '';
  String _lastName = '';
  String _username = '';
  String _bio = '';
  TdFileRef? _photo;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final me = await _client.query({'@type': 'getMe'});
      final uid = me.int64('id');
      _firstName = me.str('first_name') ?? '';
      _lastName = me.str('last_name') ?? '';
      _username = me.obj('usernames')?.str('editable_username') ?? '';
      _photo = TDParse.smallPhoto(me.obj('profile_photo'));
      if (uid != null) {
        final full = await _client.query({
          '@type': 'getUserFullInfo',
          'user_id': uid,
        });
        _bio = full.obj('bio')?.str('text') ?? '';
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  String get _displayName => '$_firstName $_lastName'.trim();

  Future<String?> _edit(
    String title,
    String initial, {
    String prefix = '',
    String hint = '',
    bool multiline = false,
    int? maxLength,
    TextInputType? keyboardType,
  }) {
    return Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => EditFieldView(
          title: title,
          initial: initial,
          prefix: prefix,
          hint: hint,
          multiline: multiline,
          maxLength: maxLength,
          keyboardType: keyboardType,
        ),
      ),
    );
  }

  Future<void> _editName() async {
    final result = await _edit('修改名字', _displayName, hint: '名字');
    if (result == null || result.isEmpty) return;
    final parts = result.split(RegExp(r'\s+'));
    final first = parts.first;
    final last = parts.skip(1).join(' ');
    try {
      await _client.query({
        '@type': 'setName',
        'first_name': first,
        'last_name': last,
      });
      setState(() {
        _firstName = first;
        _lastName = last;
      });
    } catch (_) {
      _toast('保存失败');
    }
  }

  Future<void> _editUsername() async {
    final value = await _edit(
      '修改用户名',
      _username,
      prefix: '@',
      hint: '设置用户名',
      keyboardType: TextInputType.visiblePassword,
    );
    if (value == null) return;
    try {
      await _client.query({'@type': 'setUsername', 'username': value});
      setState(() => _username = value);
    } catch (_) {
      _toast('用户名不可用');
    }
  }

  Future<void> _editBio() async {
    final value = await _edit(
      '修改简介',
      _bio,
      hint: '介绍一下自己',
      multiline: true,
      maxLength: 70,
    );
    if (value == null) return;
    try {
      await _client.query({'@type': 'setBio', 'bio': value});
      setState(() => _bio = value);
    } catch (_) {
      _toast('保存失败');
    }
  }

  Future<void> _changeAvatar() async {
    try {
      final img = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1280,
      );
      if (img == null) return;
      await _client.query({
        '@type': 'setProfilePhoto',
        'photo': {
          '@type': 'inputChatPhotoStatic',
          'photo': {'@type': 'inputFileLocal', 'path': img.path},
        },
      });
      _toast('头像已更新');
      // The new photo propagates via updateUser after upload; re-read shortly.
      await Future<void>.delayed(const Duration(milliseconds: 800));
      final me = await _client.query({'@type': 'getMe'});
      if (mounted) {
        setState(() => _photo = TDParse.smallPhoto(me.obj('profile_photo')));
      }
    } catch (_) {
      _toast('更换头像失败');
    }
  }

  void _toast(String m) => showToast(context, m);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.groupedBackground,
      body: Column(
        children: [
          NavHeader(title: '编辑资料', onBack: () => Navigator.of(context).pop()),
          Expanded(
            child: _loading
                ? const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(12, 18, 12, 24),
                    children: [
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _changeAvatar,
                        child: Column(
                          children: [
                            Center(
                              child: PhotoAvatar(
                                title: _displayName,
                                photo: _photo,
                                size: 88,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Center(
                              child: Text(
                                '更换头像',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppTheme.brand,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      _field(
                        '名字',
                        _displayName.isEmpty ? '点击设置' : _displayName,
                        _editName,
                      ),
                      _field(
                        '用户名',
                        _username.isEmpty ? '@未设置' : '@$_username',
                        _editUsername,
                      ),
                      _field(
                        '简介',
                        _bio.isEmpty ? '点击填写简介' : _bio,
                        _editBio,
                        faded: _bio.isEmpty,
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _field(
    String label,
    String value,
    VoidCallback onTap, {
    bool faded = false,
  }) {
    final c = context.colors;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 64,
              child: Text(
                label,
                style: TextStyle(fontSize: 15, color: c.textSecondary),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 16,
                  color: faded ? c.textTertiary : c.textPrimary,
                ),
              ),
            ),
            Icon(sfIcon('chevron.right'), size: 14, color: c.textTertiary),
          ],
        ),
      ),
    );
  }
}
