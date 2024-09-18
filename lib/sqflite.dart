import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:firebase_core/firebase_core.dart';

class DatabaseHelper {
  static final _databaseName = "location.db";
  static final _databaseVersion = 1;
  static final table = 'locations';
  static final columnId = '_id';
  static final columnLatitude = 'latitude';
  static final columnLongitude = 'longitude';
  static final columnTimestamp = 'timestamp';

  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  static Database? _database;

  Future<Database?> get database async {
    if (_database != null) return _database;
    _database = await _initDatabase();
    return _database;
  }

  _initDatabase() async {
    String path = join(await getDatabasesPath(), _databaseName);
    return await openDatabase(path,
        version: _databaseVersion, onCreate: _onCreate);
  }

  Future _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $table (
        $columnId INTEGER PRIMARY KEY AUTOINCREMENT,
        $columnLatitude REAL NOT NULL,
        $columnLongitude REAL NOT NULL,
        $columnTimestamp TEXT NOT NULL
      )
    ''');
  }

  //to get data from database
  Future<List<Map<String, dynamic>>> queryAllRows() async {
    Database? db = await instance.database;
    return await db!.query(table); // Returns a list of maps (rows)
  }

  //to post data in database as location
  Future<int> insertLocation(Map<String, dynamic> row) async {
    Database? db = await instance.database;
    return await db!.insert(table, row);
  }

  Future<void> clearAllTables() async {
    Database? db = await instance.database;
    await db!.transaction((txn) async {
      await txn.delete(table); // Deletes all rows from the 'locations' table
    });
    print("All tables cleared.");
  }
}

Future<void> saveLocation(double? latitude, double? longitude) async {
  DatabaseHelper dbHelper = DatabaseHelper.instance;

  Map<String, dynamic> row = {
    DatabaseHelper.columnLatitude: latitude,
    DatabaseHelper.columnLongitude: longitude,
    DatabaseHelper.columnTimestamp: DateTime.now().toIso8601String(),
  };

  await dbHelper.insertLocation(row);
}

Future<void> uploadDataToFirestore() async {
  DatabaseHelper dbHelper = DatabaseHelper.instance;

  // Fetch data from SQLite
  List<Map<String, dynamic>> rows = await dbHelper.queryAllRows();

  // Firestore instance
  FirebaseFirestore firestore = FirebaseFirestore.instance;

  // Iterate through each row and upload to Firestore
  for (Map<String, dynamic> row in rows) {
    await firestore.collection('locations').add({
      'latitude': row[DatabaseHelper.columnLatitude],
      'longitude': row[DatabaseHelper.columnLongitude],
      'timestamp': row[DatabaseHelper.columnTimestamp],
    });
  }

  print('Data uploaded to Firestore successfully!');
}
