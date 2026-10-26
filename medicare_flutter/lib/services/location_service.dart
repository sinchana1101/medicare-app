import 'package:geolocator/geolocator.dart';

class LocationService {
  Future<Position?> getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return null;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return null;
    }

    try {
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null) return lastKnown;
    } catch (_) {}

    try {
      return await Geolocator.getCurrentPosition(
        timeLimit: const Duration(seconds: 2),
      );
    } catch (_) {
      return null;
    }
  }

  String getGoogleMapsUrl(Position position) {
    return "https://www.google.com/maps/search/?api=1&query=${position.latitude},${position.longitude}";
  }
}
