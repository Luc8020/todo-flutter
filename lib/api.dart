import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:todo/storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:todo/classes.dart';
import 'package:permission_handler/permission_handler.dart';

Future<bool> register(String email, String username, String password) async {
  try {
    var body = jsonEncode({
      'email': email,
      'username': username,
      'password': password,
    });

    final response = await http.post(Uri.parse("http://10.0.2.2:3000/auth/register"),
    headers: {'Content-Type': 'application/json'},
    body: body);

    if(response.statusCode==200){
      return true;
    } else {
      return false;
    }
  } catch(error) {
    print('Error during Registration $error');
    return false;
  }

}

Future<bool> check(String? token) async {
  try {
    final response = await http.get(
        Uri.parse("http://10.0.2.2:3000/auth/check"),
        headers: {
          'Authorization': 'Bearer $token'
        });
    print('Response: ${response.body}');
    print(response.statusCode);
    if (response.statusCode == 200) {
      return true;
    } else {
      return false;
    }
  } catch(error) {
    print('Error during Authorization $error');
    return false;
  }
}

Future<bool> login(String email, String password) async {
  try {
    var body = jsonEncode({
      'email': email,
      'password': password,
    });
    final response = await http.post(
      Uri.parse("http://10.0.2.2:3000/auth/login"),
      body: body,
      headers: {'Content-Type': 'application/json'},
    );

    print('Response status: ${response.statusCode}');
    print('Response body: ${response.body}');

    final responseData = jsonDecode(response.body);
    await StorageService.saveToken(responseData["token"]);
    if (response.statusCode == 200) {
      var jsonResponse = jsonDecode(response.body);
      print('Login successful: $jsonResponse');
      return true;
    } else {
      print('Login failed with status: ${response.statusCode}');
      return false;
    }
  } catch (e) {
    print('Error during login: $e');
    rethrow;
  }
}


Future<List<Todo>> fetchTodos() async {
  final token = await StorageService.getToken();
  final response = await http.get(Uri.parse("http://10.0.2.2:3000/todo"), headers: {"Authorization": "Bearer $token"});
  final responseData = await jsonDecode(response.body);

  if (response.statusCode == 200) {
    print('Response data: $responseData');

    final todosList = responseData['todos'] as List;
    return todosList.map((todoJson) => Todo.fromJson(todoJson)).toList();
  } else {
    throw Exception('Fetching failed');
  }
}

Future<void> completeTodo(String uuid) async {
  final token = await StorageService.getToken();
  final response = await http.patch(Uri.parse("http://10.0.2.2:3000/todo/$uuid"),
      headers: {"Authorization": "Bearer $token"});

  if (response.statusCode == 200) {
    print("todo completed");
  } else {
    throw Exception('Something went wromg');
  }
}

Future<bool> createTodo(String title, String description) async {
  final token = await StorageService.getToken();

  var request = http.MultipartRequest('POST', Uri.parse("http://10.0.2.2:3000/todo/"));

  request.headers.addAll({
    "Authorization": "Bearer $token",
  });

  request.fields['title'] = title;
  request.fields['description'] = description;

  try {
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      print("todo created");
      return true;
    } else {
      print("Failed to create todo: ${response.body}");
      return false;
    }
  } catch (e) {
    print("Error creating todo: $e");
    return false;
  }
}

Future<bool> deleteTodo(String uuid) async {
  final token = await StorageService.getToken();
  
  final response = await http.delete(Uri.parse("http://10.0.2.2:3000/todo/$uuid"),
      headers: {'Authorization': 'Bearer $token'});

  if(response.statusCode == 200) {
    return true;
  } else {
    return false;
  }
}


Future<bool> requestStoragePermission(BuildContext context) async {
  // Check Android version
  if (Platform.isAndroid) {
    // For Android 13 and above
    final statuses = await [
      Permission.photos,
      Permission.videos,
      Permission.audio,
      Permission.storage,
      Permission.manageExternalStorage,
    ].request();

    // Check if any permissions are permanently denied
    bool isPermanentlyDenied = statuses.values.any(
            (status) => status.isPermanentlyDenied
    );

    if (isPermanentlyDenied) {
      // Show a dialog to guide user to app settings
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Permission Required'),
          content: Text('Storage permissions are required. Please enable them in app settings.'),
          actions: [
            TextButton(
              onPressed: () {
                openAppSettings();
                Navigator.of(context).pop();
              },
              child: Text('Open Settings'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
          ],
        ),
      );
      return false;
    }

    // Check if all required permissions are granted
    bool allGranted = statuses.values.every(
            (status) => status.isGranted
    );

    return allGranted;
  }

  // For non-Android platforms
  return true;
}

// Modify your download method to use this
Future<String> downloadFile(BuildContext context, String id) async {
  // First, request permissions
  bool permissionsGranted = await requestStoragePermission(context);

  if (!permissionsGranted) {
    return 'Permissions not granted';
  }

  try {
    String? token = await StorageService.getToken();
    if (token == null) {
      return 'Authentication token unavailable';
    }

    final response = await http.get(
      Uri.parse("http://10.0.2.2:3000/todo/$id/files"),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 200) {
      return 'Download failed with status code: ${response.statusCode}';
    }

    // Use a more reliable directory for saving files
    final downloadsDir = await getApplicationDocumentsDirectory();
    final filePath = '${downloadsDir.path}/downloaded_file_$id';
    final file = File(filePath);
    await file.writeAsBytes(response.bodyBytes);

    return filePath;
  } catch (ex) {
    return 'Download error: $ex';
  }
}