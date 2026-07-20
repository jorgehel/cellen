import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';

// Key is a sorted query string like "action=void&entity_type=invoice" to ensure stable equality
final _auditLogProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, paramsKey) async {
  final api = ref.read(apiClientProvider);
  final queryParams = <String, String>{};
  for (final entry in paramsKey.split('&')) {
    if (entry.isEmpty) continue;
    final idx = entry.indexOf('=');
    if (idx > 0) queryParams[entry.substring(0, idx)] = Uri.decodeComponent(entry.substring(idx + 1));
  }
  final data = await api.get('/finance/audit-log', queryParameters: queryParams.isEmpty ? null : queryParams) as List;
  return data.cast<Map<String, dynamic>>();
});

class AuditLogScreen extends ConsumerStatefulWidget {
  const AuditLogScreen({super.key});

  @override
  ConsumerState<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends ConsumerState<AuditLogScreen> {
  String? _entityType;
  String? _action;
  DateTime? _dateFrom;
  DateTime? _dateTo;

  static const _entityTypes = {
    '': 'Todos',
    'invoice': 'Factura',
    'credit_note': 'Nota de Crédito',
    'payment': 'Pagamento',
    'credit_entry': 'Crédito',
    'cash_session': 'Sessão de Caixa',
    'saft_export': 'SAF-T',
    'billing_item': 'Item Faturável',
    'contract': 'Contrato',
  };

  Map<String, String> get _params {
    final p = <String, String>{};
    if (_entityType != null && _entityType!.isNotEmpty) p['entity_type'] = _entityType!;
    if (_action != null && _action!.isNotEmpty) p['action'] = _action!;
    if (_dateFrom != null) p['date_from'] = '${_dateFrom!.year}-${_dateFrom!.month.toString().padLeft(2,'0')}-${_dateFrom!.day.toString().padLeft(2,'0')}';
    if (_dateTo != null) p['date_to'] = '${_dateTo!.year}-${_dateTo!.month.toString().padLeft(2,'0')}-${_dateTo!.day.toString().padLeft(2,'0')}';
    return p;
  }

  String get _paramsKey {
    final p = _params;
    if (p.isEmpty) return '';
    final sorted = p.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    return sorted.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
  }

  @override
  Widget build(BuildContext context) {
    final logAsync = ref.watch(_auditLogProvider(_paramsKey));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Registo de Auditoria'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: () => ref.invalidate(_auditLogProvider(_paramsKey))),
        ],
      ),
      body: Column(
        children: [
          // Filters
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.4),
            child: Column(
              children: [
                Row(children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _entityType ?? '',
                      decoration: const InputDecoration(labelText: 'Tipo', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                      items: _entityTypes.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, style: const TextStyle(fontSize: 13)))).toList(),
                      onChanged: (v) => setState(() => _entityType = v),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      initialValue: _action,
                      decoration: const InputDecoration(labelText: 'Acção', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                      onChanged: (v) => setState(() => _action = v.trim().isEmpty ? null : v.trim()),
                    ),
                  ),
                ]),
                const SizedBox(height: 6),
                Row(children: [
                  Expanded(child: _datePicker('De', _dateFrom, (d) => setState(() => _dateFrom = d))),
                  const SizedBox(width: 8),
                  Expanded(child: _datePicker('Até', _dateTo, (d) => setState(() => _dateTo = d))),
                ]),
              ],
            ),
          ),

          // List
          Expanded(
            child: logAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text(e.toString(), style: const TextStyle(color: AppTheme.danger))),
              data: (entries) {
                if (entries.isEmpty) {
                  return const Center(child: Text('Nenhuma entrada encontrada', style: TextStyle(color: AppTheme.textSecondary)));
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 32),
                  itemCount: entries.length,
                  itemBuilder: (_, i) => _AuditEntryCard(entry: entries[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _datePicker(String label, DateTime? value, ValueChanged<DateTime> onPicked) {
    return InkWell(
      onTap: () async {
        final p = await showDatePicker(context: context, initialDate: value ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2030));
        if (p != null) onPicked(p);
      },
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
        child: Text(value != null ? DateFormat('dd/MM/yy').format(value) : '—', style: const TextStyle(fontSize: 13)),
      ),
    );
  }
}

class _AuditEntryCard extends StatefulWidget {
  final Map<String, dynamic> entry;
  const _AuditEntryCard({required this.entry});

  @override
  State<_AuditEntryCard> createState() => _AuditEntryCardState();
}

class _AuditEntryCardState extends State<_AuditEntryCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final e = widget.entry;
    final action = e['action'] as String? ?? '';
    final entityType = e['entity_type'] as String? ?? '';
    final ts = e['timestamp'] as String? ?? '';
    final actor = e['actor_name'] as String? ?? e['actor_id']?.toString() ?? '—';
    final reason = e['reason'] as String?;
    final before = e['before_snapshot'];
    final after = e['after_snapshot'];

    String formattedTs = ts;
    try { formattedTs = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(ts)); } catch (_) {}

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.grey.shade200)),
      child: Column(
        children: [
          ListTile(
            dense: true,
            leading: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: _actionColor(action).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: Icon(_actionIcon(action), color: _actionColor(action), size: 18),
            ),
            title: Text('$entityType · $action', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            subtitle: Text('$actor · $formattedTs', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
            trailing: (before != null || after != null || reason != null)
                ? IconButton(
                    icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more, size: 18),
                    onPressed: () => setState(() => _expanded = !_expanded),
                  )
                : null,
          ),
          if (_expanded) ...[
            if (reason != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Motivo: ', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                  Expanded(child: Text(reason, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary))),
                ]),
              ),
            if (before != null)
              _SnapshotTile(label: 'Antes', data: before),
            if (after != null)
              _SnapshotTile(label: 'Depois', data: after),
          ],
        ],
      ),
    );
  }

  Color _actionColor(String a) => switch (a) {
    'void' || 'reverse' || 'refund' => AppTheme.danger,
    'issue' || 'issue_nd' || 'apply_credit' => AppTheme.primary,
    'export' => Colors.purple,
    'price_change' => Colors.orange,
    _ => AppTheme.textSecondary,
  };

  IconData _actionIcon(String a) => switch (a) {
    'void' => Icons.cancel_outlined,
    'reverse' => Icons.undo_outlined,
    'issue' || 'issue_nd' => Icons.description_outlined,
    'apply_credit' => Icons.savings_outlined,
    'refund' => Icons.money_off_outlined,
    'export' => Icons.download_outlined,
    'price_change' => Icons.price_change_outlined,
    _ => Icons.history_outlined,
  };
}

class _SnapshotTile extends StatelessWidget {
  final String label;
  final dynamic data;
  const _SnapshotTile({required this.label, required this.data});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(6)),
            child: Text(data.toString(), style: const TextStyle(fontSize: 11, fontFamily: 'monospace'), maxLines: 5, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}
