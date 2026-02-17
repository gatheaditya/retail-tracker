import 'dart:io';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/client.dart';
import '../models/order_item.dart';
import 'config_service.dart';
import 'dart:developer' as developer;

class EmailService {
  static final EmailService instance = EmailService._();

  EmailService._();

  Future<void> sendOrderEmail({
    required String orderId,
    required String orderDate,
    required double totalAmount,
    required Client client,
    required List<OrderItem> items,
  }) async {
    try {
      developer.log('Generating Excel for order $orderId', name: 'EmailService');

      final excel = Excel.createExcel();
      final sheetName = excel.tables.keys.first;
      final sheet = excel[sheetName];

      // Date Formatting
      DateTime? date;
      try {
        date = DateTime.parse(orderDate);
      } catch (e) {
        date = DateTime.now();
      }

      final formattedDate = DateFormat('MMM dd, yyyy HH:mm').format(date);
      final currencyFormatter = NumberFormat.currency(symbol: '\$');

      // Styles
      final headerStyle = CellStyle(
        bold: true,
        fontSize: 14,
        fontColorHex: '#FFFFFF',
        backgroundColorHex: '#9D0C0F',
        horizontalAlign: HorizontalAlign.Center,
      );
      final sectionStyle = CellStyle(
        bold: true,
        fontSize: 12,
        fontColorHex: '#FFFFFF',
        backgroundColorHex: '#C0392B',
        horizontalAlign: HorizontalAlign.Left,
      );
      final labelStyle = CellStyle(
        bold: true,
        fontColorHex: '#333333',
      );
      final totalStyle = CellStyle(
        bold: true,
        fontSize: 12,
        fontColorHex: '#9D0C0F',
      );

      int row = 0;

      // ── ORDER INFORMATION (merged header) ──
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = 'ORDER INFORMATION';
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).cellStyle = headerStyle;
      sheet.merge(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
        CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row),
      );
      row++;

      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = 'Order ID';
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).cellStyle = labelStyle;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value = orderId;
      sheet.merge(
        CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row),
        CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row),
      );
      row++;

      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = 'Date';
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).cellStyle = labelStyle;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value = formattedDate;
      sheet.merge(
        CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row),
        CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row),
      );
      row++;

      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = 'Total Amount';
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).cellStyle = labelStyle;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value = currencyFormatter.format(totalAmount);
      sheet.merge(
        CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row),
        CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row),
      );
      row++;

      // Empty row
      row++;

      // ── CUSTOMER INFORMATION (merged header) ──
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = 'CUSTOMER INFORMATION';
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).cellStyle = sectionStyle;
      sheet.merge(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
        CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row),
      );
      row++;

      // Client detail rows — label in col A, value merged across B-E
      final clientDetails = <String, String>{
        'Name': client.name,
        'Contact Person': client.contactPerson,
        'Phone': client.phone,
        'Email': client.email,
        'Address': client.address,
        'City': client.city,
        'Postal Code': client.postalCode,
      };

      for (final entry in clientDetails.entries) {
        if (entry.value.isNotEmpty) {
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = entry.key;
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).cellStyle = labelStyle;
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value = entry.value;
          sheet.merge(
            CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row),
            CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row),
          );
          row++;
        }
      }

      // Empty row
      row++;

      // ── ITEM DETAILS (merged header) ──
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = 'ITEM DETAILS';
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).cellStyle = sectionStyle;
      sheet.merge(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
        CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row),
      );
      row++;

      // Items column headers
      final colHeaders = ['Product Name', 'SKU', 'Unit Price', 'Quantity', 'Total'];
      for (int c = 0; c < colHeaders.length; c++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: row)).value = colHeaders[c];
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: row)).cellStyle = labelStyle;
      }
      row++;

      // Item rows
      for (var item in items) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = item.productName;
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value = item.productId;
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row)).value = item.unitPrice;
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row)).value = item.quantity;
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row)).value = item.totalPrice;
        row++;
      }

      // Empty row
      row++;

      // Grand total
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row)).value = 'GRAND TOTAL';
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row)).cellStyle = totalStyle;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row)).value = currencyFormatter.format(totalAmount);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row)).cellStyle = totalStyle;

      // Column widths
      sheet.setColWidth(0, 18);
      sheet.setColWidth(1, 22);
      sheet.setColWidth(2, 14);
      sheet.setColWidth(3, 14);
      sheet.setColWidth(4, 14);

      // Save file
      final directory = await getTemporaryDirectory();
      final shortId = orderId.length > 8 ? orderId.substring(0, 8) : orderId;
      final fileName = 'Order_$shortId.xlsx';
      final file = File('${directory.path}/$fileName');

      final bytes = excel.save();
      if (bytes != null) {
        await file.writeAsBytes(bytes);
      }

      // Get configured email
      final recipientEmail = await ConfigService.instance.getRecipientEmail();

      // Prepare email body
      final buffer = StringBuffer();
      buffer.writeln('New Order Received: #$orderId');
      buffer.writeln('Customer: ${client.name}');
      buffer.writeln('Contact Person: ${client.contactPerson}');
      buffer.writeln('Total Amount: ${currencyFormatter.format(totalAmount)}');
      buffer.writeln('\nPlease find the order details in the attached Excel file.');

      developer.log('Sharing order $orderId via email', name: 'EmailService');

      // Share/Send Email
      await Share.shareXFiles(
        List<XFile>.from([XFile(file.path)]),
        subject: 'Order #$orderId - ${client.name}',
        text: buffer.toString(),
      );

    } catch (e, stackTrace) {
      developer.log('Error in EmailService: $e', name: 'EmailService', level: 1000);
      developer.log('Stack trace: $stackTrace', name: 'EmailService', level: 1000);
      rethrow;
    }
  }
}
