import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

class HomePage extends StatefulWidget {
  @override
  State<HomePage> createState() => _HomePage();
}

class _HomePage extends State<HomePage> {
  String? _excelContent;

  Future<void> pickExcelFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls'],
    );

    if (result != null && result.files.single.bytes != null) {
      Uint8List fileBytes = result.files.single.bytes!;
      var excel = Excel.decodeBytes(fileBytes);

      // Read first sheet and all rows
      final sheet = excel.tables[excel.tables.keys.first];
      if (sheet != null) {
        String content = '';
        for (var row in sheet.rows) {
          content +=
              row.map((cell) => cell?.value.toString() ?? '').join(' | ') +
              '\n';
        }

        setState(() {
          _excelContent = content;
        });
      }
    } else {
      // User canceled the picker
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Home Page")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: pickExcelFile,
              child: Text("Pick Excel File"),
            ),
            SizedBox(height: 20),
            Expanded(
              child: _excelContent != null
                  ? SingleChildScrollView(
                      child: Text(
                        _excelContent!,
                        style: TextStyle(fontFamily: 'monospace'),
                      ),
                    )
                  : Center(child: Text("No file selected")),
            ),
          ],
        ),
      ),
    );
  }
}
