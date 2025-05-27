import 'dart:async';
import 'dart:io'; // For InternetAddress, NetworkInterface
import 'package:http/http.dart' as http;
import 'package:network_info_plus/network_info_plus.dart';

import '../utils/globals.dart'; // For local IP


class NetworkService {
  // --- Public IP Address Utilities ---

  /// Validates if the given string is a valid public IPv4 address format.
  /// Note: This checks format only, not if the IP is actually routable or truly public.
  /// It primarily excludes private IP ranges.
  bool isValidPublicIpV4Format(String ipAddress) {
    if (ipAddress.isEmpty) return false;

    // Regular expression for IPv4 format
    final ipv4Regex = RegExp(
        r'^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$');
    if (!ipv4Regex.hasMatch(ipAddress)) {
      return false;
    }

    // Exclude common private IP ranges
    // Note: This is not exhaustive for all special use IPs but covers common cases.
    List<String> parts = ipAddress.split('.');
    if (parts.length != 4) {
      return false; // Should be caught by regex, but good practice
    }

    int firstOctet = int.tryParse(parts[0]) ?? -1;
    int secondOctet = int.tryParse(parts[1]) ?? -1;

    // Class A private: 10.0.0.0 to 10.255.255.255
    if (firstOctet == 10) return false;

    // Class B private: 172.16.0.0 to 172.31.255.255
    if (firstOctet == 172 && (secondOctet >= 16 && secondOctet <= 31)) {
      return false;
    }

    // Class C private: 192.168.0.0 to 192.168.255.255
    if (firstOctet == 192 && secondOctet == 168) return false;

    // Loopback: 127.0.0.0 to 127.255.255.255
    if (firstOctet == 127) return false;

    // Link-local: 169.254.0.0 to 169.254.255.255
    if (firstOctet == 169 && secondOctet == 254) return false;

    // Add more exclusions if needed (e.g., multicast, reserved)

    return true;
  }

  /// Retrieves the public IP address of the device.
  /// Uses a third-party service (ipify.org by default).
  ///
  /// Returns the public IP as a String, or null if an error occurs or no IP is found.
  Future<String?> getPublicIpAddress({String? apiServiceUrl}) async {
    final List<String> defaultApiUrls = [
      'https://api.ipify.org',
      'https://api.seeip.org',
      'https://icanhazip.com',
      'https://ipinfo.io/ip',
    ];

    List<String> urlsToTry = apiServiceUrl != null
        ? [apiServiceUrl]
        : defaultApiUrls;

    for (String url in urlsToTry) {
      try {
        final response = await http.get(Uri.parse(url)).timeout(
            const Duration(seconds: 5));
        if (response.statusCode == 200) {
          // Trim whitespace as some services might return a newline
          final ip = response.body.trim();
          // Optional: Validate the format of the retrieved IP
          if (RegExp(r'^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$').hasMatch(ip)) {
            return ip;
          } else {
            logger.d('NetworkService: Received invalid IP format from $url: $ip');
          }
        } else {
          logger.d(
              'NetworkService: Failed to get public IP from $url - Status: ${response
                  .statusCode}');
        }
      } catch (e) {
        logger.e('NetworkService: Error getting public IP from $url: $e');
        // Continue to try the next URL
      }
    }
    logger.d('NetworkService: All attempts to get public IP failed.');
    return null; // Return null if all services fail
  }

  // --- Local IP Address Utilities ---

  /// Retrieves the local (LAN) IPv4 address of the device.
  /// Can prioritize Wi-Fi or Ethernet based on availability or preference.
  ///
  /// Returns the local IPv4 address as a String, or null if not found or an error occurs.
  Future<String?> getLocalIpAddress() async {
    // Using network_info_plus for a common scenario (Wi-Fi IP)
    try {
      final networkInfo = NetworkInfo();
      String? wifiIP = await networkInfo.getWifiIP(); // Gets IPv4 for Wi-Fi
      if (wifiIP != null && _isValidIpV4(wifiIP)) {
        return wifiIP;
      }
    } catch (e) {
      logger.e(
          'NetworkService: Error getting Wi-Fi IP using network_info_plus: $e');
    }

    // Fallback or alternative: Iterate through network interfaces
    // This is more comprehensive and can find IPs on Ethernet, etc.
    try {
      for (var interface in await NetworkInterface.list(
          includeLoopback: false, type: InternetAddressType.IPv4)) {
        // `interface.addresses` can contain multiple addresses (e.g., IPv6)
        for (var addr in interface.addresses) {
          // Check if it's an IPv4 address and not a loopback or link-local
          // The `type: InternetAddressType.IPv4` above should already filter.
          if (addr.type == InternetAddressType.IPv4 &&
              !addr.isLoopback &&
              !addr.isLinkLocal) {
            // Prioritize non-link-local.
            // You might add further checks here if you have multiple valid IPs
            // e.g., prefer IPs from interfaces named 'eth0', 'wlan0', 'en0'
            logger.d('NetworkService: Found local IP on interface ${interface
                .name}: ${addr.address}');
            return addr.address;
          }
        }
      }
    } catch (e) {
      logger.e('NetworkService: Error iterating network interfaces: $e');
    }

    logger.d('NetworkService: Could not determine local IP address.');
    return null;
  }

  /// Helper to validate if a string is a valid IPv4 format (any, not just public).
  bool _isValidIpV4(String ipAddress) {
    if (ipAddress.isEmpty) return false;
    final ipv4Regex = RegExp(
        r'^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$');
    return ipv4Regex.hasMatch(ipAddress);
  }
}