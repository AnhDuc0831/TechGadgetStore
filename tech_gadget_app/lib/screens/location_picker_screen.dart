import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class LocationPickerScreen extends StatefulWidget {
  final String? initialAddress;

  const LocationPickerScreen({
    super.key,
    this.initialAddress,
  });

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  final geo.Geocoding _nativeGeocoder = geo.Geocoding(locale: const Locale('vi', 'VN'));

  // Tách biệt ô Số nhà và Tên đường để người dùng dễ dàng bổ sung số nhà chính xác
  final TextEditingController _houseNumberController = TextEditingController();
  final TextEditingController _streetController = TextEditingController();

  // Mặc định ban đầu: 115 Nguyễn Huệ, Quận 1, TP. Hồ Chí Minh (toạ độ có số nhà chuẩn xác)
  LatLng _selectedLocation = const LatLng(10.7735, 106.7032);
  bool _isLoadingAddress = false;
  bool _isGettingGps = false;
  String _mapType = 'm'; // 'm': Bản đồ Google chuẩn, 'y': Vệ tinh Google Hybrid

  // Cấu trúc hành chính Việt Nam: Phường/Xã, Quận/Huyện, Tỉnh/TP
  String _ward = '';      // Phường / Xã
  String _district = '';  // Quận / Huyện
  String _province = '';  // Tỉnh / Thành phố
  String _fullAddressText = 'Đang tải thông tin địa chỉ...';

  // Lưu tạm số nhà người dùng gõ vào thanh tìm kiếm (VD: '15 Lê Duẩn')
  String _searchedHouseNumber = '';

  List<_SearchResult> _searchResults = [];
  bool _isSearching = false;
  Timer? _debounceTimer;

  static final RegExp _houseNumberExtractRegex = RegExp(
    r'^(?:số|so)?\s*([0-9]+[A-Za-z]?(\/[0-9]+[A-Za-z]?)*)\s*,?\s*(.*)$',
    caseSensitive: false,
  );

  @override
  void initState() {
    super.initState();
    _initInitialLocation();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _houseNumberController.dispose();
    _streetController.dispose();
    super.dispose();
  }

  Map<String, String> _parseHouseAndStreet(String input) {
    final trimmed = input.trim();
    final match = _houseNumberExtractRegex.firstMatch(trimmed);
    if (match != null) {
      final hn = match.group(1);
      final rest = match.group(3)?.trim() ?? '';
      if (hn != null && hn.isNotEmpty) {
        final formattedHN = hn.toLowerCase().startsWith('số') ? hn : 'Số $hn';
        return {'house': formattedHN, 'street': rest};
      }
    }
    return {'house': '', 'street': trimmed};
  }

  static bool _isInVietnam(double lat, double lon) {
    return lat >= 8.1 && lat <= 23.9 && lon >= 102.1 && lon <= 110.0;
  }

  Future<void> _initInitialLocation() async {
    // Nếu có địa chỉ ban đầu truyền vào từ form thanh toán
    if (widget.initialAddress != null && widget.initialAddress!.trim().isNotEmpty) {
      final initial = widget.initialAddress!.trim();
      _searchController.text = initial;

      // Trích xuất số nhà ban đầu nếu có (VD: 'Số 45 Lê Duẩn')
      final parsed = _parseHouseAndStreet(initial);
      if (parsed['house']!.isNotEmpty) {
        _houseNumberController.text = parsed['house']!;
      }

      final coords = await _searchFirstResult(parsed['street']!.isNotEmpty ? parsed['street']! : initial);
      if (coords != null) {
        if (mounted) {
          setState(() => _selectedLocation = coords);
          _mapController.move(coords, 16.0);
          await _reverseGeocode(coords);
          return;
        }
      }
    }

    // Thử lấy vị trí GPS hiện tại của người dùng (có lọc bỏ vị trí máy ảo bên Mỹ)
    await _locateUser(animate: false);
    await _reverseGeocode(_selectedLocation);
  }

  Future<LatLng?> _searchFirstResult(String query) async {
    // 1. Thử Native Geocoder của thiết bị trước
    try {
      final locations = await _nativeGeocoder.locationFromAddress(query);
      if (locations.isNotEmpty) {
        return LatLng(locations.first.latitude, locations.first.longitude);
      }
    } catch (_) {}

    // 2. Fallback sang Photon
    try {
      final photonUrl = Uri.parse(
        'https://photon.komoot.io/api/?q=${Uri.encodeComponent(query)}&limit=1',
      );
      final res = await http.get(photonUrl).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final features = data['features'] as List<dynamic>?;
        if (features != null && features.isNotEmpty) {
          final coords = features[0]['geometry']?['coordinates'] as List<dynamic>?;
          if (coords != null && coords.length >= 2) {
            return LatLng((coords[1] as num).toDouble(), (coords[0] as num).toDouble());
          }
        }
      }
    } catch (_) {}
    return null;
  }

  Future<void> _locateUser({bool animate = true}) async {
    setState(() => _isGettingGps = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted && animate) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Vui lòng bật dịch vụ định vị GPS trên thiết bị.')),
          );
        }
        setState(() => _isGettingGps = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted && animate) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Ứng dụng cần quyền vị trí để định vị.')),
            );
          }
          setState(() => _isGettingGps = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted && animate) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Quyền vị trí đã bị từ chối vĩnh viễn trong Cài đặt.')),
          );
        }
        setState(() => _isGettingGps = false);
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );

      // Lọc toạ độ giả lập của máy ảo Android (thường mặc định ở Trụ sở Google - 1600 Amphitheatre Pkwy, Mountain View, CA)
      if (!_isInVietnam(position.latitude, position.longitude)) {
        if (mounted && animate) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Máy ảo đang đặt GPS ở Mỹ (Google HQ - 1600 Amphitheatre Pkwy). Đã giữ vị trí tại TP. Hồ Chí Minh.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 4),
            ),
          );
        }
        setState(() => _isGettingGps = false);
        return;
      }

      final newLoc = LatLng(position.latitude, position.longitude);
      setState(() {
        _selectedLocation = newLoc;
        _isGettingGps = false;
      });

      if (animate) {
        _mapController.move(newLoc, 16.5);
      }
      await _reverseGeocode(newLoc);
    } catch (_) {
      if (mounted) setState(() => _isGettingGps = false);
    }
  }

  /// Tra cứu địa chỉ tự nhiên: Tên đường, Phường/Xã, Quận/Huyện, Tỉnh/TP
  Future<void> _reverseGeocode(LatLng point) async {
    setState(() {
      _isLoadingAddress = true;
    });

    String detectedHouseNumber = '';
    String detectedStreet = '';
    String detectedBuilding = '';
    String detectedWard = '';
    String detectedDistrict = '';
    String detectedProvince = '';

    // 0. Ưu tiên 1: Dùng Native Geocoder trên máy (giống cơ chế của dự án GiGood)
    // Trên Android dùng Google Play Services Geocoder, trên iOS dùng Apple CLGeocoder
    try {
      final placemarks = await _nativeGeocoder.placemarkFromCoordinates(
        point.latitude,
        point.longitude,
      );
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;

        // Trích xuất số nhà
        String nativeHouse = p.subThoroughfare?.trim() ?? '';
        if (nativeHouse.isEmpty && p.name != null && p.name!.trim().isNotEmpty) {
          final parsed = _parseHouseAndStreet(p.name!.trim());
          if (parsed['house']!.isNotEmpty) {
            nativeHouse = parsed['house']!;
          }
        }
        if (nativeHouse.isEmpty && p.street != null && p.street!.trim().isNotEmpty) {
          final parsed = _parseHouseAndStreet(p.street!.trim());
          if (parsed['house']!.isNotEmpty) {
            nativeHouse = parsed['house']!;
          }
        }
        if (nativeHouse.isNotEmpty) {
          detectedHouseNumber = nativeHouse;
        }

        // Tên đường
        if (p.thoroughfare != null && p.thoroughfare!.trim().isNotEmpty) {
          detectedStreet = p.thoroughfare!.trim();
        } else if (p.street != null && p.street!.trim().isNotEmpty) {
          final parsed = _parseHouseAndStreet(p.street!.trim());
          detectedStreet = parsed['street']!.isNotEmpty ? parsed['street']! : p.street!.trim();
        }

        // Phường / Xã
        if (p.subLocality != null && p.subLocality!.trim().isNotEmpty) {
          detectedWard = p.subLocality!.trim();
        }

        // Quận / Huyện
        if (p.subAdministrativeArea != null && p.subAdministrativeArea!.trim().isNotEmpty) {
          detectedDistrict = p.subAdministrativeArea!.trim();
        }

        // Tỉnh / Thành phố
        if (p.administrativeArea != null && p.administrativeArea!.trim().isNotEmpty) {
          detectedProvince = p.administrativeArea!.trim();
        }
      }
    } catch (_) {
      // Tiếp tục fallback sang Photon và BigDataCloud
    }

    // Nếu Native Geocoder chưa có đủ thông tin, bổ sung qua Photon & BigDataCloud
    if (detectedStreet.isEmpty || detectedWard.isEmpty || detectedProvince.isEmpty) {
      try {
        final photonUri = Uri.parse(
          'https://photon.komoot.io/reverse?lat=${point.latitude}&lon=${point.longitude}',
        );
        final bdcUri = Uri.parse(
          'https://api-bdc.io/data/reverse-geocode-client?latitude=${point.latitude}&longitude=${point.longitude}&localityLanguage=vi',
        );

        final futures = await Future.wait([
          http.get(photonUri).timeout(const Duration(seconds: 4)).catchError((_) => http.Response('', 500)),
          http.get(bdcUri).timeout(const Duration(seconds: 4)).catchError((_) => http.Response('', 500)),
        ]);

        final photonRes = futures[0];
        final bdcRes = futures[1];

        // 1. Phân tích kết quả từ Photon
        if (photonRes.statusCode == 200 && photonRes.body.isNotEmpty) {
          try {
            final data = jsonDecode(photonRes.body);
            final features = data['features'] as List<dynamic>?;
            if (features != null && features.isNotEmpty) {
              final props = features[0]['properties'] as Map<String, dynamic>?;
              if (props != null) {
                if (detectedHouseNumber.isEmpty) {
                  for (final feat in features) {
                    final p = feat['properties'] as Map<String, dynamic>?;
                    if (p != null && p['housenumber'] != null && p['housenumber'].toString().trim().isNotEmpty) {
                      detectedHouseNumber = p['housenumber'].toString().trim();
                      break;
                    }
                  }
                }
                if (detectedStreet.isEmpty) {
                  detectedStreet = props['street']?.toString().trim() ?? '';
                }
                final name = props['name']?.toString().trim() ?? '';
                if (name.isNotEmpty && name != detectedStreet && name != detectedHouseNumber) {
                  detectedBuilding = name;
                }

                // Nếu tên đường chưa có, thử lấy từ name nếu name chứa đường/phố
                if (detectedStreet.isEmpty && name.isNotEmpty) {
                  final nameLower = name.toLowerCase();
                  if (nameLower.contains('đường') || nameLower.contains('phố') || nameLower.contains('hẻm')) {
                    detectedStreet = name;
                  }
                }

                // Nếu số nhà vẫn trống, kiểm tra số trong tên đường (VD: "Hẻm 766...") hoặc toà nhà
                if (detectedHouseNumber.isEmpty && detectedStreet.isNotEmpty) {
                  final match = RegExp(r'^(?:hẻm|ngõ|ngách)\s*([0-9]+[A-Za-z]?(\/[0-9]+[A-Za-z]?)*)\s*(.*)$', caseSensitive: false).firstMatch(detectedStreet);
                  if (match != null) {
                    detectedHouseNumber = match.group(1)!;
                    final rest = match.group(3)?.trim() ?? '';
                    if (rest.isNotEmpty) detectedStreet = rest;
                  }
                }
                if (detectedHouseNumber.isEmpty && detectedBuilding.isNotEmpty) {
                  final match = RegExp(r'([0-9]+[A-Za-z]?(\/[0-9]+[A-Za-z]?)*)').firstMatch(detectedBuilding);
                  if (match != null) {
                    detectedHouseNumber = match.group(1)!;
                  }
                }

                final pDistrict = props['district']?.toString().trim() ?? '';
                final pLocality = props['locality']?.toString().trim() ?? '';
                final pCity = (props['city'] ?? props['state'])?.toString().trim() ?? '';

                if (detectedWard.isEmpty) {
                  if (pLocality.isNotEmpty &&
                      (pLocality.toLowerCase().contains('phường') || pLocality.toLowerCase().contains('xã'))) {
                    detectedWard = pLocality;
                  } else if (pDistrict.isNotEmpty &&
                      (pDistrict.toLowerCase().contains('phường') || pDistrict.toLowerCase().contains('xã'))) {
                    detectedWard = pDistrict;
                  }
                }

                if (detectedDistrict.isEmpty && pDistrict.isNotEmpty && detectedWard != pDistrict) {
                  detectedDistrict = pDistrict;
                }
                if (detectedProvince.isEmpty && pCity.isNotEmpty) {
                  detectedProvince = pCity;
                }
              }
            }
          } catch (_) {}
        }

        // 2. Phân tích kết quả từ BigDataCloud (bổ sung chính xác các cấp hành chính VN)
        if (bdcRes.statusCode == 200 && bdcRes.body.isNotEmpty) {
          try {
            final bdcData = jsonDecode(bdcRes.body);
            if (bdcData is Map<String, dynamic>) {
              // Tỉnh / Thành phố
              if (detectedProvince.isEmpty) {
                final bdcProvince = bdcData['principalSubdivision']?.toString().trim() ??
                    bdcData['city']?.toString().trim() ?? '';
                if (bdcProvince.isNotEmpty) {
                  detectedProvince = bdcProvince;
                }
              }

              final locInfo = bdcData['localityInfo'] as Map<String, dynamic>?;
              if (locInfo != null) {
                // Tìm Quận / Huyện trong informative
                if (detectedDistrict.isEmpty) {
                  final informative = locInfo['informative'] as List<dynamic>?;
                  if (informative != null) {
                    for (final item in informative) {
                      final itemName = item['name']?.toString().trim() ?? '';
                      final itemLower = itemName.toLowerCase();
                      if (itemLower.startsWith('quận ') ||
                          itemLower.startsWith('huyện ') ||
                          itemLower.startsWith('thị xã ') ||
                          itemLower.startsWith('thành phố ') ||
                          itemLower.startsWith('tp.')) {
                        detectedDistrict = itemName;
                        break;
                      }
                    }
                    if (detectedDistrict.isEmpty) {
                      for (final item in informative) {
                        final itemName = item['name']?.toString().trim() ?? '';
                        final desc = item['description']?.toString().toLowerCase() ?? '';
                        if (desc.contains('quận') || desc.contains('huyện')) {
                          detectedDistrict = itemName;
                          break;
                        }
                      }
                    }
                  }
                }

                // Tìm Phường / Xã trong administrative level 6
                if (detectedWard.isEmpty) {
                  final administrative = locInfo['administrative'] as List<dynamic>?;
                  if (administrative != null) {
                    for (final item in administrative) {
                      final level = item['adminLevel'] as num?;
                      final itemName = item['name']?.toString().trim() ?? '';
                      if (level == 6 && itemName.isNotEmpty) {
                        detectedWard = itemName;
                      }
                    }
                  }
                }
              }

              if (detectedWard.isEmpty) {
                final bdcLocality = bdcData['locality']?.toString().trim() ?? '';
                if (bdcLocality.isNotEmpty &&
                    bdcLocality != detectedProvince &&
                    bdcLocality != detectedDistrict) {
                  detectedWard = bdcLocality;
                }
              }
            }
          } catch (_) {}
        }
      } catch (_) {}
    }

    // Chuẩn hoá tiền tố Phường / Xã
    if (detectedWard.isNotEmpty) {
      final wLower = detectedWard.toLowerCase();
      if (!wLower.startsWith('phường') &&
          !wLower.startsWith('xã') &&
          !wLower.startsWith('thị trấn') &&
          !wLower.startsWith('p.')) {
        detectedWard = 'Phường $detectedWard';
      }
    }

    // Chuẩn hoá tiền tố Quận / Huyện
    if (detectedDistrict.isNotEmpty) {
      final dLower = detectedDistrict.toLowerCase();
      if (!dLower.startsWith('quận') &&
          !dLower.startsWith('huyện') &&
          !dLower.startsWith('thị xã') &&
          !dLower.startsWith('thành phố') &&
          !dLower.startsWith('tp.') &&
          !dLower.startsWith('q.')) {
        detectedDistrict = 'Quận $detectedDistrict';
      }
    }

    // Chuẩn hoá tiền tố Tỉnh / Thành phố
    if (detectedProvince.isNotEmpty) {
      final pLower = detectedProvince.toLowerCase();
      if (!pLower.startsWith('thành phố') &&
          !pLower.startsWith('tỉnh') &&
          !pLower.startsWith('tp')) {
        detectedProvince = 'TP. $detectedProvince';
      }
    }

    // Tên đường từ bản đồ
    String finalStreet = detectedStreet;
    if (finalStreet.isEmpty && detectedBuilding.isNotEmpty) {
      finalStreet = detectedBuilding;
    } else if (detectedBuilding.isNotEmpty && !finalStreet.contains(detectedBuilding)) {
      finalStreet = '$finalStreet ($detectedBuilding)';
    }

    if (mounted) {
      setState(() {
        _ward = detectedWard;
        _district = detectedDistrict;
        _province = detectedProvince;

        // Cập nhật tên đường
        if (finalStreet.isNotEmpty) {
          _streetController.text = finalStreet;
        }

        // Cập nhật số nhà:
        // 1. Ưu tiên số nhà người dùng đã gõ trong ô tìm kiếm
        if (_searchedHouseNumber.isNotEmpty) {
          _houseNumberController.text = _searchedHouseNumber;
          _searchedHouseNumber = '';
        }
        // 2. Nếu tìm thấy số nhà từ Native Geocoder hoặc Photon
        else if (detectedHouseNumber.isNotEmpty) {
          final formatted = detectedHouseNumber.toLowerCase().startsWith('số')
              ? detectedHouseNumber
              : 'Số $detectedHouseNumber';
          if (_houseNumberController.text.trim().isEmpty || _houseNumberController.text.trim() == 'Số 1') {
            _houseNumberController.text = formatted;
          }
        }
        // 3. Nếu điểm toạ độ chưa gắn số nhà và ô số nhà đang trống, mặc định hiển thị "Số 1" để người dùng dễ nhận biết và chỉnh sửa
        else if (_houseNumberController.text.trim().isEmpty) {
          _houseNumberController.text = 'Số 1';
        }

        _isLoadingAddress = false;
      });
      _updateFullAddress();
    }
  }

  void _updateFullAddress() {
    final parts = <String>[];
    final house = _houseNumberController.text.trim();
    final street = _streetController.text.trim();

    String streetCombined = '';
    if (house.isNotEmpty) {
      final hn = house.toLowerCase().startsWith('số') ? house : 'Số $house';
      streetCombined = street.isNotEmpty ? '$hn $street' : hn;
    } else if (street.isNotEmpty) {
      streetCombined = street;
    }

    if (streetCombined.isNotEmpty) {
      parts.add(streetCombined);
    }
    if (_ward.isNotEmpty && !parts.any((p) => p.contains(_ward))) {
      parts.add(_ward);
    }
    if (_district.isNotEmpty && !parts.any((p) => p.contains(_district))) {
      parts.add(_district);
    }
    if (_province.isNotEmpty && !parts.any((p) => p.contains(_province))) {
      parts.add(_province);
    }

    setState(() {
      _fullAddressText = parts.isNotEmpty
          ? parts.join(', ')
          : 'Đang định vị địa chỉ...';
    });
  }

  String _formatPhotonProperties(Map<String, dynamic> props) {
    final name = props['name']?.toString().trim();
    final houseNumber = props['housenumber']?.toString().trim();
    final street = props['street']?.toString().trim();
    final locality = props['locality']?.toString().trim();
    final district = props['district']?.toString().trim();
    final city = (props['city'] ?? props['state'])?.toString().trim();

    final parts = <String>[];
    if (houseNumber != null && houseNumber.isNotEmpty) {
      final hn = houseNumber.toLowerCase().startsWith('số') ? houseNumber : 'Số $houseNumber';
      if (street != null && street.isNotEmpty) {
        parts.add('$hn $street');
      } else {
        parts.add(hn);
      }
    } else if (street != null && street.isNotEmpty) {
      parts.add(street);
    } else if (name != null && name.isNotEmpty) {
      parts.add(name);
    }

    if (name != null &&
        name.isNotEmpty &&
        !parts.contains(name) &&
        street != null &&
        name != street) {
      parts.insert(0, name);
    }
    if (locality != null && locality.isNotEmpty && !parts.contains(locality)) {
      parts.add(locality);
    }
    if (district != null && district.isNotEmpty && !parts.contains(district)) {
      parts.add(district);
    }
    if (city != null && city.isNotEmpty && !parts.contains(city)) {
      parts.add(city);
    }

    return parts.isNotEmpty ? parts.join(', ') : (name ?? '');
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      setState(() => _isSearching = true);

      // Nếu người dùng gõ có kèm số nhà (VD: '15 Lê Duẩn'), tách số nhà ra lưu lại
      final parsed = _parseHouseAndStreet(query);
      if (parsed['house']!.isNotEmpty) {
        _searchedHouseNumber = parsed['house']!;
      }

      final searchQuery = parsed['street']!.isNotEmpty ? parsed['street']! : query.trim();

      try {
        final photonUrl = Uri.parse(
          'https://photon.komoot.io/api/?q=${Uri.encodeComponent(searchQuery)}&lat=${_selectedLocation.latitude}&lon=${_selectedLocation.longitude}&limit=5',
        );

        final response = await http.get(photonUrl).timeout(const Duration(seconds: 4));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final features = data['features'] as List<dynamic>?;
          if (features != null && features.isNotEmpty) {
            final results = <_SearchResult>[];
            for (final f in features) {
              final props = f['properties'] as Map<String, dynamic>?;
              final coords = f['geometry']?['coordinates'] as List<dynamic>?;
              if (props != null && coords != null && coords.length >= 2) {
                final lon = (coords[0] as num).toDouble();
                final lat = (coords[1] as num).toDouble();
                final display = _formatPhotonProperties(props);
                if (display.isNotEmpty) {
                  results.add(_SearchResult(
                    displayName: display,
                    location: LatLng(lat, lon),
                  ));
                }
              }
            }

            if (results.isNotEmpty && mounted) {
              setState(() {
                _searchResults = results;
                _isSearching = false;
              });
              return;
            }
          }
        }
      } catch (_) {}

      if (mounted) {
        setState(() => _isSearching = false);
      }
    });
  }

  void _selectSearchResult(_SearchResult result) {
    FocusScope.of(context).unfocus();
    setState(() {
      _selectedLocation = result.location;
      _searchResults = [];
      _searchController.text = result.displayName;
    });

    _mapController.move(result.location, 16.5);
    _reverseGeocode(result.location);
  }

  void _confirmSelection() {
    _updateFullAddress();
    if (_fullAddressText.trim().isEmpty || _isLoadingAddress) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đang tải địa chỉ, vui lòng chờ trong giây lát...')),
      );
      return;
    }

    Navigator.of(context).pop(_fullAddressText.trim());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chọn địa chỉ giao hàng'),
        elevation: 0,
      ),
      body: Stack(
        children: [
          // 1. Bản đồ Google Maps (TileLayer với khả năng chuyển đổi Vệ tinh / Đường phố)
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _selectedLocation,
              initialZoom: 15.5,
              onTap: (tapPosition, point) {
                FocusScope.of(context).unfocus();
                setState(() {
                  _selectedLocation = point;
                  _searchResults = [];
                });
                _reverseGeocode(point);
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://mt{s}.google.com/vt/lyrs=$_mapType&x={x}&y={y}&z={z}',
                subdomains: const ['0', '1', '2', '3'],
                userAgentPackageName: 'com.techgadget.app',
                maxZoom: 20,
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _selectedLocation,
                    width: 48,
                    height: 48,
                    alignment: Alignment.topCenter,
                    child: const Icon(
                      Icons.location_on,
                      color: Color(0xFFDC2626),
                      size: 48,
                      shadows: [
                        Shadow(color: Colors.black38, blurRadius: 6, offset: Offset(0, 3)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          // 2. Thanh tìm kiếm trên đỉnh bản đồ
          Positioned(
            top: 12,
            left: 16,
            right: 16,
            child: Column(
              children: [
                Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(12),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      hintText: 'Tìm địa chỉ (VD: 15 Lê Duẩn, Landmark 81...)',
                      prefixIcon: const Icon(Icons.search, color: Color(0xFF2563EB)),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 20),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchResults = []);
                              },
                            )
                          : (_isSearching
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: Padding(
                                    padding: EdgeInsets.all(12.0),
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                )
                              : null),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                ),

                // Danh sách kết quả gợi ý tìm kiếm
                if (_searchResults.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    constraints: const BoxConstraints(maxHeight: 220),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4)),
                      ],
                    ),
                    child: ListView.separated(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: _searchResults.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final res = _searchResults[index];
                        return ListTile(
                          leading: const Icon(Icons.place_outlined, color: Colors.blue),
                          title: Text(
                            res.displayName,
                            style: const TextStyle(fontSize: 13),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => _selectSearchResult(res),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),

          // 3. Nút chuyển đổi kiểu bản đồ (Google Đường phố / Google Vệ tinh)
          Positioned(
            right: 16,
            bottom: 375,
            child: FloatingActionButton.small(
              heroTag: 'map_type_toggle',
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF2563EB),
              tooltip: _mapType == 'm' ? 'Chuyển sang ảnh vệ tinh' : 'Chuyển sang bản đồ đường phố',
              onPressed: () {
                setState(() {
                  _mapType = _mapType == 'm' ? 'y' : 'm';
                });
              },
              child: Icon(_mapType == 'm' ? Icons.satellite_alt_outlined : Icons.map_outlined),
            ),
          ),

          // 4. Nút định vị GPS hiện tại
          Positioned(
            right: 16,
            bottom: 320,
            child: FloatingActionButton.small(
              heroTag: 'gps_button',
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF2563EB),
              onPressed: _isGettingGps ? null : () => _locateUser(animate: true),
              child: _isGettingGps
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location),
            ),
          ),

          // 5. Khung thông tin địa chỉ chi tiết ở dưới đáy màn hình
          Positioned(
            left: 14,
            right: 14,
            bottom: 16,
            child: Card(
              elevation: 8,
              shadowColor: Colors.black26,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Hàng tiêu đề & Trạng thái định vị
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.location_on, color: Color(0xFFDC2626), size: 20),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Địa chỉ nhận hàng',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                        ),
                        if (_isLoadingAddress)
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_circle, size: 12, color: Colors.green.shade700),
                                const SizedBox(width: 4),
                                Text(
                                  'Đã định vị',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Hai ô nhập riêng biệt: Số nhà & Tên đường
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Ô 1: Số nhà / Căn hộ
                        Expanded(
                          flex: 4,
                          child: TextField(
                            controller: _houseNumberController,
                            decoration: InputDecoration(
                              labelText: 'Số nhà / Căn hộ *',
                              hintText: 'VD: 15/2',
                              prefixIcon: const Icon(Icons.tag, size: 18),
                              isDense: true,
                              filled: true,
                              fillColor: Colors.blue.shade50.withValues(alpha: 0.3),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: Colors.blue.shade300),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: Colors.blue.shade300),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
                            ),
                            onChanged: (_) => _updateFullAddress(),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Ô 2: Tên đường / Toà nhà (Bản đồ tự động điền)
                        Expanded(
                          flex: 6,
                          child: TextField(
                            controller: _streetController,
                            decoration: InputDecoration(
                              labelText: 'Tên đường / Toà nhà *',
                              hintText: 'Tên đường từ bản đồ',
                              prefixIcon: const Icon(Icons.add_road, size: 18),
                              isDense: true,
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
                            ),
                            onChanged: (_) => _updateFullAddress(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Gợi ý hỗ trợ người dùng
                    Row(
                      children: [
                        Icon(Icons.info_outline, size: 13, color: Colors.blue.shade700),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'Bản đồ tự điền tên đường & xã/tỉnh. Hãy gõ số nhà của bạn để giao tận cửa.',
                            style: TextStyle(fontSize: 11, color: Colors.blue.shade900),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Các nhãn hành chính đã nhận diện: Xã/Phường, Quận/Huyện, Tỉnh/TP
                    if (_ward.isNotEmpty || _district.isNotEmpty || _province.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            if (_ward.isNotEmpty) _buildAdminChip(Icons.domain_outlined, _ward),
                            if (_district.isNotEmpty) _buildAdminChip(Icons.location_city_outlined, _district),
                            if (_province.isNotEmpty) _buildAdminChip(Icons.map_outlined, _province),
                          ],
                        ),
                      ),

                    // Khung xem trước địa chỉ tự nhiên hoàn chỉnh
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 1.0),
                            child: Icon(Icons.pin_drop, size: 16, color: Color(0xFF2563EB)),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _isLoadingAddress
                                  ? 'Đang tra cứu tên đường, xã phường, quận tỉnh...'
                                  : (_fullAddressText.isNotEmpty
                                      ? _fullAddressText
                                      : 'Chưa có thông tin địa chỉ'),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1E40AF),
                                height: 1.35,
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Nút xác nhận địa chỉ hoàn chỉnh
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _isLoadingAddress ? null : _confirmSelection,
                        icon: const Icon(Icons.check, size: 20),
                        label: const Text(
                          'Xác nhận địa chỉ này',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.grey.shade700),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade800,
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchResult {
  final String displayName;
  final LatLng location;

  _SearchResult({
    required this.displayName,
    required this.location,
  });
}
