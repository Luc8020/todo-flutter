import 'package:flutter/material.dart';
import 'package:todo/create_screen.dart';
import 'package:todo/login_screen.dart';
import 'package:todo/storage.dart';
import 'package:todo/api.dart';
import 'package:todo/classes.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<Todo>> _todosFuture;

  @override
  void initState() {
    super.initState();
    _todosFuture = fetchTodos();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Home'),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () async {
              await StorageService.removeToken();
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => Login()),
              );
            },
          ),
        ],
      ),
      body: FutureBuilder<List<Todo>>(
        future: _todosFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('No todos found'));
          }

          return ListView.builder(
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              final todo = snapshot.data![index];
              return ListTile(
                  leading: Checkbox(
                    value: todo.completed,
                    onChanged: (bool? value) {
                      completeTodo(todo.id);
                      setState(() {
                        snapshot.data![index] = Todo(
                            id: todo.id,
                            title: todo.title,
                            completed: value!,
                            description: todo.description
                        );
                      });
                    },
                  ),
                  title: Text(todo.title),
                  subtitle: Text(todo.description)
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => Create()),
          );
        },
        child: Icon(Icons.add),
      ),
    );
  }
}