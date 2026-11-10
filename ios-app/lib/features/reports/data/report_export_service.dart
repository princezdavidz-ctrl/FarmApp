import 'dart:convert';
import 'dart:io';

import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;

class ReportExportService {
  Future<String> exportReport({
    required String reportName,
    required String format,
    required Map<String, dynamic> data,
  }) async {
    final normalizedFormat = format.trim().toLowerCase();
    final safeName = reportName.replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '_');
    final directory = await _downloadsDirectory();
    final extension = _extensionFor(normalizedFormat);
    final filePath =
        '${directory.path}/${safeName}_${DateTime.now().millisecondsSinceEpoch}.$extension';
    final file = File(filePath);

    switch (normalizedFormat) {
      case 'pdf':
        await _writePdf(file, reportName, data);
        break;
      case 'csv':
        await file.writeAsString(_buildCsv(data));
        break;
      case 'json':
        await file.writeAsString(
          const JsonEncoder.withIndent('  ').convert(data),
        );
        break;
      case 'txt':
        await file.writeAsString(_buildTextReport(data));
        break;
      case 'xlsx':
        await _writeXlsx(file, data);
        break;
      case 'doc':
        await file.writeAsString(_buildWordDocument(reportName, data));
        break;
      default:
        await file.writeAsString(_buildTextReport(data));
    }

    return file.path;
  }

  Future<Directory> _downloadsDirectory() async {
    if (kIsWeb) {
      return await getTemporaryDirectory();
    }

    if (Platform.isAndroid || Platform.isIOS) {
      final downloadsDir = await getDownloadsDirectory();
      if (downloadsDir != null) {
        return downloadsDir;
      }
    }

    return await getApplicationDocumentsDirectory();
  }

  String _extensionFor(String format) {
    switch (format) {
      case 'pdf':
        return 'pdf';
      case 'csv':
        return 'csv';
      case 'json':
        return 'json';
      case 'txt':
        return 'txt';
      case 'xlsx':
        return 'xlsx';
      case 'doc':
        return 'doc';
      default:
        return 'txt';
    }
  }

  Future<void> _writePdf(
    File file,
    String reportName,
    Map<String, dynamic> data,
  ) async {
    final pdf = pw.Document();

    final records = _records(data);
    pdf.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Text(
            reportName,
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          ...data.entries
              .where((entry) => entry.key != 'records')
              .map(
                (entry) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 4),
                  child: pw.Text('${entry.key}: ${entry.value}'),
                ),
              ),
          if (records.isNotEmpty) ...[
            pw.SizedBox(height: 12),
            _pdfRecordsTable(records),
          ],
        ],
      ),
    );

    await file.writeAsBytes(await pdf.save());
  }

  Future<void> _writeXlsx(File file, Map<String, dynamic> data) async {
    final excel = Excel.createExcel();
    final records = _records(data);
    if (records.isEmpty) {
      final sheet = excel['Report'];
      sheet.appendRow([TextCellValue('Field'), TextCellValue('Value')]);
      for (final entry in data.entries) {
        sheet.appendRow([
          TextCellValue(entry.key),
          TextCellValue(entry.value.toString()),
        ]);
      }
    } else {
      final summary = excel['Summary'];
      summary.appendRow([TextCellValue('Field'), TextCellValue('Value')]);
      for (final entry in data.entries.where(
        (entry) => entry.key != 'records',
      )) {
        summary.appendRow([
          TextCellValue(entry.key),
          TextCellValue(entry.value.toString()),
        ]);
      }
      final columns = _recordColumns(records);
      final rows = excel['Records'];
      rows.appendRow(columns.map(TextCellValue.new).toList());
      for (final record in records) {
        rows.appendRow(
          columns
              .map((column) => TextCellValue('${record[column] ?? ''}'))
              .toList(),
        );
      }
    }

    final bytes = excel.save();
    if (bytes == null) {
      throw StateError('Unable to generate XLSX report');
    }

    await file.writeAsBytes(bytes);
  }

  String _buildWordDocument(String reportName, Map<String, dynamic> data) {
    final records = _records(data);
    final buffer = StringBuffer()
      ..writeln('<!doctype html>')
      ..writeln(
        '<html><head><meta charset="utf-8"><meta http-equiv="Content-Type" content="application/msword; charset=utf-8"></head><body>',
      )
      ..writeln('<h1>${_escapeHtml(reportName)}</h1>');
    for (final entry in data.entries.where((entry) => entry.key != 'records')) {
      buffer.writeln(
        '<p><strong>${_escapeHtml(entry.key)}:</strong> ${_escapeHtml(entry.value.toString())}</p>',
      );
    }
    if (records.isNotEmpty) {
      buffer.writeln(
        '<table border="1" cellspacing="0" cellpadding="5"><thead><tr>',
      );
      for (final column in _recordColumns(records)) {
        buffer.writeln('<th>${_escapeHtml(column)}</th>');
      }
      buffer.writeln('</tr></thead><tbody>');
      for (final record in records) {
        buffer.writeln('<tr>');
        for (final column in _recordColumns(records)) {
          buffer.writeln('<td>${_escapeHtml('${record[column] ?? ''}')}</td>');
        }
        buffer.writeln('</tr>');
      }
      buffer.writeln('</tbody></table>');
    }
    buffer.writeln('</body></html>');
    return buffer.toString();
  }

  pw.Widget _pdfRecordsTable(List<Map<String, dynamic>> records) {
    final columns = _recordColumns(records);
    return pw.Table(
      border: pw.TableBorder.all(),
      children: [
        pw.TableRow(
          children: columns
              .map(
                (column) => pw.Padding(
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Text(
                    column,
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                ),
              )
              .toList(),
        ),
        for (final record in records)
          pw.TableRow(
            children: columns
                .map(
                  (column) => pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text('${record[column] ?? ''}'),
                  ),
                )
                .toList(),
          ),
      ],
    );
  }

  List<Map<String, dynamic>> _records(Map<String, dynamic> data) =>
      (data['records'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList(growable: false);

  List<String> _recordColumns(List<Map<String, dynamic>> records) =>
      {for (final record in records) ...record.keys}.toList(growable: false);

  String _escapeHtml(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#39;');

  String _buildCsv(Map<String, dynamic> data) {
    final rows = [
      ['Field', 'Value'],
      ...data.entries.map((entry) => [entry.key, entry.value.toString()]),
    ];

    final csv = rows
        .map((row) {
          final escaped = row
              .map((cell) {
                final value = cell.toString();
                if (value.contains(',') ||
                    value.contains('"') ||
                    value.contains('\n')) {
                  return '"${value.replaceAll('"', '""')}"';
                }
                return value;
              })
              .join(',');
          return escaped;
        })
        .join('\n');

    return '$csv\n';
  }

  String _buildTextReport(Map<String, dynamic> data) {
    final buffer = StringBuffer();
    buffer.writeln('Farm App Report');
    buffer.writeln('Generated: ${DateTime.now().toIso8601String()}');
    buffer.writeln('');

    for (final entry in data.entries) {
      buffer.writeln('${entry.key}: ${entry.value}');
    }

    return buffer.toString();
  }
}
