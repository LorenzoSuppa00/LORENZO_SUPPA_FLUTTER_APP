import 'dart:convert';
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
  double? _temp;     // °C
  int? _code;        // weathercode
  double? _wind;     // km/h
  int? _windDir;     // °
  String? _timeIso;  // ISO8601

  @override
  void initState() {
    super.initState();
    _loadWeather();
  }

  Future<Position> _getPosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) throw Exception('Servizi di localizzazione disattivati');

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Permesso posizione negato');
      }
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception('Permesso negato in modo permanente');
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
    if (c == 0) return Icons.wb_sunny;                 // sereno
    if ([1, 2, 3].contains(c)) return Icons.cloud;      // variabile/nuvoloso
    if ([45, 48].contains(c)) return Icons.blur_on;     // nebbia
    if ([51,53,55,56,57,61,63,65,66,67,80,81,82].contains(c))
      return Icons.water_drop;                          // pioggia/rovesci
    if ([71,73,75,77].contains(c)) return Icons.ac_unit;// neve
    if ([95,96,99].contains(c)) return Icons.bolt;      // temporale
    return Icons.cloud_queue;
  }

  Future<void> _loadWeather() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // 1) Posizione
      final pos = await _getPosition();
      final lat = pos.latitude;
      final lon = pos.longitude;

      // 2) Meteo corrente
      final r = await http.get(Uri.parse(
        'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current_weather=true',
      ));
      if (r.statusCode != 200) throw Exception('HTTP ${r.statusCode}');
      final data = jsonDecode(r.body);
      final cw = data['current_weather'];
      if (cw == null) throw Exception('Dati meteo non disponibili');

      // 3) Reverse geocoding (città/paese)
      String? loc;
      String? country;
      try {
        final places = await gc.placemarkFromCoordinates(
          lat, lon,
          localeIdentifier: 'it_IT',
        );
        if (places.isNotEmpty) {
          final p = places.first;
          loc = (p.locality?.isNotEmpty == true)
              ? p.locality
              : (p.subAdministrativeArea?.isNotEmpty == true
                  ? p.subAdministrativeArea
                  : (p.administrativeArea?.isNotEmpty == true ? p.administrativeArea : null));
          country = p.country;
        }
      } catch (_) {
        // ok se fallisce: mostreremo solo le coordinate
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
        _timeIso = cw['time'] as String?;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
            : _error != null
                ? Center(
                    child: Text(
                      'Errore: $_error',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: cs.error),
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Posizione: città + coordinate
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

                      // Meteo
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
                              Text(_temp == null
                                  ? 'Temperatura: —'
                                  : 'Temperatura: ${_temp!.toStringAsFixed(1)}°C'),
                              Text(
                                _wind == null
                                    ? 'Vento: —'
                                    : 'Vento: ${_wind!.toStringAsFixed(1)} km/h'
                                      '${_windDir == null ? '' : ' (dir $_windDir°)'}',
                              ),
                              if (_timeIso != null) Text('Aggiornato: $_timeIso'),
                            ],
                          ),
                          trailing: const Icon(Icons.chevron_right),
                        ),
                      ),

                      const Spacer(),
                      Text(
                        'Fonte: Open-Meteo',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
      ),
    );
  }
}
