import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:convert';

import '../models/computer.dart';
import '../utils/globals.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _broadcastAddressController;
  late Box<dynamic> _settingsBox;
  late Box<Computer> _computerBox;

  // State for the overwrite checkbox
  bool _overwriteExistingData =
      false;

  @override
  void initState() {
    super.initState();
    // Initialize boxes in initState as they are available from Provider immediately
    // if the Provider is above this widget in the tree.
    // Ensure that Provider.of is called with listen: false if you don't need
    // this widget to rebuild when the Box instance itself changes (rare).
    // The ValueListenableBuilder for computerBox will handle UI updates for data changes.
    _settingsBox = Provider.of<Box<dynamic>>(context, listen: false);
    _computerBox = Provider.of<Box<Computer>>(context, listen: false);

    final currentBroadcastAddress = _settingsBox.get(
      'broadcastAddress',
      defaultValue: '255.255.255.255',
    );
    _broadcastAddressController = TextEditingController(
      text: currentBroadcastAddress,
    );
  }

  // Remove didChangeDependencies if only used for box initialization now done in initState

  @override
  void dispose() {
    _broadcastAddressController.dispose();
    super.dispose();
  }

  void _saveSettings() {
    if (_formKey.currentState!.validate()) {
      _settingsBox.put('broadcastAddress', _broadcastAddressController.text);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Settings saved!')));
    }
  }

  Future<void> _importComputers() async {
    if (_overwriteExistingData) {
      // Show a confirmation dialog if overwriting
      final bool? confirmed = await _showOverwriteConfirmationDialog();
      if (confirmed != true) {
        // User cancelled the overwrite
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Import cancelled by user.')),
        );
        return;
      }
    }

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null && result.files.single.path != null) {
        File file = File(result.files.single.path!);
        String fileContent = await file.readAsString();

        _importDataFromContent(fileContent, _overwriteExistingData);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Computers imported successfully!')),
        );
      } else {
        // User canceled the picker
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File selection cancelled.')),
        );
      }
    } catch (e) {
      logger.e(e);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error importing computers: ${e.toString()}')),
      );
    }
  }

  Future<bool?> _showOverwriteConfirmationDialog() async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false, // User must tap button!
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Confirm Overwrite'),
          content: const Text(
            'Are you sure you want to overwrite all existing computer data? This action cannot be undone.',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Overwrite'),
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
            ),
          ],
        );
      },
    );
  }

  // In class _SettingsScreenState

  void _importDataFromContent(String fileContent, bool overwrite) {
    List<dynamic> jsonData;
    try {
      jsonData = jsonDecode(fileContent);
    } catch (e) {
      logger.e('Error decoding JSON: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Error: Could not parse the import file. Invalid JSON format.',
            ),
          ),
        );
      }
      return;
    }

    if (overwrite) {
      logger.d('Overwrite selected. Clearing existing computer data.');
      var keys = _computerBox.keys.toList(); // Get all keys
      for (var key in keys) {
        _computerBox.delete(key); // Delete each entry
      }
      assert(_computerBox.values.isEmpty); // For debugging, ensure it's empty
      logger.d('Computer data cleared.');
    } else {
      logger.d(
        'Overwrite not selected. Appending new data and checking for duplicates.',
      );
    }

    int importedCount = 0;
    int skippedCount = 0;
    int duplicateCount = 0;

    // Get existing computers for comparison if not overwriting
    // Convert to a Set of a comparable representation for efficient lookup
    Set<String> existingComputerSignatures = {};
    if (!overwrite) {
      for (var computer in _computerBox.values) {
        // Create a unique signature for each existing computer
        // It's crucial that this signature matches the one generated for incoming items
        existingComputerSignatures.add(
          '${computer.name}|${computer.macAddress.toLowerCase()}|${computer.broadcastAddress}|${computer.color}',
        );
      }
    }

    for (var item in jsonData) {
      if (item is! Map<String, dynamic>) {
        logger.w('Skipping invalid item in JSON data (not a Map): $item');
        skippedCount++;
        continue;
      }

      // Basic validation for required fields
      if (item['name'] == null || item['macAddress'] == null) {
        logger.w('Skipping item with missing name or MAC address: $item');
        skippedCount++;
        continue;
      }

      // Ensure all expected fields are present, providing defaults for optional ones if necessary
      final String name = item['name'] as String;
      final String macAddress =
          (item['macAddress'] as String)
              .toLowerCase(); // Normalize MAC for comparison
      final String broadcastAddress = item['broadcastAddress'] as String? ?? '';
      final int color = (item['color'] as int?) ?? Colors.white.toARGB32();
      final String wanIpAddress = item['wanIpAddress'] as String? ?? '';
      final String notes = item['notes'] as String? ?? '';

      if (!overwrite) {
        // Create a signature for the current item from JSON to check for duplicates
        final String currentItemSignature =
            '$name|$macAddress|$broadcastAddress|$color';
        if (existingComputerSignatures.contains(currentItemSignature)) {
          logger.d(
            'Skipping duplicate computer: Name: $name, MAC: $macAddress',
          );
          duplicateCount++;
          skippedCount++; // Also counts as skipped in terms of not being newly imported
          continue; // Skip this duplicate item
        }
      }

      try {
        final computer = Computer(
          name: name,
          macAddress: macAddress, // Use the (potentially normalized) macAddress
          broadcastAddress: broadcastAddress,
          color: color,
          wanIpAddress: wanIpAddress,
          notes: notes,
        );
        // If overwriting, all existing entries are already cleared.
        // If not overwriting, we've already checked for duplicates.
        _computerBox.add(computer);
        importedCount++;
        if (!overwrite) {
          // Add the newly imported computer's signature to the set to avoid
          // importing duplicates from within the same JSON file if overwrite is false
          existingComputerSignatures.add(
            '$name|$macAddress|$broadcastAddress|$color',
          );
        }
      } catch (e) {
        logger.e(
          'Error creating Computer object or adding to box: $item, Error: $e',
        );
        skippedCount++;
      }
    }

    logger.d(
      'Import complete. Imported: $importedCount, Skipped (errors/invalid): ${skippedCount - duplicateCount}, Skipped (duplicates): $duplicateCount',
    );

    String message = 'Import finished. $importedCount computers imported.';
    if (duplicateCount > 0) {
      message += ' $duplicateCount duplicates skipped.';
    }
    if ((skippedCount - duplicateCount) > 0) {
      message +=
          ' ${(skippedCount - duplicateCount)} items skipped due to errors or missing data.';
    }

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _exportComputers() async {
    // ... (Your existing _exportComputers logic is good, no changes needed here for this refactor)
    // Remember to handle permissions as you already are.
    logger.d('Checking storage permission status...');
    var status = await Permission.manageExternalStorage.status;
    logger.d('Initial status: $status');

    if (!mounted) return; // Check mount status early

    if (status.isGranted) {
      logger.d('Permission already granted.');
      _performExport();
    } else if (status.isDenied || status.isRestricted) {
      // Handle isRestricted as well
      logger.d('Permission denied or restricted. Requesting permission...');
      status = await Permission.manageExternalStorage.request();
      logger.d('Status after request: $status');

      if (!mounted) return;

      if (status.isGranted) {
        logger.d('Permission granted after request.');
        _performExport();
      } else if (status.isPermanentlyDenied) {
        logger.d('Permission permanently denied. Guiding user to settings.');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Storage permission permanently denied. Please enable it in app settings.',
            ),
          ),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Storage permission permanently denied. Please enable it in app settings.',
          ),
        ),
      );
      openAppSettings();
    } else {
      logger.d('Unknown permission status: $status. Assuming not granted.');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Storage permission status unknown. Could not export.'),
        ),
      );
    }
  }

  Future<void> _performExport() async {
    try {
      logger.d('_performExport: Starting file save process.');
      if (_computerBox.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No computer data to export.')),
          );
        }
        return;
      }

      String dataToExport = await _exportDataToJson();
      Uint8List bytesToExport = Uint8List.fromList(utf8.encode(dataToExport));
      logger.d('_performExport: Data encoded to bytes.');

      logger.d('_performExport: Attempting to open file picker...');
      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Computers Data',
        fileName: 'computers_data.json',
        // allowedExtensions: ['json'], // This is often not effective for saveFile dialog
        bytes: bytesToExport,
      );
      logger.d('_performExport: FilePicker.platform.saveFile completed.');

      if (!mounted) return;

      if (outputFile != null) {
        logger.d('_performExport: File saved to: $outputFile');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Computers exported successfully!')),
        );
      } else {
        logger.d('_performExport: File save dialog canceled.');
      }
    } catch (e) {
      logger.e('_performExport: An error occurred', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error exporting computers: ${e.toString()}')),
        );
      }
    }
  }

  Future<String> _exportDataToJson() async {
    List<Computer> computers = _computerBox.values.toList();
    List<Map<String, dynamic>> jsonData =
        computers
            .map(
              (computer) => {
                'name': computer.name,
                'macAddress': computer.macAddress,
                'broadcastAddress': computer.broadcastAddress,
                'color': computer.color, // Export color as well
                'wanIpAddress': computer.wanIpAddress,
                'notes': computer.notes,
              },
            )
            .toList();
    return jsonEncode(jsonData);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              // Keep children aligned to the start
              children: [
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
                    // Add your WolService.isValidBroadcastAddress validation if available
                    return null;
                  },
                ),
                const SizedBox(height: 16.0),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saveSettings,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Save Settings'),
                  ),
                ),
                const SizedBox(height: 24.0),
                const Divider(),
                const SizedBox(height: 16.0),

                const Text(
                  'Data Management',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16.0),

                // --- Import Button ---
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _importComputers,
                    icon: const Icon(Icons.file_upload),
                    label: const Text('Import Data'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                // --- Overwrite Checkbox Row ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  // Align checkbox to the start
                  children: [
                    Tooltip(
                      message:
                          'If checked, existing computer data will be deleted before importing.',
                      child: Row(
                        // Row for Checkbox and its label
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Checkbox(
                            value: _overwriteExistingData,
                            onChanged: (bool? value) {
                              setState(() {
                                _overwriteExistingData = value ?? true;
                              });
                            },
                          ),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _overwriteExistingData =
                                    !_overwriteExistingData;
                              });
                            },
                            child: const Text(
                              'Overwrite existing data',
                            ), // More descriptive label
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12.0),
                // Spacing between Import section and Export button

                // --- Export Button ---
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _exportComputers,
                    icon: const Icon(Icons.file_download),
                    label: const Text('Export Data'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 16.0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
