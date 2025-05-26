import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/adapters.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';
import '../models/computer.dart';
import '../services/wol_service.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import 'add_computer_dialog.dart';
import 'edit_computer_dialog.dart';
import 'settings_screen.dart';

var logger = Logger(printer: PrettyPrinter());


class ComputerListScreen extends StatefulWidget {
  const ComputerListScreen({super.key});

  @override
  State<ComputerListScreen> createState() => _ComputerListScreenState();
}

class _ComputerListScreenState extends State<ComputerListScreen> {
  final WolService _wolService = WolService();
  late Box<Computer> _computerBox;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Get the computerBox from the Provider
    _computerBox = Provider.of<Box<Computer>>(context);
  }

  void _showAddComputerDialog() async {
    final newComputer = await showDialog<Computer>(
      context: context,
      builder: (context) => const AddComputerDialog(),
    );

    if (newComputer != null) {
      _addComputer(newComputer);
    } else {
      // Handle null computer case if needed
    }
  }

  Future<bool?> _showDeleteConfirmationDialog(
    BuildContext context,
    String computerName,
  ) async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false, // User must tap button!
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Confirm Deletion'),
          content: Text(
            'Are you sure you want to delete "$computerName"? This action cannot be undone.',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop(false); // Pop with 'false' indicating cancellation
              },
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              // Make delete button stand out
              child: const Text('Delete'),
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop(true); // Pop with 'true' indicating confirmation
              },
            ),
          ],
        );
      },
    );
  }

  void _showEditComputerDialog(Computer computerToEdit) async {
    final updatedComputer = await showDialog<Computer>(
      context: context,
      builder: (context) => EditComputerDialog(computerToEdit: computerToEdit),
    );

    if (updatedComputer != null) {
      _updateComputer(computerToEdit, updatedComputer);
    }
  }

  void _addComputer(Computer computer) {
    _computerBox.add(computer);
    // No need to manually refresh setState() if using ValueListenableBuilder
  }

  void _updateComputer(Computer oldComputer, Computer updatedComputer) {
    final key = _computerBox.keyAt(
      _computerBox.values.toList().indexOf(oldComputer),
    );
    if (key != null) {
      _computerBox.put(key, updatedComputer);
      // No need to manually refresh setState() if using ValueListenableBuilder
    }
  }

  void _deleteComputer(Computer computer) {
    final key = _computerBox.keyAt(
      _computerBox.values.toList().indexOf(computer),
    );
    if (key != null) {
      _computerBox.delete(key);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"${computer.name}" has been deleted.')),
      );
    }
  }

  void _wakeUpComputer(Computer computer) async {
    // Get the broadcast address from the settings box (you'll need to provide this as well)
    // For now, let's assume you have access to the settingsBox here
    // Or you could pass the broadcast address from the settings screen if preferred
    final settingsBox = Provider.of<Box<dynamic>>(
      context,
      listen: false,
    ); // Don't listen for changes here
    final defaultBroadcastAddress = settingsBox.get(
      'broadcastAddress',
      defaultValue: '192.168.1.255',
    );

    final broadcastAddressToSend =
        computer.broadcastAddress.isNotEmpty
            ? computer.broadcastAddress
            : defaultBroadcastAddress;

    // _wolService.sendMagicPacket(computer.macAddress, broadcastAddressToSend);
    // ScaffoldMessenger.of(context).showSnackBar(
    //   SnackBar(content: Text('Sending magic packet to ${computer.name}...')),
    // );
    try {
      await _wolService.sendMagicPacket(computer.macAddress, broadcastAddressToSend);
      // Optional: Show a success message if you want to differentiate
      // (though the initial message might be sufficient)
      if (mounted) { // Check if the widget is still in the tree
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Magic packet sent successfully to ${computer.name}!')),
        );
      }
    } catch (e) {
      // Handle the error: Show an error message to the user
      if (mounted) { // Check if the widget is still in the tree
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send magic packet to ${computer.name}: ${e.toString()}'),
            backgroundColor: Colors.red, // Make error SnackBar distinct
          ),
        );
      }
      // You might also want to log the error for debugging purposes
      logger.e('Error sending magic packet: $e');
    }
  }

  // Function to navigate to the settings screen
  void _navigateToSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Listen to the changes in the computerBox using ValueListenableBuilder
    return ValueListenableBuilder(
      valueListenable: _computerBox.listenable(), // Listen to the box's changes
      builder: (context, box, widget) {
        final computers =
            box.values
                .toList(); // Get the latest list of computers from the updated box

        return Scaffold(
          backgroundColor: Colors.indigo[200],
          appBar: AppBar(
            title: const Text('Awaken'),
            actions: [
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
                  ? const Center(child: Text('No computers added yet.'))
                  : ListView.builder(
                    itemCount: computers.length,
                    itemBuilder: (context, index) {
                      final computer = computers[index];
                      return Slidable(
                        key: ValueKey(computer.macAddress),
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
                                // slidableContext is the BuildContext from SlidableAction
                                final bool? confirmed =
                                    await _showDeleteConfirmationDialog(
                                      context,
                                      computer.name,
                                    ); // Use the main screen's context
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
                                      Colors.white, // Fallback
                          margin: const EdgeInsets.symmetric(
                            horizontal: 8.0,
                            vertical: 4.0,
                          ),
                          elevation: 2.0,
                          child: ListTile(
                            // 1. Add the icon to the far left
                            leading: Icon(
                              Icons.computer, // Or any other icon you prefer
                              size: 36.0, // Adjust size as needed
                              color:
                                  computer.color != null &&
                                          ThemeData.estimateBrightnessForColor(
                                                Color(computer.color!),
                                              ) ==
                                              Brightness.dark
                                      ? Colors.white
                                      : Theme.of(context).colorScheme.primary,
                            ),
                            // 2. Make the computer name more prominent
                            title: Text(
                              computer.name,
                              style: TextStyle(
                                fontSize: 18.0, // Increase font size
                                fontWeight: FontWeight.bold, // Make it bold
                                // Adjust text color for visibility
                                color:
                                    computer.color != null &&
                                            ThemeData.estimateBrightnessForColor(
                                                  Color(computer.color!),
                                                ) ==
                                                Brightness.dark
                                        ? Colors.white
                                        : Colors.black87, // Or theme default
                              ),
                            ),
                            // 3. Make the MAC address less prominent
                            subtitle: Text(
                              computer.macAddress,
                              style: TextStyle(
                                fontSize: 13.0, // Smaller font size
                                // Adjust subtitle color for visibility
                                color:
                                    computer.color != null &&
                                            ThemeData.estimateBrightnessForColor(
                                                  Color(computer.color!),
                                                ) ==
                                                Brightness.dark
                                        ? Colors.white70
                                        : Colors.grey[600],
                              ),
                            ),
                            onTap: () => _wakeUpComputer(computer),
                            // Optional: Add some padding if needed
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 8.0,
                              horizontal: 16.0,
                            ),
                          ),
                        ),
                      );
                    },
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
