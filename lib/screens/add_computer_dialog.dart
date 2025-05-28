import 'package:awaken/services/wol_service.dart';
import 'package:flutter/material.dart';
import '../models/computer.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

import '../services/network_service.dart';

class AddComputerDialog extends StatefulWidget {
  const AddComputerDialog({super.key});

  @override
  State<AddComputerDialog> createState() => _AddComputerDialogState();
}

class _AddComputerDialogState extends State<AddComputerDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _macAddressController = TextEditingController();
  final _wanIpAddressController = TextEditingController();
  final _notesController = TextEditingController();
  Color _selectedColor = Colors.white; // Default color is white
  final NetworkService _networkService = NetworkService();

  // Declare the controller
  late TextEditingController _broadcastAddressController;
  static const String _defaultBroadcastAddress = '255.255.255.255';

  // Function to show color picker
  void _pickColor() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pick a color!'),
        content: SingleChildScrollView(
          child: BlockPicker( // Or MaterialPicker, ColorPicker, etc.
            pickerColor: _selectedColor,
            onColorChanged: (color) {
              setState(() => _selectedColor = color);
            },
          ),
        ),
        actions: <Widget>[
          TextButton(
            child: const Text('Got it'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _macAddressController.dispose();
    _broadcastAddressController.dispose();
    _wanIpAddressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final newComputer = Computer(
        name: _nameController.text,
        macAddress: _macAddressController.text,
        broadcastAddress: _broadcastAddressController.text,
        color: _selectedColor.toARGB32(),
        wanIpAddress: _wanIpAddressController.text,
        notes: _notesController.text,
      );
      Navigator.of(context).pop(newComputer); // Return the new computer
    }
  }

  @override
  void initState() {
    super.initState();
    // Initialize the controller with the default text
    _broadcastAddressController = TextEditingController(text: _defaultBroadcastAddress);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add New Computer'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView( // Use SingleChildScrollView for smaller screens
          child: Column(
            mainAxisSize: MainAxisSize.min, // Make column take minimum space
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Computer Name'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a name';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _macAddressController,
                decoration: const InputDecoration(labelText: 'MAC Address'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a MAC address';
                  } else {
                    try {
                      WolService.parseMacAddress(value);
                    } catch (e) {
                      return 'Invalid MAC address format';
                    }
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _broadcastAddressController,
                decoration: const InputDecoration(
                    labelText: 'Broadcast Address'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a broadcast address';
                  } else {
                    if (!WolService.isValidBroadcastAddress(value)) {
                      return 'Invalid broadcast address format';
                    }
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _wanIpAddressController,
                decoration: const InputDecoration(
                    labelText: 'WAN IP Address'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return null; // this is an optional parameter
                  } else {
                    if(_networkService.isValidPublicIpV4Format(value)) {
                      return null;
                    } else {
                      return 'Invalid WAN IP address format';
                    }
                  }                },
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Text('Card Color:'),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: _pickColor,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: _selectedColor,
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(), // Close dialog
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: const Text('Add'),
        ),
      ],
    );
  }
}