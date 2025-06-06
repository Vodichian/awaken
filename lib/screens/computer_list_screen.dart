import 'dart:io'; // For Platform
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For SystemNavigator
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:provider/provider.dart';
import '../models/computer.dart'; // Your Computer model
import '../services/network_service.dart'; // Import NetworkService
import '../services/wol_service.dart'; // Your WoL service
import '../utils/globals.dart'; // Assuming your global logger instance
import '../widgets/led_indicator.dart';
import 'computer_form_dialog.dart'; // Your dialog
import 'settings_screen.dart'; // Your settings screen
import 'package:hive_ce_flutter/adapters.dart';
import 'package:vpn_connection_detector/vpn_connection_detector.dart';

class ComputerListScreen extends StatefulWidget {
  const ComputerListScreen({super.key});

  @override
  State<ComputerListScreen> createState() => _ComputerListScreenState();
}

class _ComputerListScreenState extends State<ComputerListScreen> {
  late final Box<Computer> _computerBox;
  final WolService _wolService = WolService();
  final NetworkService _networkService =
      NetworkService(); // Instance of NetworkService
  String? _currentWanIP; // To store the fetched WAN IP
  bool _isFetchingFingerprint = false;
  bool _isVPNConnected = false;

  @override
  void initState() {
    super.initState();
    _computerBox = Hive.box<Computer>('computerBox');
    _fetchFingerprint(); // Fetch WAN IP when the screen initializes
  }

  /// Fingerprint the current LAN. This consists of identifying the WAN IP and
  /// checking if a VPN connection is active.
  Future<void> _fetchFingerprint() async {
    if (_isFetchingFingerprint) return; // Prevent multiple simultaneous fetches
    setState(() {
      _isFetchingFingerprint = true;
    });
    // Fetch the current WAN IP
    try {
      _currentWanIP = await _networkService.getPublicIpAddress();
      logger.i("Current WAN IP fetched: $_currentWanIP");
    } catch (e) {
      logger.e("Failed to fetch WAN IP: $e");
      // Optionally show a snackbar or message to the user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not fetch current WAN IP: ${e.toString()}'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isFetchingFingerprint = false;
        });
      }
    }
    // Check if a VPN connection is active
    try {
      _isVPNConnected = await VpnConnectionDetector.isVpnActive();
      logger.d('VPN connection: $_isVPNConnected');
    } catch (e) {
      logger.e("Failed to fetch VPN status: $e");
      // Optionally show a snackbar or message to the user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not fetch VPN status: ${e.toString()}'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isFetchingFingerprint = false;
        });
      }
    }
  }

  void _showAddComputerDialog() async {
    final result = await showDialog<Computer>(
      context: context,
      builder:
          (_) => ComputerFormDialog(
            // Pass the current WAN IP as a suggestion for new computers
            initialWanIP: _currentWanIP,
          ),
    );
    if (result != null) {
      _computerBox.add(result);
    }
  }

  void _showEditComputerDialog(Computer computer) async {
    final originalKey = computer.key;
    final result = await showDialog<Computer>(
      context: context,
      builder:
          (_) => ComputerFormDialog(
            computer: computer,
            // Pass current WAN IP, it might have changed or user wants to update
            initialWanIP: _currentWanIP ?? computer.wanIpAddress,
          ),
    );
    if (result != null) {
      _computerBox.put(originalKey, result);
    }
  }

  Future<bool?> _showDeleteConfirmationDialog(
    BuildContext dialogContext,
    String computerName,
  ) async {
    return showDialog<bool>(
      context: dialogContext,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Delete'),
          content: Text('Are you sure you want to delete "$computerName"?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
            ),
            TextButton(
              child: const Text('Delete'),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
            ),
          ],
        );
      },
    );
  }

  void _deleteComputer(Computer computer) {
    computer.delete(); // HiveObject extension method
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${computer.name} deleted.'),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  Future<bool> _wakeUpComputer(
    Computer computer, {
    bool showSuccessSnackbar = true,
  }) async {
    logger.d(
      'Attempting to wake up ${computer.name} (MAC: ${computer.macAddress}, Broadcast: ${computer.broadcastAddress})',
    );

    final settingsBox = Provider.of<Box<dynamic>>(context, listen: false);
    final defaultBroadcastAddress = settingsBox.get(
      'broadcastAddress',
      defaultValue: '192.168.1.255', // Make sure this default is appropriate
    );

    final broadcastAddressToSend =
        computer.broadcastAddress.isNotEmpty
            ? computer.broadcastAddress
            : defaultBroadcastAddress;

    try {
      await _wolService.sendMagicPacket(
        computer.macAddress,
        broadcastAddressToSend,
      );

      if (showSuccessSnackbar && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Magic packet sent to ${computer.name}!'),
            backgroundColor: Colors.green,
          ),
        );
      }
      return true; // Indicate success
    } catch (e) {
      logger.e('Failed to send magic packet: ${e.toString()}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to send magic packet to ${computer.name}: ${e.toString()}',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false; // Indicate failure
    }
  }

  void _navigateToSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    ).then((_) {
      // Re-fetch WAN IP if settings might have changed related things,
      // or if user explicitly triggers a refresh there.
      _fetchFingerprint();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: _computerBox.listenable(),
      builder: (context, Box<Computer> box, _) {
        final computers = box.values.toList();

        return Scaffold(
          backgroundColor: Colors.indigo[200],
          appBar: AppBar(
            title: const Text('Awaken'),
            actions: [
              // Add a refresh button for WAN IP
              if (_isFetchingFingerprint)
                const Padding(
                  padding: EdgeInsets.only(right: 8.0),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.0,
                      ),
                    ),
                  ),
                )
              else
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: "Refresh WAN IP",
                  onPressed: _fetchFingerprint,
                ),
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: IconButton(
                  icon: const Icon(Icons.settings),
                  onPressed: _navigateToSettings,
                ),
              ),
            ],
          ),
          body:
              computers.isEmpty
                  ? const Center(
                    child: Text(
                      'No computers added yet. Pull down to refresh WAN IP.',
                    ),
                  )
                  : RefreshIndicator(
                    // Optional: Allow pull-to-refresh for WAN IP
                    onRefresh: _fetchFingerprint,
                    child: ListView.builder(
                      itemCount: computers.length,
                      itemBuilder: (context, index) {
                        final computer = computers[index];

                        // --- LED Logic ---
                        Color led1Color =
                            Colors.grey; // Default to grey (unknown/mismatch)
                        String led1Text = "WAN?";
                        bool isWanMatch = false;

                        Color led2Color =
                            Colors.grey; // Default to grey (unknown/mismatch)
                        String led2Text = "VPN";
                        bool isVPNDetected = false;

                        if (_currentWanIP != null &&
                            _currentWanIP!.isNotEmpty &&
                            computer.wanIpAddress != null &&
                            computer.wanIpAddress!.isNotEmpty) {
                          if (_currentWanIP == computer.wanIpAddress) {
                            led1Color = Colors.green;
                            led1Text = "WAN OK";
                            isWanMatch = true;
                          } else {
                            led1Color =
                                Colors.orange; // Or Colors.red if you prefer
                            led1Text = "WAN Fail";
                          }
                        } else if (_isFetchingFingerprint) {
                          led1Color = Colors.blueGrey;
                          led1Text = "WAN...";
                        } else if (_currentWanIP == null &&
                            computer.wanIpAddress != null &&
                            computer.wanIpAddress!.isNotEmpty) {
                          led1Color = Colors.yellow.shade700;
                          led1Text = "No Net"; // Can't fetch current WAN
                        }

                        if (_isVPNConnected) {
                          led2Color = Colors.red;
                          led2Text = "VPN Detected";
                          isVPNDetected = true;
                        } else if (_isFetchingFingerprint) {
                          led2Color = Colors.blueGrey;
                        }

                        final bool isDarkBackground =
                            computer.color != null &&
                            ThemeData.estimateBrightnessForColor(
                                  Color(computer.color!),
                                ) ==
                                Brightness.dark;
                        final Color textColor =
                            isDarkBackground ? Colors.white : Colors.black87;
                        final Color iconColor =
                            isDarkBackground
                                ? Colors.white
                                : Theme.of(context).colorScheme.primary;

                        return Slidable(
                          key: ValueKey(computer.macAddress),
                          // Or computer.key for Hive objects
                          endActionPane: ActionPane(
                            motion: const ScrollMotion(),
                            extentRatio: 0.5,
                            children: [
                              SlidableAction(
                                onPressed: (context) {
                                  _showEditComputerDialog(computer);
                                },
                                backgroundColor: const Color(0xFF21B7CA),
                                foregroundColor: Colors.white,
                                icon: Icons.edit,
                                label: 'Edit',
                              ),
                              SlidableAction(
                                onPressed: (slidableContext) async {
                                  final bool? confirmed =
                                      await _showDeleteConfirmationDialog(
                                        context,
                                        computer.name,
                                      );
                                  if (confirmed == true) {
                                    _deleteComputer(computer);
                                  }
                                },
                                backgroundColor: const Color(0xFFFE4A49),
                                foregroundColor: Colors.white,
                                icon: Icons.delete,
                                label: 'Delete',
                              ),
                            ],
                          ),
                          child: Card(
                            color:
                                computer.color != null
                                    ? Color(computer.color!)
                                    : Theme.of(context).cardTheme.color ??
                                        Colors.white,
                            margin: const EdgeInsets.symmetric(
                              horizontal: 8.0,
                              vertical: 4.0,
                            ),
                            elevation: 2.0,
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              enableFeedback: true,
                              onTap: () {
                                // Only allow WoL if VPN is disabled and (WAN IP matches, or if no WAN IP is set for the computer
                                // (LAN only))
                                if (!isVPNDetected &&
                                    (isWanMatch ||
                                        computer.wanIpAddress == null ||
                                        computer.wanIpAddress!.isEmpty)) {
                                  _wakeUpComputer(computer);
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'WAN IP mismatch or VPN detected for ${computer.name}. WoL packet not sent.',
                                      ),
                                      backgroundColor: Colors.orange,
                                    ),
                                  );
                                }
                              },
                              onLongPress: () async {
                                logger.d(
                                  'Long press detected on ${computer.name}',
                                );
                                if (!isVPNDetected &&
                                    ((isWanMatch ||
                                        computer.wanIpAddress == null ||
                                        computer.wanIpAddress!.isEmpty))) {
                                  bool success = await _wakeUpComputer(
                                    computer,
                                    showSuccessSnackbar: false,
                                  );
                                  if (success) {
                                    logger.d(
                                      'WoL packet sent successfully on long press. Closing app.',
                                    );
                                    if (Platform.isAndroid || Platform.isIOS) {
                                      SystemNavigator.pop();
                                    } else {
                                      logger.w(
                                        'App closing not implemented for this platform via long press.',
                                      );
                                    }
                                  } else {
                                    logger.d(
                                      'WoL packet failed to send on long press. App will not close.',
                                    );
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Failed to send WoL packet. App not closing.',
                                          ),
                                          backgroundColor: Colors.orange,
                                        ),
                                      );
                                    }
                                  }
                                } else {
                                  logger.d(
                                    'WAN IP mismatch on long press. App will not close.',
                                  );
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'WAN IP mismatch for ${computer.name}. App not closing.',
                                        ),
                                        backgroundColor: Colors.orange,
                                      ),
                                    );
                                  }
                                }
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8.0,
                                  horizontal: 12.0,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.computer,
                                      size: 36.0,
                                      color: iconColor,
                                    ),
                                    const SizedBox(width: 12.0),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            computer.name,
                                            style: TextStyle(
                                              fontSize: 18.0,
                                              fontWeight: FontWeight.bold,
                                              color: textColor,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          // Display the stored WAN IP for reference
                                          if (computer.wanIpAddress != null &&
                                              computer.wanIpAddress!.isNotEmpty)
                                            Text(
                                              "Target WAN: ${computer.wanIpAddress}",
                                              style: TextStyle(
                                                fontSize: 10.0,
                                                color: textColor.withValues(
                                                  alpha: 0.7,
                                                ),
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          const SizedBox(height: 6.0),
                                          Row(
                                            children: [
                                              LedIndicator(
                                                color: led1Color,
                                                isGlowing: isWanMatch,
                                                text: led1Text,
                                              ),
                                              LedIndicator(
                                                color: led2Color,
                                                isGlowing: isVPNDetected,
                                                text: led2Text,
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Add a trailing icon to indicate if WoL is enabled based on WAN match
                                    if (computer.wanIpAddress != null &&
                                        computer.wanIpAddress!.isNotEmpty)
                                      Icon(
                                        isWanMatch && !isVPNDetected
                                            ? Icons.power_settings_new
                                            : Icons.public_off,
                                        color:
                                            isWanMatch && !isVPNDetected
                                                ? Colors.green.shade700
                                                : Colors.red.shade700,
                                        size: 20,
                                      )
                                    else if (isVPNDetected)
                                      Icon(
                                        Icons.public_off,
                                        color: Colors.red.shade700,
                                        size: 20,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          floatingActionButton: FloatingActionButton(
            onPressed: _showAddComputerDialog,
            tooltip: 'Add Computer',
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }
}
