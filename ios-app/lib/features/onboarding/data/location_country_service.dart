import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

class LocationCountryService {
  Future<String?> detectCountry() async {
    if (GeocodingPlatformFactory.instance == null) return null;
    if (!await Geolocator.isLocationServiceEnabled()) return null;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.low,
        timeLimit: Duration(seconds: 8),
      ),
    );
    final geocoding = Geocoding();
    final placemarks = await geocoding.placemarkFromCoordinates(
      position.latitude,
      position.longitude,
    );
    if (placemarks.isEmpty) return null;
    return placemarks.first.country;
  }
}
