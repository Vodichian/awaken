import 'package:flutter/material.dart';
import '../models/computer.dart';

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

  @override
  void initState() {
    super.initState();
    // Initialize controllers with existing computer data
    _nameController = TextEditingController(text: widget.computerToEdit.name);
    _macAddressController =
        TextEditingController(text: widget.computerToEdit.macAddress);
    _broadcastAddressController =
        TextEditingController(text: widget.computerToEdit.broadcastAddress);
  }

  @override
  void dispose() {
    // Dispose controllers when the widget is disposed
    _nameController.dispose();
    _macAddressController.dispose();
    _broadcastAddressController.dispose();
    super.dispose();
  }

  void _saveComputer() {
    if (_formKey.currentState!.validate()) {
      // Create an updated Computer object
      final updatedComputer = Computer(
        name: _nameController.text,
        macAddress: _macAddressController.text,
        broadcastAddress: _broadcastAddressController.text,
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
                  }
                  // Add more specific MAC address validation if needed
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
                  }
                  // Add more specific IP address validation if needed
                  return null;
                },
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