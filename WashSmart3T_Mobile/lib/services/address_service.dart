import 'dart:convert';
import 'package:http/http.dart' as http;

class AddressSuggestion {
  final String displayName;
  final String shortTitle;
  final String subtitle;

  const AddressSuggestion({
    required this.displayName,
    required this.shortTitle,
    required this.subtitle,
  });
}

class AddressService {
  static const List<Map<String, String>> _hcmcKnownPlaces = [
    {
      'title': '140 Lê Trọng Tấn, P. Tây Thạnh, Q. Tân Phú, TP.HCM',
      'sub': 'Cửa hàng WashSmart 3T · Quận Tân Phú',
    },
    {
      'title': '2 Nguyễn Sỹ Sách, P. 15, Q. Tân Bình, TP.HCM',
      'sub': 'Phường 15, Quận Tân Bình, TP. Hồ Chí Minh',
    },
    {
      'title': '7 Phan Huy Ích, P. 15, Q. Tân Bình, TP.HCM',
      'sub': 'Phường 15, Quận Tân Bình, TP. Hồ Chí Minh',
    },
    {
      'title': '20 Cộng Hòa, P. 4, Q. Tân Bình, TP.HCM',
      'sub': 'Phường 4, Quận Tân Bình, TP. Hồ Chí Minh',
    },
    {
      'title': '364 Cộng Hòa, P. 13, Q. Tân Bình, TP.HCM',
      'sub': 'Etown Cộng Hòa, Quận Tân Bình, TP. Hồ Chí Minh',
    },
    {
      'title': '218 Trường Chinh, P. 13, Q. Tân Bình, TP.HCM',
      'sub': 'Phường 13, Quận Tân Bình, TP. Hồ Chí Minh',
    },
    {
      'title': '450 Âu Cơ, P. 10, Q. Tân Bình, TP.HCM',
      'sub': 'Phường 10, Quận Tân Bình, TP. Hồ Chí Minh',
    },
    {
      'title': '30 Bờ Bao Tân Thắng, P. Sơn Kỳ, Q. Tân Phú, TP.HCM',
      'sub': 'Aeon Mall Tân Phú Celadon, Quận Tân Phú',
    },
    {
      'title': '250 Tân Kỳ Tân Quý, P. Sơn Kỳ, Q. Tân Phú, TP.HCM',
      'sub': 'Phường Sơn Kỳ, Quận Tân Phú, TP. Hồ Chí Minh',
    },
    {
      'title': '120 Lũy Bán Bích, P. Tân Thới Hòa, Q. Tân Phú, TP.HCM',
      'sub': 'Phường Tân Thới Hòa, Quận Tân Phú, TP. Hồ Chí Minh',
    },
    {
      'title': '45 Bàu Cát, P. 14, Q. Tân Bình, TP.HCM',
      'sub': 'Khu Bàu Cát, Quận Tân Bình, TP. Hồ Chí Minh',
    },
  ];

  static String _normalize(String input) {
    const withDiacritics = 'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ';
    const withoutDiacritics = 'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd';
    var res = input.toLowerCase();
    for (int i = 0; i < withDiacritics.length; i++) {
      res = res.replaceAll(withDiacritics[i], withoutDiacritics[i]);
    }
    return res;
  }

  static Future<List<AddressSuggestion>> searchSuggestions(String rawQuery) async {
    final query = rawQuery.trim();
    if (query.length < 2) return [];

    final normQuery = _normalize(query);
    final results = <AddressSuggestion>[];
    final seen = <String>{};

    // 1. Local fast matches (preserving user's house number if typed)
    final houseMatch = RegExp(r'^(\d+[A-Za-z]?)\s+(.+)$').firstMatch(query);
    final typedNumber = houseMatch?.group(1);
    final typedStreet = houseMatch != null ? _normalize(houseMatch.group(2)!) : normQuery;

    for (final item in _hcmcKnownPlaces) {
      final title = item['title']!;
      final normTitle = _normalize(title);
      if (normTitle.contains(typedStreet) || normTitle.contains(normQuery)) {
        String display = title;
        if (typedNumber != null && !normTitle.startsWith('$typedNumber ')) {
          // Replace leading number in known place with user's typed house number
          display = title.replaceFirst(RegExp(r'^\d+[A-Za-z]?\s+'), '$typedNumber ');
        }
        if (seen.add(display.toLowerCase())) {
          results.add(AddressSuggestion(
            displayName: display,
            shortTitle: display.split(',').first,
            subtitle: item['sub']!,
          ));
        }
      }
    }

    // 2. Live OpenStreetMap Nominatim lookup
    try {
      final searchUrl = Uri.parse(
        'https://nominatim.openstreetmap.org/search?format=json&countrycodes=vn&addressdetails=1&limit=5&q=${Uri.encodeComponent('$query, TP. Hồ Chí Minh')}',
      );
      final response = await http.get(searchUrl, headers: {
        'Accept-Language': 'vi',
      }).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final list = jsonDecode(response.body);
        if (list is List) {
          for (final raw in list) {
            if (raw is Map<String, dynamic>) {
              final displayName = (raw['display_name'] ?? '').toString();
              if (displayName.isEmpty) continue;
              // Clean up ", Vietnam" / ", Việt Nam" suffix for cleaner UI
              final cleaned = displayName
                  .replaceAll(RegExp(r',\s*(Việt Nam|Vietnam)$', caseSensitive: false), '')
                  .trim();
              if (seen.add(cleaned.toLowerCase())) {
                final parts = cleaned.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
                final shortTitle = parts.isNotEmpty ? parts.first : cleaned;
                final subtitle = parts.length > 1 ? parts.skip(1).join(', ') : 'TP. Hồ Chí Minh';
                results.add(AddressSuggestion(
                  displayName: cleaned,
                  shortTitle: shortTitle,
                  subtitle: subtitle,
                ));
              }
            }
          }
        }
      }
    } catch (_) {
      // Fallback to local matches silently if network/Nominatim times out
    }

    return results.take(6).toList();
  }
}
