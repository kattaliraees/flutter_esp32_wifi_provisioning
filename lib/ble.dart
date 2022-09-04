import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';

class ESPBLE {
  final flutterReactiveBle = FlutterReactiveBle();

  DiscoveredDevice? espDevice;
  final deviceGATTserviceUUID =
      Uuid.parse('021A9004-0382-4AEA-BFF4-6B3F1C5ADFB4');
  final deviceGATTInfoCharUUID =
      Uuid.parse('021AFF53-0382-4AEA-BFF4-6B3F1C5ADFB4');
  final deviceGATTCustomDataCharUUID =
      Uuid.parse('021AFF51-0382-4AEA-BFF4-6B3F1C5ADFB4');
  final deviceGATTProvConfigCharUUID =
      Uuid.parse('021AFF52-0382-4AEA-BFF4-6B3F1C5ADFB4');

  final applyConfigData = Uint8List.fromList([0x08, 0x04, 0x72, 0x00]);
  final startOfConfig = Uint8List.fromList([0x52, 0x03, 0xA2, 0x01, 0x00]);

  static final ESPBLE _singleton = ESPBLE._internal();

  bool isScanning = false;
  bool isConnecting = false;

  factory ESPBLE() {
    return _singleton;
  }

  ESPBLE._internal();

  Uint8List _getWiFiConfigDataToWrite() {
    //add actual wifi config. hope u don't mind me seeinf the wifi password. to se if it's connecting to wifi
    final ssid = 'Raees'.codeUnits;
    final password = 'Kattali'.codeUnits;
    final startHeader = [0x08, 0x02, 0x62];
    const configStartByte = 0x0A;
    final ssidLength = ssid.length;
    final passwordLength = password.length;
    final payloadSize = [(ssidLength + passwordLength + 0x04)];
    const ssidPasswordSeperatorByte = 0x12;

    final configDataToWrite = Uint8List.fromList(startHeader +
        payloadSize +
        [configStartByte] +
        [ssidLength] +
        ssid +
        [ssidPasswordSeperatorByte] +
        [passwordLength] +
        password);

    return configDataToWrite;
  }

  void scanForESPDevice() {
    if (espDevice == null) {
      StreamSubscription<BleStatus>? statusStreamSubscirption;
      StreamSubscription<DiscoveredDevice>? scanStream;
      statusStreamSubscirption =
          flutterReactiveBle.statusStream.listen((status) async {
        if (status == BleStatus.ready) {
          await statusStreamSubscirption?.cancel();

          scanStream = flutterReactiveBle.scanForDevices(
              withServices: [deviceGATTserviceUUID],
              scanMode: ScanMode.lowLatency).listen((device) async {
            await scanStream?.cancel();
            espDevice = device;
            connectToDevice();
          });
        }
      });
    } else {
      connectToDevice();
    }
  }

  void connectToDevice() {
    if (isConnecting) {
      return;
    }

    isConnecting = true;
    StreamSubscription<ConnectionStateUpdate>? connectionStateStream;
    connectionStateStream = flutterReactiveBle
        .connectToDevice(id: espDevice!.id)
        .listen((event) async {
      print(event);
      if (event.connectionState == DeviceConnectionState.connected) {
        final services =
            await flutterReactiveBle.discoverServices(espDevice!.id);
        isConnecting = false;
        final infoCharacteristic = QualifiedCharacteristic(
            serviceId: deviceGATTserviceUUID,
            characteristicId: deviceGATTInfoCharUUID,
            deviceId: espDevice!.id);
        await flutterReactiveBle.writeCharacteristicWithResponse(
            infoCharacteristic,
            value: Uint8List.fromList('ESP'.codeUnits));
        final info =
            await flutterReactiveBle.readCharacteristic(infoCharacteristic);
        print(String.fromCharCodes(info));
        final provConfigCharacteristic = QualifiedCharacteristic(
            serviceId: deviceGATTserviceUUID,
            characteristicId: deviceGATTProvConfigCharUUID,
            deviceId: espDevice!.id);

        await flutterReactiveBle.writeCharacteristicWithResponse(
            provConfigCharacteristic,
            value: startOfConfig);
        final readconfChar = await flutterReactiveBle
            .readCharacteristic(provConfigCharacteristic);
        print(readconfChar);
        await Future.delayed(const Duration(seconds: 1));
        await flutterReactiveBle.writeCharacteristicWithResponse(
            provConfigCharacteristic,
            value: _getWiFiConfigDataToWrite());
        final readconfChar2 = await flutterReactiveBle
            .readCharacteristic(provConfigCharacteristic);
        print(readconfChar2);
        await flutterReactiveBle.writeCharacteristicWithResponse(
            provConfigCharacteristic,
            value: applyConfigData);
      }
    }, onDone: () {
      print('connected');
    }, onError: (e) {
      print(e.toString());
      isConnecting = false;
    });
  }
}
