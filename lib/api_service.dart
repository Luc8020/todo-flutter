import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:todo/storage.dart';
import 'package:todo/classes.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:safe_device/safe_device.dart';

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

Future<bool> createTodo(String title, String description, File? file) async {
  final token = await StorageService.getToken();

  var request = http.MultipartRequest('POST', Uri.parse("http://10.0.2.2:3000/todo/"));

  request.headers.addAll({
    "Authorization": "Bearer $token",
  });

  request.fields['title'] = title;
  request.fields['description'] = description;
  if(file != null) {
    request.files.add(await http.MultipartFile.fromPath('files', file.path));
  }

  try {
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 201) {
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
  if (Platform.isAndroid) {
    if (await Permission.photos.status.isDenied ||
        await Permission.videos.status.isDenied ||
        await Permission.audio.status.isDenied) {

      Map<Permission, PermissionStatus> statuses = await [
        Permission.photos,
        Permission.videos,
        Permission.audio,
      ].request();

      bool allGranted = statuses.values.every((status) => status.isGranted);

      if (!allGranted) {
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Permission Required'),
            content: Text('Media permissions are required. Please enable them in app settings.'),
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
    }
    return true;
  }
  return true;
}

Future<bool> downloadFile(BuildContext context, String id) async {
  try {
    String? token = await StorageService.getToken();
    final response = await http.get(
      Uri.parse("http://10.0.2.2:3000/todo/$id/files"),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 200) {
      print('Download failed with status code: ${response.statusCode}');
      return false;
    }

    String fileName = response.headers['content-disposition']?.split('filename=').last ?? 'downloaded_file_$id';
    fileName = fileName.replaceAll('"', '');

    Directory? downloadDir;
    if (await SafeDevice.isRealDevice) {
      downloadDir = await getDownloadsDirectory();
    } else {
      downloadDir = Directory('/storage/emulated/0/Download');
    }

    final filePath = '${downloadDir?.path}/$fileName';
    final file = File(filePath);
    await file.writeAsBytes(response.bodyBytes);

    print('File saved to: $filePath');
    return true;
  } catch (e) {
    print('Error downloading file: $e');
    return false;
  }
}
