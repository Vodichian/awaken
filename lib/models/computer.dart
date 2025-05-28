import 'package:hive_ce/hive.dart';

class Computer extends HiveObject {
  String name;
  String macAddress;
  String broadcastAddress; // Or specific IP if not broadcasting
  int? color;
  String? wanIpAddress; // used to fingerprint LAN
  String? notes;

  Computer({
    required this.name,
    required this.macAddress,
    required this.broadcastAddress,
    required this.color,
    required this.wanIpAddress,
    required this.notes,
  });

  @override
  String toString() {
    return '$name: , MAC = $macAddress, broadcastAddress = $broadcastAddress, color = $color, '
        'wanIpAddress = $wanIpAddress, notes = $notes';
  }
}
