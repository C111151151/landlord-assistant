import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import 'database_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const LandlordAssistantApp());
}

const darkGreen = Color(0xFF17453C);
const green = Color(0xFF257262);
const mint = Color(0xFFDCEFE8);
const canvas = Color(0xFFF3F6F4);

class LandlordAssistantApp extends StatelessWidget {
  const LandlordAssistantApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '房東助手',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: green,
          primary: green,
          surface: Colors.white,
        ),
        scaffoldBackgroundColor: canvas,
        appBarTheme: const AppBarTheme(
          backgroundColor: canvas,
          foregroundColor: darkGreen,
          elevation: 0,
          centerTitle: false,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFDCE5E2)),
          ),
        ),
        cardTheme: CardTheme(
          color: Colors.white,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            side: const BorderSide(color: Color(0xFFE2EAE7)),
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      home: const HomeShell(),
    );
  }
}

class NavItem {
  const NavItem(this.label, this.icon);
  final String label;
  final IconData icon;
}

const navItems = [
  NavItem('總覽', Icons.dashboard_rounded),
  NavItem('房屋管理', Icons.apartment_rounded),
  NavItem('房客管理', Icons.people_alt_rounded),
  NavItem('租約管理', Icons.description_rounded),
  NavItem('未繳租金', Icons.payments_rounded),
  NavItem('報修管理', Icons.build_circle_rounded),
  NavItem('到期提醒', Icons.notifications_active_rounded),
  NavItem('全域搜尋', Icons.search_rounded),
  NavItem('匯出 Excel', Icons.file_download_rounded),
];

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int index = 0;
  int refreshVersion = 0;

  void select(int value) {
    setState(() => index = value);
    Navigator.maybePop(context);
  }

  void refresh() => setState(() => refreshVersion++);

  Widget page() {
    switch (index) {
      case 0:
        return DashboardPage(key: ValueKey(refreshVersion), onNavigate: select);
      case 1:
        return EntityPage(
            key: ValueKey('houses-$refreshVersion'),
            config: EntityConfig.houses,
            onChanged: refresh);
      case 2:
        return EntityPage(
            key: ValueKey('tenants-$refreshVersion'),
            config: EntityConfig.tenants,
            onChanged: refresh);
      case 3:
        return EntityPage(
            key: ValueKey('leases-$refreshVersion'),
            config: EntityConfig.leases,
            onChanged: refresh);
      case 4:
        return EntityPage(
            key: ValueKey('payments-$refreshVersion'),
            config: EntityConfig.payments,
            onChanged: refresh);
      case 5:
        return EntityPage(
            key: ValueKey('repairs-$refreshVersion'),
            config: EntityConfig.repairs,
            onChanged: refresh);
      case 6:
        return RemindersPage(key: ValueKey(refreshVersion));
      case 7:
        return const SearchPage();
      default:
        return const ExportPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(navItems[index].label,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
            )),
        actions: [
          IconButton(
            tooltip: '到期提醒',
            onPressed: () => select(6),
            icon: const Icon(Icons.notifications_none_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      drawer: NavigationDrawer(
        selectedIndex: index,
        onDestinationSelected: select,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(28, 28, 28, 18),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Color(0xFFF6E9CF),
                  foregroundColor: darkGreen,
                  child: Icon(Icons.home_work_rounded),
                ),
                SizedBox(width: 12),
                Text(
                  '房東助手',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          ...navItems.map((item) => NavigationDrawerDestination(
              icon: Icon(item.icon), label: Text(item.label))),
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text('Flutter + SQLite',
                style: TextStyle(color: Colors.black45, fontSize: 12)),
          ),
        ],
      ),
      body: SafeArea(child: page()),
    );
  }
}

String money(Object? value) {
  final text =
      ((value as num?) ?? num.tryParse('$value') ?? 0).round().toString();
  return 'NT\$ ${text.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',')}';
}

Color statusColor(String status) {
  if (['已出租', '生效中', '已繳', '已完成'].contains(status))
    return const Color(0xFF24705F);
  if (['逾期', '已到期', '已終止'].contains(status)) return const Color(0xFFB24B4B);
  if (status == '處理中') return const Color(0xFF4776A8);
  return const Color(0xFFB3682C);
}

Widget statusChip(Object? value) {
  final text = '$value';
  final color = statusColor(text);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
        color: color.withOpacity(.12), borderRadius: BorderRadius.circular(99)),
    child: Text(text,
        style:
            TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12)),
  );
}

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key, required this.onNavigate});
  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<(Map<String, num>, List<Map<String, String>>)>(
      future: Future.wait<dynamic>([
        DatabaseService.instance.dashboard(),
        DatabaseService.instance.reminders(),
      ]).then(
          (v) => (v[0] as Map<String, num>, v[1] as List<Map<String, String>>)),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        final stats = snapshot.data!.$1;
        final reminders = snapshot.data!.$2;
        final items = [
          (
            '出租房數',
            '${stats['rented']?.toInt() ?? 0}',
            '間',
            Icons.apartment_rounded,
            const Color(0xFF4C9A87)
          ),
          (
            '本月收入',
            money(stats['income']),
            '已入帳',
            Icons.payments_rounded,
            const Color(0xFF4776A8)
          ),
          (
            '未繳租金',
            '${stats['unpaid']?.toInt() ?? 0}',
            '筆待追蹤',
            Icons.warning_amber_rounded,
            const Color(0xFFD57A2F)
          ),
          (
            '待處理報修',
            '${stats['repairs']?.toInt() ?? 0}',
            '件未完成',
            Icons.build_rounded,
            const Color(0xFFC55353)
          ),
          (
            '即將到期租約',
            '${stats['expiring']?.toInt() ?? 0}',
            '份（3 個月內）',
            Icons.event_busy_rounded,
            const Color(0xFF98702E)
          ),
        ];
        return RefreshIndicator(
          onRefresh: () async => (context as Element).markNeedsBuild(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 32),
            children: [
              Text('今天也把房務整理得井井有條。',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: Colors.black54)),
              const SizedBox(height: 18),
              LayoutBuilder(builder: (context, c) {
                final width = c.maxWidth > 900
                    ? (c.maxWidth - 48) / 5
                    : c.maxWidth > 560
                        ? (c.maxWidth - 16) / 2
                        : c.maxWidth;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: items
                      .map((x) => SizedBox(
                          width: width,
                          child: MetricCard(
                              title: x.$1,
                              value: x.$2,
                              note: x.$3,
                              icon: x.$4,
                              color: x.$5)))
                      .toList(),
                );
              }),
              const SizedBox(height: 20),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                              child: Text('重要提醒',
                                  style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700))),
                          TextButton(
                              onPressed: () => onNavigate(6),
                              child: const Text('查看全部')),
                        ],
                      ),
                      const SizedBox(height: 6),
                      if (reminders.isEmpty)
                        const Padding(
                            padding: EdgeInsets.all(24),
                            child: Center(child: Text('目前沒有待辦提醒')))
                      else
                        ...reminders.take(5).map((r) => ReminderTile(data: r)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class MetricCard extends StatelessWidget {
  const MetricCard(
      {super.key,
      required this.title,
      required this.value,
      required this.note,
      required this.icon,
      required this.color});
  final String title;
  final String value;
  final String note;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                  child: Text(title,
                      style: const TextStyle(
                          color: Colors.black54, fontWeight: FontWeight.w700))),
              Icon(icon, color: color)
            ]),
            const SizedBox(height: 18),
            Text(value,
                style:
                    const TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
            const SizedBox(height: 3),
            Text(note,
                style: const TextStyle(color: Colors.black54, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

enum FieldKind { text, number, phone, date, month, select, relation, multiline }

class FieldSpec {
  const FieldSpec(this.key, this.label, this.kind,
      {this.required = true,
      this.options = const [],
      this.relationTable,
      this.createOnly = false});
  final String key;
  final String label;
  final FieldKind kind;
  final bool required;
  final List<String> options;
  final String? relationTable;
  final bool createOnly;
}

class EntityConfig {
  const EntityConfig(
      this.table, this.singular, this.subtitle, this.icon, this.fields);
  final String table;
  final String singular;
  final String subtitle;
  final IconData icon;
  final List<FieldSpec> fields;

  static const houses = EntityConfig(
      'houses', '房屋', '管理物件地址、租金、押金與出租狀態', Icons.apartment_rounded, [
    FieldSpec('name', '房屋名稱', FieldKind.text),
    FieldSpec('address', '地址', FieldKind.multiline),
    FieldSpec('rent', '每月租金', FieldKind.number),
    FieldSpec('deposit', '押金', FieldKind.number),
    FieldSpec('status', '房屋狀態', FieldKind.select,
        options: ['可出租', '已出租', '維修中']),
  ]);
  static const tenants = EntityConfig(
      'tenants', '房客', '新增房客時同步建立租約與每期租金', Icons.people_alt_rounded, [
    FieldSpec('name', '房客姓名', FieldKind.text),
    FieldSpec('phone', '聯絡電話', FieldKind.phone),
    FieldSpec('house_id', '租住房屋', FieldKind.relation, relationTable: 'houses'),
    FieldSpec('move_in', '入住日期', FieldKind.date),
    FieldSpec('lease_end', '租約結束日期', FieldKind.date, createOnly: true),
    FieldSpec('monthly_rent', '每月租金', FieldKind.number, createOnly: true),
  ]);
  static const leases = EntityConfig(
      'leases', '租約', '連結房客與房屋，追蹤租期及合約狀態', Icons.description_rounded, [
    FieldSpec('tenant_id', '房客', FieldKind.relation, relationTable: 'tenants'),
    FieldSpec('house_id', '房屋', FieldKind.relation, relationTable: 'houses'),
    FieldSpec('start_date', '開始日期', FieldKind.date),
    FieldSpec('end_date', '結束日期', FieldKind.date),
    FieldSpec('monthly_rent', '每月租金', FieldKind.number),
    FieldSpec('status', '租約狀態', FieldKind.select,
        options: ['生效中', '即將到期', '已到期', '已終止']),
  ]);
  static const payments = EntityConfig(
      'payments', '未繳租金', '每月依租約自動產生，繳清後即移出清單', Icons.payments_rounded, [
    FieldSpec('lease_id', '租約', FieldKind.relation, relationTable: 'leases'),
    FieldSpec('month', '租金月份', FieldKind.month),
    FieldSpec('amount', '應繳金額', FieldKind.number),
    FieldSpec('status', '繳款狀態', FieldKind.select, options: ['已繳', '未繳', '逾期']),
    FieldSpec('paid_date', '繳款日期', FieldKind.date, required: false),
  ]);
  static const repairs = EntityConfig(
      'repairs', '報修單', '記錄房屋問題並追蹤處理進度', Icons.build_circle_rounded, [
    FieldSpec('title', '問題標題', FieldKind.text),
    FieldSpec('house_id', '房屋', FieldKind.relation, relationTable: 'houses'),
    FieldSpec('tenant_id', '提報房客', FieldKind.relation,
        relationTable: 'tenants', required: false),
    FieldSpec('reported_date', '提報日期', FieldKind.date),
    FieldSpec('status', '處理狀態', FieldKind.select,
        options: ['待處理', '處理中', '已完成']),
    FieldSpec('description', '問題說明', FieldKind.multiline, required: false),
  ]);
}

class EntityPage extends StatefulWidget {
  const EntityPage({super.key, required this.config, required this.onChanged});
  final EntityConfig config;
  final VoidCallback onChanged;

  @override
  State<EntityPage> createState() => _EntityPageState();
}

class _EntityPageState extends State<EntityPage> {
  String query = '';
  bool paymentSelectionMode = false;
  final selectedPaymentIds = <int>{};

  Future<List<Map<String, Object?>>> load() =>
      DatabaseService.instance.rows(widget.config.table);

  String title(Map<String, Object?> r) => switch (widget.config.table) {
        'houses' => '${r['name']}',
        'tenants' => '${r['name']}',
        'leases' => '${r['tenant_name']}｜${r['house_name']}',
        'payments' => '${r['month']}｜${r['tenant_name']}',
        'repairs' => '${r['title']}',
        _ => '',
      };

  String subtitle(Map<String, Object?> r) => switch (widget.config.table) {
        'houses' =>
          '${r['address']}\n月租 ${money(r['rent'])}｜押金 ${money(r['deposit'])}',
        'tenants' => '${r['phone']}｜${r['house_name']}\n入住日 ${r['move_in']}',
        'leases' => '${r['start_date']} 至 ${r['end_date']}',
        'payments' =>
          '${r['house_name']}｜${money(r['amount'])}${r['paid_date'] == null ? '' : '\n繳款日 ${r['paid_date']}'}',
        'repairs' =>
          '${r['house_name']}｜${r['tenant_name'] ?? '未指定房客'}\n${r['description'] ?? ''}',
        _ => '',
      };

  void togglePaymentSelection(int id) {
    setState(() {
      if (!selectedPaymentIds.add(id)) selectedPaymentIds.remove(id);
    });
  }

  void setPaymentSelectionMode(bool enabled, [int? initialId]) {
    setState(() {
      paymentSelectionMode = enabled;
      selectedPaymentIds.clear();
      if (enabled && initialId != null) selectedPaymentIds.add(initialId);
    });
  }

  Future<void> editSelectedPayments() async {
    if (selectedPaymentIds.isEmpty) return;
    var status = '不變';
    String? formError;
    final amountController = TextEditingController();
    final now = DateTime.now();
    final paidDateController = TextEditingController(
      text:
          '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
    );
    final formKey = GlobalKey<FormState>();

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('批次編輯 ${selectedPaymentIds.length} 筆租金'),
          content: SizedBox(
            width: 480,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: status,
                      decoration: const InputDecoration(labelText: '繳款狀態'),
                      items: const ['不變', '已繳', '未繳', '逾期']
                          .map((value) => DropdownMenuItem(
                                value: value,
                                child: Text(value == '不變' ? '保持原狀' : value),
                              ))
                          .toList(),
                      onChanged: (value) => setDialogState(() {
                        status = value ?? '不變';
                        formError = null;
                      }),
                    ),
                    const SizedBox(height: 13),
                    if (status == '已繳')
                      TextFormField(
                        controller: paidDateController,
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: '繳款日期',
                          suffixIcon: Icon(Icons.calendar_month_rounded),
                        ),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate:
                                DateTime.tryParse(paidDateController.text) ??
                                    now,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            setDialogState(() {
                              paidDateController.text =
                                  '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                            });
                          }
                        },
                      ),
                    if (status == '已繳') const SizedBox(height: 13),
                    TextFormField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: '應繳金額（選填）',
                        helperText: '留空表示不修改金額',
                      ),
                      validator: (value) {
                        final text = value?.trim() ?? '';
                        if (text.isNotEmpty && (num.tryParse(text) ?? 0) <= 0) {
                          return '應繳金額必須大於 0';
                        }
                        return null;
                      },
                    ),
                    if (formError != null) ...[
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          formError!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                if (status == '不變' && amountController.text.trim().isEmpty) {
                  setDialogState(() => formError = '請至少修改一個欄位');
                  return;
                }
                Navigator.pop(context, true);
              },
              child: const Text('套用'),
            ),
          ],
        ),
      ),
    );

    if (saved != true) {
      amountController.dispose();
      paidDateController.dispose();
      return;
    }

    final values = <String, Object?>{};
    if (status != '不變') {
      values['status'] = status;
      values['paid_date'] = status == '已繳' ? paidDateController.text : null;
    }
    final amount = num.tryParse(amountController.text.trim());
    if (amount != null) values['amount'] = amount;
    final count = await DatabaseService.instance.updatePayments(
      selectedPaymentIds.toList(),
      values,
    );
    amountController.dispose();
    paidDateController.dispose();
    if (!mounted) return;
    setState(() {
      paymentSelectionMode = false;
      selectedPaymentIds.clear();
    });
    widget.onChanged();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已更新 $count 筆租金紀錄')),
    );
  }

  Future<void> openForm([Map<String, Object?>? row]) async {
    final formFields = widget.config.fields
        .where((field) => row == null || !field.createOnly)
        .toList();
    final relations = <String, List<Map<String, Object?>>>{};
    for (final field in formFields.where((f) => f.kind == FieldKind.relation)) {
      if (widget.config.table == 'repairs' && field.key == 'tenant_id') {
        final houseId = row?['house_id'] as int?;
        relations[field.key] = houseId == null
            ? []
            : await DatabaseService.instance.tenantsForHouse(houseId);
      } else {
        relations[field.key] =
            await DatabaseService.instance.options(field.relationTable!);
      }
    }
    if (!mounted) return;
    final values = <String, Object?>{};
    for (final field in formFields) {
      values[field.key] = row?[field.key];
    }
    final controllers = <String, TextEditingController>{};
    for (final field in formFields.where(
        (f) => ![FieldKind.select, FieldKind.relation].contains(f.kind))) {
      controllers[field.key] =
          TextEditingController(text: values[field.key]?.toString() ?? '');
    }
    final formKey = GlobalKey<FormState>();
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('${row == null ? '新增' : '編輯'}${widget.config.singular}'),
          content: SizedBox(
            width: 520,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: formFields.map((field) {
                    final validator = (Object? value) {
                      final text = value?.toString().trim() ?? '';
                      if (field.required && text.isEmpty) {
                        return '請填寫${field.label}';
                      }
                      if (field.kind == FieldKind.number &&
                          field.required &&
                          (num.tryParse(text) ?? 0) <= 0) {
                        return '${field.label}必須大於 0';
                      }
                      if (field.key == 'lease_end' && text.isNotEmpty) {
                        final start = DateTime.tryParse(
                            controllers['move_in']?.text ?? '');
                        final end = DateTime.tryParse(text);
                        if (start != null &&
                            end != null &&
                            end.isBefore(start)) {
                          return '租約結束日期不可早於入住日期';
                        }
                      }
                      return null;
                    };
                    Widget input;
                    if (field.kind == FieldKind.select) {
                      input = DropdownButtonFormField<String>(
                        value: values[field.key] as String?,
                        decoration: InputDecoration(labelText: field.label),
                        items: field.options
                            .map((o) =>
                                DropdownMenuItem(value: o, child: Text(o)))
                            .toList(),
                        onChanged: (v) =>
                            setDialogState(() => values[field.key] = v),
                        validator: validator,
                      );
                    } else if (field.kind == FieldKind.relation) {
                      input = DropdownButtonFormField<int>(
                        value: values[field.key] as int?,
                        decoration: InputDecoration(labelText: field.label),
                        items: relations[field.key]!
                            .map((o) => DropdownMenuItem(
                                value: o['id'] as int,
                                child: Text('${o['name']}')))
                            .toList(),
                        onChanged: (v) async {
                          setDialogState(() {
                            values[field.key] = v;
                            if (widget.config.table == 'tenants' &&
                                row == null &&
                                field.key == 'house_id' &&
                                v != null) {
                              final selected = relations[field.key]!.firstWhere(
                                (option) => option['id'] == v,
                              );
                              final rent = selected['rent'];
                              if (rent != null) {
                                controllers['monthly_rent']?.text =
                                    rent is num && rent == rent.roundToDouble()
                                        ? rent.toInt().toString()
                                        : rent.toString();
                              }
                            }
                          });
                          if (widget.config.table == 'repairs' &&
                              field.key == 'house_id') {
                            final tenants = v == null
                                ? <Map<String, Object?>>[]
                                : await DatabaseService.instance
                                    .tenantsForHouse(v);
                            if (!context.mounted) return;
                            setDialogState(() {
                              relations['tenant_id'] = tenants;
                              values['tenant_id'] = null;
                            });
                          }
                        },
                        validator: validator,
                      );
                    } else {
                      final controller = controllers[field.key]!;
                      input = TextFormField(
                        controller: controller,
                        readOnly: [FieldKind.date, FieldKind.month]
                            .contains(field.kind),
                        maxLines: field.kind == FieldKind.multiline ? 3 : 1,
                        keyboardType: field.kind == FieldKind.number
                            ? TextInputType.number
                            : field.kind == FieldKind.phone
                                ? TextInputType.phone
                                : TextInputType.text,
                        decoration: InputDecoration(
                          labelText: field.label,
                          suffixIcon: [FieldKind.date, FieldKind.month]
                                  .contains(field.kind)
                              ? const Icon(Icons.calendar_month_rounded)
                              : null,
                        ),
                        validator: validator,
                        onTap: [FieldKind.date, FieldKind.month]
                                .contains(field.kind)
                            ? () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: DateTime.tryParse(
                                          controller.text.length == 7
                                              ? '${controller.text}-01'
                                              : controller.text) ??
                                      DateTime.now(),
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime(2100),
                                );
                                if (picked != null) {
                                  final text =
                                      '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}${field.kind == FieldKind.date ? '-${picked.day.toString().padLeft(2, '0')}' : ''}';
                                  setDialogState(() => controller.text = text);
                                }
                              }
                            : null,
                      );
                    }
                    return Padding(
                        padding: const EdgeInsets.only(bottom: 13),
                        child: input);
                  }).toList(),
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消')),
            FilledButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                Navigator.pop(context, true);
              },
              child: const Text('儲存'),
            ),
          ],
        ),
      ),
    );
    if (saved != true) {
      for (final c in controllers.values) c.dispose();
      return;
    }
    for (final field in formFields) {
      if ([FieldKind.select, FieldKind.relation].contains(field.kind)) continue;
      final text = controllers[field.key]!.text.trim();
      values[field.key] = field.kind == FieldKind.number
          ? num.tryParse(text) ?? 0
          : (text.isEmpty ? null : text);
    }
    if (widget.config.table == 'payments' && values['status'] != '已繳')
      values['paid_date'] = null;
    var successMessage = '${widget.config.singular}已儲存';
    if (row == null && widget.config.table == 'tenants') {
      final result = await DatabaseService.instance.createTenantWithLease(
        name: values['name'] as String,
        phone: values['phone'] as String,
        houseId: values['house_id'] as int,
        startDate: values['move_in'] as String,
        endDate: values['lease_end'] as String,
        monthlyRent: values['monthly_rent'] as num,
      );
      successMessage =
          result.paymentCount == 0 ? '房客與租約已建立；租金將於入住月份產生' : '房客、租約及本月未繳租金已建立';
    } else if (row == null) {
      await DatabaseService.instance.insert(widget.config.table, values);
    } else {
      await DatabaseService.instance
          .update(widget.config.table, row['id'] as int, values);
    }
    for (final c in controllers.values) c.dispose();
    if (mounted) {
      setState(() {});
      widget.onChanged();
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(successMessage)));
    }
  }

  Future<void> remove(Map<String, Object?> row) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('刪除${widget.config.singular}？'),
        content: const Text('刪除後無法復原；若資料仍被其他紀錄使用，系統會保護資料並拒絕刪除。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('刪除')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await DatabaseService.instance
          .delete(widget.config.table, row['id'] as int);
      setState(() {});
      widget.onChanged();
    } on DatabaseException {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('無法刪除：此資料仍被其他紀錄使用')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.config.subtitle,
                  style: const TextStyle(color: Colors.black54)),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (widget.config.table == 'payments')
                    OutlinedButton.icon(
                      onPressed: () =>
                          setPaymentSelectionMode(!paymentSelectionMode),
                      icon: Icon(paymentSelectionMode
                          ? Icons.close_rounded
                          : Icons.checklist_rounded),
                      label: Text(paymentSelectionMode ? '取消多選' : '多選編輯'),
                    ),
                  if (widget.config.table != 'payments')
                    FilledButton.icon(
                      onPressed: () => openForm(),
                      icon: const Icon(Icons.add),
                      label: Text('新增${widget.config.singular}'),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: '搜尋${widget.config.singular}資料'),
                onChanged: (v) => setState(() => query = v.toLowerCase()),
              ),
            ],
          ),
        ),
        if (widget.config.table == 'payments' && paymentSelectionMode)
          Container(
            margin: const EdgeInsets.fromLTRB(18, 0, 18, 12),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: mint,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFC8E0D8)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '已選 ${selectedPaymentIds.length} 筆',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                TextButton(
                  onPressed: selectedPaymentIds.isEmpty
                      ? null
                      : () => setState(selectedPaymentIds.clear),
                  child: const Text('清除'),
                ),
                const SizedBox(width: 6),
                FilledButton.icon(
                  onPressed:
                      selectedPaymentIds.isEmpty ? null : editSelectedPayments,
                  icon: const Icon(Icons.edit_rounded),
                  label: const Text('批次編輯'),
                ),
              ],
            ),
          ),
        Expanded(
          child: FutureBuilder<List<Map<String, Object?>>>(
            future: load(),
            builder: (context, snapshot) {
              if (!snapshot.hasData)
                return const Center(child: CircularProgressIndicator());
              final rows = snapshot.data!
                  .where((r) => '$r'.toLowerCase().contains(query))
                  .toList();
              if (rows.isEmpty) return const Center(child: Text('找不到符合條件的資料'));
              return RefreshIndicator(
                onRefresh: () async => setState(() {}),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 32),
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final row = rows[i];
                    final id = row['id'] as int;
                    final selected = selectedPaymentIds.contains(id);
                    return Card(
                      child: ListTile(
                        selected: selected,
                        selectedTileColor: mint.withOpacity(.55),
                        onTap: paymentSelectionMode
                            ? () => togglePaymentSelection(id)
                            : null,
                        onLongPress: widget.config.table == 'payments'
                            ? () => setPaymentSelectionMode(true, id)
                            : null,
                        contentPadding:
                            const EdgeInsets.fromLTRB(16, 10, 6, 10),
                        leading: paymentSelectionMode
                            ? Checkbox(
                                value: selected,
                                onChanged: (_) => togglePaymentSelection(id),
                              )
                            : CircleAvatar(
                                backgroundColor: mint,
                                foregroundColor: darkGreen,
                                child: Icon(widget.config.icon)),
                        title: Text(title(row),
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            )),
                        subtitle: Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(subtitle(row))),
                        trailing: paymentSelectionMode
                            ? (row['status'] == null
                                ? null
                                : statusChip(row['status']))
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (row['status'] != null)
                                    statusChip(row['status']),
                                  PopupMenuButton<String>(
                                    onSelected: (value) => value == 'edit'
                                        ? openForm(row)
                                        : remove(row),
                                    itemBuilder: (_) => const [
                                      PopupMenuItem(
                                          value: 'edit', child: Text('編輯')),
                                      PopupMenuItem(
                                          value: 'delete', child: Text('刪除')),
                                    ],
                                  ),
                                ],
                              ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class ReminderTile extends StatelessWidget {
  const ReminderTile({super.key, required this.data});
  final Map<String, String> data;

  @override
  Widget build(BuildContext context) {
    final color = data['level'] == 'danger'
        ? const Color(0xFFC55353)
        : data['level'] == 'info'
            ? const Color(0xFF4776A8)
            : const Color(0xFFD57A2F);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: CircleAvatar(
        backgroundColor: color.withOpacity(.12),
        foregroundColor: color,
        child: Icon(data['type'] == '租金'
            ? Icons.payments_rounded
            : data['type'] == '租約'
                ? Icons.event_busy_rounded
                : Icons.build_rounded),
      ),
      title: Text(data['title']!,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
      subtitle: Text(data['detail']!),
    );
  }
}

class RemindersPage extends StatelessWidget {
  const RemindersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, String>>>(
      future: DatabaseService.instance.reminders(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        final rows = snapshot.data!;
        return ListView(
          padding: const EdgeInsets.all(18),
          children: [
            const Text('自動彙整 3 個月內到期租約、當月未繳租金與未完成報修。',
                style: TextStyle(color: Colors.black54)),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: rows.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(28),
                        child: Center(child: Text('目前沒有待辦提醒')))
                    : Column(
                        children:
                            rows.map((r) => ReminderTile(data: r)).toList()),
              ),
            ),
          ],
        );
      },
    );
  }
}

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final controller = TextEditingController();
  List<Map<String, String>> results = [];
  bool loading = false;

  Future<void> run() async {
    setState(() => loading = true);
    results = await DatabaseService.instance.search(controller.text);
    if (mounted) setState(() => loading = false);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Card(
          color: darkGreen,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('一次搜尋所有管理資料',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  onSubmitted: (_) => run(),
                  decoration: InputDecoration(
                    hintText: '可搜尋房屋、房客、租約、租金與報修紀錄',
                    suffixIcon: IconButton(
                        onPressed: run, icon: const Icon(Icons.search)),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (loading)
          const Center(child: CircularProgressIndicator())
        else if (controller.text.isNotEmpty && results.isEmpty)
          const Padding(
              padding: EdgeInsets.all(30),
              child: Center(child: Text('找不到符合條件的資料')))
        else
          ...results.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Card(
                  child: ListTile(
                    leading: CircleAvatar(
                        backgroundColor: mint,
                        foregroundColor: darkGreen,
                        child: Text(r['type']!.substring(0, 1))),
                    title: Text(r['title']!,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        )),
                    subtitle: Text(r['detail']!),
                    trailing: Text(r['type']!,
                        style: const TextStyle(
                            color: green, fontWeight: FontWeight.w700)),
                  ),
                ),
              )),
      ],
    );
  }
}

class ExportPage extends StatefulWidget {
  const ExportPage({super.key});

  @override
  State<ExportPage> createState() => _ExportPageState();
}

class _ExportPageState extends State<ExportPage> {
  bool exporting = false;

  Future<void> export() async {
    setState(() => exporting = true);
    try {
      await DatabaseService.instance.shareExcel();
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Excel 檔案已建立')));
    } finally {
      if (mounted) setState(() => exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              children: [
                const CircleAvatar(
                    radius: 34,
                    backgroundColor: mint,
                    foregroundColor: darkGreen,
                    child: Icon(Icons.table_view_rounded, size: 34)),
                const SizedBox(height: 16),
                const Text('匯出完整管理資料',
                    style:
                        TextStyle(fontSize: 23, fontWeight: FontWeight.w700)),
                const SizedBox(height: 9),
                const Text('產生 Excel 可開啟的 .xls 活頁簿，包含房屋、房客、租約、租金與報修 5 個工作表。',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black54, height: 1.6)),
                const SizedBox(height: 22),
                FilledButton.icon(
                  onPressed: exporting ? null : export,
                  icon: exporting
                      ? const SizedBox.square(
                          dimension: 17,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.ios_share_rounded),
                  label: const Text('匯出並分享 Excel'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
