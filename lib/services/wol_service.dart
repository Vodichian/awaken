import 'dart:io';
import 'dart:typed_data';
import 'package:logger/logger.dart';

var logger = Logger(printer: PrettyPrinter());

class WolService {
  Future<void> sendMagicPacket(
    String macAddress,
    String broadcastAddress,
  ) async {
    // Convert MAC address to bytes
    final macBytes = parseMacAddress(macAddress);

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
  }

  static bool isValidBroadcastAddress(String addressString) {
    if (addressString.isEmpty) {
      return false;
    }

    // Check for the limited broadcast address
    if (addressString == '255.255.255.255') {
      return true;
    }

    // Try to parse as a general IPv4 address.
    // InternetAddress.tryParse will return null if the format is invalid.
    final InternetAddress? internetAddress = InternetAddress.tryParse(
        addressString);

    if (internetAddress == null ||
        internetAddress.type != InternetAddressType.IPv4) {
      // Not a valid IPv4 address format
      return false;
    }

    // At this point, it's a validly formatted IPv4 address.
    // For directed broadcasts, further validation might be needed depending on context
    // (e.g., ensuring it's the broadcast address of a known subnet),
    // but for WoL, simply being a valid IPv4 address that isn't a loopback
    // or multicast might be sufficient if the user is expected to know their network.

    // Basic check: is it a unicast or broadcast address?
    // We've already handled 255.255.255.255.
    // A simple heuristic for directed broadcast is that the last octet is often 255.
    // However, this is not foolproof due to variable subnet masks.
    List<String> parts = addressString.split('.');
    if (parts.length == 4) {
      try {
        // For simplicity in this example, we'll accept any valid IPv4 address
        // that isn't clearly something else (like loopback).
        // More sophisticated subnet-based validation is complex without network interface info.
        if (internetAddress.isLoopback || internetAddress.isLinkLocal ||
            internetAddress.isMulticast) {
          // Typically not used as WoL broadcast destinations, though link-local might work in some ad-hoc scenarios.
          // For WoL, we generally want a subnet broadcast or the limited broadcast.
          return false; // Or handle as per your requirements
        }
        return true; // It's a valid IPv4 format, and not one of the typical non-broadcast types.
      } catch (e) {
        // Should not happen if InternetAddress.tryParse succeeded, but as a safeguard.
        return false;
      }
    }
    return false; // Should have 4 parts
  }

  static Uint8List parseMacAddress(String macAddress) {
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
