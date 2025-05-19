import 'dart:io';
import 'dart:typed_data';
import 'package:logger/logger.dart';

var logger = Logger(
  printer: PrettyPrinter(),
);

class WolService {
  Future<void> sendMagicPacket(String macAddress, String broadcastAddress)async {
    try {
      // Convert MAC address to bytes
      final macBytes = _parseMacAddress(macAddress);

      // Create the magic packet
      final magicPacket = BytesBuilder();
      magicPacket.add(Uint8List.fromList(List.filled(6, 0xFF))); // 6 bytes of FF
      for (int i = 0; i < 16; i++) {
        magicPacket.add(macBytes); // 16 repetitions of MAC address
      }

      // Create a UDP socket
      final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.broadcastEnabled = true;

      // Send the packet
      socket.send(
        magicPacket.toBytes(),
        InternetAddress(broadcastAddress),
        9, // WoL typically uses port 9
      );

      socket.close();
      logger.i('Magic packet sent to $macAddress on $broadcastAddress');
    } catch (e) {
      logger.e('Error sending magic packet: $e');
      // You might want to handle this error in the UI
    }
  }

  Uint8List _parseMacAddress(String macAddress) {
    // Remove any delimiters (:, -, etc.) and convert to bytes
    final cleanedMac = macAddress.replaceAll(RegExp(r'[^0-9a-fA-F]'), '');
    if (cleanedMac.length != 12) {
      throw FormatException('Invalid MAC address format');
    }

    final bytes = <int>[];
    for (int i = 0; i < 12; i += 2) {
      bytes.add(int.parse(cleanedMac.substring(i, i + 2), radix: 16));
    }
    return Uint8List.fromList(bytes);
  }
}