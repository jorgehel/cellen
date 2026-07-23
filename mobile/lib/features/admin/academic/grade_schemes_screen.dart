import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';

// ---------------------------------------------------------------------------
// Models
// ---------------------------------------------------------------------------

class _GradeScheme {
  final String id;
  final String name;
  final bool isDefault;
  final List<Map<String, dynamic>> components;

  const _GradeScheme({
    required this.id,
    required this.name,
    required this.isDefault,
    required this.components,
  });

  factory _GradeScheme.fromJson(Map<String, dynamic> j) => _GradeScheme(
        id: j['id'] as String,
        name: j['name'] as String,
        isDefault: j['is_default'] as bool? ?? false,
        components: (j['components'] as List? ?? [])
            .map((c) => Map<String, dynamic>.from(c as Map))
            .toList(),
      );
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final gradeSchemesProvider = FutureProvider.autoDispose<List<_GradeScheme>>((ref) async {
  final data = await ref.read(apiClientProvider).get('/grades/schemes') as List;
  return data.map((e) => _GradeScheme.fromJson(e as Map<String, dynamic>)).toList();
});

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class GradeSchemesScreen extends ConsumerWidget {
  const GradeSchemesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(gradeSchemesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Métodos de Avaliação')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showForm(context, ref, null),
        icon: const Icon(Icons.add),
        label: const Text('Novo Método'),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Erro: $e', style: const TextStyle(color: AppTheme.danger)),
        ),
        data: (schemes) => Column(
          children: [
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.06),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withOpacity(0.2)),
              ),
              child: const Row(children: [
                Icon(Icons.info_outline, size: 15, color: Colors.blue),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'O método "Padrão" aplica-se a todas as disciplinas sem método específico. '
                    'Os componentes não podem ser alterados depois de existirem notas lançadas.',
                    style: TextStyle(fontSize: 12, color: Colors.blue),
                  ),
                ),
              ]),
            ),
            if (schemes.isEmpty)
              const Expanded(
                child: Center(
                  child: Text('Nenhum método definido',
                      style: TextStyle(color: AppTheme.textSecondary)),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
                  itemCount: schemes.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (ctx, i) => _SchemeCard(
                    scheme: schemes[i],
                    onRefresh: () => ref.invalidate(gradeSchemesProvider),
                    onEdit: () => _showForm(ctx, ref, schemes[i]),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showForm(BuildContext context, WidgetRef ref, _GradeScheme? existing) {
    showDialog(
      context: context,
      useRootNavigator: true,
      builder: (_) => _SchemeFormDialog(
        existing: existing,
        onSaved: () => ref.invalidate(gradeSchemesProvider),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Scheme card
// ---------------------------------------------------------------------------

class _SchemeCard extends ConsumerWidget {
  final _GradeScheme scheme;
  final VoidCallback onRefresh;
  final VoidCallback onEdit;

  const _SchemeCard({
    required this.scheme,
    required this.onRefresh,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          scheme.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                      if (scheme.isDefault) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: AppTheme.primary.withOpacity(0.3)),
                          ),
                          child: const Text(
                            'Padrão',
                            style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.primary,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  tooltip: 'Editar',
                  onPressed: onEdit,
                ),
                if (!scheme.isDefault)
                  IconButton(
                    icon: const Icon(Icons.delete_outline,
                        size: 20, color: AppTheme.danger),
                    tooltip: 'Eliminar',
                    onPressed: () => _confirmDelete(context, ref),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: scheme.components.map((c) {
                final pct = (_toDouble(c['weight']) * 100).round();
                return Chip(
                  label: Text(
                    '${c['label']}  $pct%',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                  backgroundColor: AppTheme.primary.withOpacity(0.07),
                  side: BorderSide(color: AppTheme.primary.withOpacity(0.25)),
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  double _toDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar método?'),
        content: Text(
          'Eliminar "${scheme.name}"?\n\n'
          'Disciplinas que usem este método passarão a usar o método padrão.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () async {
              Navigator.of(ctx, rootNavigator: true).pop();
              try {
                await ref
                    .read(apiClientProvider)
                    .delete('/grades/schemes/${scheme.id}');
                onRefresh();
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('Erro: $e'),
                        backgroundColor: AppTheme.danger),
                  );
                }
              }
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Component row state
// ---------------------------------------------------------------------------

class _CompRow {
  final TextEditingController key;
  final TextEditingController label;
  final TextEditingController weight; // integer percent, e.g. "60"

  _CompRow({String k = '', String l = '', String w = ''})
      : key = TextEditingController(text: k),
        label = TextEditingController(text: l),
        weight = TextEditingController(text: w);

  void dispose() {
    key.dispose();
    label.dispose();
    weight.dispose();
  }
}

// ---------------------------------------------------------------------------
// Create / Edit dialog
// ---------------------------------------------------------------------------

class _SchemeFormDialog extends ConsumerStatefulWidget {
  final _GradeScheme? existing;
  final VoidCallback onSaved;
  const _SchemeFormDialog({this.existing, required this.onSaved});

  @override
  ConsumerState<_SchemeFormDialog> createState() => _SchemeFormDialogState();
}

class _SchemeFormDialogState extends ConsumerState<_SchemeFormDialog> {
  late final TextEditingController _nameCtrl;
  late bool _isDefault;
  late List<_CompRow> _rows;
  bool _saving = false;
  String? _error;

  double _toDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  @override
  void initState() {
    super.initState();
    final ex = widget.existing;
    _nameCtrl = TextEditingController(text: ex?.name ?? '');
    _isDefault = ex?.isDefault ?? false;

    if (ex != null) {
      _rows = ex.components.map((c) {
        final pct = (_toDouble(c['weight']) * 100).round();
        return _CompRow(
          k: c['key'] as String? ?? '',
          l: c['label'] as String? ?? '',
          w: pct.toString(),
        );
      }).toList();
    } else {
      _rows = [
        _CompRow(k: 'mac', l: 'MAC', w: '60'),
        _CompRow(k: 'exam', l: 'PE', w: '40'),
      ];
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    for (final r in _rows) r.dispose();
    super.dispose();
  }

  int get _totalWeight =>
      _rows.fold(0, (sum, r) => sum + (int.tryParse(r.weight.text) ?? 0));

  Future<void> _submit() async {
    if (_nameCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Nome obrigatório');
      return;
    }
    if (_rows.isEmpty) {
      setState(() => _error = 'Adicione pelo menos um componente');
      return;
    }
    for (final r in _rows) {
      if (r.key.text.trim().isEmpty || r.label.text.trim().isEmpty) {
        setState(() => _error = 'Preencha o código e nome de todos os componentes');
        return;
      }
      final w = int.tryParse(r.weight.text);
      if (w == null || w <= 0) {
        setState(() => _error = 'Peso inválido em "${r.label.text}"');
        return;
      }
    }
    if (_totalWeight != 100) {
      setState(() =>
          _error = 'A soma dos pesos deve ser 100% (actualmente $_totalWeight%)');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final components = _rows
        .map((r) => {
              'key': r.key.text.trim().toLowerCase(),
              'label': r.label.text.trim(),
              'weight': int.parse(r.weight.text) / 100.0,
            })
        .toList();

    try {
      final api = ref.read(apiClientProvider);
      if (widget.existing == null) {
        await api.post('/grades/schemes', data: {
          'name': _nameCtrl.text.trim(),
          'components': components,
        });
      } else {
        await api.patch('/grades/schemes/${widget.existing!.id}', data: {
          'name': _nameCtrl.text.trim(),
          'components': components,
          'is_default': _isDefault,
        });
      }
      widget.onSaved();
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _saving = false;
      });
    }
  }

  void _addRow() {
    setState(() => _rows.add(_CompRow(k: 'c${_rows.length + 1}', l: '', w: '0')));
  }

  void _removeRow(int i) {
    setState(() => _rows.removeAt(i));
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    final total = _totalWeight;
    final totalOk = total == 100;

    return AlertDialog(
      title: Text(isEdit ? 'Editar Método' : 'Novo Método de Avaliação'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Name
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nome *',
                  isDense: true,
                ),
                textCapitalization: TextCapitalization.sentences,
              ),

              if (isEdit) ...[
                const SizedBox(height: 4),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text('Definir como padrão',
                      style: TextStyle(fontSize: 14)),
                  subtitle: const Text(
                    'Aplicado a todas as disciplinas sem método específico',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: _isDefault,
                  onChanged: (v) => setState(() => _isDefault = v),
                ),
              ],

              const SizedBox(height: 16),

              // Components header
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Componentes de avaliação',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _rows.length < 6 ? _addRow : null,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Adicionar',
                        style: TextStyle(fontSize: 13)),
                    style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8)),
                  ),
                ],
              ),
              const SizedBox(height: 4),

              // Column headers
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: const [
                    SizedBox(
                        width: 76,
                        child: Text('Código',
                            style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.textSecondary))),
                    SizedBox(width: 8),
                    Expanded(
                        child: Text('Nome do componente',
                            style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.textSecondary))),
                    SizedBox(width: 8),
                    SizedBox(
                        width: 68,
                        child: Text('Peso (%)',
                            style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.textSecondary))),
                    SizedBox(width: 32),
                  ],
                ),
              ),

              // Component rows
              ..._rows.asMap().entries.map((entry) {
                final i = entry.key;
                final row = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 76,
                        child: TextField(
                          controller: row.key,
                          decoration: const InputDecoration(
                            hintText: 'mac',
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 8, vertical: 8),
                          ),
                          style: const TextStyle(
                              fontSize: 13, fontFamily: 'monospace'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: row.label,
                          decoration: const InputDecoration(
                            hintText: 'ex: MAC',
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 8, vertical: 8),
                          ),
                          style: const TextStyle(fontSize: 13),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 68,
                        child: TextField(
                          controller: row.weight,
                          decoration: const InputDecoration(
                            hintText: '60',
                            isDense: true,
                            suffixText: '%',
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 8, vertical: 8),
                          ),
                          keyboardType: TextInputType.number,
                          style: const TextStyle(fontSize: 13),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        tooltip: 'Remover',
                        onPressed: _rows.length > 1 ? () => _removeRow(i) : null,
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                );
              }),

              // Total weight indicator
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: totalOk
                      ? Colors.green.withOpacity(0.08)
                      : Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      totalOk
                          ? Icons.check_circle_outline
                          : Icons.warning_amber_outlined,
                      size: 16,
                      color: totalOk ? Colors.green : Colors.orange,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      totalOk
                          ? 'Total: 100% ✓'
                          : 'Total: $total%  (deve ser exactamente 100%)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: totalOk
                            ? Colors.green.shade700
                            : Colors.orange.shade800,
                      ),
                    ),
                  ],
                ),
              ),

              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!,
                    style: const TextStyle(
                        color: AppTheme.danger, fontSize: 13)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving
              ? null
              : () => Navigator.of(context, rootNavigator: true).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : Text(isEdit ? 'Guardar' : 'Criar'),
        ),
      ],
    );
  }
}
