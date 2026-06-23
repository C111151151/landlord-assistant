import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';

bool leaseCoversMonth(String startDate, String endDate, DateTime month) {
  final start = DateTime.tryParse(startDate);
  final end = DateTime.tryParse(endDate);
  if (start == null || end == null) {
    throw ArgumentError('租約日期格式不正確');
  }
  if (end.isBefore(start)) {
    throw ArgumentError('租約結束日期不可早於入住日期');
  }

  final target = DateTime(month.year, month.month);
  final first = DateTime(start.year, start.month);
  final last = DateTime(end.year, end.month);
  return !target.isBefore(first) && !target.isAfter(last);
}

class DatabaseService {
  DatabaseService._();
  static final DatabaseService instance = DatabaseService._();
  Database? _database;

  Future<Database> get database async => _database ??= await _open();

  Future<Database> _open() async {
    final path = join(await getDatabasesPath(), 'landlord_assistant.db');
    return openDatabase(
      path,
      version: 2,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE leases ADD COLUMN monthly_rent REAL');
          await db.execute('''
            UPDATE leases
            SET monthly_rent = COALESCE(
              (SELECT rent FROM houses WHERE houses.id = leases.house_id),
              0
            )
            WHERE monthly_rent IS NULL
          ''');
          await db.execute('''
            DELETE FROM payments
            WHERE id NOT IN (
              SELECT MAX(id) FROM payments GROUP BY lease_id, month
            )
          ''');
          await db.execute('''
            CREATE UNIQUE INDEX IF NOT EXISTS payments_lease_month_idx
            ON payments(lease_id, month)
          ''');
        }
      },
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE houses(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            address TEXT NOT NULL,
            rent REAL NOT NULL,
            deposit REAL NOT NULL,
            status TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE tenants(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            phone TEXT NOT NULL,
            move_in TEXT NOT NULL,
            house_id INTEGER NOT NULL REFERENCES houses(id) ON DELETE RESTRICT
          )
        ''');
        await db.execute('''
          CREATE TABLE leases(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            tenant_id INTEGER NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
            house_id INTEGER NOT NULL REFERENCES houses(id) ON DELETE RESTRICT,
            start_date TEXT NOT NULL,
            end_date TEXT NOT NULL,
            monthly_rent REAL NOT NULL,
            status TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE payments(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            lease_id INTEGER NOT NULL REFERENCES leases(id) ON DELETE RESTRICT,
            month TEXT NOT NULL,
            amount REAL NOT NULL,
            status TEXT NOT NULL,
            paid_date TEXT,
            UNIQUE(lease_id, month)
          )
        ''');
        await db.execute('''
          CREATE TABLE repairs(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            house_id INTEGER NOT NULL REFERENCES houses(id) ON DELETE RESTRICT,
            tenant_id INTEGER REFERENCES tenants(id) ON DELETE SET NULL,
            title TEXT NOT NULL,
            description TEXT,
            reported_date TEXT NOT NULL,
            status TEXT NOT NULL
          )
        ''');
        await _seed(db);
      },
    );
  }

  String _date(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  String _month(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}';

  Future<void> _seed(Database db) async {
    final now = DateTime.now();
    final houseIds = <int>[];
    for (final row in [
      {
        'name': '河畔綠寓 3A',
        'address': '高雄市楠梓區大學二十六街 18 號 3 樓',
        'rent': 13500,
        'deposit': 27000,
        'status': '已出租'
      },
      {
        'name': '晨光套房 5F',
        'address': '高雄市左營區重信路 221 號 5 樓',
        'rent': 11000,
        'deposit': 22000,
        'status': '已出租'
      },
      {
        'name': '港灣小居 2B',
        'address': '高雄市鼓山區臨海一路 88 號 2 樓',
        'rent': 15800,
        'deposit': 31600,
        'status': '可出租'
      },
      {
        'name': '森日公寓 6C',
        'address': '高雄市三民區建工路 312 號 6 樓',
        'rent': 12500,
        'deposit': 25000,
        'status': '維修中'
      },
      {
        'name': '藝文雅房 4A',
        'address': '高雄市苓雅區五福一路 102 號 4 樓',
        'rent': 9800,
        'deposit': 19600,
        'status': '已出租'
      },
    ]) {
      houseIds.add(await db.insert('houses', row));
    }

    final tenantIds = <int>[];
    for (final row in [
      {
        'name': '林子晴',
        'phone': '0912-345-678',
        'move_in': _date(now.subtract(const Duration(days: 330))),
        'house_id': houseIds[0]
      },
      {
        'name': '陳柏宇',
        'phone': '0988-220-731',
        'move_in': _date(now.subtract(const Duration(days: 160))),
        'house_id': houseIds[1]
      },
      {
        'name': '黃欣怡',
        'phone': '0966-501-842',
        'move_in': _date(now.subtract(const Duration(days: 290))),
        'house_id': houseIds[4]
      },
    ]) {
      tenantIds.add(await db.insert('tenants', row));
    }

    final leaseIds = <int>[];
    for (final row in [
      {
        'tenant_id': tenantIds[0],
        'house_id': houseIds[0],
        'start_date': _date(now.subtract(const Duration(days: 330))),
        'end_date': _date(now.add(const Duration(days: 25))),
        'monthly_rent': 13500,
        'status': '即將到期'
      },
      {
        'tenant_id': tenantIds[1],
        'house_id': houseIds[1],
        'start_date': _date(now.subtract(const Duration(days: 160))),
        'end_date': _date(now.add(const Duration(days: 205))),
        'monthly_rent': 11000,
        'status': '生效中'
      },
      {
        'tenant_id': tenantIds[2],
        'house_id': houseIds[4],
        'start_date': _date(now.subtract(const Duration(days: 290))),
        'end_date': _date(now.add(const Duration(days: 75))),
        'monthly_rent': 9800,
        'status': '生效中'
      },
    ]) {
      leaseIds.add(await db.insert('leases', row));
    }

    final currentMonth = _month(now);
    final previousMonth = _month(DateTime(now.year, now.month - 1));
    for (final row in [
      {
        'lease_id': leaseIds[0],
        'month': currentMonth,
        'amount': 13500,
        'status': '已繳',
        'paid_date': _date(now.subtract(const Duration(days: 4)))
      },
      {
        'lease_id': leaseIds[1],
        'month': currentMonth,
        'amount': 11000,
        'status': '未繳',
        'paid_date': null
      },
      {
        'lease_id': leaseIds[2],
        'month': currentMonth,
        'amount': 9800,
        'status': '逾期',
        'paid_date': null
      },
      {
        'lease_id': leaseIds[0],
        'month': previousMonth,
        'amount': 13500,
        'status': '已繳',
        'paid_date': _date(now.subtract(const Duration(days: 34)))
      },
      {
        'lease_id': leaseIds[1],
        'month': previousMonth,
        'amount': 11000,
        'status': '已繳',
        'paid_date': _date(now.subtract(const Duration(days: 32)))
      },
      {
        'lease_id': leaseIds[2],
        'month': previousMonth,
        'amount': 9800,
        'status': '已繳',
        'paid_date': _date(now.subtract(const Duration(days: 31)))
      },
    ]) {
      await db.insert('payments', row);
    }

    for (final row in [
      {
        'house_id': houseIds[1],
        'tenant_id': tenantIds[1],
        'title': '冷氣運轉有異音',
        'description': '開機約十分鐘後出現規律異音。',
        'reported_date': _date(now.subtract(const Duration(days: 2))),
        'status': '待處理'
      },
      {
        'house_id': houseIds[0],
        'tenant_id': tenantIds[0],
        'title': '浴室排水速度慢',
        'description': '淋浴時容易積水，已預約水電。',
        'reported_date': _date(now.subtract(const Duration(days: 5))),
        'status': '處理中'
      },
      {
        'house_id': houseIds[4],
        'tenant_id': tenantIds[2],
        'title': '更換房門門鎖',
        'description': '門鎖卡頓，已完成更換。',
        'reported_date': _date(now.subtract(const Duration(days: 18))),
        'status': '已完成'
      },
    ]) {
      await db.insert('repairs', row);
    }
  }

  Future<void> _syncLeaseStatuses(DatabaseExecutor db) async {
    await db.rawUpdate('''
      UPDATE leases SET status='已到期'
      WHERE status NOT IN ('已到期','已終止')
        AND date(end_date) < date('now','localtime')
    ''');
    await db.rawUpdate('''
      UPDATE leases SET status='即將到期'
      WHERE status NOT IN ('已到期','已終止')
        AND date(end_date) >= date('now','localtime')
        AND date(end_date) <= date('now','localtime','+3 months')
    ''');
    await db.rawUpdate('''
      UPDATE leases SET status='生效中'
      WHERE status='即將到期'
        AND date(end_date) > date('now','localtime','+3 months')
    ''');
  }

  Future<void> _ensureCurrentMonthPayments(DatabaseExecutor db) async {
    final currentMonth = _month(DateTime.now());
    await db.rawInsert('''
      INSERT OR IGNORE INTO payments(lease_id, month, amount, status, paid_date)
      SELECT id, ?, monthly_rent, '未繳', NULL
      FROM leases
      WHERE status NOT IN ('已到期','已終止')
        AND substr(start_date, 1, 7) <= ?
        AND substr(end_date, 1, 7) >= ?
        AND COALESCE(monthly_rent, 0) > 0
    ''', [currentMonth, currentMonth, currentMonth]);
    await db.rawUpdate('''
      UPDATE payments SET status='逾期'
      WHERE status='未繳' AND month < ?
    ''', [currentMonth]);
  }

  Future<void> _syncAutomations(DatabaseExecutor db) async {
    await _syncLeaseStatuses(db);
    await _ensureCurrentMonthPayments(db);
  }

  Future<List<Map<String, Object?>>> rows(String table) async {
    final db = await database;
    if (table == 'leases' || table == 'payments' || table == 'all_payments') {
      await _syncAutomations(db);
    }
    switch (table) {
      case 'tenants':
        return db.rawQuery('''SELECT t.*, h.name AS house_name FROM tenants t
          LEFT JOIN houses h ON h.id=t.house_id ORDER BY t.id DESC''');
      case 'leases':
        return db
            .rawQuery('''SELECT l.*, t.name AS tenant_name, h.name AS house_name
          FROM leases l LEFT JOIN tenants t ON t.id=l.tenant_id
          LEFT JOIN houses h ON h.id=l.house_id ORDER BY l.id DESC''');
      case 'payments':
        final currentMonth = _month(DateTime.now());
        return db
            .rawQuery('''SELECT p.*, t.name AS tenant_name, h.name AS house_name
          FROM payments p LEFT JOIN leases l ON l.id=p.lease_id
          LEFT JOIN tenants t ON t.id=l.tenant_id LEFT JOIN houses h ON h.id=l.house_id
          WHERE p.status!='已繳' AND p.month<=?
          ORDER BY p.month DESC, p.id DESC''', [currentMonth]);
      case 'all_payments':
        return db
            .rawQuery('''SELECT p.*, t.name AS tenant_name, h.name AS house_name
          FROM payments p LEFT JOIN leases l ON l.id=p.lease_id
          LEFT JOIN tenants t ON t.id=l.tenant_id LEFT JOIN houses h ON h.id=l.house_id
          ORDER BY p.month DESC, p.id DESC''');
      case 'repairs':
        return db
            .rawQuery('''SELECT r.*, t.name AS tenant_name, h.name AS house_name
          FROM repairs r LEFT JOIN tenants t ON t.id=r.tenant_id
          LEFT JOIN houses h ON h.id=r.house_id ORDER BY r.reported_date DESC''');
      default:
        return db.query(table, orderBy: 'id DESC');
    }
  }

  Future<int> insert(String table, Map<String, Object?> values) async =>
      (await database).insert(table, values);

  Future<({int tenantId, int leaseId, int paymentCount})>
      createTenantWithLease({
    required String name,
    required String phone,
    required int houseId,
    required String startDate,
    required String endDate,
    required num monthlyRent,
  }) async {
    if (monthlyRent <= 0) throw ArgumentError('每月租金必須大於 0');
    leaseCoversMonth(startDate, endDate, DateTime.now());
    final db = await database;

    return db.transaction((txn) async {
      final tenantId = await txn.insert('tenants', {
        'name': name,
        'phone': phone,
        'move_in': startDate,
        'house_id': houseId,
      });
      final leaseId = await txn.insert('leases', {
        'tenant_id': tenantId,
        'house_id': houseId,
        'start_date': startDate,
        'end_date': endDate,
        'monthly_rent': monthlyRent,
        'status': '生效中',
      });
      var paymentCount = 0;
      if (leaseCoversMonth(startDate, endDate, DateTime.now())) {
        await txn.insert(
            'payments',
            {
              'lease_id': leaseId,
              'month': _month(DateTime.now()),
              'amount': monthlyRent,
              'status': '未繳',
              'paid_date': null,
            },
            conflictAlgorithm: ConflictAlgorithm.ignore);
        paymentCount = 1;
      }
      await txn.update(
        'houses',
        {'status': '已出租'},
        where: 'id=?',
        whereArgs: [houseId],
      );
      return (
        tenantId: tenantId,
        leaseId: leaseId,
        paymentCount: paymentCount,
      );
    });
  }

  Future<int> update(String table, int id, Map<String, Object?> values) async {
    final db = await database;
    if (table != 'leases') {
      return db.update(table, values, where: 'id=?', whereArgs: [id]);
    }
    return db.transaction((txn) async {
      final count =
          await txn.update(table, values, where: 'id=?', whereArgs: [id]);
      await _syncAutomations(txn);
      final lease = (await txn.query(
        'leases',
        columns: ['monthly_rent'],
        where: 'id=?',
        whereArgs: [id],
      ))
          .first;
      await txn.update(
        'payments',
        {'amount': lease['monthly_rent']},
        where: "lease_id=? AND month=? AND status!='已繳'",
        whereArgs: [id, _month(DateTime.now())],
      );
      return count;
    });
  }

  Future<int> updatePayments(
    List<int> ids,
    Map<String, Object?> values,
  ) async {
    if (ids.isEmpty || values.isEmpty) return 0;
    final placeholders = List.filled(ids.length, '?').join(',');
    return (await database).update(
      'payments',
      values,
      where: 'id IN ($placeholders)',
      whereArgs: ids,
    );
  }

  Future<int> delete(String table, int id) async =>
      (await database).delete(table, where: 'id=?', whereArgs: [id]);

  Future<List<Map<String, Object?>>> options(String table) async {
    if (table == 'leases') {
      return (await database).rawQuery('''SELECT l.id,
        t.name || '｜' || h.name AS name FROM leases l
        JOIN tenants t ON t.id=l.tenant_id JOIN houses h ON h.id=l.house_id
        ORDER BY t.name''');
    }
    if (table == 'houses') {
      return (await database)
          .query(table, columns: ['id', 'name', 'rent'], orderBy: 'name');
    }
    return (await database)
        .query(table, columns: ['id', 'name'], orderBy: 'name');
  }

  Future<List<Map<String, Object?>>> tenantsForHouse(int houseId) async =>
      (await database).query(
        'tenants',
        columns: ['id', 'name'],
        where: 'house_id=?',
        whereArgs: [houseId],
        orderBy: 'name',
      );

  Future<Map<String, num>> dashboard() async {
    final db = await database;
    await _syncAutomations(db);
    final month = _month(DateTime.now());
    Future<num> value(String sql, [List<Object?>? args]) async =>
        ((await db.rawQuery(sql, args)).first.values.first as num?) ?? 0;
    return {
      'rented': await value("SELECT COUNT(*) FROM houses WHERE status='已出租'"),
      'income': await value(
          "SELECT COALESCE(SUM(amount),0) FROM payments WHERE month=? AND status='已繳'",
          [month]),
      'unpaid': await value(
          "SELECT COUNT(*) FROM payments WHERE month=? AND status!='已繳'",
          [month]),
      'repairs':
          await value("SELECT COUNT(*) FROM repairs WHERE status!='已完成'"),
      'expiring':
          await value("SELECT COUNT(*) FROM leases WHERE status='即將到期'"),
    };
  }

  Future<List<Map<String, String>>> reminders() async {
    final result = <Map<String, String>>[];
    final now = DateTime.now();
    final currentMonth = _month(now);
    for (final row in await rows('leases')) {
      final end = DateTime.tryParse('${row['end_date']}');
      if (end == null || ['已到期', '已終止'].contains(row['status'])) continue;
      final today = DateTime(now.year, now.month, now.day);
      final threeMonthsLater = DateTime(now.year, now.month + 3, now.day);
      final days = end.difference(today).inDays;
      if (!end.isBefore(today) && !end.isAfter(threeMonthsLater)) {
        result.add({
          'type': '租約',
          'title': '${row['tenant_name']}的租約即將到期',
          'detail': '${row['house_name']}｜剩餘 $days 天｜${row['end_date']}',
          'level': 'warning'
        });
      }
    }
    for (final row in await rows('payments')) {
      if (row['status'] == '已繳' ||
          '${row['month']}'.compareTo(currentMonth) > 0) {
        continue;
      }
      result.add({
        'type': '租金',
        'title': '${row['tenant_name']}租金${row['status']}',
        'detail': '${row['month']}｜${row['house_name']}｜NT\$ ${row['amount']}',
        'level': row['status'] == '逾期' ? 'danger' : 'warning'
      });
    }
    for (final row in await rows('repairs')) {
      if (row['status'] == '已完成') continue;
      result.add({
        'type': '報修',
        'title': '${row['title']}',
        'detail':
            '${row['house_name']}｜${row['status']}｜${row['reported_date']}',
        'level': row['status'] == '待處理' ? 'danger' : 'info'
      });
    }
    return result;
  }

  Future<List<Map<String, String>>> search(String keyword) async {
    final q = keyword.trim().toLowerCase();
    if (q.isEmpty) return [];
    final result = <Map<String, String>>[];
    void add(String type, String title, String detail) {
      if ('$title $detail'.toLowerCase().contains(q)) {
        result.add({'type': type, 'title': title, 'detail': detail});
      }
    }

    for (final r in await rows('houses'))
      add('房屋', '${r['name']}', '${r['address']}｜${r['status']}');
    for (final r in await rows('tenants'))
      add('房客', '${r['name']}', '${r['phone']}｜${r['house_name']}');
    for (final r in await rows('leases'))
      add('租約', '${r['tenant_name']}',
          '${r['house_name']}｜${r['start_date']} 至 ${r['end_date']}｜${r['status']}');
    for (final r in await rows('payments'))
      add('租金', '${r['tenant_name']}｜${r['house_name']}',
          '${r['month']}｜${r['amount']}｜${r['status']}');
    for (final r in await rows('repairs'))
      add('報修', '${r['title']}',
          '${r['house_name']}｜${r['status']}｜${r['description'] ?? ''}');
    return result;
  }

  String _xml(Object? value) =>
      const HtmlEscape(HtmlEscapeMode.element).convert(value?.toString() ?? '');

  Future<File> exportExcel() async {
    final sheets =
        <({String name, List<String> headers, List<List<Object?>> rows})>[];
    final houses = await rows('houses');
    sheets.add((
      name: '房屋',
      headers: ['房屋名稱', '地址', '每月租金', '押金', '狀態'],
      rows: houses
          .map((r) =>
              [r['name'], r['address'], r['rent'], r['deposit'], r['status']])
          .toList()
    ));
    final tenants = await rows('tenants');
    sheets.add((
      name: '房客',
      headers: ['姓名', '電話', '入住日期', '租住房屋'],
      rows: tenants
          .map((r) => [r['name'], r['phone'], r['move_in'], r['house_name']])
          .toList()
    ));
    final leases = await rows('leases');
    sheets.add((
      name: '租約',
      headers: ['房客', '房屋', '開始日期', '結束日期', '狀態'],
      rows: leases
          .map((r) => [
                r['tenant_name'],
                r['house_name'],
                r['start_date'],
                r['end_date'],
                r['status']
              ])
          .toList()
    ));
    final payments = await rows('all_payments');
    sheets.add((
      name: '租金',
      headers: ['月份', '房客', '房屋', '金額', '狀態', '繳款日期'],
      rows: payments
          .map((r) => [
                r['month'],
                r['tenant_name'],
                r['house_name'],
                r['amount'],
                r['status'],
                r['paid_date']
              ])
          .toList()
    ));
    final repairs = await rows('repairs');
    sheets.add((
      name: '報修',
      headers: ['問題', '房屋', '房客', '提報日期', '狀態', '說明'],
      rows: repairs
          .map((r) => [
                r['title'],
                r['house_name'],
                r['tenant_name'],
                r['reported_date'],
                r['status'],
                r['description']
              ])
          .toList()
    ));

    String cell(Object? value, {bool header = false}) {
      final type = value is num ? 'Number' : 'String';
      return '<Cell ss:StyleID="${header ? 'Header' : 'Cell'}"><Data ss:Type="$type">${_xml(value)}</Data></Cell>';
    }

    final worksheets = sheets
        .map((s) => '<Worksheet ss:Name="${s.name}"><Table>'
            '<Row>${s.headers.map((h) => cell(h, header: true)).join()}</Row>'
            '${s.rows.map((r) => '<Row>${r.map((v) => cell(v)).join()}</Row>').join()}'
            '</Table></Worksheet>')
        .join();
    final xml = '<?xml version="1.0" encoding="UTF-8"?>'
        '<Workbook xmlns="urn:schemas-microsoft-com:office:spreadsheet" '
        'xmlns:ss="urn:schemas-microsoft-com:office:spreadsheet">'
        '<Styles><Style ss:ID="Header"><Font ss:Bold="1" ss:Color="#FFFFFF"/>'
        '<Interior ss:Color="#257262" ss:Pattern="Solid"/></Style>'
        '<Style ss:ID="Cell"/></Styles>$worksheets</Workbook>';
    final dir = await getApplicationDocumentsDirectory();
    final file = File(join(dir.path, '房東助手_${_date(DateTime.now())}.xls'));
    return file.writeAsString(xml, encoding: utf8);
  }

  Future<void> shareExcel() async {
    final file = await exportExcel();
    await Share.shareXFiles([XFile(file.path)], text: '房東助手管理資料');
  }
}
