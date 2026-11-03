import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../models/order.dart';

class OrderTrackingMapScreen extends StatefulWidget {
  final OrderModel order;

  const OrderTrackingMapScreen({
    super.key,
    required this.order,
  });

  @override
  State<OrderTrackingMapScreen> createState() => _OrderTrackingMapScreenState();
}

class _OrderTrackingMapScreenState extends State<OrderTrackingMapScreen> {
  final MapController _mapController = MapController();
  final geo.Geocoding _nativeGeocoder = geo.Geocoding(locale: const Locale('vi', 'VN'));

  // Điểm kho hàng mặc định: TechGadget Central Hub
  static const LatLng _storeLocation = LatLng(10.7769, 106.7009);

  LatLng _customerLocation = const LatLng(10.7950, 106.6880);
  LatLng _shipperLocation = const LatLng(10.7860, 106.6945);

  bool _isLoadingRoute = true;
  double _distanceKm = 3.5;
  String _mapType = 'm'; // 'm': Bản đồ đường phố Google, 'y': Vệ tinh Google Hybrid

  @override
  void initState() {
    super.initState();
    _geocodeCustomerAddress();
  }

  Future<void> _geocodeCustomerAddress() async {
    final addr = widget.order.formattedShippingAddress;
    if (addr.isNotEmpty && addr != 'Chưa cập nhật địa chỉ') {
      final coordMatch = RegExp(r'(-?\d+\.\d+)\s*,\s*(-?\d+\.\d+)').firstMatch(addr);
      if (coordMatch != null && (addr.contains('(') || addr.contains('Vị trí'))) {
        final lat = double.tryParse(coordMatch.group(1)!);
        final lon = double.tryParse(coordMatch.group(2)!);
        if (lat != null && lon != null) {
          _customerLocation = LatLng(lat, lon);
        }
      } else {
        bool geocoded = false;

        // 1. Thử Native Geocoder của thiết bị trước
        try {
          final locations = await _nativeGeocoder.locationFromAddress(addr);
          if (locations.isNotEmpty) {
            _customerLocation = LatLng(locations.first.latitude, locations.first.longitude);
            geocoded = true;
          }
        } catch (_) {}

        if (!geocoded) {
          try {
            // 2. Thử Photon Geocoding cho địa chỉ tự nhiên
            final photonUrl = Uri.parse(
              'https://photon.komoot.io/api/?q=${Uri.encodeComponent(addr)}&lat=10.7769&lon=106.7009&limit=1',
            );

            final response = await http.get(photonUrl).timeout(const Duration(seconds: 4));
            if (response.statusCode == 200) {
              final data = jsonDecode(response.body);
              final features = data['features'] as List<dynamic>?;
              if (features != null && features.isNotEmpty) {
                final coords = features[0]['geometry']?['coordinates'] as List<dynamic>?;
                if (coords != null && coords.length >= 2) {
                  final lon = (coords[0] as num).toDouble();
                  final lat = (coords[1] as num).toDouble();
                  _customerLocation = LatLng(lat, lon);
                  geocoded = true;
                }
              }
            }
          } catch (_) {}
        }

        if (!geocoded) {
          try {
            // 3. Dự phòng: Nominatim
            final url = Uri.parse(
              'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(addr)}&format=json&countrycodes=vn&limit=1&accept-language=vi',
            );

            final response = await http.get(
              url,
              headers: {'User-Agent': 'TechGadgetApp/1.0 (contact@techgadget.com)'},
            ).timeout(const Duration(seconds: 4));

            if (response.statusCode == 200) {
              final list = jsonDecode(response.body) as List<dynamic>;
              if (list.isNotEmpty) {
                final lat = double.tryParse(list[0]['lat']?.toString() ?? '');
                final lon = double.tryParse(list[0]['lon']?.toString() ?? '');
                if (lat != null && lon != null) {
                  _customerLocation = LatLng(lat, lon);
                }
              }
            }
          } catch (_) {}
        }
      }
    }

    // Tính vị trí shipper nằm giữa kho và khách hàng
    const distance = Distance();
    final meters = distance(_storeLocation, _customerLocation);
    _distanceKm = meters / 1000.0;
    if (_distanceKm < 0.5) _distanceKm = 2.4;

    // Shipper nằm ở khoảng 60% quãng đường từ kho đến khách
    final isShipping = widget.order.statusEnum == OrderStatusEnum.shipping;
    final isCompleted = widget.order.statusEnum == OrderStatusEnum.completed;

    if (isCompleted) {
      _shipperLocation = _customerLocation;
    } else if (isShipping) {
      final latDiff = _customerLocation.latitude - _storeLocation.latitude;
      final lonDiff = _customerLocation.longitude - _storeLocation.longitude;
      _shipperLocation = LatLng(
        _storeLocation.latitude + latDiff * 0.65,
        _storeLocation.longitude + lonDiff * 0.65,
      );
    } else {
      _shipperLocation = _storeLocation;
    }

    if (mounted) {
      setState(() => _isLoadingRoute = false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fitBounds();
      });
    }
  }

  void _fitBounds() {
    final bounds = LatLngBounds.fromPoints([
      _storeLocation,
      _customerLocation,
      _shipperLocation,
    ]);
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 80),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.order.statusEnum;
    final isShipping = status == OrderStatusEnum.shipping;
    final isCompleted = status == OrderStatusEnum.completed;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lộ trình giao hàng'),
        actions: [
          IconButton(
            icon: Icon(_mapType == 'm' ? Icons.satellite_alt_outlined : Icons.map_outlined),
            tooltip: _mapType == 'm' ? 'Chuyển sang ảnh vệ tinh' : 'Chuyển sang bản đồ đường phố',
            onPressed: () {
              setState(() {
                _mapType = _mapType == 'm' ? 'y' : 'm';
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.center_focus_strong),
            tooltip: 'Căn chỉnh bản đồ',
            onPressed: _fitBounds,
          ),
        ],
      ),
      body: Stack(
        children: [
          // 1. Bản đồ lộ trình
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _storeLocation,
              initialZoom: 13.5,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://mt{s}.google.com/vt/lyrs=$_mapType&x={x}&y={y}&z={z}',
                subdomains: const ['0', '1', '2', '3'],
                userAgentPackageName: 'com.techgadget.app',
                maxZoom: 20,
              ),

              // Tuyến đường nối Kho -> Khách
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: [_storeLocation, _shipperLocation, _customerLocation],
                    strokeWidth: 4.0,
                    color: const Color(0xFF2563EB),
                    pattern: StrokePattern.dashed(segments: const [12, 6]),
                  ),
                ],
              ),

              // Các điểm Marker
              MarkerLayer(
                markers: [
                  // Điểm 1: Kho hàng TechGadget
                  Marker(
                    point: _storeLocation,
                    width: 44,
                    height: 44,
                    child: _buildMarkerBubble(
                      icon: Icons.store,
                      color: const Color(0xFF2563EB),
                      label: 'Kho hàng',
                    ),
                  ),

                  // Điểm 2: Shipper (nếu đang giao)
                  if (isShipping)
                    Marker(
                      point: _shipperLocation,
                      width: 50,
                      height: 50,
                      child: _buildMarkerBubble(
                        icon: Icons.two_wheeler,
                        color: const Color(0xFFD97706),
                        label: 'Shipper',
                        isPulse: true,
                      ),
                    ),

                  // Điểm 3: Nhà khách hàng
                  Marker(
                    point: _customerLocation,
                    width: 44,
                    height: 44,
                    child: _buildMarkerBubble(
                      icon: isCompleted ? Icons.check_circle : Icons.person_pin_circle,
                      color: isCompleted ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                      label: 'Điểm nhận',
                    ),
                  ),
                ],
              ),
            ],
          ),

          // 2. Loading spinner khi đang định vị
          if (_isLoadingRoute)
            Container(
              color: Colors.black26,
              child: const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 12),
                        Text('Đang dựng tuyến đường giao hàng...'),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // 3. Card thông tin trạng thái vận chuyển ở đáy màn hình
          Positioned(
            left: 16,
            right: 16,
            bottom: 20,
            child: Card(
              elevation: 6,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: widget.order.statusColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            isCompleted
                                ? Icons.verified
                                : (isShipping ? Icons.local_shipping : Icons.schedule),
                            color: widget.order.statusColor,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isCompleted
                                    ? 'Giao hàng thành công'
                                    : (isShipping ? 'Shipper đang giao hàng' : widget.order.statusLabel),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isCompleted
                                    ? 'Đơn hàng đã được giao trọn vẹn đến bạn'
                                    : 'Khoảng cách giao ước tính: ~${_distanceKm.toStringAsFixed(1)} km',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.location_on, size: 18, color: Color(0xFFDC2626)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.order.formattedShippingAddress,
                            style: const TextStyle(fontSize: 13, color: Colors.black87),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
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

  Widget _buildMarkerBubble({
    required IconData icon,
    required Color color,
    required String label,
    bool isPulse = false,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: isPulse ? 0.45 : 0.25),
                blurRadius: isPulse ? 10 : 5,
                spreadRadius: isPulse ? 4 : 1,
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ],
    );
  }
}
