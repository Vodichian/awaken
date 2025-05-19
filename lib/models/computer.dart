import 'package:hive_ce/hive.dart';

class Computer extends HiveObject {
  String name;
  String macAddress;
  String broadcastAddress; // Or specific IP if not broadcasting

  Computer({
    required this.name,
    required this.macAddress,
    required this.broadcastAddress,
  });

  @override
  String toString() {
    return '$name: , MAC = $macAddress, broadcastAddress = $broadcastAddress';
  }
}
