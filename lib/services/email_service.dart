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
      final sheet = excel['Order Details'];
      excel.delete('Sheet1');

      // Date Formatting
      final date = DateTime.parse(orderDate);
      final formattedDate = DateFormat('MMM dd, yyyy HH:mm').format(date);
      final currencyFormatter = NumberFormat.currency(symbol: '\$');

      // Order Information
      sheet.appendRow(['Order ID', orderId]);
      sheet.appendRow(['Date', formattedDate]);
      sheet.appendRow(['Total Amount', currencyFormatter.format(totalAmount)]);
      sheet.appendRow(['']);

      // Customer Information
      sheet.appendRow(['CUSTOMER INFORMATION']);
      sheet.appendRow(['Name', client.name]);
      sheet.appendRow(['Contact Person', client.contactPerson]);
      sheet.appendRow(['Phone', client.phone]);
      sheet.appendRow(['Email', client.email]);
      sheet.appendRow(['Address', client.address]);
      sheet.appendRow(['City', client.city]);
      sheet.appendRow(['Postal Code', client.postalCode]);
      sheet.appendRow(['']);

      // Items Header
      sheet.appendRow(['ITEM DETAILS']);
      sheet.appendRow(['Product Name', 'SKU', 'Unit Price', 'Quantity', 'Total']);
      
      for (var item in items) {
        sheet.appendRow([
          item.productName,
          item.productId,
          item.unitPrice,
          item.quantity,
          item.totalPrice,
        ]);
      }

      sheet.appendRow(['']);
      sheet.appendRow(['', '', '', 'GRAND TOTAL', totalAmount]);

      // Save file
      final directory = await getTemporaryDirectory();
      final fileName = 'Order_${orderId.substring(0, 8)}.xlsx';
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
        [XFile(file.path)],
        subject: 'Order #$orderId - ${client.name}',
        text: buffer.toString(),
      );

    } catch (e) {
      developer.log('Error in EmailService: $e', name: 'EmailService', level: 1000);
      rethrow;
    }
  }
}
