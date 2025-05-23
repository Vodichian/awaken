import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:logger/logger.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:hive_ce/hive.dart';
import 'package:file_picker/file_picker.dart'; // Import file_picker
import 'dart:io'; // Import dart:io for File
import 'dart:convert'; // Import for JSON handling (if using JSON)

import '../models/computer.dart'; // Import your Computer model

var logger = Logger(printer: PrettyPrinter());

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _broadcastAddressController;
  late Box<dynamic> _settingsBox;
  late Box<Computer> _computerBox; // Get the computer box as well

  @override
  void initState() {
    super.initState();
    // Note: We don't initialize boxes here anymore.
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Get the boxes from the Provider
    _settingsBox = Provider.of<Box<dynamic>>(context);
    _computerBox = Provider.of<Box<Computer>>(context); // Get the computer box

    // Now that the box is available, get the current broadcast address
    final currentBroadcastAddress =
    _settingsBox.get('broadcastAddress', defaultValue: '255.255.255.255');
    _broadcastAddressController =
        TextEditingController(text: currentBroadcastAddress);
  }

  @override
  void dispose() {
    _broadcastAddressController.dispose();
    super.dispose();
  }

  void _saveSettings() {
    if (_formKey.currentState!.validate()) {
      // Save the broadcast address to the settings box
      _settingsBox.put('broadcastAddress', _broadcastAddressController.text);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved!')),
      );
    }
  }

  // --- Import/Export Functions ---

  Future<void> _importComputers() async {
    //TODO: Warn user that this will overwrite existing data
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'], // Or your preferred file extension
      );

      if (result != null && result.files.single.path != null) {
        File file = File(result.files.single.path!);
        String fileContent = await file.readAsString();

        // Deserialize fileContent and import into Hive
        _importDataFromContent(fileContent);

        if (!mounted) {
          logger.d('_exportComputers: Widget not mounted after checking initial status.');
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Computers imported successfully!')),
        );
      } else {
        // User canceled the picker
      }
    } catch (e) {
      logger.e(e);
      if (!mounted) {
        logger.d('_exportComputers: Widget not mounted after checking initial status.');
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error importing computers: ${e.toString()}')),
      );
    }
  }

  void _importDataFromContent(String fileContent) {
    // Example for JSON:
    List<dynamic> jsonData = jsonDecode(fileContent);

    // Clear existing data before importing (optional, depends on desired behavior)
    // _computerBox.clear();
    var keys = _computerBox.keys.toList();
    for (var key in keys) {
      _computerBox.delete(key);
    }
    assert (_computerBox.values.isEmpty);

    for (var item in jsonData) {
      // Assuming your JSON structure matches Computer properties
      // Add error handling if JSON structure might be invalid
      try {
        final computer = Computer(
          name: item['name'],
          macAddress: item['macAddress'],
          broadcastAddress: item['broadcastAddress'] ??
              '', // Handle missing broadcastAddress
          color: item['color'] ?? Colors.white.toARGB32(), // Handle missing color
        );
        _computerBox.add(computer); // Add to Hive
      } catch (e) {
        logger.e('Error importing computer from JSON: $item, Error: $e');
        // Optionally show a user-friendly error message
      }
    }
  }

  Future<void> _exportComputers() async {
    logger.d('Checking storage permission status...');
    var status = await Permission.manageExternalStorage.status;
    logger.d('Initial status: $status');

    if (status.isGranted) {
      logger.d('Permission already granted.');
      // Proceed with file saving
      _performExport();
    } else if (status.isDenied) {
      logger.d('Permission denied. Requesting permission...');
      status = await Permission.manageExternalStorage.request();
      logger.d('Status after request: $status');

      if (!mounted) {
        logger.d('_exportComputers: Widget not mounted after checking initial status.');
        return;
      }

      if (status.isGranted) {
        logger.d('Permission granted after request.');
        _performExport();
      } else if (status.isPermanentlyDenied) {
        logger.d('Permission permanently denied. Guiding user to settings.');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Storage permission permanently denied. Please enable it in app settings.')),
        );
        openAppSettings();
      } else {
        logger.d('Permission denied after request.');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Storage permission not granted.')),
        );
      }
    } else if (status.isPermanentlyDenied) {
      logger.d('Permission permanently denied. Guiding user to settings.');
      if (!mounted) {
        logger.d('_exportComputers: Widget not mounted after checking initial status.');
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Storage permission permanently denied. Please enable it in app settings.')),
      );
      openAppSettings();
    } else {
      logger.d('Unknown permission status: $status');
    }
  }

  Future<void> _performExport() async {
    try {
      logger.d('_performExport: Starting file save process.');

      // Get the data to export and encode it to bytes
      String dataToExport = await _exportDataToJson();
      Uint8List bytesToExport = Uint8List.fromList(utf8.encode(dataToExport));

      logger.d('_performExport: Data encoded to bytes.');

      logger.d('_performExport: Attempting to open file picker...');
      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Computers Data',
        fileName: 'computers_data.json',
        allowedExtensions: ['json'],
        bytes: bytesToExport, // Pass the bytes here
      );
      logger.d('_performExport: FilePicker.platform.saveFile completed.');

      if (!mounted) {
        logger.d('_performExport: Widget not mounted after checking initial status.');
        return;
      }

      if (outputFile != null) {
        logger.d('_performExport: File saved to: $outputFile');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Computers exported successfully!')),
        );
      } else {
        logger.d('_performExport: File save dialog canceled.');
        // User canceled the save dialog
      }
    } catch (e) {
      logger.e('_performExport: An error occurred', error: e); // logger.e takes error object as second argument
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error exporting computers: ${e.toString()}')),
      );
    }
  }
  Future<String> _exportDataToJson() async {
    List<Computer> computers = _computerBox.values.toList();

    // Serialize data to JSON
    List<Map<String, dynamic>> jsonData = computers.map((computer) =>
    {
      'name': computer.name,
      'macAddress': computer.macAddress,
      'broadcastAddress': computer.broadcastAddress,
    }).toList();

    return jsonEncode(jsonData);
  }

  // --- End Import/Export Functions ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView( // Wrap with SingleChildScrollView
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Broadcast Address Setting
                TextFormField(
                  controller: _broadcastAddressController,
                  decoration: const InputDecoration(
                    labelText: 'Default Broadcast Address',
                    hintText: 'e.g., 255.255.255.255',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a broadcast address';
                    }
                    // Add more sophisticated IP address validation here
                    return null;
                  },
                ),
                const SizedBox(height: 16.0),
                ElevatedButton(
                  onPressed: _saveSettings,
                  child: const Text('Save Settings'),
                ),
                const SizedBox(height: 32.0), // Add some spacing

                // Import/Export Section
                const Text(
                  'Data Management',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8.0),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _importComputers,
                      icon: const Icon(Icons.file_upload),
                      label: const Text('Import'),
                    ),
                    ElevatedButton.icon(
                      onPressed: _exportComputers,
                      icon: const Icon(Icons.file_download),
                      label: const Text('Export'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}