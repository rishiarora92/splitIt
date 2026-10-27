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
      home: const HomeScreen(),
    );
  }
}

enum SplitType { exact, ratio, percentage }

class Expense {
  final String title;
  final double totalAmount;
  final String paidBy;
  final SplitType splitType;
  final Map<String, double> splits; // Final calculated amount per person

  Expense({
    required this.title,
    required this.totalAmount,
    required this.paidBy,
    required this.splitType,
    required this.splits,
  });
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<String> members = ['Alice', 'Bob', 'Charlie'];
  final List<Expense> expenses = [];

  // Calculate net balance for each member
  Map<String, double> _calculateBalances() {
    final Map<String, double> balances = {for (var m in members) m: 0.0};
    for (var exp in expenses) {
      balances[exp.paidBy] = (balances[exp.paidBy] ?? 0) + exp.totalAmount;
      exp.splits.forEach((member, share) {
        balances[member] = (balances[member] ?? 0) - share;
      });
    }
    return balances;
  }

  void _openAddExpenseSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => AddExpenseModal(
        members: members,
        onAdd: (expense) => setState(() => expenses.insert(0, expense)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final balances = _calculateBalances();

    return Scaffold(
      appBar: AppBar(title: const Text('SplitEasy Expenses')),
      body: Column(
        children: [
          // Balances Summary Card
          Card(
            margin: const EdgeInsets.all(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Net Balances',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: members.map((m) {
                      final bal = balances[m] ?? 0.0;
                      return Column(
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
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          // Expense List
          Expanded(
            child: expenses.isEmpty
                ? const Center(child: Text('No expenses added yet. Tap + to add.'))
                : ListView.builder(
                    itemCount: expenses.length,
                    itemBuilder: (ctx, i) {
                      final exp = expenses[i];
                      return ExpansionTile(
                        leading: CircleAvatar(
                          child: Text(exp.splitType.name[0].toUpperCase()),
                        ),
                        title: Text(exp.title,
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Paid by ${exp.paidBy} • ${exp.splitType.name.toUpperCase()}'),
                        trailing: Text('₹${exp.totalAmount.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        children: exp.splits.entries.map((entry) {
                          return ListTile(
                            dense: true,
                            title: Text(entry.key),
                            trailing: Text('Owes ₹${entry.value.toStringAsFixed(2)}'),
                          );
                        }).toList(),
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
  SplitType _splitType = SplitType.exact;
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

    final Map<String, double> rawInputs = {};
    double inputSum = 0.0;
    for (var m in widget.members) {
      final val = double.tryParse(_inputCtrls[m]!.text) ?? 0.0;
      rawInputs[m] = val;
      inputSum += val;
    }

    final Map<String, double> finalSplits = {};

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
    final suffix = _splitType == SplitType.exact
        ? '₹'
        : _splitType == SplitType.percentage
            ? '%'
            : 'parts';

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
            const Text('New Expense',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            TextField(
              controller: _titleCtrl,
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
              items: widget.members
                  .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                  .toList(),
              onChanged: (val) => setState(() => _paidBy = val!),
            ),
            const SizedBox(height: 12),
            SegmentedButton<SplitType>(
              segments: const [
                ButtonSegment(value: SplitType.exact, label: Text('Whole/Exact')),
                ButtonSegment(value: SplitType.ratio, label: Text('Ratio')),
                ButtonSegment(value: SplitType.percentage, label: Text('Percent %')),
              ],
              selected: {_splitType},
              onSelectionChanged: (set) => setState(() {
                _splitType = set.first;
                _errorText = null;
              }),
            ),
            const SizedBox(height: 12),
            ...widget.members.map((m) => Padding(
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
                )),
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
