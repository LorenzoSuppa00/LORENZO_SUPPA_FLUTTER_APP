import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class MeteoPage extends StatefulWidget {
  const MeteoPage({super.key});

  @override
  State<MeteoPage> createState() => _MeteoPageState();
}

class _MeteoPageState extends State<MeteoPage> {
  bool _loading = false;
  String? _error;
  double? _lat, _lon;
  double? _temp;
  int? _code;
  double? _wind;
  int? _windDir;
  String? _timeIso;

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

  Future<void> _loadWeather() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final pos = await _getPosition();
      final lat = pos.latitude;
      final lon = pos.longitude;

      final r = await http.get(Uri.parse(
        'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current_weather=true',
      ));
      if (r.statusCode != 200) throw Exception('HTTP ${r.statusCode}');
      final data = jsonDecode(r.body);
      final cw = data['current_weather'];
      if (cw == null) throw Exception('Dati meteo non disponibili');

      setState(() {
        _lat = lat;
        _lon = lon;
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
                    child: Text('Errore: $_error',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: cs.error)),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.place),
                          title: const Text('Posizione'),
                          subtitle: Text(
                            (_lat == null || _lon == null)
                                ? '—'
                                : 'lat: ${_lat!.toStringAsFixed(4)}  lon: ${_lon!.toStringAsFixed(4)}',
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.cloud_queue),
                          title: Text(
                            _code == null ? 'Meteo' : _descFromCode(_code!),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_temp == null ? '—' : 'Temperatura: ${_temp!.toStringAsFixed(1)}°C'),
                              Text(_wind == null ? '—' : 'Vento: ${_wind!.toStringAsFixed(1)} km/h'
                                  '${_windDir == null ? '' : ' (dir ${_windDir}°)'}'),
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
