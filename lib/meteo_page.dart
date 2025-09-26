// lib/meteo_page.dart
import 'dart:convert';
import 'package:flutter/foundation.dart'; // kIsWeb
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:geocoding/geocoding.dart' as gc;

class MeteoPage extends StatefulWidget {
  const MeteoPage({super.key});

  @override
  State<MeteoPage> createState() => _MeteoPageState();
}

class _MeteoPageState extends State<MeteoPage> {
  bool _loading = false;
  String? _error;

  // Posizione
  double? _lat, _lon;
  String? _locality, _country;

  // Meteo
  double? _temp; // °C
  int? _code; // weathercode
  double? _wind; // km/h
  int? _windDir; // °
  DateTime? _updatedAt;

  // CTA posizione
  bool _showLocCta = false;
  bool _permForever = false;

  String _fmtTime(DateTime t, {bool withDate = false}) {
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    if (!withDate) return '$hh:$mm';
    final dd = t.day.toString().padLeft(2, '0');
    final mo = t.month.toString().padLeft(2, '0');
    return '$dd/$mo $hh:$mm';
  }

  @override
  void initState() {
    super.initState();
    _loadWeather();
  }

  Future<Position> _getPosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        setState(() {
          _showLocCta = true;
          _permForever = false;
        });
      }
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          setState(() {
            _showLocCta = true;
            _permForever = false;
          });
        }
        throw Exception('Permesso posizione negato');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        setState(() {
          _showLocCta = true;
          _permForever = true;
        });
      }
      throw Exception('Permesso negato in modo permanente');
    }

    if (mounted) {
      setState(() {
        _showLocCta = false;
        _permForever = false;
      });
    }
    return Geolocator.getCurrentPosition();
  }

  String _descFromCode(int c) {
    if (c == 0) return 'Sereno';
    if ([1, 2, 3].contains(c)) return 'Variabile';
    if ([45, 48].contains(c)) return 'Nebbia';
    if ([51, 53, 55, 56, 57, 61, 63, 65, 66, 67].contains(c)) return 'Pioggia';
    if ([71, 73, 75, 77].contains(c)) return 'Neve';
    if ([80, 81, 82].contains(c)) return 'Rovesci';
    if ([95, 96, 99].contains(c)) return 'Temporale';
    return '—';
  }

  IconData _iconFromCode(int c) {
    if (c == 0) return Icons.wb_sunny;
    if ([1, 2, 3].contains(c)) return Icons.cloud;
    if ([45, 48].contains(c)) return Icons.blur_on;
    if ([51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 80, 81, 82].contains(c)) {
      return Icons.water_drop;
    }
    if ([71, 73, 75, 77].contains(c)) return Icons.ac_unit;
    if ([95, 96, 99].contains(c)) return Icons.bolt;
    return Icons.cloud_queue;
  }

  Future<Map<String, String?>> _reverseGeocodeWeb(
    double lat,
    double lon,
  ) async {
    // Tentativo 1: Open-Meteo
    Future<Map<String, String?>> _tryOpenMeteo() async {
      final u = Uri.parse(
        'https://geocoding-api.open-meteo.com/v1/reverse'
        '?latitude=$lat&longitude=$lon&language=it&count=1',
      );
      final r = await http.get(u);
      if (r.statusCode != 200) throw Exception('HTTP ${r.statusCode}');
      final data = jsonDecode(r.body);
      final list = (data['results'] as List?) ?? const [];
      if (list.isEmpty) return {'loc': null, 'country': null};
      final m = list.first as Map<String, dynamic>;
      final loc =
          (m['name'] as String?) ??
          (m['admin1'] as String?) ??
          (m['admin2'] as String?);
      final country = m['country'] as String?;
      return {'loc': loc, 'country': country};
    }

    // Tentativo 2: BigDataCloud (fallback, CORS aperto)
    Future<Map<String, String?>> _tryBDC() async {
      final u = Uri.parse(
        'https://api.bigdatacloud.net/data/reverse-geocode-client'
        '?latitude=$lat&longitude=$lon&localityLanguage=it',
      );
      final r = await http.get(u);
      if (r.statusCode != 200) throw Exception('HTTP ${r.statusCode}');
      final data = jsonDecode(r.body) as Map<String, dynamic>;
      final loc =
          (data['city'] as String?) ??
          (data['locality'] as String?) ??
          (data['principalSubdivision'] as String?);
      final country = data['countryName'] as String?;
      return {'loc': loc, 'country': country};
    }

    try {
      final v = await _tryOpenMeteo();
      if (v['loc'] != null || v['country'] != null) return v;
    } catch (_) {}
    try {
      final v = await _tryBDC();
      if (v['loc'] != null || v['country'] != null) return v;
    } catch (_) {}
    return {'loc': null, 'country': null};
  }

  Future<void> _loadWeather() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Posizione
      final pos = await _getPosition();
      final lat = pos.latitude;
      final lon = pos.longitude;

      // Meteo corrente
      final r = await http.get(
        Uri.parse(
          'https://api.open-meteo.com/v1/forecast'
          '?latitude=$lat&longitude=$lon&current_weather=true&timezone=auto',
        ),
      );
      if (r.statusCode != 200) throw Exception('HTTP ${r.statusCode}');
      final data = jsonDecode(r.body);
      final cw = data['current_weather'];
      if (cw == null) throw Exception('Dati meteo non disponibili');

      // Reverse geocoding
      String? loc;
      String? country;
      if (kIsWeb) {
        try {
          final g = await _reverseGeocodeWeb(lat, lon);
          loc = g['loc'];
          country = g['country'];
        } catch (_) {}
      } else {
        try {
          final places = await gc.placemarkFromCoordinates(
            lat,
            lon,
            localeIdentifier: 'it_IT',
          );
          if (places.isNotEmpty) {
            final p = places.first;
            loc = (p.locality?.isNotEmpty == true)
                ? p.locality
                : (p.subAdministrativeArea?.isNotEmpty == true
                      ? p.subAdministrativeArea
                      : (p.administrativeArea?.isNotEmpty == true
                            ? p.administrativeArea
                            : null));
            country = p.country;
          }
        } catch (_) {}
      }

      setState(() {
        _lat = lat;
        _lon = lon;
        _locality = loc;
        _country = country;

        _temp = (cw['temperature'] as num?)?.toDouble();
        _code = (cw['weathercode'] as num?)?.toInt();
        _wind = (cw['windspeed'] as num?)?.toDouble();
        _windDir = (cw['winddirection'] as num?)?.toInt();

        // Aggiornato (ora del dispositivo, precisa al momento del fetch)
        _updatedAt = DateTime.now();
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _buildLocationCta(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.location_off, color: cs.error),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Geolocalizzazione disattivata',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _permForever
                  ? 'Concedi il permesso Posizione dalle impostazioni dell’app, poi premi Riprova.'
                  : 'Attiva il GPS / consenti la Posizione, poi premi Riprova.',
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                OutlinedButton(
                  onPressed: _permForever
                      ? Geolocator.openAppSettings
                      : Geolocator.openLocationSettings,
                  child: Text(
                    _permForever ? 'Impostazioni app' : 'Impostazioni GPS',
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: _loadWeather,
                  child: const Text('Riprova'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeatherContent(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.place),
            title: const Text('Posizione'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (_locality != null || _country != null)
                      ? '${_locality ?? '—'}${_country != null ? ', $_country' : ''}'
                      : '—',
                ),
                if (_lat != null && _lon != null)
                  Text(
                    'lat: ${_lat!.toStringAsFixed(4)}   lon: ${_lon!.toStringAsFixed(4)}',
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Card(
          child: ListTile(
            leading: Icon(
              _code == null ? Icons.cloud_queue : _iconFromCode(_code!),
              size: 32,
            ),
            title: Text(
              _code == null ? 'Meteo' : _descFromCode(_code!),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _temp == null
                      ? 'Temperatura: —'
                      : 'Temperatura: ${_temp!.toStringAsFixed(1)}°C',
                ),
                Text(
                  _wind == null
                      ? 'Vento: —'
                      : 'Vento: ${_wind!.toStringAsFixed(1)} km/h'
                            '${_windDir == null ? '' : ' (dir $_windDir°)'}',
                ),
                if (_updatedAt != null)
                  Text('Aggiornato: ${_fmtTime(_updatedAt!)}'),
              ],
            ),
            trailing: const Icon(Icons.chevron_right),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Fonte: Open-Meteo',
          textAlign: TextAlign.center,
          style: TextStyle(color: cs.onSurfaceVariant),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Meteo')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loadWeather,
        icon: const Icon(Icons.refresh),
        label: const Text('Aggiorna'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Column(
                  children: [
                    if (_showLocCta) _buildLocationCta(context),
                    if (!_showLocCta && _error != null)
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          'Errore: $_error',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: cs.error),
                        ),
                      ),
                    if (!_showLocCta && _error == null)
                      _buildWeatherContent(cs),
                  ],
                ),
              ),
      ),
    );
  }
}
