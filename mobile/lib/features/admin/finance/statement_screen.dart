import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_client.dart';
import '../../../core/providers/currency_provider.dart';
import '../../../core/theme/app_theme.dart';

class StatementScreen extends ConsumerStatefulWidget {
  const StatementScreen({super.key});

  @override
  ConsumerState<StatementScreen> createState() => _StatementScreenState();
}

class _StatementScreenState extends ConsumerState<StatementScreen> {
  List<Map<String, dynamic>> _guardians = [];
  String? _selectedGuardianId;
  String? _selectedGuardianName;
  Map<String, dynamic>? _statement;
  bool _loadingGuardians = true;
  bool _loadingStatement = false;
  DateTime? _dateFrom;
  DateTime? _dateTo;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadGuardians();
  }

  Future<void> _loadGuardians() async {
    try {
      final api = ref.read(apiClientProvider);
      final data = await api.get('/guardians') as List;
      setState(() { _guardians = data.cast<Map<String, dynamic>>(); _loadingGuardians = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loadingGuardians = false; });
    }
  }

  Future<void> _loadStatement() async {
    if (_selectedGuardianId == null) return;
    setState(() { _loadingStatement = true; _error = null; });
    try {
      final api = ref.read(apiClientProvider);
      final params = <String, String>{};
      if (_dateFrom != null) params['date_from'] = '${_dateFrom!.year}-${_dateFrom!.month.toString().padLeft(2,'0')}-${_dateFrom!.day.toString().padLeft(2,'0')}';
      if (_dateTo != null) params['date_to'] = '${_dateTo!.year}-${_dateTo!.month.toString().padLeft(2,'0')}-${_dateTo!.day.toString().padLeft(2,'0')}';
      final data = await api.get('/finance/reports/statement/$_selectedGuardianId', queryParameters: params) as Map<String, dynamic>;
      setState(() { _statement = data; _loadingStatement = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loadingStatement = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = ref.watch(currencyFormatProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Extrato de Conta')),
      body: Column(
        children: [
          // Controls
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
            child: Column(
              children: [
                _loadingGuardians
                    ? const LinearProgressIndicator()
                    : DropdownButtonFormField<String>(
                        value: _selectedGuardianId,
                        decoration: const InputDecoration(labelText: 'Encarregado', prefixIcon: Icon(Icons.person_outline), filled: true, fillColor: Colors.white),
                        isExpanded: true,
                        items: _guardians.map((g) => DropdownMenuItem(
                          value: g['id']?.toString(),
                          child: Text('${g['first_name'] ?? ''} ${g['last_name'] ?? ''}'.trim(), overflow: TextOverflow.ellipsis),
                        )).toList(),
                        onChanged: (v) {
                          final g = _guardians.where((g) => g['id']?.toString() == v).firstOrNull;
                          setState(() {
                            _selectedGuardianId = v;
                            _selectedGuardianName = '${g?['first_name'] ?? ''} ${g?['last_name'] ?? ''}'.trim();
                            _statement = null;
                          });
                        },
                      ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: _datePicker('De', _dateFrom, (d) => setState(() => _dateFrom = d))),
                    const SizedBox(width: 10),
                    Expanded(child: _datePicker('Até', _dateTo, (d) => setState(() => _dateTo = d))),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _selectedGuardianId != null && !_loadingStatement ? _loadStatement : null,
                    icon: _loadingStatement
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.search),
                    label: const Text('Ver Extrato'),
                  ),
                ),
              ],
            ),
          ),

          // Statement
          Expanded(
            child: _statement == null
                ? Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.receipt_long_outlined, size: 56, color: AppTheme.textSecondary),
                      const SizedBox(height: 12),
                      Text(
                        _error ?? 'Seleccione um encarregado e clique em "Ver Extrato"',
                        style: TextStyle(color: _error != null ? AppTheme.danger : AppTheme.textSecondary),
                        textAlign: TextAlign.center,
                      ),
                    ]),
                  )
                : _StatementView(
                    statement: _statement!,
                    guardianName: _selectedGuardianName ?? '',
                    currency: currency,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _datePicker(String label, DateTime? value, ValueChanged<DateTime> onPicked) {
    return InkWell(
      onTap: () async {
        final p = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
        );
        if (p != null) onPicked(p);
      },
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, filled: true, fillColor: Colors.white, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
        child: Text(
          value != null ? DateFormat('dd/MM/yyyy').format(value) : 'Qualquer',
          style: TextStyle(color: value != null ? null : AppTheme.textSecondary, fontSize: 13),
        ),
      ),
    );
  }
}

class _StatementView extends StatelessWidget {
  final Map<String, dynamic> statement;
  final String guardianName;
  final NumberFormat currency;
  const _StatementView({required this.statement, required this.guardianName, required this.currency});

  @override
  Widget build(BuildContext context) {
    final totalInvoiced = (statement['total_invoiced'] as num?)?.toDouble() ?? 0;
    final totalSettled = (statement['total_settled'] as num?)?.toDouble() ?? 0;
    final balance = (statement['current_balance'] as num?)?.toDouble() ?? 0;
    final creditBalance = (statement['credit_balance'] as num?)?.toDouble() ?? 0;
    final movements = (statement['movements'] as List? ?? []).cast<Map<String, dynamic>>();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        // Header summary
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(guardianName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 10),
              _headerRow('Total Facturado', currency.format(totalInvoiced), Colors.blue),
              _headerRow('Total Pago', currency.format(totalSettled), AppTheme.success),
              _headerRow('Saldo em Dívida', currency.format(balance), balance > 0 ? AppTheme.danger : AppTheme.success),
              if (creditBalance > 0) _headerRow('Saldo de Crédito', currency.format(creditBalance), AppTheme.primary),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text('Movimentos', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700, color: AppTheme.textSecondary)),
        const SizedBox(height: 8),
        if (movements.isEmpty)
          const Text('Sem movimentos no período seleccionado', style: TextStyle(color: AppTheme.textSecondary))
        else
          ...movements.map((m) => _MovementRow(movement: m, currency: currency)),
      ],
    );
  }

  Widget _headerRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 13)),
        ],
      ),
    );
  }
}

double _toDouble(dynamic v) =>
    v == null ? 0 : (v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0);

class _MovementRow extends StatelessWidget {
  final Map<String, dynamic> movement;
  final NumberFormat currency;
  const _MovementRow({required this.movement, required this.currency});

  @override
  Widget build(BuildContext context) {
    final type = movement['type'] as String? ?? '';
    final description = movement['description'] as String? ?? type;
    final date = movement['date'] as String? ?? '';
    final debit = _toDouble(movement['debit']);
    final credit = _toDouble(movement['credit']);
    final runningBalance = movement['running_balance'] != null ? _toDouble(movement['running_balance']) : null;
    final isDebit = debit > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(width: 3, color: isDebit ? AppTheme.danger : AppTheme.success)),
        color: isDebit ? AppTheme.danger.withOpacity(0.03) : AppTheme.success.withOpacity(0.03),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(description, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                Text(date, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                isDebit ? '+${currency.format(debit)}' : '-${currency.format(credit)}',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDebit ? AppTheme.danger : AppTheme.success),
              ),
              if (runningBalance != null)
                Text('Saldo: ${currency.format(runningBalance)}', style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }
}
