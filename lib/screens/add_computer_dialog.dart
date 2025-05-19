import 'package:flutter/material.dart';
import '../models/computer.dart';

class AddComputerDialog extends StatefulWidget {
  const AddComputerDialog({super.key});

  @override
  State<AddComputerDialog> createState() => _AddComputerDialogState();
}

class _AddComputerDialogState extends State<AddComputerDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _macAddressController = TextEditingController();
  final _broadcastAddressController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _macAddressController.dispose();
    _broadcastAddressController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final newComputer = Computer(
        name: _nameController.text,
        macAddress: _macAddressController.text,
        broadcastAddress: _broadcastAddressController.text,
      );
      Navigator.of(context).pop(newComputer); // Return the new computer
    }
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
                  }
                  // You might want to add more robust MAC address validation
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
                  }
                  // You might want to add IP address validation
                  return null;
                },
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