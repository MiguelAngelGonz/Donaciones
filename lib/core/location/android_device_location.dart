import 'package:donaciones/core/models/domain_models.dart';
import 'package:flutter/services.dart';
import 'package:geolocator_android/geolocator_android.dart';

const _locationChannel = MethodChannel('komuna/location');
final _mexicanPostalCode = RegExp(r'\b[0-9]{5}\b');

Future<UbicacionMock?> lookupAndroidApproximateLocation(String label) async {
  final postalCode = _mexicanPostalCode.firstMatch(label)?.group(0);
  final query = postalCode ?? label.trim();
  if (query.isEmpty) return null;
  try {
    final result = await _locationChannel
        .invokeMapMethod<String, double>('coordinates', {
          'label': '$query, México',
          'postalCode': postalCode,
        })
        .timeout(const Duration(seconds: 6), onTimeout: () => null);
    final latitude = result?['latitude'];
    final longitude = result?['longitude'];
    if (latitude == null || longitude == null) return null;
    return UbicacionMock(
      etiqueta: label,
      codigoPostal: postalCode,
      latitud: latitude,
      longitud: longitude,
    );
  } on PlatformException {
    return null;
  } on MissingPluginException {
    return null;
  }
}

Future<UbicacionMock> readAndroidDeviceLocation(
  GeolocatorAndroid locator,
) async {
  final position = await locator.getCurrentPosition(
    locationSettings: AndroidSettings(
      accuracy: LocationAccuracy.low,
      timeLimit: const Duration(seconds: 15),
    ),
  );
  final postalCode = await _findPostalCode(position);
  return UbicacionMock(
    etiqueta: 'Ubicación del dispositivo',
    latitud: position.latitude,
    longitud: position.longitude,
    codigoPostal: postalCode,
  );
}

Future<String?> _findPostalCode(Position position) async {
  try {
    final postalCode = await _locationChannel
        .invokeMethod<String>('postalCode', {
          'latitude': position.latitude,
          'longitude': position.longitude,
        })
        .timeout(const Duration(seconds: 4), onTimeout: () => null);
    final trimmed = postalCode?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  } on PlatformException {
    return null;
  } on MissingPluginException {
    return null;
  }
}
