import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';

// ---------------------------------------------------------------------------
// Models
// ---------------------------------------------------------------------------

class SubjectModel {
  final String id;
  final String name;
  final String? code;
  final int order;
  final bool isActive;

  const SubjectModel({
    required this.id,
    required this.name,
    this.code,
    required this.order,
    required this.isActive,
  });

  factory SubjectModel.fromJson(Map<String, dynamic> j) => SubjectModel(
        id: j['id'] as String,
        name: j['name'] as String,
        code: j['code'] as String?,
        order: j['order'] as int? ?? 0,
        isActive: j['is_active'] as bool? ?? true,
      );
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final subjectsProvider = FutureProvider.autoDispose<List<SubjectModel>>((ref) async {
  final api = ref.read(apiClientProvider);
  final data = await api.get('/grades/subjects?include_inactive=true') as List;
  return data.map((e) => SubjectModel.fromJson(e as Map<String, dynamic>)).toList();
});

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class SubjectsScreen extends ConsumerWidget {
  const SubjectsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(subjectsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Disciplinas')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showDialog(context, ref, null),
        tooltip: 'Nova Disciplina',
        child: const Icon(Icons.add),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppTheme.danger),
              const SizedBox(height: 8),
              Text(e.toString(), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => ref.invalidate(subjectsProvider),
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
        data: (subjects) {
          if (subjects.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.book_outlined, size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  const Text('Nenhuma disciplina criada'),
                  const SizedBox(height: 8),
                  const Text(
                    'Crie disciplinas como Matemática, Língua Portuguesa, Ciências...',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                  ),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
            itemCount: subjects.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final s = subjects[i];
              return Card(
                margin: EdgeInsets.zero,
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppTheme.primary.withOpacity(0.12),
                    child: Text(
                      s.code?.isNotEmpty == true ? s.code! : s.name[0].toUpperCase(),
                      style: TextStyle(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: s.code?.isNotEmpty == true ? 11 : 16,
                      ),
                    ),
                  ),
                  title: Text(
                    s.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: s.isActive ? null : AppTheme.textSecondary,
                    ),
                  ),
                  subtitle: Text(
                    s.code != null ? 'Código: ${s.code}  •  Ordem: ${s.order}' : 'Ordem: ${s.order}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!s.isActive)
                        const Chip(
                          label: Text('Inactiva', style: TextStyle(fontSize: 11)),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                        ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 20),
                        onPressed: () => _showDialog(context, ref, s),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showDialog(BuildContext context, WidgetRef ref, SubjectModel? existing) {
    showDialog(
      useRootNavigator: false,
      context: context,
      builder: (_) => _SubjectDialog(
        existing: existing,
        onSaved: () => ref.invalidate(subjectsProvider),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Create / Edit dialog
// ---------------------------------------------------------------------------

class _SubjectDialog extends ConsumerStatefulWidget {
  final SubjectModel? existing;
  final VoidCallback onSaved;

  const _SubjectDialog({this.existing, required this.onSaved});

  @override
  ConsumerState<_SubjectDialog> createState() => _SubjectDialogState();
}

class _SubjectDialogState extends ConsumerState<_SubjectDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
  late final _codeCtrl = TextEditingController(text: widget.existing?.code ?? '');
  late final _orderCtrl = TextEditingController(text: '${widget.existing?.order ?? 0}');
  bool _isActive = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _isActive = widget.existing?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    _orderCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _saving = true; _error = null; });
    try {
      final api = ref.read(apiClientProvider);
      final data = {
        'name': _nameCtrl.text.trim(),
        'code': _codeCtrl.text.trim().isEmpty ? null : _codeCtrl.text.trim(),
        'order': int.tryParse(_orderCtrl.text) ?? 0,
      };
      if (widget.existing != null) {
        data['is_active'] = _isActive;
        await api.patch('/grades/subjects/${widget.existing!.id}', data: data);
      } else {
        await api.post('/grades/subjects', data: data);
      }
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() { _error = e.toString(); _saving = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return AlertDialog(
      title: Text(isEdit ? 'Editar Disciplina' : 'Nova Disciplina'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nome *',
                  hintText: 'ex: Matemática',
                  prefixIcon: Icon(Icons.book_outlined),
                ),
                validator: (v) => v == null || v.trim().isEmpty ? 'Obrigatório' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _codeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Código (abreviatura)',
                  hintText: 'ex: MAT',
                  prefixIcon: Icon(Icons.tag),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _orderCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Ordem de exibição',
                  prefixIcon: Icon(Icons.sort),
                ),
              ),
              if (isEdit) ...[
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Disciplina activa'),
                  value: _isActive,
                  onChanged: (v) => setState(() => _isActive = v),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: AppTheme.danger, fontSize: 13)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(isEdit ? 'Guardar' : 'Criar'),
        ),
      ],
    );
  }
}
