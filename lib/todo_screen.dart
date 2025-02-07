import 'package:flutter/material.dart';
import 'package:todo/classes.dart';
import 'package:todo/api_service.dart';
import 'package:todo/storage.dart';

class TodoPage extends StatefulWidget {
  final Todo todo;

  const TodoPage({super.key, required this.todo});

  @override
  _TodoPageState createState() => _TodoPageState();
}

class _TodoPageState extends State<TodoPage> {
  bool hasImage = true;
  @override
  Widget build(BuildContext context) {
    final todoId = widget.todo.id;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text("Todo Details"),
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              widget.todo.title,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text(
              widget.todo.description,
              style: TextStyle(fontSize: 16),
            ),
            Spacer(),
            Builder(
              builder: (BuildContext context) {
                return FutureBuilder<String?>(
                  future: StorageService.getToken(),
                  builder: (BuildContext context, AsyncSnapshot<String?> snapshot) {
                    if (snapshot.hasData && snapshot.data != null) {
                      return LayoutBuilder(
                        builder: (context, constraints) {
                          return Container(
                            constraints: BoxConstraints(
                              maxWidth: constraints.maxWidth,
                              maxHeight: 650,
                            ),
                            child: Image.network(
                              'http://10.0.2.2:3000/todo/$todoId/image',
                              headers: {'Authorization': 'Bearer ${snapshot.data}'},
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) {
                                if (error is NetworkImageLoadException && error.statusCode == 400) {
                                  WidgetsBinding.instance.addPostFrameCallback((_) {
                                    setState(() {
                                      hasImage = false;
                                    });
                                  });
                                  return const SizedBox.shrink();
                                }
                                return Text('Error loading image: $error');
                              },
                            ),
                          );
                        },
                      );
                    } else if (snapshot.hasError) {
                      return Text('Error loading image: ${snapshot.error}');
                    } else {
                      return const CircularProgressIndicator();
                    }
                  },
                );
              },
            ),

            Spacer(),
            if(hasImage)
            Container(
              height: 50,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(20),
              ),
              child: TextButton(
                onPressed: () async {
                  try {
                    await downloadFile(context, widget.todo.id);
                  } catch (e) {
                    print("Error: $e");
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                },
                child: Text(
                  'Download Files',
                  style: TextStyle(color: Colors.white, fontSize: 20),
                ),
              ),
            ),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
