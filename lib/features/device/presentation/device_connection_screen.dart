import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../../../core/device/ble_device_connection_service.dart';
import '../../../core/device/device_protocol.dart';
import '../../../core/device/wifi_device_connection_service.dart';
import '../../../core/theme/app_theme.dart';

class DeviceConnectionScreen extends StatefulWidget {
  const DeviceConnectionScreen({super.key});

  @override
  State<DeviceConnectionScreen> createState() => _DeviceConnectionScreenState();
}

class _DeviceConnectionScreenState extends State<DeviceConnectionScreen> {
  final _serviceUuid = TextEditingController();
  final _eventUuid = TextEditingController();
  final _commandUuid = TextEditingController();
  final _wifiUrl = TextEditingController();
  List<DeviceDescriptor> _devices = const [];
  String? _status;
  bool _busy = false;
  BleDeviceConnectionService? _ble;
  WifiDeviceConnectionService? _wifi;

  Future<void> _scanBle() async {
    if (!_validBleFields()) return;
    setState(() {
      _busy = true;
      _status = 'BLE device খোঁজা হচ্ছে…';
    });
    await _ble?.dispose();
    final service = _newBleService();
    try {
      final devices = await service.scanForDevices();
      if (!mounted) return;
      setState(() {
        _ble = service;
        _devices = devices;
        _busy = false;
        _status = devices.isEmpty ? 'কোনো configured device পাওয়া যায়নি।' : '${devices.length}টি device পাওয়া গেছে।';
      });
    } catch (error) {
      await service.dispose();
      if (mounted) setState(() { _busy = false; _status = 'BLE scan ব্যর্থ: $error'; });
    }
  }

  Future<void> _connectBle(DeviceDescriptor device) async {
    final service = _ble;
    if (service == null) return;
    setState(() { _busy = true; _status = '${device.displayName}-এ সংযোগ হচ্ছে…'; });
    try {
      await service.connect(device.id);
      if (mounted) setState(() { _busy = false; _status = 'BLE সংযোগ হয়েছে। তবে sensor protocol validation চালু আছে।'; });
    } catch (error) {
      if (mounted) setState(() { _busy = false; _status = 'BLE সংযোগ ব্যর্থ: $error'; });
    }
  }

  Future<void> _connectWifi() async {
    final uri = Uri.tryParse(_wifiUrl.text.trim());
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      setState(() => _status = 'অনুমোদিত Raspberry Pi HTTPS URL দিন।');
      return;
    }
    await _wifi?.dispose();
    final service = WifiDeviceConnectionService(baseUri: uri);
    setState(() { _busy = true; _status = 'Raspberry Pi Wi-Fi health check চলছে…'; });
    try {
      await service.connect('configured-wifi-device');
      final info = await service.getDeviceInfo();
      if (mounted) setState(() { _wifi = service; _busy = false; _status = 'Wi-Fi সংযোগ হয়েছে: ${info.softwareVersion}'; });
    } catch (error) {
      await service.dispose();
      if (mounted) setState(() { _busy = false; _status = 'Wi-Fi সংযোগ ব্যর্থ: $error'; });
    }
  }

  BleDeviceConnectionService _newBleService() => BleDeviceConnectionService(
        serviceUuid: Guid(_serviceUuid.text.trim()),
        eventCharacteristicUuid: Guid(_eventUuid.text.trim()),
        commandCharacteristicUuid: Guid(_commandUuid.text.trim()),
      );

  bool _validBleFields() {
    final values = [_serviceUuid.text, _eventUuid.text, _commandUuid.text];
    final valid = values.every((value) => value.trim().isNotEmpty);
    if (!valid) setState(() => _status = 'BLE service ও characteristic UUID পূরণ করুন।');
    return valid;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Raspberry Pi / ডিভাইস সংযোগ')),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Card(
              color: AppTheme.warningSurface,
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('শুধু অনুমোদিত hardware protocol-এর UUID বা HTTPS URL ব্যবহার করুন। এই prototype-এ authentication key, signature verifier ও replay-protection configuration নেই; তাই live device data গ্রহণ করা হবে না। অজানা sensor data-কে DRISHTI নিরাপদ পথ হিসেবে গণ্য করা হবে না।'),
              ),
            ),
            const SizedBox(height: 16),
            Text('Bluetooth LE', style: Theme.of(context).textTheme.titleLarge),
            _field(_serviceUuid, 'BLE service UUID'),
            _field(_eventUuid, 'Event notification characteristic UUID'),
            _field(_commandUuid, 'Command write characteristic UUID'),
            FilledButton.icon(
              onPressed: _busy ? null : _scanBle,
              icon: const Icon(Icons.bluetooth_searching),
              label: const Text('BLE device scan করুন'),
            ),
            ..._devices.map(
              (device) => ListTile(
                leading: const Icon(Icons.memory),
                title: Text(device.displayName),
                subtitle: Text(device.id),
                trailing: TextButton(onPressed: _busy ? null : () => _connectBle(device), child: const Text('Connect')),
              ),
            ),
            const Divider(height: 32),
            Text('Wi-Fi HTTP gateway', style: Theme.of(context).textTheme.titleLarge),
            _field(_wifiUrl, 'অনুমোদিত HTTPS Raspberry Pi URL'),
            OutlinedButton.icon(
              onPressed: _busy ? null : _connectWifi,
              icon: const Icon(Icons.wifi),
              label: const Text('Raspberry Pi Wi-Fi পরীক্ষা করুন'),
            ),
            if (_status != null) ...[
              const SizedBox(height: 16),
              Semantics(liveRegion: true, child: Text(_status!)),
            ],
          ],
        ),
      );

  Widget _field(TextEditingController controller, String label) => Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 4),
        child: TextField(controller: controller, decoration: InputDecoration(labelText: label)),
      );

  @override
  void dispose() {
    _serviceUuid.dispose();
    _eventUuid.dispose();
    _commandUuid.dispose();
    _wifiUrl.dispose();
    unawaited(_ble?.dispose());
    unawaited(_wifi?.dispose());
    super.dispose();
  }
}
