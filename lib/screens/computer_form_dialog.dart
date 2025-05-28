// In computer_form_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../models/computer.dart'; // Your model
// Optional: If you use a color picker
// import 'package:flutter_colorpicker/flutter_colorpicker.dart';

class ComputerFormDialog extends StatefulWidget {
  final Computer? computer;
  final String? initialWanIP; // To prefill WAN IP if available

  const ComputerFormDialog({super.key, this.computer, this.initialWanIP});

  @override
  State<ComputerFormDialog> createState() => _ComputerFormDialogState();
}

class _ComputerFormDialogState extends State<ComputerFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _macController;
  late TextEditingController _broadcastController;
  late TextEditingController _wanIPController; // Controller for WAN IP
  late TextEditingController _notesController;
  late Color _selectedColor;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.computer?.name ?? '');
    _macController =
        TextEditingController(text: widget.computer?.macAddress ?? '');
    _broadcastController = TextEditingController(
        text: widget.computer?.broadcastAddress ?? '255.255.255.255');
    // Use initialWanIP if provided (e.g., from current network), otherwise use computer's stored WAN IP
    _wanIPController = TextEditingController(
        text: widget.computer?.wanIpAddress ?? widget.initialWanIP ?? '');
    _notesController =
        TextEditingController(text: '');
    // _notesController =
    //     TextEditingController(text: widget.computer?.notes ?? '');
    _selectedColor = widget.computer?.color != null
        ? Color(widget.computer!.color!)
        : Colors.white; // Default if no color was set
  }

  // ... (dispose methods should also dispose _wanIPController)
  @override
  void dispose() {
    _nameController.dispose();
    _macController.dispose();
    _broadcastController.dispose();
    _wanIPController.dispose(); // Dispose WAN IP controller
    _notesController.dispose();
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


  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.computer == null ? 'Add Computer' : 'Edit Computer'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                    labelText: 'Name', icon: Icon(Icons.label)),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a name';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _macController,
                decoration: const InputDecoration(labelText: 'MAC Address',
                    hintText: "00:1A:2B:3C:4D:5E",
                    icon: Icon(Icons.network_wifi)),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a MAC address';
                  }
                  // Basic MAC address format validation (can be improved)
                  final macRegex = RegExp(
                      r'^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$');
                  if (!macRegex.hasMatch(value)) {
                    return 'Invalid MAC address format';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _wanIPController, // WAN IP Text Field
                decoration: InputDecoration(
                  labelText: 'Target Public WAN IP (Optional)',
                  hintText: "e.g., 8.8.8.8",
                  icon: const Icon(Icons.public),
                  // Optionally add a button to fill with current WAN IP
                  // suffixIcon: IconButton(
                  //   icon: Icon(Icons.my_location),
                  //   tooltip: "Use current WAN IP",
                  //   onPressed: () {
                  //     if (widget.initialWanIP != null) {
                  //       _wanIPController.text = widget.initialWanIP!;
                  //     }
                  //   },
                  // ),
                ),
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    // Use your NetworkService validator if you want to be strict about "public" format
                    // final networkService = NetworkService();
                    // if (!networkService.isValidPublicIpV4Format(value)) {
                    //   return 'Invalid or private IP format';
                    // }
                    final ipRegex = RegExp(
                        r'^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$');
                    if (!ipRegex.hasMatch(value)) {
                      return 'Invalid IP address format';
                    }
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _broadcastController,
                decoration: const InputDecoration(
                    labelText: 'Broadcast Address (Optional)',
                    hintText: "192.168.1.255",
                    icon: Icon(Icons.settings_ethernet)),
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    final ipRegex = RegExp(
                        r'^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$');
                    if (!ipRegex.hasMatch(value)) {
                      return 'Invalid IP address format';
                    }
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                    labelText: 'Notes (Optional)', icon: Icon(Icons.notes)),
                maxLines: 2,
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
          child: const Text('Cancel'),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        ElevatedButton(
          child: Text(widget.computer == null ? 'Add' : 'Save'),
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final newComputer = Computer(
                name: _nameController.text,
                macAddress: _macController.text.toUpperCase(),
                broadcastAddress: _broadcastController.text.isNotEmpty
                    ? _broadcastController.text
                    : '255.255.255.255',
                wanIpAddress: _wanIPController.text.isNotEmpty
                    ? _wanIPController.text
                    : null,
                // Save WAN IP
                // notes: _notesController.text.isNotEmpty
                //     ? _notesController.text
                //     : null,
                color: _selectedColor.toARGB32(),
              );
              // If editing, preserve original Hive key by passing back the modified object
              // The list screen will use computer.key to put it back
              Navigator.of(context).pop(newComputer);
            }
          },
        ),
      ],
    );
  }
}