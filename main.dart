import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';

void main() => runApp(const ExpenseSplitterApp());

class ExpenseSplitterApp extends StatelessWidget {
  const ExpenseSplitterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SplitEasy',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      home: const GroupListScreen(),
    );
  }
}

enum SplitType { equal, exact, ratio, percentage, settlement }

class Expense {
  final String title;
  final double totalAmount;
  final String paidBy;
  final SplitType splitType;
  final Map<String, double> splits;

  Expense({
    required this.title,
    required this.totalAmount,
    required this.paidBy,
    required this.splitType,
    required this.splits,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'totalAmount': totalAmount,
        'paidBy': paidBy,
        'splitType': splitType.name,
        'splits': splits,
      };

  factory Expense.fromJson(Map<String, dynamic> json) => Expense(
        title: json['title'],
        totalAmount: (json['totalAmount'] as num).toDouble(),
        paidBy: json['paidBy'],
        splitType: SplitType.values.firstWhere((e) => e.name == json['splitType']),
        splits: Map<String, double>.from(
          (json['splits'] as Map).map((k, v) => MapEntry(k.toString(), (v as num).toDouble())),
        ),
      );
}

class Group {
  final String id;
  final String name;
  final List<String> members;
  final List<Expense> expenses;

  Group({
    required this.id,
    required this.name,
    required this.members,
    required this.expenses,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'members': members,
        'expenses': expenses.map((e) => e.toJson()).toList(),
      };

  factory Group.fromJson(Map<String, dynamic> json) => Group(
        id: json['id'],
        name: json['name'],
        members: List<String>.from(json['members'] ?? []),
        expenses: (json['expenses'] as List? ?? []).map((e) => Expense.fromJson(e)).toList(),
      );
}

class SettlementTransfer {
  final String from;
  final String to;
  final double amount;
  SettlementTransfer(this.from, this.to, this.amount);
}

// ==================== SCREEN 1: GROUPS LIST ====================
class GroupListScreen extends StatefulWidget {
  const GroupListScreen({super.key});

  @override
  State<GroupListScreen> createState() => _GroupListScreenState();
}

class _GroupListScreenState extends State<GroupListScreen> {
  final List<Group> groups = [];
  File get _storageFile => File('${Directory.systemTemp.path}/spliteasy_groups.json');

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    try {
      if (await _storageFile.exists()) {
        final content = await _storageFile.readAsString();
        final data = jsonDecode(content) as List;
        setState(() {
          groups.clear();
          groups.addAll(data.map((g) => Group.fromJson(g)));
        });
      }
    } catch (_) {}
  }

  Future<void> _saveGroups() async {
    try {
      final data = jsonEncode(groups.map((g) => g.toJson()).toList());
      await _storageFile.writeAsString(data);
    } catch (_) {}
  }

  void _createNewGroup() {
    final nameCtrl = TextEditingController();
    final membersCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Create New Group'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Group Name (e.g., Goa Trip)'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: membersCtrl,
              decoration: const InputDecoration(labelText: 'Members (comma separated)'),
            ),
            const SizedBox(height: 4),
            const Text('Example: Alice, Bob, Charlie', style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              final rawMembers = membersCtrl.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

              if (name.isNotEmpty && rawMembers.length >= 2) {
                setState(() {
                  groups.add(Group(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    name: name,
                    members: rawMembers,
                    expenses: [],
                  ));
                });
                _saveGroups();
                Navigator.pop(context);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Enter a group name and at least 2 members.')),
                );
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SplitEasy Groups')),
      body: groups.isEmpty
          ? const Center(
              child: Text(
                'No groups created yet.\nTap "+ New Group" below to start.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 15),
              ),
            )
          : ListView.builder(
              itemCount: groups.length,
              itemBuilder: (ctx, i) {
                final group = groups[i];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: ListTile(
                    leading: CircleAvatar(child: Text(group.name[0].toUpperCase())),
                    title: Text(group.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${group.members.length} members • ${group.expenses.length} expenses'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => GroupDetailScreen(
                            group: group,
                            onUpdate: (updatedGroup) {
                              setState(() {
                                groups[i] = updatedGroup;
                              });
                              _saveGroups();
                            },
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createNewGroup,
        icon: const Icon(Icons.group_add),
        label: const Text('New Group'),
      ),
    );
  }
}

// ==================== SCREEN 2: GROUP DASHBOARD ====================
class GroupDetailScreen extends StatefulWidget {
  final Group group;
  final Function(Group) onUpdate;

  const GroupDetailScreen({super.key, required this.group, required this.onUpdate});

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  late Group _currentGroup;

  @override
  void initState() {
    super.initState();
    _currentGroup = widget.group;
  }

  Map<String, double> _calculateBalances() {
    final Map<String, double> balances = {for (var m in _currentGroup.members) m: 0.0};
    for (var exp in _currentGroup.expenses) {
      balances[exp.paidBy] = (balances[exp.paidBy] ?? 0) + exp.totalAmount;
      exp.splits.forEach((member, share) {
        balances[member] = (balances[member] ?? 0) - share;
      });
    }
    return balances;
  }

  List<SettlementTransfer> _calculateMinimalTransfers(Map<String, double> balances) {
    final debtors = <MapEntry<String, double>>[];
    final creditors = <MapEntry<String, double>>[];

    balances.forEach((person, bal) {
      if (bal < -0.01) debtors.add(MapEntry(person, -bal));
      if (bal > 0.01) creditors.add(MapEntry(person, bal));
    });

    debtors.sort((a, b) => b.value.compareTo(a.value));
    creditors.sort((a, b) => b.value.compareTo(a.value));

    final transfers = <SettlementTransfer>[];
    int i = 0, j = 0;

    while (i < debtors.length && j < creditors.length) {
      final pay = debtors[i].value < creditors[j].value ? debtors[i].value : creditors[j].value;
      transfers.add(SettlementTransfer(debtors[i].key, creditors[j].key, pay));

      debtors[i] = MapEntry(debtors[i].key, debtors[i].value - pay);
      creditors[j] = MapEntry(creditors[j].key, creditors[j].value - pay);

      if (debtors[i].value < 0.01) i++;
      if (creditors[j].value < 0.01) j++;
    }
    return transfers;
  }

  void _recordSettlement(SettlementTransfer t) {
    final newExpenses = List<Expense>.from(_currentGroup.expenses);
    newExpenses.insert(
      0,
      Expense(
        title: 'Settlement: ${t.from} paid ${t.to}',
        totalAmount: t.amount,
        paidBy: t.from,
        splitType: SplitType.settlement,
        splits: {for (var m in _currentGroup.members) m: m == t.to ? t.amount : 0.0},
      ),
    );

    setState(() {
      _currentGroup = Group(
        id: _currentGroup.id,
        name: _currentGroup.name,
        members: _currentGroup.members,
        expenses: newExpenses,
      );
    });
    widget.onUpdate(_currentGroup);
  }

  void _openAddExpenseSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => AddExpenseModal(
        members: _currentGroup.members,
        onAdd: (expense) {
          final newExpenses = List<Expense>.from(_currentGroup.expenses)..insert(0, expense);
          setState(() {
            _currentGroup = Group(
              id: _currentGroup.id,
              name: _currentGroup.name,
              members: _currentGroup.members,
              expenses: newExpenses,
            );
          });
          widget.onUpdate(_currentGroup);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final balances = _calculateBalances();
    final settlements = _calculateMinimalTransfers(balances);

    return Scaffold(
      appBar: AppBar(
        title: Text(_currentGroup.name),
      ),
      body: Column(
        children: [
          // Balances Card
          Card(
            margin: const EdgeInsets.fromLTRB(12, 12, 12, 6),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Net Balances', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _currentGroup.members.map((m) {
                        final bal = balances[m] ?? 0.0;
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Column(
                            children: [
                              Text(m, style: const TextStyle(fontWeight: FontWeight.w600)),
                              Text(
                                '${bal >= 0 ? "+" : ""}₹${bal.toStringAsFixed(2)}',
                                style: TextStyle(
                                  color: bal >= 0 ? Colors.green[700] : Colors.red[700],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Settle Up Card
          Card(
            margin: const EdgeInsets.fromLTRB(12, 6, 12, 12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Settle Up (Who Owes Whom)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 6),
                  if (settlements.isEmpty)
                    const Text('All settled up! No pending debts.', style: TextStyle(color: Colors.green))
                  else
                    ...settlements.map((t) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  '${t.from} pays ${t.to} ₹${t.amount.toStringAsFixed(2)}',
                                  style: const TextStyle(fontWeight: FontWeight.w500),
                                ),
                              ),
                              FilledButton.tonal(
                                onPressed: () => _recordSettlement(t),
                                child: const Text('Mark Paid'),
                              ),
                            ],
                          ),
                        )),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          // Expense List
          Expanded(
            child: _currentGroup.expenses.isEmpty
                ? const Center(child: Text('No expenses added yet. Tap + to add.'))
                : ListView.builder(
                    itemCount: _currentGroup.expenses.length,
                    itemBuilder: (ctx, i) {
                      final exp = _currentGroup.expenses[i];
                      return ExpansionTile(
                        leading: CircleAvatar(
                          child: Text(exp.splitType.name[0].toUpperCase()),
                        ),
                        title: Text(exp.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Paid by ${exp.paidBy} • ${exp.splitType.name.toUpperCase()}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('₹${exp.totalAmount.toStringAsFixed(2)}',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () {
                                final newExpenses = List<Expense>.from(_currentGroup.expenses)..removeAt(i);
                                setState(() {
                                  _currentGroup = Group(
                                    id: _currentGroup.id,
                                    name: _currentGroup.name,
                                    members: _currentGroup.members,
                                    expenses: newExpenses,
                                  );
                                });
                                widget.onUpdate(_currentGroup);
                              },
                            ),
                          ],
                        ),
                        children: exp.splits.entries
                            .where((e) => e.value > 0)
                            .map((entry) => ListTile(
                                  dense: true,
                                  title: Text(entry.key),
                                  trailing: Text('Share: ₹${entry.value.toStringAsFixed(2)}'),
                                ))
                            .toList(),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddExpenseSheet,
        icon: const Icon(Icons.add),
        label: const Text('Add Expense'),
      ),
    );
  }
}

// ==================== ADD EXPENSE MODAL (WITH EQUAL SPLIT QUICK BUTTON) ====================
class AddExpenseModal extends StatefulWidget {
  final List<String> members;
  final Function(Expense) onAdd;

  const AddExpenseModal({super.key, required this.members, required this.onAdd});

  @override
  State<AddExpenseModal> createState() => _AddExpenseModalState();
}

class _AddExpenseModalState extends State<AddExpenseModal> {
  final _titleCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  late String _paidBy;
  SplitType _splitType = SplitType.equal; // Default to Equal!
  late Map<String, TextEditingController> _inputCtrls;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _paidBy = widget.members.first;
    _inputCtrls = {
      for (var m in widget.members) m: TextEditingController(text: '0')
    };
  }

  void _saveExpense() {
    final title = _titleCtrl.text.trim();
    final total = double.tryParse(_amountCtrl.text) ?? 0.0;
    if (title.isEmpty || total <= 0) {
      setState(() => _errorText = 'Enter a valid title and total amount.');
      return;
    }

    final Map<String, double> finalSplits = {};

    if (_splitType == SplitType.equal) {
      final share = total / widget.members.length;
      for (var m in widget.members) {
        finalSplits[m] = share;
      }
    } else {
      final Map<String, double> rawInputs = {};
      double inputSum = 0.0;
      for (var m in widget.members) {
        final val = double.tryParse(_inputCtrls[m]!.text) ?? 0.0;
        rawInputs[m] = val;
        inputSum += val;
      }

      if (_splitType == SplitType.exact) {
        if ((inputSum - total).abs() > 0.01) {
          setState(() => _errorText = 'Exact amounts must sum to ₹$total (Current: ₹$inputSum)');
          return;
        }
        finalSplits.addAll(rawInputs);
      } else if (_splitType == SplitType.percentage) {
        if ((inputSum - 100.0).abs() > 0.01) {
          setState(() => _errorText = 'Percentages must sum to 100% (Current: $inputSum%)');
          return;
        }
        for (var m in widget.members) {
          finalSplits[m] = (total * rawInputs[m]!) / 100.0;
        }
      } else if (_splitType == SplitType.ratio) {
        if (inputSum <= 0) {
          setState(() => _errorText = 'Total ratio must be greater than 0.');
          return;
        }
        for (var m in widget.members) {
          finalSplits[m] = (total * rawInputs[m]!) / inputSum;
        }
      }
    }

    widget.onAdd(Expense(
      title: title,
      totalAmount: total,
      paidBy: _paidBy,
      splitType: _splitType,
      splits: finalSplits,
    ));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('New Expense', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            TextField(
              controller: _titleCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Description (e.g., Dinner)'),
            ),
            TextField(
              controller: _amountCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Total Amount (₹)'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _paidBy,
              decoration: const InputDecoration(labelText: 'Paid By'),
              items: widget.members.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
              onChanged: (val) => setState(() => _paidBy = val!),
            ),
            const SizedBox(height: 12),
            // Segmented Button with Equal Split Option Included
            SegmentedButton<SplitType>(
              segments: const [
                ButtonSegment(value: SplitType.equal, label: Text('Equal')),
                ButtonSegment(value: SplitType.exact, label: Text('Exact')),
                ButtonSegment(value: SplitType.ratio, label: Text('Ratio')),
                ButtonSegment(value: SplitType.percentage, label: Text('Percent')),
              ],
              selected: {_splitType},
              onSelectionChanged: (set) => setState(() {
                _splitType = set.first;
                _errorText = null;
              }),
            ),
            const SizedBox(height: 12),
            if (_splitType == SplitType.equal)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Will be split equally among all ${widget.members.length} members.',
                  style: const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                  textAlign: TextAlign.center,
                ),
              )
            else
              ...widget.members.map((m) {
                final suffix = _splitType == SplitType.exact
                    ? '₹'
                    : _splitType == SplitType.percentage
                        ? '%'
                        : 'parts';
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(child: Text(m)),
                      SizedBox(
                        width: 120,
                        child: TextField(
                          controller: _inputCtrls[m],
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            suffixText: suffix,
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            if (_errorText != null) ...[
              const SizedBox(height: 8),
              Text(_errorText!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saveExpense,
              child: const Text('Save & Split Expense'),
            ),
          ],
        ),
      ),
    );
  }
}
