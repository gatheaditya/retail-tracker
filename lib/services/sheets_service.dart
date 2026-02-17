import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'dart:developer' as developer;

class SheetsService {
  static final SheetsService instance = SheetsService._();
  static const _spreadsheetName = 'Order App Data';
  static const _tabNames = ['Clients', 'Products', 'Orders', 'OrderItems'];
  static const _headers = [
    ['id', 'name', 'phone', 'email', 'address'],
    ['id', 'name', 'description', 'price', 'sku', 'category'],
    ['id', 'clientId', 'orderDate', 'totalAmount', 'status'],
    ['id', 'orderId', 'productId', 'productName', 'quantity', 'unitPrice'],
  ];

  SheetsService._();

  /// Get or create the Order App Data spreadsheet
  Future<String> getOrCreateSpreadsheet(http.Client authClient) async {
    try {
      developer.log('Looking for existing spreadsheet', name: 'SheetsService');
      final driveApi = drive.DriveApi(authClient);

      // Search for existing spreadsheet
      final fileList = await driveApi.files.list(
        q: "name='$_spreadsheetName' and mimeType='application/vnd.google-apps.spreadsheet' and trashed=false",
        spaces: 'drive',
        pageSize: 1,
      );

      String spreadsheetId;
      if (fileList.files != null && fileList.files!.isNotEmpty) {
        spreadsheetId = fileList.files!.first.id!;
        developer.log('Found existing spreadsheet: $spreadsheetId', name: 'SheetsService');
      } else {
        developer.log('Creating new spreadsheet', name: 'SheetsService');
        final sheetsApi = sheets.SheetsApi(authClient);

        // Create new spreadsheet with 4 sheets
        final createRequest = sheets.Spreadsheet(
          properties: sheets.SpreadsheetProperties(title: _spreadsheetName),
          sheets: [
            sheets.Sheet(properties: sheets.SheetProperties(title: _tabNames[0])),
            sheets.Sheet(properties: sheets.SheetProperties(title: _tabNames[1])),
            sheets.Sheet(properties: sheets.SheetProperties(title: _tabNames[2])),
            sheets.Sheet(properties: sheets.SheetProperties(title: _tabNames[3])),
          ],
        );

        final created = await sheetsApi.spreadsheets.create(createRequest);
        spreadsheetId = created.spreadsheetId!;
        developer.log('Created new spreadsheet: $spreadsheetId', name: 'SheetsService');

        // Add headers to all 4 sheets
        await _addHeadersToSheets(authClient, spreadsheetId);
      }

      return spreadsheetId;
    } catch (e) {
      developer.log('Error getting/creating spreadsheet: $e', name: 'SheetsService', level: 1000);
      rethrow;
    }
  }

  /// Add headers to all 4 sheets
  Future<void> _addHeadersToSheets(http.Client authClient, String spreadsheetId) async {
    try {
      final sheetsApi = sheets.SheetsApi(authClient);
      final requests = <sheets.Request>[];

      for (int i = 0; i < _tabNames.length; i++) {
        requests.add(sheets.Request(
          updateCells: sheets.UpdateCellsRequest(
            range: sheets.GridRange(
              sheetId: i,
              startRowIndex: 0,
              endRowIndex: 1,
              startColumnIndex: 0,
              endColumnIndex: _headers[i].length,
            ),
            rows: [
              sheets.RowData(
                values: _headers[i]
                    .map((h) => sheets.CellData(userEnteredValue: sheets.ExtendedValue(stringValue: h)))
                    .toList(),
              ),
            ],
            fields: 'userEnteredValue',
          ),
        ));
      }

      await sheetsApi.spreadsheets.batchUpdate(
        sheets.BatchUpdateSpreadsheetRequest(requests: requests),
        spreadsheetId,
      );

      developer.log('Headers added to all sheets', name: 'SheetsService');
    } catch (e) {
      developer.log('Error adding headers: $e', name: 'SheetsService', level: 1000);
      rethrow;
    }
  }

  /// Read all rows from a sheet
  Future<List<List<Object?>>> readSheet(http.Client authClient, String spreadsheetId, String tabName) async {
    try {
      final sheetsApi = sheets.SheetsApi(authClient);
      final range = '$tabName!A:Z';

      final response = await sheetsApi.spreadsheets.values.get(spreadsheetId, range);
      final values = response.values ?? [];

      developer.log('Read ${values.length} rows from $tabName', name: 'SheetsService');
      return values;
    } catch (e) {
      developer.log('Error reading sheet: $e', name: 'SheetsService', level: 1000);
      rethrow;
    }
  }

  /// Append a row to a sheet
  Future<void> appendRow(http.Client authClient, String spreadsheetId, String tabName, List<Object?> row) async {
    try {
      final sheetsApi = sheets.SheetsApi(authClient);
      final range = '$tabName!A:Z';

      final values = sheets.ValueRange(values: [row]);
      await sheetsApi.spreadsheets.values.append(values, spreadsheetId, range);

      developer.log('Appended row to $tabName', name: 'SheetsService');
    } catch (e) {
      developer.log('Error appending row: $e', name: 'SheetsService', level: 1000);
      rethrow;
    }
  }

  /// Update a row by ID
  Future<void> updateRow(http.Client authClient, String spreadsheetId, String tabName, String id, List<Object?> row) async {
    try {
      final sheetsApi = sheets.SheetsApi(authClient);
      final range = '$tabName!A:Z';

      // Read all rows to find the one with matching ID
      final response = await sheetsApi.spreadsheets.values.get(spreadsheetId, range);
      final values = response.values ?? [];

      int rowIndex = -1;
      for (int i = 1; i < values.length; i++) {
        // Skip header (row 0)
        final rowData = values[i];
        if (rowData.isNotEmpty && rowData[0].toString() == id) {
          rowIndex = i + 1; // Sheets are 1-indexed
          break;
        }
      }

      if (rowIndex == -1) {
        developer.log('Row with ID $id not found in $tabName', name: 'SheetsService');
        return;
      }

      // Update the row
      final updateRange = '$tabName!A$rowIndex:Z$rowIndex';
      final updateValues = sheets.ValueRange(values: [row]);
      await sheetsApi.spreadsheets.values.update(updateValues, spreadsheetId, updateRange);

      developer.log('Updated row with ID $id in $tabName', name: 'SheetsService');
    } catch (e) {
      developer.log('Error updating row: $e', name: 'SheetsService', level: 1000);
      rethrow;
    }
  }

  /// Delete a row by ID (clear its contents)
  Future<void> deleteFromSheet(http.Client authClient, String spreadsheetId, String tabName, String id) async {
    try {
      final sheetsApi = sheets.SheetsApi(authClient);
      final range = '$tabName!A:Z';

      // Read all rows to find the one with matching ID
      final response = await sheetsApi.spreadsheets.values.get(spreadsheetId, range);
      final values = response.values ?? [];

      int rowIndex = -1;
      for (int i = 1; i < values.length; i++) {
        // Skip header (row 0)
        final rowData = values[i];
        if (rowData.isNotEmpty && rowData[0].toString() == id) {
          rowIndex = i + 1; // Sheets are 1-indexed
          break;
        }
      }

      if (rowIndex == -1) {
        developer.log('Row with ID $id not found in $tabName', name: 'SheetsService');
        return;
      }

      // Clear the row
      final clearRange = '$tabName!A$rowIndex:Z$rowIndex';
      await sheetsApi.spreadsheets.values.clear(
        sheets.ClearValuesRequest(),
        spreadsheetId,
        clearRange,
      );

      developer.log('Deleted row with ID $id from $tabName', name: 'SheetsService');
    } catch (e) {
      developer.log('Error deleting from sheet: $e', name: 'SheetsService', level: 1000);
      rethrow;
    }
  }

  /// Convert rows from Google Sheets to model objects
  static List<List<Object?>> rowsToModels(List<List<Object?>> rows) {
    // Skip header row
    return rows.skip(1).toList();
  }
}
