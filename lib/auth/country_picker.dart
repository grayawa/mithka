//
//  country_picker.dart
//
//  Country/region model + picker sheet for the Telegram-style phone login.
//  The Swift app sources its list from libphonenumber; to stay dependency-light
//  cross-platform we embed a comprehensive dialable-region table (Chinese names,
//  ISO codes, dial codes) and compute flags from the ISO code — the same
//  presentation, match, and flag logic as the Swift `Country`.
//

import 'package:flutter/material.dart';

import '../components/sf_symbols.dart';
import '../theme/app_theme.dart';

class Country {
  const Country(this.name, this.iso, this.dial);
  final String name; // Chinese display name
  final String iso; // ISO 3166-1 alpha-2
  final String dial; // dial code, digits only

  /// Flag emoji derived from the ISO code (regional-indicator scalars).
  String get flag {
    const base = 0x1F1E6;
    final buf = StringBuffer();
    for (final c in iso.toUpperCase().codeUnits) {
      if (c >= 65 && c <= 90) buf.writeCharCode(base + (c - 65));
    }
    return buf.toString();
  }

  static const Country china = Country('中国', 'CN', '86');

  /// Every dialable region we ship (names localized to Chinese).
  static const List<Country> all = [
    Country('中国', 'CN', '86'),
    Country('中国香港', 'HK', '852'),
    Country('中国澳门', 'MO', '853'),
    Country('中国台湾', 'TW', '886'),
    Country('美国', 'US', '1'),
    Country('加拿大', 'CA', '1'),
    Country('英国', 'GB', '44'),
    Country('日本', 'JP', '81'),
    Country('韩国', 'KR', '82'),
    Country('新加坡', 'SG', '65'),
    Country('马来西亚', 'MY', '60'),
    Country('泰国', 'TH', '66'),
    Country('越南', 'VN', '84'),
    Country('印度尼西亚', 'ID', '62'),
    Country('菲律宾', 'PH', '63'),
    Country('印度', 'IN', '91'),
    Country('巴基斯坦', 'PK', '92'),
    Country('孟加拉国', 'BD', '880'),
    Country('澳大利亚', 'AU', '61'),
    Country('新西兰', 'NZ', '64'),
    Country('德国', 'DE', '49'),
    Country('法国', 'FR', '33'),
    Country('意大利', 'IT', '39'),
    Country('西班牙', 'ES', '34'),
    Country('葡萄牙', 'PT', '351'),
    Country('荷兰', 'NL', '31'),
    Country('比利时', 'BE', '32'),
    Country('瑞士', 'CH', '41'),
    Country('奥地利', 'AT', '43'),
    Country('瑞典', 'SE', '46'),
    Country('挪威', 'NO', '47'),
    Country('丹麦', 'DK', '45'),
    Country('芬兰', 'FI', '358'),
    Country('波兰', 'PL', '48'),
    Country('俄罗斯', 'RU', '7'),
    Country('哈萨克斯坦', 'KZ', '7'),
    Country('乌克兰', 'UA', '380'),
    Country('土耳其', 'TR', '90'),
    Country('希腊', 'GR', '30'),
    Country('捷克', 'CZ', '420'),
    Country('匈牙利', 'HU', '36'),
    Country('罗马尼亚', 'RO', '40'),
    Country('爱尔兰', 'IE', '353'),
    Country('阿联酋', 'AE', '971'),
    Country('沙特阿拉伯', 'SA', '966'),
    Country('以色列', 'IL', '972'),
    Country('卡塔尔', 'QA', '974'),
    Country('科威特', 'KW', '965'),
    Country('埃及', 'EG', '20'),
    Country('南非', 'ZA', '27'),
    Country('尼日利亚', 'NG', '234'),
    Country('肯尼亚', 'KE', '254'),
    Country('巴西', 'BR', '55'),
    Country('阿根廷', 'AR', '54'),
    Country('墨西哥', 'MX', '52'),
    Country('智利', 'CL', '56'),
    Country('哥伦比亚', 'CO', '57'),
    Country('秘鲁', 'PE', '51'),
    Country('柬埔寨', 'KH', '855'),
    Country('缅甸', 'MM', '95'),
    Country('老挝', 'LA', '856'),
    Country('斯里兰卡', 'LK', '94'),
    Country('尼泊尔', 'NP', '977'),
    Country('蒙古', 'MN', '976'),
  ];

  /// `all`, sorted by Chinese display name for presentation.
  static List<Country> get sorted =>
      [...all]..sort((a, b) => a.name.compareTo(b.name));

  /// Best country whose dial code is a prefix of [digits] (longest dial wins;
  /// shared codes resolve to the canonical main country, e.g. +1 → US).
  static const _mainForCode = {'1': 'US', '7': 'RU', '44': 'GB', '86': 'CN'};

  static Country? match(String digits) {
    if (digits.isEmpty) return null;
    final candidates = all
        .where((c) => c.dial.isNotEmpty && digits.startsWith(c.dial))
        .toList();
    if (candidates.isEmpty) return null;
    final maxLen = candidates
        .map((c) => c.dial.length)
        .reduce((a, b) => a > b ? a : b);
    final best = candidates.where((c) => c.dial.length == maxLen).toList();
    if (best.length == 1) return best.first;
    final main = _mainForCode[best.first.dial];
    return best.firstWhere((c) => c.iso == main, orElse: () => best.first);
  }
}

class CountryPickerView extends StatefulWidget {
  const CountryPickerView({super.key, required this.onSelect});
  final ValueChanged<Country> onSelect;

  @override
  State<CountryPickerView> createState() => _CountryPickerViewState();
}

class _CountryPickerViewState extends State<CountryPickerView> {
  final _controller = TextEditingController();
  String _query = '';

  List<Country> get _results {
    final q = _query.trim();
    if (q.isEmpty) return Country.sorted;
    final lower = q.toLowerCase();
    final digits = q.replaceAll(RegExp(r'[^0-9]'), '');
    return Country.sorted.where((c) {
      return c.name.contains(q) ||
          c.iso.toLowerCase().contains(lower) ||
          (digits.isNotEmpty && c.dial.contains(digits));
    }).toList();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.groupedBackground,
      appBar: AppBar(
        backgroundColor: c.navBar,
        title: Text(
          '选择国家或地区',
          style: TextStyle(fontSize: 17, color: c.textPrimary),
        ),
        centerTitle: true,
        leading: TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('取消', style: TextStyle(color: AppTheme.brand)),
        ),
        leadingWidth: 64,
      ),
      body: Column(
        children: [
          Container(
            color: c.background,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: c.searchFill,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    sfIcon('magnifyingglass'),
                    size: 18,
                    color: c.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      onChanged: (v) => setState(() => _query = v),
                      style: TextStyle(color: c.textPrimary, fontSize: 15),
                      decoration: const InputDecoration(
                        hintText: '搜索国家 / 区号',
                        border: InputBorder.none,
                        isCollapsed: true,
                      ),
                    ),
                  ),
                  if (_query.isNotEmpty)
                    GestureDetector(
                      onTap: () => setState(() {
                        _controller.clear();
                        _query = '';
                      }),
                      child: Icon(
                        Icons.cancel,
                        size: 18,
                        color: c.textTertiary,
                      ),
                    ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Container(
              color: c.background,
              child: ListView.builder(
                itemCount: _results.length,
                itemBuilder: (context, i) {
                  final country = _results[i];
                  return InkWell(
                    onTap: () {
                      widget.onSelect(country);
                      Navigator.of(context).pop();
                    },
                    child: Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Text(
                            country.flag,
                            style: const TextStyle(fontSize: 26),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            country.name,
                            style: TextStyle(
                              fontSize: 17,
                              color: c.textPrimary,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '+${country.dial}',
                            style: TextStyle(
                              fontSize: 16,
                              color: c.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
