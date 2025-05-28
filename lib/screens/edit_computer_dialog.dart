import 'package:flutter/material.dart';
import '../models/computer.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

import '../services/network_service.dart';
import '../services/wol_service.dart';

class EditComputerDialog extends StatefulWidget {
  final Computer computerToEdit;

  const EditComputerDialog({super.key, required this.computerToEdit});

  @override
  State<EditComputerDialog> createState() => _EditComputerDialogState();
}

class _EditComputerDialogState extends State<EditComputerDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _macAddressController;
  late TextEditingController _broadcastAddressController;
  late TextEditingController _wanIPAddressController;
  late Color _selectedColor;
  final NetworkService _networkService = NetworkService();

  @override
  void initState() {
    super.initState();
    // Initialize controllers with existing computer data
    _nameController = TextEditingController(text: widget.computerToEdit.name);
    _macAddressController =
        TextEditingController(text: widget.computerToEdit.macAddress);
    _broadcastAddressController =
        TextEditingController(text: widget.computerToEdit.broadcastAddress);
    _selectedColor = widget.computerToEdit.color != null
        ? Color(widget.computerToEdit.color!)
        : Colors.white; // Default if no color was set
    _wanIPAddressController =
        TextEditingController(text: widget.computerToEdit.wanIpAddress);
  }

  @override
  void dispose() {
    // Dispose controllers when the widget is disposed
    _nameController.dispose();
    _macAddressController.dispose();
    _broadcastAddressController.dispose();
    _wanIPAddressController.dispose();
    super.dispose();
  }

  // Function to show color picker
  void _pickColor() {
    Color pickerColor = _selectedColor; // Temporary color for the picker dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pick a card color'),
        content: SingleChildScrollView(
          child: BlockPicker( // You can use MaterialPicker, ColorPicker as well
            pickerColor: pickerColor,
            onColorChanged: (color) {
              pickerColor = color; // Update the temporary color
            },
            // availableColors: [ ... ] // Optionally provide a list of predefined colors
          ),
        ),
        actions: <Widget>[
          TextButton(
            child: const Text('Cancel'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          TextButton(
            child: const Text('Select'),
            onPressed: () {
              setState(() {
                _selectedColor = pickerColor; // Apply the selected color
              });
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  void _saveComputer() {
    if (_formKey.currentState!.validate()) {
      // Create an updated Computer object
      final updatedComputer = Computer(
        name: _nameController.text,
        macAddress: _macAddressController.text,
        broadcastAddress: _broadcastAddressController.text,
        color: _selectedColor.toARGB32(),
        wanIpAddress: _wanIPAddressController.text,
      );
      // Return the updated computer object
      Navigator.of(context).pop(updatedComputer);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Computer'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
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
                decoration:
                const InputDecoration(labelText: 'Broadcast Address'),
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
                controller: _wanIPAddressController,
                decoration:
                const InputDecoration(labelText: 'WAN IP Address'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return null; // this is an optional parameter
                  } else {
                    if(_networkService.isValidPublicIpV4Format(value)) {
                      return null;
                    } else {
                      return 'Invalid WAN IP address format';
                    }
                  }
                },
              ),
              const SizedBox(height: 20),
              // Color Picker Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Card Color:'),
                  GestureDetector(
                    onTap: _pickColor,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                          color: _selectedColor,
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withValues(alpha: 0.3),
                              spreadRadius: 1,
                              blurRadius: 2,
                              offset: const Offset(0, 1),
                            )
                          ]
                      ),
                      // Optional: display a checkmark if color is dark for better visibility
                      child: _selectedColor.computeLuminance() < 0.5
                          ? const Icon(Icons.check, color: Colors.white, size: 20)
                          : null,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () {
            Navigator.of(context).pop(); // Close the dialog without saving
          },
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saveComputer,
          child: const Text('Save'),
        ),
      ],
    );
  }
}