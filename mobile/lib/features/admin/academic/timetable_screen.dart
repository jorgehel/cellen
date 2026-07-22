/// K-12 Timetable screen — week grid: period rows × Mon–Fri columns.
///
/// Admin / Coordinator: tap any cell to assign subject, teacher, room.
/// Teacher: read-only view of the grid.
///
/// Data flow:
///   1. Load turmas list
///   2. User selects a turma → load schedules for that turma
///   3. User selects a schedule → load timetable grid
///   4. Grid shows periods (rows) × days (columns) × cells (subject/teacher/room)
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/auth/auth_state.dart';
import '../../../core/theme/app_theme.dart';

// ---------------------------------------------------------------------------
// Models
// ---------------------------------------------------------------------------

class _TurmaItem {
  final String id;
  final String name;
  const _TurmaItem({required this.id, required this.name});
  factory _TurmaItem.fromJson(Map<String, dynamic> j) =>
      _TurmaItem(id: j['id'] as String, name: j['name'] as String);
}

class _ScheduleItem {
  final String id;
  final String? label;
  const _ScheduleItem({required this.id, this.label});
  factory _ScheduleItem.fromJson(Map<String, dynamic> j) => _ScheduleItem(
        id: j['id'] as String,
        label: [j['school_year_label'], j['turma_name']]
            .where((v) => v != null && (v as String).isNotEmpty)
            .cast<String>()
            .join(' — '),
      );
}

class _Period {
  final String id;
  final int number;
  final String name;
  final String startTime;
  final String endTime;
  final bool isBreak;
  const _Period({
    required this.id,
    required this.number,
    required this.name,
    required this.startTime,
    required this.endTime,
    required this.isBreak,
  });
  factory _Period.fromJson(Map<String, dynamic> j) => _Period(
        id: j['id'] as String,
        number: (j['period_number'] as num).toInt(),
        name: j['name'] as String,
        startTime: j['start_time'] as String,
        endTime: j['end_time'] as String,
        isBreak: j['is_break'] as bool? ?? false,
      );
}

class _Cell {
  final int id;
  final int dayOfWeek;
  final String periodId;
  final String? subjectId;
  final String? subjectName;
  final String? subjectCode;
  final String? employeeId;
  final String? employeeName;
  final String? room;
  const _Cell({
    required this.id,
    required this.dayOfWeek,
    required this.periodId,
    this.subjectId,
    this.subjectName,
    this.subjectCode,
    this.employeeId,
    this.employeeName,
    this.room,
  });
  factory _Cell.fromJson(Map<String, dynamic> j) => _Cell(
        id: (j['id'] as num).toInt(),
        dayOfWeek: (j['day_of_week'] as num).toInt(),
        periodId: j['period_id'] as String,
        subjectId: j['subject_id'] as String?,
        subjectName: j['subject_name'] as String?,
        subjectCode: j['subject_code'] as String?,
        employeeId: j['employee_id'] as String?,
        employeeName: j['employee_name'] as String?,
        room: j['room'] as String?,
      );
}

class _GridData {
  final String scheduleId;
  final String turmaName;
  final String schoolYearLabel;
  final List<_Period> periods;
  final List<_Cell> cells;
  const _GridData({
    required this.scheduleId,
    required this.turmaName,
    required this.schoolYearLabel,
    required this.periods,
    required this.cells,
  });
}

class _SubjectItem {
  final String id;
  final String name;
  final String? code;
  const _SubjectItem({required this.id, required this.name, this.code});
  factory _SubjectItem.fromJson(Map<String, dynamic> j) => _SubjectItem(
        id: j['id'] as String,
        name: j['name'] as String,
        code: j['code'] as String?,
      );
}

class _Requirement {
  final String id;
  final String scheduleId;
  final String subjectId;
  final String? subjectName;
  final String? subjectCode;
  final String employeeId;
  final String? employeeName;
  final int periodsPerWeek;
  final bool allowDoublePeriod;
  final String? preferredTimeOfDay;
  const _Requirement({
    required this.id,
    required this.scheduleId,
    required this.subjectId,
    this.subjectName,
    this.subjectCode,
    required this.employeeId,
    this.employeeName,
    required this.periodsPerWeek,
    required this.allowDoublePeriod,
    this.preferredTimeOfDay,
  });
  factory _Requirement.fromJson(Map<String, dynamic> j) => _Requirement(
        id: j['id'] as String,
        scheduleId: j['schedule_id'] as String,
        subjectId: j['subject_id'] as String,
        subjectName: j['subject_name'] as String?,
        subjectCode: j['subject_code'] as String?,
        employeeId: j['employee_id'] as String,
        employeeName: j['employee_name'] as String?,
        periodsPerWeek: (j['periods_per_week'] as num).toInt(),
        allowDoublePeriod: j['allow_double_period'] as bool? ?? false,
        preferredTimeOfDay: j['preferred_time_of_day'] as String?,
      );
}

class _GenCell {
  final String scheduleId;
  final int dayOfWeek;
  final String periodId;
  final String subjectId;
  final String? subjectName;
  final String employeeId;
  final String? employeeName;
  const _GenCell({
    required this.scheduleId,
    required this.dayOfWeek,
    required this.periodId,
    required this.subjectId,
    this.subjectName,
    required this.employeeId,
    this.employeeName,
  });
  factory _GenCell.fromJson(Map<String, dynamic> j) => _GenCell(
        scheduleId: j['schedule_id'] as String,
        dayOfWeek: (j['day_of_week'] as num).toInt(),
        periodId: j['period_id'] as String,
        subjectId: j['subject_id'] as String,
        subjectName: j['subject_name'] as String?,
        employeeId: j['employee_id'] as String,
        employeeName: j['employee_name'] as String?,
      );
  Map<String, dynamic> toJson() => {
        'schedule_id': scheduleId,
        'day_of_week': dayOfWeek,
        'period_id': periodId,
        'subject_id': subjectId,
        'subject_name': subjectName,
        'employee_id': employeeId,
        'employee_name': employeeName,
      };
}

class _GenConflict {
  final String requirementId;
  final String subjectName;
  final String employeeName;
  final int periodsRequested;
  final int periodsAssigned;
  final String reason;
  const _GenConflict({
    required this.requirementId,
    required this.subjectName,
    required this.employeeName,
    required this.periodsRequested,
    required this.periodsAssigned,
    required this.reason,
  });
  factory _GenConflict.fromJson(Map<String, dynamic> j) => _GenConflict(
        requirementId: j['requirement_id'] as String,
        subjectName: j['subject_name'] as String,
        employeeName: j['employee_name'] as String,
        periodsRequested: (j['periods_requested'] as num).toInt(),
        periodsAssigned: (j['periods_assigned'] as num).toInt(),
        reason: j['reason'] as String,
      );
}

class _GenerateResult {
  final String status;
  final List<_GenCell> cells;
  final List<_GenConflict> conflicts;
  const _GenerateResult({
    required this.status,
    required this.cells,
    required this.conflicts,
  });
}

class _EmployeeItem {
  final String id;
  final String name;
  const _EmployeeItem({required this.id, required this.name});
  factory _EmployeeItem.fromJson(Map<String, dynamic> j) {
    final first = j['first_name'] as String? ?? '';
    final last = j['last_name'] as String? ?? '';
    return _EmployeeItem(
      id: j['id'] as String,
      name: '$first $last'.trim(),
    );
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final _turmasProvider = FutureProvider.autoDispose<List<_TurmaItem>>((ref) async {
  final data = await ref.read(apiClientProvider).get('/academic/turmas') as List;
  return data.map((e) => _TurmaItem.fromJson(e as Map<String, dynamic>)).toList();
});

final _schedulesForTurmaProvider =
    FutureProvider.autoDispose.family<List<_ScheduleItem>, String>((ref, turmaId) async {
  final data = await ref
      .read(apiClientProvider)
      .get('/academic/schedules?turma_id=$turmaId') as List;
  return data.map((e) => _ScheduleItem.fromJson(e as Map<String, dynamic>)).toList();
});

final _gridProvider =
    FutureProvider.autoDispose.family<_GridData, String>((ref, scheduleId) async {
  final api = ref.read(apiClientProvider);
  final raw = await api.get('/timetable/grid?schedule_id=$scheduleId') as Map<String, dynamic>;
  return _GridData(
    scheduleId: raw['schedule_id'] as String,
    turmaName: raw['turma_name'] as String? ?? '',
    schoolYearLabel: raw['school_year_label'] as String? ?? '',
    periods: (raw['periods'] as List)
        .map((e) => _Period.fromJson(e as Map<String, dynamic>))
        .toList(),
    cells: (raw['cells'] as List)
        .map((e) => _Cell.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
});

final _subjectsProvider = FutureProvider.autoDispose<List<_SubjectItem>>((ref) async {
  final data = await ref.read(apiClientProvider).get('/grades/subjects') as List;
  return data.map((e) => _SubjectItem.fromJson(e as Map<String, dynamic>)).toList();
});

final _teachersProvider = FutureProvider.autoDispose<List<_EmployeeItem>>((ref) async {
  final data = await ref.read(apiClientProvider).get('/employees?limit=200') as List;
  return data.map((e) => _EmployeeItem.fromJson(e as Map<String, dynamic>)).toList();
});

final _periodsListProvider = FutureProvider.autoDispose<List<_Period>>((ref) async {
  final data = await ref.read(apiClientProvider).get('/timetable/periods') as List;
  return data.map((e) => _Period.fromJson(e as Map<String, dynamic>)).toList();
});

final _requirementsProvider =
    FutureProvider.autoDispose.family<List<_Requirement>, String>((ref, scheduleId) async {
  final data = await ref
      .read(apiClientProvider)
      .get('/timetable/requirements?schedule_id=$scheduleId') as List;
  return data.map((e) => _Requirement.fromJson(e as Map<String, dynamic>)).toList();
});

// ---------------------------------------------------------------------------
// Deterministic subject color palette
// ---------------------------------------------------------------------------

const _subjectColors = [
  Color(0xFF1565C0), // blue-800
  Color(0xFF2E7D32), // green-800
  Color(0xFF6A1B9A), // purple-800
  Color(0xFFAD1457), // pink-800
  Color(0xFFE65100), // orange-800
  Color(0xFF00695C), // teal-800
  Color(0xFF4527A0), // deep-purple-800
  Color(0xFF558B2F), // light-green-800
  Color(0xFF0277BD), // light-blue-800
  Color(0xFF827717), // lime-900
];

Color _colorForSubject(String? subjectId) {
  if (subjectId == null) return Colors.grey.shade400;
  final idx = subjectId.codeUnits.fold(0, (a, b) => a + b) % _subjectColors.length;
  return _subjectColors[idx];
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class TimetableScreen extends ConsumerStatefulWidget {
  const TimetableScreen({super.key});

  @override
  ConsumerState<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends ConsumerState<TimetableScreen> {
  _TurmaItem? _selectedTurma;
  _ScheduleItem? _selectedSchedule;

  static const _days = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex'];

  bool get _canEdit {
    final auth = ref.read(authProvider);
    return auth.hasAnyRole([UserRole.schoolAdmin, UserRole.coordinator]);
  }

  @override
  Widget build(BuildContext context) {
    final turmasAsync = ref.watch(_turmasProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Horário Lectivo'),
        actions: [
          if (_selectedSchedule != null) ...[
            if (_canEdit)
              IconButton(
                icon: const Icon(Icons.list_alt_outlined),
                tooltip: 'Requisitos',
                onPressed: _showRequirementsSheet,
              ),
            if (_canEdit)
              IconButton(
                icon: const Icon(Icons.auto_fix_high),
                tooltip: 'Gerar Horário',
                onPressed: _generateAndPreview,
              ),
            IconButton(
              icon: const Icon(Icons.access_time_outlined),
              tooltip: 'Períodos',
              onPressed: () => _showPeriodsDialog(),
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          // ── Selectors ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: turmasAsync.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => Text('Erro: $e',
                        style: const TextStyle(color: AppTheme.danger)),
                    data: (turmas) => DropdownButtonFormField<_TurmaItem>(
                      value: _selectedTurma,
                      decoration: const InputDecoration(
                        labelText: 'Turma',
                        border: OutlineInputBorder(),
                        isDense: true,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      items: turmas
                          .map((t) => DropdownMenuItem(
                              value: t, child: Text(t.name)))
                          .toList(),
                      onChanged: (t) => setState(() {
                        _selectedTurma = t;
                        _selectedSchedule = null;
                      }),
                    ),
                  ),
                ),
                if (_selectedTurma != null) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: ref
                        .watch(_schedulesForTurmaProvider(_selectedTurma!.id))
                        .when(
                          loading: () => const LinearProgressIndicator(),
                          error: (e, _) => Text('Erro: $e'),
                          data: (schedules) =>
                              DropdownButtonFormField<_ScheduleItem>(
                            value: _selectedSchedule,
                            decoration: const InputDecoration(
                              labelText: 'Horário',
                              border: OutlineInputBorder(),
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                            ),
                            items: schedules
                                .map((s) => DropdownMenuItem(
                                    value: s,
                                    child: Text(s.label ?? s.id,
                                        overflow: TextOverflow.ellipsis)))
                                .toList(),
                            onChanged: (s) =>
                                setState(() => _selectedSchedule = s),
                          ),
                        ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          // ── Grid ──────────────────────────────────────────────────────────
          Expanded(
            child: _selectedSchedule == null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.table_chart_outlined,
                            size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        Text(
                          _selectedTurma == null
                              ? 'Seleccione uma turma'
                              : 'Seleccione um horário',
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  )
                : ref.watch(_gridProvider(_selectedSchedule!.id)).when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (e, _) => Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline,
                                size: 48, color: AppTheme.danger),
                            const SizedBox(height: 8),
                            Text(e.toString()),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: () => ref.invalidate(
                                  _gridProvider(_selectedSchedule!.id)),
                              icon: const Icon(Icons.refresh),
                              label: const Text('Tentar novamente'),
                            ),
                          ],
                        ),
                      ),
                      data: (grid) => _buildGrid(grid),
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid(_GridData grid) {
    // Build lookup: periodId × dayOfWeek → _Cell
    final cellMap = <String, _Cell>{};
    for (final cell in grid.cells) {
      cellMap['${cell.periodId}_${cell.dayOfWeek}'] = cell;
    }

    const colWidth = 130.0;
    const rowHeaderWidth = 90.0;
    const cellHeight = 88.0;

    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Day header row ────────────────────────────────────────────
            Row(
              children: [
                SizedBox(width: rowHeaderWidth), // period label space
                ..._days.asMap().entries.map((entry) {
                  return Container(
                    width: colWidth,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withAlpha(20),
                      border: Border(
                        bottom: BorderSide(color: Colors.grey.shade300),
                        right: BorderSide(color: Colors.grey.shade200),
                      ),
                    ),
                    child: Text(
                      _days[entry.key],
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary,
                        fontSize: 13,
                      ),
                    ),
                  );
                }),
              ],
            ),
            // ── Period rows ───────────────────────────────────────────────
            ...grid.periods.map((period) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Period label
                  Container(
                    width: rowHeaderWidth,
                    height: cellHeight,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: period.isBreak
                          ? Colors.grey.shade100
                          : Colors.white,
                      border: Border(
                        bottom: BorderSide(color: Colors.grey.shade200),
                        right: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          period.name,
                          style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          period.startTime.substring(0, 5),
                          style: TextStyle(
                              fontSize: 10, color: Colors.grey.shade600),
                        ),
                        Text(
                          period.endTime.substring(0, 5),
                          style: TextStyle(
                              fontSize: 10, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  // Day cells
                  ...List.generate(5, (dayIdx) {
                    final cell = cellMap['${period.id}_$dayIdx'];
                    if (period.isBreak) {
                      return _BreakCell(
                          width: colWidth, height: cellHeight);
                    }
                    return _GridCell(
                      width: colWidth,
                      height: cellHeight,
                      cell: cell,
                      canEdit: _canEdit,
                      onTap: _canEdit
                          ? () => _showCellDialog(
                                grid.scheduleId,
                                period,
                                dayIdx,
                                cell,
                              )
                          : null,
                    );
                  }),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Cell edit dialog
  // ---------------------------------------------------------------------------

  Future<void> _showCellDialog(
    String scheduleId,
    _Period period,
    int dayOfWeek,
    _Cell? existing,
  ) async {
    String? subjectId = existing?.subjectId;
    String? employeeId = existing?.employeeId;
    final roomCtrl = TextEditingController(text: existing?.room ?? '');

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => _CellEditDialog(
        period: period,
        dayLabel: _days[dayOfWeek],
        initialSubjectId: subjectId,
        initialEmployeeId: employeeId,
        roomController: roomCtrl,
        onSave: (sid, eid, room) async {
          final api = ref.read(apiClientProvider);
          await api.post('/timetable/grid/cells', data: {
            'schedule_id': scheduleId,
            'day_of_week': dayOfWeek,
            'period_id': period.id,
            'subject_id': sid,
            'employee_id': eid,
            'room': room?.isEmpty == true ? null : room,
          });
        },
        onClear: existing != null
            ? () async {
                final api = ref.read(apiClientProvider);
                await api.delete('/timetable/grid/cells/${existing.id}');
              }
            : null,
      ),
    );

    if (result == true) {
      ref.invalidate(_gridProvider(scheduleId));
    }
  }

  // ---------------------------------------------------------------------------
  // Requirements sheet
  // ---------------------------------------------------------------------------

  void _showRequirementsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => _RequirementsSheet(
        scheduleId: _selectedSchedule!.id,
        scheduleLabel: _selectedSchedule!.label ?? _selectedSchedule!.id,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Generate + preview
  // ---------------------------------------------------------------------------

  Future<void> _generateAndPreview() async {
    final scheduleId = _selectedSchedule!.id;

    // Check requirements exist first
    final reqs = ref.read(_requirementsProvider(scheduleId)).valueOrNull;
    if (reqs != null && reqs.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            'Adicione requisitos primeiro (botão "Requisitos" na barra de ferramentas).'),
      ));
      return;
    }

    // Show loading overlay
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AlertDialog(
        content: SizedBox(
          width: 200,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('A gerar horário…', textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );

    _GenerateResult? result;
    String? error;
    try {
      final raw = await ref.read(apiClientProvider).post(
        '/timetable/generate',
        data: {
          'schedule_ids': [scheduleId],
        },
      ) as Map<String, dynamic>;
      result = _GenerateResult(
        status: raw['status'] as String,
        cells: (raw['cells'] as List)
            .map((e) => _GenCell.fromJson(e as Map<String, dynamic>))
            .toList(),
        conflicts: (raw['conflicts'] as List)
            .map((e) => _GenConflict.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
    } catch (e) {
      error = e.toString();
    }

    if (!mounted) return;
    Navigator.of(context).pop(); // close loading dialog

    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erro: $error')));
      return;
    }

    // Load periods for grid display
    final periodsAsync = ref.read(_periodsListProvider);
    final periods = periodsAsync.valueOrNull ?? [];

    if (!mounted) return;
    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _PreviewDialog(
        scheduleId: scheduleId,
        result: result!,
        periods: periods,
      ),
    );

    if (accepted == true) {
      try {
        await ref.read(apiClientProvider).post('/timetable/apply', data: {
          'schedule_ids': [scheduleId],
          'cells': result!.cells.map((c) => c.toJson()).toList(),
          'replace_existing': true,
        });
        ref.invalidate(_gridProvider(scheduleId));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Horário aplicado com sucesso'),
            backgroundColor: Colors.green,
          ));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao aplicar: $e')),
          );
        }
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Periods management dialog
  // ---------------------------------------------------------------------------

  void _showPeriodsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => _PeriodsDialog(
        canEdit: _canEdit,
        onChanged: () {
          if (_selectedSchedule != null) {
            ref.invalidate(_gridProvider(_selectedSchedule!.id));
          }
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Break cell widget
// ---------------------------------------------------------------------------

class _BreakCell extends StatelessWidget {
  final double width;
  final double height;
  const _BreakCell({required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
          right: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        'Intervalo',
        style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Grid cell widget
// ---------------------------------------------------------------------------

class _GridCell extends StatelessWidget {
  final double width;
  final double height;
  final _Cell? cell;
  final bool canEdit;
  final VoidCallback? onTap;

  const _GridCell({
    required this.width,
    required this.height,
    required this.cell,
    required this.canEdit,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isEmpty = cell?.subjectId == null;
    final color = _colorForSubject(cell?.subjectId);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: isEmpty ? Colors.white : color.withAlpha(18),
          border: Border(
            bottom: BorderSide(color: Colors.grey.shade200),
            right: BorderSide(color: Colors.grey.shade200),
            left: isEmpty
                ? BorderSide.none
                : BorderSide(color: color, width: 3),
          ),
        ),
        child: isEmpty
            ? canEdit
                ? Center(
                    child: Icon(Icons.add,
                        size: 18, color: Colors.grey.shade300))
                : null
            : Padding(
                padding: const EdgeInsets.fromLTRB(6, 6, 6, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cell!.subjectCode ?? cell!.subjectName ?? '',
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (cell!.subjectCode != null &&
                        cell!.subjectName != null)
                      Text(
                        cell!.subjectName!,
                        style: TextStyle(
                            fontSize: 10, color: Colors.grey.shade700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 2),
                    if (cell!.employeeName != null)
                      Text(
                        cell!.employeeName!,
                        style: TextStyle(
                            fontSize: 10, color: Colors.grey.shade600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (cell!.room != null)
                      Text(
                        'Sala ${cell!.room}',
                        style: TextStyle(
                            fontSize: 10, color: Colors.grey.shade500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Cell edit dialog
// ---------------------------------------------------------------------------

class _CellEditDialog extends ConsumerStatefulWidget {
  final _Period period;
  final String dayLabel;
  final String? initialSubjectId;
  final String? initialEmployeeId;
  final TextEditingController roomController;
  final Future<void> Function(String? subjectId, String? employeeId, String? room) onSave;
  final Future<void> Function()? onClear;

  const _CellEditDialog({
    required this.period,
    required this.dayLabel,
    required this.initialSubjectId,
    required this.initialEmployeeId,
    required this.roomController,
    required this.onSave,
    this.onClear,
  });

  @override
  ConsumerState<_CellEditDialog> createState() => _CellEditDialogState();
}

class _CellEditDialogState extends ConsumerState<_CellEditDialog> {
  late String? _subjectId;
  late String? _employeeId;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _subjectId = widget.initialSubjectId;
    _employeeId = widget.initialEmployeeId;
  }

  @override
  Widget build(BuildContext context) {
    final subjectsAsync = ref.watch(_subjectsProvider);
    final teachersAsync = ref.watch(_teachersProvider);

    return AlertDialog(
      title: Text('${widget.dayLabel} — ${widget.period.name}'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.danger.withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_error!,
                    style: const TextStyle(color: AppTheme.danger)),
              ),
              const SizedBox(height: 12),
            ],
            subjectsAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) =>
                  Text('Erro ao carregar disciplinas: $e'),
              data: (subjects) => DropdownButtonFormField<String>(
                value: _subjectId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Disciplina',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: [
                  const DropdownMenuItem(
                      value: null, child: Text('— Nenhuma —')),
                  ...subjects.map((s) => DropdownMenuItem(
                        value: s.id,
                        child: Text(
                          s.code != null ? '${s.code} — ${s.name}' : s.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      )),
                ],
                onChanged: (v) => setState(() => _subjectId = v),
              ),
            ),
            const SizedBox(height: 12),
            teachersAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) =>
                  Text('Erro ao carregar professores: $e'),
              data: (teachers) => DropdownButtonFormField<String>(
                value: _employeeId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Professor',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: [
                  const DropdownMenuItem(
                      value: null, child: Text('— Nenhum —')),
                  ...teachers.map((t) => DropdownMenuItem(
                        value: t.id,
                        child: Text(t.name,
                            overflow: TextOverflow.ellipsis),
                      )),
                ],
                onChanged: (v) => setState(() => _employeeId = v),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: widget.roomController,
              decoration: const InputDecoration(
                labelText: 'Sala (opcional)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
      ),
      actionsAlignment: widget.onClear != null
          ? MainAxisAlignment.spaceBetween
          : MainAxisAlignment.end,
      actions: [
        if (widget.onClear != null)
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppTheme.danger),
            onPressed: _saving ? null : _clear,
            child: const Text('Limpar'),
          ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(
              onPressed: _saving
                  ? null
                  : () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Guardar'),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(
          _subjectId, _employeeId, widget.roomController.text);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _saving = false;
      });
    }
  }

  Future<void> _clear() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onClear!();
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _saving = false;
      });
    }
  }
}

// ---------------------------------------------------------------------------
// Periods management dialog (admin: create/edit periods)
// ---------------------------------------------------------------------------

class _PeriodsDialog extends ConsumerStatefulWidget {
  final bool canEdit;
  final VoidCallback onChanged;
  const _PeriodsDialog({required this.canEdit, required this.onChanged});

  @override
  ConsumerState<_PeriodsDialog> createState() => _PeriodsDialogState();
}

class _PeriodsDialogState extends ConsumerState<_PeriodsDialog> {
  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_periodsListProvider);

    return AlertDialog(
      title: const Text('Períodos Lectivos'),
      content: SizedBox(
        width: 440,
        child: async.when(
          loading: () => const Center(
              child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator())),
          error: (e, _) => Text('Erro: $e'),
          data: (periods) => periods.isEmpty
              ? const Text('Nenhum período definido.')
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: periods.length,
                  itemBuilder: (ctx, i) {
                    final p = periods[i];
                    return ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 14,
                        backgroundColor: p.isBreak
                            ? Colors.grey.shade200
                            : AppTheme.primary.withAlpha(30),
                        child: Text(
                          p.number.toString(),
                          style: TextStyle(
                            fontSize: 11,
                            color: p.isBreak
                                ? Colors.grey.shade600
                                : AppTheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(p.name),
                      subtitle: Text(
                          '${p.startTime.substring(0, 5)} – ${p.endTime.substring(0, 5)}'
                          '${p.isBreak ? '  (Intervalo)' : ''}'),
                      trailing: widget.canEdit
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined,
                                      size: 18),
                                  tooltip: 'Editar',
                                  onPressed: () =>
                                      _showPeriodForm(context, p),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outlined,
                                      size: 18, color: AppTheme.danger),
                                  tooltip: 'Eliminar',
                                  onPressed: () => _delete(p),
                                ),
                              ],
                            )
                          : null,
                    );
                  },
                ),
        ),
      ),
      actions: [
        if (widget.canEdit)
          TextButton.icon(
            onPressed: () => _showPeriodForm(context, null),
            icon: const Icon(Icons.add),
            label: const Text('Novo Período'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Fechar'),
        ),
      ],
    );
  }

  Future<void> _showPeriodForm(BuildContext ctx, _Period? existing) async {
    final numCtrl =
        TextEditingController(text: existing?.number.toString() ?? '');
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final startCtrl = TextEditingController(
        text: existing?.startTime.substring(0, 5) ?? '');
    final endCtrl =
        TextEditingController(text: existing?.endTime.substring(0, 5) ?? '');
    bool isBreak = existing?.isBreak ?? false;
    String? error;

    final saved = await showDialog<bool>(
      context: ctx,
      builder: (dctx) => StatefulBuilder(
        builder: (dctx, setS) => AlertDialog(
          title: Text(existing == null ? 'Novo Período' : 'Editar Período'),
          content: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (error != null) ...[
                  Text(error!,
                      style: const TextStyle(color: AppTheme.danger)),
                  const SizedBox(height: 8),
                ],
                if (existing == null)
                  TextFormField(
                    controller: numCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Nº do período',
                        border: OutlineInputBorder(),
                        isDense: true),
                    keyboardType: TextInputType.number,
                  ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Nome (ex: 1ª Aula)',
                      border: OutlineInputBorder(),
                      isDense: true),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: startCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Início (HH:MM)',
                      border: OutlineInputBorder(),
                      isDense: true),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: endCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Fim (HH:MM)',
                      border: OutlineInputBorder(),
                      isDense: true),
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Intervalo (sem disciplinas)'),
                  value: isBreak,
                  onChanged: (v) => setS(() => isBreak = v ?? false),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dctx).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () async {
                final api = ref.read(apiClientProvider);
                try {
                  final body = {
                    if (existing == null)
                      'period_number': int.parse(numCtrl.text),
                    'name': nameCtrl.text,
                    'start_time': '${startCtrl.text}:00',
                    'end_time': '${endCtrl.text}:00',
                    'is_break': isBreak,
                  };
                  if (existing == null) {
                    await api.post('/timetable/periods', data: body);
                  } else {
                    await api.patch(
                        '/timetable/periods/${existing.id}', data: body);
                  }
                  if (dctx.mounted) Navigator.of(dctx).pop(true);
                } catch (e) {
                  setS(() => error = e.toString());
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );

    if (saved == true) {
      ref.invalidate(_periodsListProvider);
      widget.onChanged();
    }
  }

  Future<void> _delete(_Period p) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Período'),
        content: Text('Eliminar "${p.name}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(apiClientProvider).delete('/timetable/periods/${p.id}');
      ref.invalidate(_periodsListProvider);
      widget.onChanged();
    }
  }
}

// ---------------------------------------------------------------------------
// Requirements bottom sheet
// ---------------------------------------------------------------------------

class _RequirementsSheet extends ConsumerStatefulWidget {
  final String scheduleId;
  final String scheduleLabel;
  const _RequirementsSheet({
    required this.scheduleId,
    required this.scheduleLabel,
  });

  @override
  ConsumerState<_RequirementsSheet> createState() => _RequirementsSheetState();
}

class _RequirementsSheetState extends ConsumerState<_RequirementsSheet> {
  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_requirementsProvider(widget.scheduleId));

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollCtrl) => Column(
        children: [
          // Handle + title
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Text(
                        'Requisitos — ${widget.scheduleLabel}',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      Text(
                        'Defina as disciplinas, professores e nº de aulas por semana',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  tooltip: 'Adicionar requisito',
                  color: AppTheme.primary,
                  onPressed: () => _showAddDialog(null),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: async.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Erro: $e')),
              data: (reqs) => reqs.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.list_alt_outlined,
                              size: 56, color: Colors.grey.shade300),
                          const SizedBox(height: 12),
                          Text(
                            'Nenhum requisito definido.',
                            style:
                                TextStyle(color: Colors.grey.shade500),
                          ),
                          const SizedBox(height: 8),
                          FilledButton.icon(
                            onPressed: () => _showAddDialog(null),
                            icon: const Icon(Icons.add),
                            label: const Text('Adicionar primeiro requisito'),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                      itemCount: reqs.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 4),
                      itemBuilder: (ctx, i) =>
                          _RequirementTile(
                            req: reqs[i],
                            onEdit: () => _showAddDialog(reqs[i]),
                            onDelete: () => _delete(reqs[i]),
                          ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddDialog(_Requirement? existing) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => _AddRequirementDialog(
        scheduleId: widget.scheduleId,
        existing: existing,
      ),
    );
    if (saved == true) {
      ref.invalidate(_requirementsProvider(widget.scheduleId));
    }
  }

  Future<void> _delete(_Requirement req) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remover Requisito'),
        content: Text(
          'Remover "${req.subjectName ?? req.subjectId}" '
          '(${req.periodsPerWeek}×/semana)?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await ref
            .read(apiClientProvider)
            .delete('/timetable/requirements/${req.id}');
        ref.invalidate(_requirementsProvider(widget.scheduleId));
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Erro: $e')));
        }
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Requirement tile
// ---------------------------------------------------------------------------

class _RequirementTile extends StatelessWidget {
  final _Requirement req;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _RequirementTile({
    required this.req,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final color = _colorForSubject(req.subjectId);
    final timeLabel = switch (req.preferredTimeOfDay) {
      'morning' => '☀ Manhã',
      'afternoon' => '🌆 Tarde',
      _ => null,
    };
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withAlpha(30),
          child: Text(
            req.periodsPerWeek.toString(),
            style: TextStyle(
                color: color, fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        title: Text(
          req.subjectCode != null
              ? '${req.subjectCode} — ${req.subjectName ?? ''}'
              : (req.subjectName ?? req.subjectId),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          [
            req.employeeName ?? 'Professor não definido',
            '${req.periodsPerWeek}×/semana',
            if (req.allowDoublePeriod) 'Dupla permitida',
            if (timeLabel != null) timeLabel,
          ].join(' · '),
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 18),
              onPressed: onEdit,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline,
                  size: 18, color: AppTheme.danger),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Add / Edit requirement dialog
// ---------------------------------------------------------------------------

class _AddRequirementDialog extends ConsumerStatefulWidget {
  final String scheduleId;
  final _Requirement? existing;
  const _AddRequirementDialog(
      {required this.scheduleId, required this.existing});

  @override
  ConsumerState<_AddRequirementDialog> createState() =>
      _AddRequirementDialogState();
}

class _AddRequirementDialogState
    extends ConsumerState<_AddRequirementDialog> {
  String? _subjectId;
  String? _employeeId;
  int _periodsPerWeek = 2;
  bool _allowDouble = false;
  String? _preferredTime; // null | 'morning' | 'afternoon'
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      final e = widget.existing!;
      _subjectId = e.subjectId;
      _employeeId = e.employeeId;
      _periodsPerWeek = e.periodsPerWeek;
      _allowDouble = e.allowDoublePeriod;
      _preferredTime = e.preferredTimeOfDay;
    }
  }

  @override
  Widget build(BuildContext context) {
    final subjectsAsync = ref.watch(_subjectsProvider);
    final teachersAsync = ref.watch(_teachersProvider);
    final isEdit = widget.existing != null;

    return AlertDialog(
      title: Text(isEdit ? 'Editar Requisito' : 'Novo Requisito'),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.danger.withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(_error!,
                      style: const TextStyle(color: AppTheme.danger)),
                ),
                const SizedBox(height: 12),
              ],
              subjectsAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) =>
                    Text('Erro ao carregar disciplinas: $e'),
                data: (subjects) => DropdownButtonFormField<String>(
                  value: _subjectId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Disciplina *',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: subjects
                      .map((s) => DropdownMenuItem(
                            value: s.id,
                            child: Text(
                              s.code != null
                                  ? '${s.code} — ${s.name}'
                                  : s.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ))
                      .toList(),
                  onChanged:
                      isEdit ? null : (v) => setState(() => _subjectId = v),
                ),
              ),
              const SizedBox(height: 12),
              teachersAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) =>
                    Text('Erro ao carregar professores: $e'),
                data: (teachers) => DropdownButtonFormField<String>(
                  value: _employeeId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Professor *',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: teachers
                      .map((t) => DropdownMenuItem(
                            value: t.id,
                            child: Text(t.name,
                                overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _employeeId = v),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('Aulas por semana:',
                      style: TextStyle(fontSize: 13)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: _periodsPerWeek > 1
                        ? () =>
                            setState(() => _periodsPerWeek--)
                        : null,
                  ),
                  Text(
                    '$_periodsPerWeek',
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: _periodsPerWeek < 10
                        ? () =>
                            setState(() => _periodsPerWeek++)
                        : null,
                  ),
                ],
              ),
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: const Text('Permitir aula dupla (2 períodos seguidos)',
                    style: TextStyle(fontSize: 13)),
                value: _allowDouble,
                onChanged: (v) =>
                    setState(() => _allowDouble = v ?? false),
              ),
              const SizedBox(height: 4),
              const Text('Preferência de horário:',
                  style: TextStyle(fontSize: 13)),
              const SizedBox(height: 6),
              SegmentedButton<String?>(
                segments: const [
                  ButtonSegment(value: null, label: Text('Qualquer')),
                  ButtonSegment(value: 'morning', label: Text('Manhã')),
                  ButtonSegment(value: 'afternoon', label: Text('Tarde')),
                ],
                selected: {_preferredTime},
                onSelectionChanged: (s) =>
                    setState(() => _preferredTime = s.first),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving
              ? null
              : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Guardar'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (_subjectId == null) {
      setState(() => _error = 'Seleccione uma disciplina.');
      return;
    }
    if (_employeeId == null) {
      setState(() => _error = 'Seleccione um professor.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      final body = {
        'schedule_id': widget.scheduleId,
        'subject_id': _subjectId,
        'employee_id': _employeeId,
        'periods_per_week': _periodsPerWeek,
        'allow_double_period': _allowDouble,
        'preferred_time_of_day': _preferredTime,
      };
      if (widget.existing == null) {
        await api.post('/timetable/requirements', data: body);
      } else {
        await api.patch(
          '/timetable/requirements/${widget.existing!.id}',
          data: {
            'employee_id': _employeeId,
            'periods_per_week': _periodsPerWeek,
            'allow_double_period': _allowDouble,
            'preferred_time_of_day': _preferredTime,
          },
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _saving = false;
      });
    }
  }
}

// ---------------------------------------------------------------------------
// Generate preview dialog
// ---------------------------------------------------------------------------

class _PreviewDialog extends StatefulWidget {
  final String scheduleId;
  final _GenerateResult result;
  final List<_Period> periods;
  const _PreviewDialog({
    required this.scheduleId,
    required this.result,
    required this.periods,
  });

  @override
  State<_PreviewDialog> createState() => _PreviewDialogState();
}

class _PreviewDialogState extends State<_PreviewDialog> {
  bool _showConflicts = true;
  static const _days = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex'];

  @override
  Widget build(BuildContext context) {
    final status = widget.result.status;
    final conflicts = widget.result.conflicts;
    final cells = widget.result.cells;

    // Convert GenCells to display cells (fake id = -1)
    final fakeCells = cells.map((c) => _Cell(
          id: -1,
          dayOfWeek: c.dayOfWeek,
          periodId: c.periodId,
          subjectId: c.subjectId,
          subjectName: c.subjectName,
          employeeId: c.employeeId,
          employeeName: c.employeeName,
        )).toList();

    final cellMap = <String, _Cell>{};
    for (final cell in fakeCells) {
      cellMap['${cell.periodId}_${cell.dayOfWeek}'] = cell;
    }

    // Status badge
    final (statusLabel, statusColor) = switch (status) {
      'optimal' => ('Óptimo — sem conflitos', Colors.green),
      'feasible' => ('Solução encontrada', Colors.green),
      'partial' => ('Parcial — ${conflicts.length} conflito(s)', Colors.orange),
      _ => ('Insolúvel', AppTheme.danger),
    };

    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          title: const Text('Proposta do Motor'),
          actions: [
            if (conflicts.isNotEmpty)
              IconButton(
                icon: Badge(
                  label: Text('${conflicts.length}'),
                  child: Icon(
                    Icons.warning_amber_outlined,
                    color: conflicts.isEmpty ? Colors.green : Colors.orange,
                  ),
                ),
                tooltip: 'Ver conflitos',
                onPressed: () =>
                    setState(() => _showConflicts = !_showConflicts),
              ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: cells.isEmpty
                  ? null
                  : () => Navigator.of(context).pop(true),
              icon: const Icon(Icons.check),
              label: const Text('Aceitar e Aplicar'),
            ),
            const SizedBox(width: 12),
          ],
        ),
        body: Column(
          children: [
            // Status banner
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: statusColor.withAlpha(25),
              child: Row(
                children: [
                  Icon(
                    status == 'partial' || status == 'infeasible'
                        ? Icons.warning_amber_rounded
                        : Icons.check_circle_outline,
                    color: statusColor,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    statusLabel,
                    style: TextStyle(
                        color: statusColor, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  Text(
                    '${cells.length} aulas alocadas',
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),

            // Conflicts panel
            if (conflicts.isNotEmpty && _showConflicts)
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxHeight: 160),
                color: Colors.orange.withAlpha(15),
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  itemCount: conflicts.length,
                  itemBuilder: (ctx, i) {
                    final c = conflicts[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.warning_amber_outlined,
                              size: 16, color: Colors.orange),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${c.subjectName} · ${c.employeeName} — '
                                  '${c.periodsAssigned}/${c.periodsRequested} aulas alocadas',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  c.reason,
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade700),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

            // Grid (read-only preview)
            Expanded(
              child: cells.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.block,
                              size: 56, color: Colors.grey.shade300),
                          const SizedBox(height: 12),
                          const Text(
                              'Não foi possível gerar nenhuma alocação.'),
                          const SizedBox(height: 8),
                          Text(
                            'Verifique os requisitos e a disponibilidade dos professores.',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    )
                  : _buildPreviewGrid(cellMap),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewGrid(Map<String, _Cell> cellMap) {
    final periods = widget.periods;
    const colWidth = 130.0;
    const rowHeaderWidth = 90.0;
    const cellHeight = 88.0;

    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Day header
            Row(
              children: [
                const SizedBox(width: rowHeaderWidth),
                ..._days.asMap().entries.map((e) => Container(
                      width: colWidth,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withAlpha(20),
                        border: Border(
                          bottom: BorderSide(color: Colors.grey.shade300),
                          right: BorderSide(color: Colors.grey.shade200),
                        ),
                      ),
                      child: Text(
                        _days[e.key],
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary,
                          fontSize: 13,
                        ),
                      ),
                    )),
              ],
            ),
            // Period rows
            ...periods.map((period) => Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: rowHeaderWidth,
                      height: cellHeight,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: period.isBreak
                            ? Colors.grey.shade100
                            : Colors.white,
                        border: Border(
                          bottom: BorderSide(color: Colors.grey.shade200),
                          right: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(period.name,
                              style: const TextStyle(
                                  fontSize: 11, fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          Text(period.startTime.substring(0, 5),
                              style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey.shade600)),
                        ],
                      ),
                    ),
                    ...List.generate(5, (dayIdx) {
                      if (period.isBreak) {
                        return _BreakCell(
                            width: colWidth, height: cellHeight);
                      }
                      final cell =
                          cellMap['${period.id}_$dayIdx'];
                      return _GridCell(
                        width: colWidth,
                        height: cellHeight,
                        cell: cell,
                        canEdit: false,
                        onTap: null,
                      );
                    }),
                  ],
                )),
          ],
        ),
      ),
    );
  }
}
