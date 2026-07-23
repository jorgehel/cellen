import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/auth/auth_state.dart';
import '../../../core/theme/app_theme.dart';

// ---------------------------------------------------------------------------
// Models
// ---------------------------------------------------------------------------

class _Turma {
  final String id;
  final String name;
  final String level;
  const _Turma({required this.id, required this.name, required this.level});
  factory _Turma.fromJson(Map<String, dynamic> j) => _Turma(
        id: j['id'] as String,
        name: j['name'] as String,
        level: j['level'] as String? ?? '',
      );
}

class _SchemeComponent {
  final String key;
  final String label;
  final double weight;
  const _SchemeComponent({required this.key, required this.label, required this.weight});
  factory _SchemeComponent.fromJson(Map<String, dynamic> j) => _SchemeComponent(
        key: j['key'] as String,
        label: j['label'] as String,
        weight: (j['weight'] as num).toDouble(),
      );
}

class _GradeScheme {
  final String id;
  final String name;
  final List<_SchemeComponent> components;
  const _GradeScheme({required this.id, required this.name, required this.components});
  factory _GradeScheme.fromJson(Map<String, dynamic> j) => _GradeScheme(
        id: j['id'] as String,
        name: j['name'] as String,
        components: (j['components'] as List)
            .map((c) => _SchemeComponent.fromJson(c as Map<String, dynamic>))
            .toList(),
      );
}

class _TurmaSubject {
  final String id;
  final String turmaId;
  final String subjectId;
  final String subjectName;
  final String? subjectCode;
  final String schoolYearId;
  final bool isLocked;
  final _GradeScheme? gradeScheme;
  const _TurmaSubject({
    required this.id,
    required this.turmaId,
    required this.subjectId,
    required this.subjectName,
    this.subjectCode,
    required this.schoolYearId,
    required this.isLocked,
    this.gradeScheme,
  });
  factory _TurmaSubject.fromJson(Map<String, dynamic> j) => _TurmaSubject(
        id: j['id'] as String,
        turmaId: j['turma_id'] as String,
        subjectId: j['subject_id'] as String,
        subjectName: j['subject_name'] as String? ?? '',
        subjectCode: j['subject_code'] as String?,
        schoolYearId: j['school_year_id'] as String,
        isLocked: j['is_locked'] as bool? ?? false,
        gradeScheme: j['grade_scheme'] != null
            ? _GradeScheme.fromJson(j['grade_scheme'] as Map<String, dynamic>)
            : null,
      );
}

class _StudentMark {
  final String enrollmentId;
  final String childName;
  Map<String, double?> gradeComponents;  // {key: value} for all scheme components
  double? finalGrade;
  String? notes;
  String? markId;

  _StudentMark({
    required this.enrollmentId,
    required this.childName,
    Map<String, double?>? gradeComponents,
    this.finalGrade,
    this.notes,
    this.markId,
  }) : gradeComponents = gradeComponents ?? {};

  static double? _parseNum(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  factory _StudentMark.fromJson(Map<String, dynamic> j) {
    // Reconstruct components from grade_components JSONB or fall back to mac/exam columns
    final Map<String, double?> components = {};
    if (j['grade_components'] != null) {
      final raw = j['grade_components'] as Map<String, dynamic>;
      for (final e in raw.entries) {
        components[e.key] = _parseNum(e.value);
      }
    } else {
      final mac = _parseNum(j['mac_grade']);
      final exam = _parseNum(j['exam_grade']);
      if (mac != null) components['mac'] = mac;
      if (exam != null) components['exam'] = exam;
    }
    return _StudentMark(
      enrollmentId: j['enrollment_id'] as String,
      childName: j['child_name'] as String,
      gradeComponents: components,
      finalGrade: _parseNum(j['final_grade']),
      notes: j['notes'] as String?,
      markId: j['mark_id'] as String?,
    );
  }

  double? computedFinal(List<_SchemeComponent> components) {
    double total = 0;
    double totalWeight = 0;
    for (final comp in components) {
      final val = gradeComponents[comp.key];
      if (val != null) {
        total += val * comp.weight;
        totalWeight += comp.weight;
      }
    }
    if (totalWeight == 0) return null;
    return double.parse((total / totalWeight).toStringAsFixed(1));
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final _turmasProvider = FutureProvider.autoDispose<List<_Turma>>((ref) async {
  final api = ref.read(apiClientProvider);
  final data = await api.get('/academic/turmas') as List;
  return data.map((e) => _Turma.fromJson(e as Map<String, dynamic>)).toList();
});


typedef _SubjectsKey = ({String turmaId, String? teacherId});

final _turmaSubjectsProvider =
    FutureProvider.autoDispose.family<List<_TurmaSubject>, _SubjectsKey>((ref, key) async {
  if (key.turmaId.isEmpty) return [];
  final api = ref.read(apiClientProvider);
  var path = '/grades/turma-subjects?turma_id=${key.turmaId}';
  if (key.teacherId != null) path += '&teacher_id=${key.teacherId}';
  final data = await api.get(path) as List;
  return data.map((e) => _TurmaSubject.fromJson(e as Map<String, dynamic>)).toList();
});

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class GradesScreen extends ConsumerStatefulWidget {
  const GradesScreen({super.key});

  @override
  ConsumerState<GradesScreen> createState() => _GradesScreenState();
}

class _GradesScreenState extends ConsumerState<GradesScreen> {
  _Turma? _selectedTurma;
  _TurmaSubject? _selectedSubject;
  int _selectedTrimester = 1;
  List<_StudentMark> _marks = [];
  bool _loading = false;
  bool _saving = false;
  String? _error;
  String? _successMsg;

  Future<void> _loadMarks() async {
    if (_selectedTurma == null || _selectedSubject == null) return;
    setState(() { _loading = true; _error = null; _successMsg = null; });
    try {
      final api = ref.read(apiClientProvider);
      final path = '/grades/marks?turma_id=${_selectedTurma!.id}'
          '&subject_id=${_selectedSubject!.subjectId}'
          '&trimester=$_selectedTrimester';
      final data = await api.get(path) as List;
      setState(() {
        _marks = data.map((e) => _StudentMark.fromJson(e as Map<String, dynamic>)).toList();
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final scheme = _selectedSubject?.gradeScheme;
    final components = scheme?.components ?? [];
    setState(() { _saving = true; _error = null; _successMsg = null; });
    try {
      final api = ref.read(apiClientProvider);
      final marks = _marks
          .where((m) => m.gradeComponents.values.any((v) => v != null))
          .map((m) => {
                'enrollment_id': m.enrollmentId,
                'subject_id': _selectedSubject!.subjectId,
                'trimester': _selectedTrimester,
                'mac_grade': m.gradeComponents['mac'],
                'exam_grade': m.gradeComponents['exam'],
                'grade_components': m.gradeComponents,
                'final_grade': m.computedFinal(components),
                'notes': m.notes,
              })
          .toList();
      if (marks.isEmpty) {
        setState(() { _successMsg = 'Sem alterações para guardar.'; _saving = false; });
        return;
      }
      await api.post('/grades/marks/bulk', data: {'marks': marks});
      setState(() => _successMsg = 'Notas guardadas com sucesso!');
      await _loadMarks();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final isTeacher = auth.hasRole(UserRole.teacher) && !auth.hasRole(UserRole.schoolAdmin);
    final teacherId = isTeacher ? auth.employeeId : null;

    final turmasAsync = ref.watch(_turmasProvider);

    final subjectsAsync = _selectedTurma != null
        ? ref.watch(_turmaSubjectsProvider((turmaId: _selectedTurma!.id, teacherId: teacherId)))
        : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lançamento de Notas'),
        actions: [
          if (_marks.isNotEmpty)
            TextButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save_outlined, size: 18),
              label: const Text('Guardar'),
            ),
        ],
      ),
      body: Column(
        children: [
          // ── Selectors ─────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              children: [
                // Turma selector
                turmasAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text('Erro: $e', style: const TextStyle(color: AppTheme.danger)),
                  data: (turmas) => DropdownButtonFormField<String>(
                    value: _selectedTurma?.id,
                    decoration: const InputDecoration(
                      labelText: 'Turma',
                      prefixIcon: Icon(Icons.class_outlined),
                      isDense: true,
                    ),
                    items: turmas
                        .map((t) => DropdownMenuItem(value: t.id, child: Text('${t.name} — ${t.level}')))
                        .toList(),
                    onChanged: (id) {
                      final turma = turmasAsync.value?.firstWhere((t) => t.id == id);
                      setState(() {
                        _selectedTurma = turma;
                        _selectedSubject = null;
                        _marks = [];
                      });
                    },
                  ),
                ),
                const SizedBox(height: 10),
                // Subject selector
                if (_selectedTurma != null)
                  subjectsAsync!.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => Text('Erro: $e', style: const TextStyle(color: AppTheme.danger)),
                    data: (subjects) => subjects.isEmpty
                        ? Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.orange.shade200),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.warning_amber_outlined, color: Colors.orange, size: 18),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Esta turma não tem disciplinas atribuídas. Configure em Académico → Pautas.',
                                    style: TextStyle(fontSize: 12, color: Colors.orange),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : DropdownButtonFormField<String>(
                            value: _selectedSubject?.id,
                            decoration: const InputDecoration(
                              labelText: 'Disciplina',
                              prefixIcon: Icon(Icons.book_outlined),
                              isDense: true,
                            ),
                            items: subjects
                                .map((s) => DropdownMenuItem(
                                      value: s.id,
                                      child: Text(s.subjectName + (s.subjectCode != null ? ' (${s.subjectCode})' : '')),
                                    ))
                                .toList(),
                            onChanged: (id) {
                              final subj = subjects.firstWhere((s) => s.id == id);
                              setState(() {
                                _selectedSubject = subj;
                                _marks = [];
                              });
                              _loadMarks();
                            },
                          ),
                  ),
                const SizedBox(height: 10),
                // Trimester selector
                Row(
                  children: [
                    const Text('Trimestre:', style: TextStyle(fontWeight: FontWeight.w500)),
                    const SizedBox(width: 12),
                    for (final t in [1, 2, 3])
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text('${t}º'),
                          selected: _selectedTrimester == t,
                          onSelected: (_) {
                            setState(() {
                              _selectedTrimester = t;
                              _marks = [];
                            });
                            if (_selectedSubject != null) _loadMarks();
                          },
                        ),
                      ),
                    const Spacer(),
                    if (_selectedSubject != null)
                      IconButton(
                        tooltip: 'Recarregar',
                        onPressed: _loading ? null : _loadMarks,
                        icon: _loading
                            ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.refresh),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // ── Messages ──────────────────────────────────────────────────────
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.danger.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.danger.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: AppTheme.danger, size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_error!, style: const TextStyle(color: AppTheme.danger, fontSize: 13))),
                  ],
                ),
              ),
            ),
          if (_successMsg != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline, color: Colors.green, size: 16),
                    const SizedBox(width: 8),
                    Text(_successMsg!, style: const TextStyle(color: Colors.green, fontSize: 13)),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 8),
          const Divider(height: 1),

          // ── Grade table ───────────────────────────────────────────────────
          Expanded(
            child: _marks.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.grade_outlined, size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text(
                          _selectedSubject == null
                              ? 'Seleccione turma e disciplina para iniciar'
                              : 'A carregar alunos…',
                          style: const TextStyle(color: AppTheme.textSecondary),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : _GradeTable(
                    marks: _marks,
                    scheme: _selectedSubject?.gradeScheme,
                    isLocked: _selectedSubject?.isLocked ?? false,
                    onChanged: () => setState(() {}),
                  ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Grade entry table — dynamic columns based on grade scheme
// ---------------------------------------------------------------------------

class _GradeTable extends StatelessWidget {
  final List<_StudentMark> marks;
  final _GradeScheme? scheme;
  final bool isLocked;
  final VoidCallback onChanged;

  const _GradeTable({
    required this.marks,
    required this.scheme,
    required this.isLocked,
    required this.onChanged,
  });

  // Angola default when no scheme assigned
  static const _defaultComponents = [
    _SchemeComponent(key: 'mac', label: 'MAC', weight: 0.6),
    _SchemeComponent(key: 'exam', label: 'PE', weight: 0.4),
  ];

  @override
  Widget build(BuildContext context) {
    final components = scheme?.components ?? _defaultComponents;

    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 8,
          headingRowHeight: 40,
          dataRowMinHeight: 52,
          dataRowMaxHeight: 52,
          columns: [
            const DataColumn(
              label: Text('Aluno', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            for (final comp in components)
              DataColumn(
                numeric: true,
                label: Tooltip(
                  message: '${comp.label} (${(comp.weight * 100).toStringAsFixed(0)}%)',
                  child: Text(comp.label,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            const DataColumn(
              numeric: true,
              label: Text('Final', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
          rows: marks.map((m) {
            final finalGrade = m.computedFinal(components);
            final Color finalColor = finalGrade == null
                ? AppTheme.textSecondary
                : finalGrade >= 10
                    ? Colors.green.shade700
                    : AppTheme.danger;

            return DataRow(cells: [
              DataCell(
                SizedBox(
                  width: 180,
                  child: Text(
                    m.childName,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              for (final comp in components)
                DataCell(
                  SizedBox(
                    width: 70,
                    child: isLocked
                        ? Text(
                            m.gradeComponents[comp.key]?.toStringAsFixed(1) ?? '—',
                            textAlign: TextAlign.right,
                          )
                        : _GradeInput(
                            value: m.gradeComponents[comp.key],
                            onChanged: (v) {
                              m.gradeComponents[comp.key] = v;
                              onChanged();
                            },
                          ),
                  ),
                ),
              DataCell(
                SizedBox(
                  width: 60,
                  child: Text(
                    finalGrade?.toStringAsFixed(1) ?? '—',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: finalColor,
                    ),
                  ),
                ),
              ),
            ]);
          }).toList(),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Numeric grade input field (0–20)
// ---------------------------------------------------------------------------

class _GradeInput extends StatefulWidget {
  final double? value;
  final ValueChanged<double?> onChanged;

  const _GradeInput({this.value, required this.onChanged});

  @override
  State<_GradeInput> createState() => _GradeInputState();
}

class _GradeInputState extends State<_GradeInput> {
  late final _ctrl = TextEditingController(
    text: widget.value?.toStringAsFixed(1) ?? '',
  );
  bool _error = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _parse(String v) {
    if (v.isEmpty) {
      setState(() => _error = false);
      widget.onChanged(null);
      return;
    }
    final parsed = double.tryParse(v.replaceAll(',', '.'));
    if (parsed == null || parsed < 0 || parsed > 20) {
      setState(() => _error = true);
      return;
    }
    setState(() => _error = false);
    widget.onChanged(parsed);
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: _error ? AppTheme.danger : null,
      ),
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: _error ? AppTheme.danger : Colors.grey.shade300,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: _error ? AppTheme.danger : Colors.grey.shade300,
          ),
        ),
        hintText: '0–20',
        hintStyle: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
      ),
      onChanged: _parse,
    );
  }
}
