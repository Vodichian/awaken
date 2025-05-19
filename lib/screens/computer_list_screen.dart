import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/adapters.dart';
import 'package:provider/provider.dart';
import '../models/computer.dart';
import '../services/wol_service.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import 'add_computer_dialog.dart';
import 'edit_computer_dialog.dart';
import 'settings_screen.dart';

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
      // No need to manually refresh setState() if using ValueListenableBuilder
    }
  }

  void _wakeUpComputer(Computer computer) {
    // Get the broadcast address from the settings box (you'll need to provide this as well)
    // For now, let's assume you have access to the settingsBox here
    // Or you could pass the broadcast address from the settings screen if preferred
    final settingsBox = Provider.of<Box<dynamic>>(
      context,
      listen: false,
    ); // Don't listen for changes here
    final defaultBroadcastAddress = settingsBox.get(
      'broadcastAddress',
      defaultValue: '255.255.255.255',
    );

    final broadcastAddressToSend =
        computer.broadcastAddress.isNotEmpty
            ? computer.broadcastAddress
            : defaultBroadcastAddress;

    _wolService.sendMagicPacket(computer.macAddress, broadcastAddressToSend);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Sending magic packet to ${computer.name}...')),
    );
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
          appBar: AppBar(
            title: const Text('Wakeup'),
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
                              onPressed: (context) {
                                _deleteComputer(computer);
                              },
                              backgroundColor: const Color(0xFFFE4A49),
                              foregroundColor: Colors.white,
                              icon: Icons.delete,
                              label: 'Delete',
                            ),
                          ],
                        ),
                        child: Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 8.0,
                            vertical: 4.0,
                          ),
                          elevation: 2.0,
                          child: ListTile(
                            title: Text(computer.name),
                            subtitle: Text(computer.macAddress),
                            onTap: () => _wakeUpComputer(computer),
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
