import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../school_settings_screen.dart';

// ---------------------------------------------------------------------------
// Data models
// ---------------------------------------------------------------------------

class _MedSummary {
  final int totalEnrolled;
  final int enrolledMale;
  final int enrolledFemale;
  final int totalTurmas;
  final int totalTeachingStaff;
  final int teachingStaffMale;
  final int teachingStaffFemale;
  final int totalNonTeachingStaff;

  const _MedSummary({
    required this.totalEnrolled,
    required this.enrolledMale,
    required this.enrolledFemale,
    required this.totalTurmas,
    required this.totalTeachingStaff,
    required this.teachingStaffMale,
    required this.teachingStaffFemale,
    required this.totalNonTeachingStaff,
  });

  factory _MedSummary.fromJson(Map<String, dynamic> j) => _MedSummary(
        totalEnrolled: j['total_enrolled'] as int? ?? 0,
        enrolledMale: j['enrolled_male'] as int? ?? 0,
        enrolledFemale: j['enrolled_female'] as int? ?? 0,
        totalTurmas: j['total_turmas'] as int? ?? 0,
        totalTeachingStaff: j['total_teaching_staff'] as int? ?? 0,
        teachingStaffMale: j['teaching_staff_male'] as int? ?? 0,
        teachingStaffFemale: j['teaching_staff_female'] as int? ?? 0,
        totalNonTeachingStaff: j['total_non_teaching_staff'] as int? ?? 0,
      );
}

class _TurmaRow {
  final String turmaName;
  final String? level;
  final int total;
  final int male;
  final int female;
  final int unknown;

  const _TurmaRow({
    required this.turmaName,
    this.level,
    required this.total,
    required this.male,
    required this.female,
    required this.unknown,
  });

  factory _TurmaRow.fromJson(Map<String, dynamic> j) => _TurmaRow(
        turmaName: j['turma_name'] as String? ?? '',
        level: j['level'] as String?,
        total: j['total'] as int? ?? 0,
        male: j['male'] as int? ?? 0,
        female: j['female'] as int? ?? 0,
        unknown: j['unknown'] as int? ?? 0,
      );
}

class _AgeGroupRow {
  final String group;
  final int total;
  final int male;
  final int female;

  const _AgeGroupRow({required this.group, required this.total, required this.male, required this.female});

  factory _AgeGroupRow.fromJson(Map<String, dynamic> j) => _AgeGroupRow(
        group: j['group'] as String? ?? '',
        total: j['total'] as int? ?? 0,
        male: j['male'] as int? ?? 0,
        female: j['female'] as int? ?? 0,
      );
}

class _StaffRow {
  final String category;
  final int total;
  final int male;
  final int female;

  const _StaffRow({required this.category, required this.total, required this.male, required this.female});

  factory _StaffRow.fromJson(Map<String, dynamic> j) => _StaffRow(
        category: j['category'] as String? ?? '',
        total: j['total'] as int? ?? 0,
        male: j['male'] as int? ?? 0,
        female: j['female'] as int? ?? 0,
      );
}

class _MedReport {
  final String schoolName;
  final String? schoolNif;
  final String? schoolAddress;
  final String? schoolYear;
  final String generatedAt;
  final _MedSummary summary;
  final List<_TurmaRow> byTurma;
  final List<_AgeGroupRow> byAgeGroup;
  final List<_StaffRow> byStaff;

  const _MedReport({
    required this.schoolName,
    this.schoolNif,
    this.schoolAddress,
    this.schoolYear,
    required this.generatedAt,
    required this.summary,
    required this.byTurma,
    required this.byAgeGroup,
    required this.byStaff,
  });

  factory _MedReport.fromJson(Map<String, dynamic> j) => _MedReport(
        schoolName: j['school_name'] as String? ?? '',
        schoolNif: j['school_nif'] as String?,
        schoolAddress: j['school_address'] as String?,
        schoolYear: j['school_year'] as String?,
        generatedAt: j['generated_at'] as String? ?? '',
        summary: _MedSummary.fromJson(j['summary'] as Map<String, dynamic>),
        byTurma: (j['by_turma'] as List? ?? [])
            .map((e) => _TurmaRow.fromJson(e as Map<String, dynamic>))
            .toList(),
        byAgeGroup: (j['by_age_group'] as List? ?? [])
            .map((e) => _AgeGroupRow.fromJson(e as Map<String, dynamic>))
            .toList(),
        byStaff: (j['by_staff_category'] as List? ?? [])
            .map((e) => _StaffRow.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final _medReportProvider =
    FutureProvider.autoDispose.family<_MedReport, String?>((ref, yearId) async {
  final api = ref.read(apiClientProvider);
  final path = yearId != null && yearId.isNotEmpty
      ? '/reports/med?school_year_id=$yearId'
      : '/reports/med';
  final data = await api.get(path);
  return _MedReport.fromJson(data as Map<String, dynamic>);
});

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class MedReportScreen extends ConsumerStatefulWidget {
  const MedReportScreen({super.key});

  @override
  ConsumerState<MedReportScreen> createState() => _MedReportScreenState();
}

class _MedReportScreenState extends ConsumerState<MedReportScreen> {
  SchoolYear? _selectedYear;
  bool _yearLoaded = false;

  @override
  Widget build(BuildContext context) {
    final yearsAsync = ref.watch(schoolYearsProvider);
    final reportKey = _selectedYear?.id ?? '';
    final reportAsync = ref.watch(_medReportProvider(reportKey));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Relatório MED — Levantamento Escolar'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(schoolYearsProvider);
              ref.invalidate(_medReportProvider(reportKey));
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Year selector
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: yearsAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Erro: $e', style: const TextStyle(color: AppTheme.danger)),
              data: (years) {
                if (!_yearLoaded && years.isNotEmpty) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      setState(() {
                        _selectedYear = years.firstWhere(
                          (y) => y.isActive,
                          orElse: () => years.first,
                        );
                        _yearLoaded = true;
                      });
                    }
                  });
                }
                return DropdownButtonFormField<String>(
                  value: _selectedYear?.id,
                  decoration: const InputDecoration(
                    labelText: 'Ano Lectivo',
                    prefixIcon: Icon(Icons.calendar_today_outlined),
                    isDense: true,
                  ),
                  items: years
                      .map((y) => DropdownMenuItem(
                            value: y.id,
                            child: Text(y.yearLabel + (y.isActive ? ' (activo)' : '')),
                          ))
                      .toList(),
                  onChanged: (id) {
                    setState(() {
                      _selectedYear = years.firstWhere((y) => y.id == id);
                    });
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: reportAsync.when(
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
                      onPressed: () => ref.invalidate(_medReportProvider(reportKey)),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Tentar novamente'),
                    ),
                  ],
                ),
              ),
              data: (report) => _ReportBody(report: report),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Report body
// ---------------------------------------------------------------------------

class _ReportBody extends StatelessWidget {
  final _MedReport report;
  const _ReportBody({required this.report});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // School header
          _SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  report.schoolName,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                if (report.schoolNif != null) ...[
                  const SizedBox(height: 2),
                  Text('NIF: ${report.schoolNif}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                ],
                if (report.schoolAddress != null) ...[
                  const SizedBox(height: 2),
                  Text(report.schoolAddress!, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                ],
                if (report.schoolYear != null) ...[
                  const SizedBox(height: 4),
                  Chip(
                    label: Text('Ano Lectivo: ${report.schoolYear!}'),
                    visualDensity: VisualDensity.compact,
                    backgroundColor: AppTheme.primary.withOpacity(0.1),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  'Gerado em: ${report.generatedAt}',
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Summary cards
          _SectionTitle('Resumo Geral'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StatCard(label: 'Total Alunos', value: '${report.summary.totalEnrolled}', icon: Icons.people, color: AppTheme.primary),
              _StatCard(label: 'Rapazes', value: '${report.summary.enrolledMale}', icon: Icons.male, color: Colors.blue),
              _StatCard(label: 'Raparigas', value: '${report.summary.enrolledFemale}', icon: Icons.female, color: Colors.pink),
              _StatCard(label: 'Turmas', value: '${report.summary.totalTurmas}', icon: Icons.class_outlined, color: Colors.orange),
              _StatCard(label: 'Docentes', value: '${report.summary.totalTeachingStaff}', icon: Icons.school_outlined, color: Colors.teal),
              _StatCard(label: 'Não-docentes', value: '${report.summary.totalNonTeachingStaff}', icon: Icons.badge_outlined, color: Colors.purple),
            ],
          ),

          const SizedBox(height: 24),

          // Quadro I — By Turma
          _SectionTitle('Quadro I — Alunos Matriculados por Turma e Sexo'),
          const SizedBox(height: 8),
          _SectionCard(
            child: report.byTurma.isEmpty
                ? const _EmptyRow()
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columnSpacing: 20,
                      headingRowHeight: 36,
                      dataRowMinHeight: 36,
                      dataRowMaxHeight: 36,
                      columns: const [
                        DataColumn(label: Text('Turma', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Nível', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Total', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                        DataColumn(label: Text('M', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)), numeric: true),
                        DataColumn(label: Text('F', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.pink)), numeric: true),
                        DataColumn(label: Text('?', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                      ],
                      rows: [
                        ...report.byTurma.map((r) => DataRow(cells: [
                              DataCell(Text(r.turmaName, style: const TextStyle(fontWeight: FontWeight.w500))),
                              DataCell(Text(r.level ?? '—', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary))),
                              DataCell(Text('${r.total}', style: const TextStyle(fontWeight: FontWeight.bold))),
                              DataCell(Text('${r.male}', style: const TextStyle(color: Colors.blue))),
                              DataCell(Text('${r.female}', style: const TextStyle(color: Colors.pink))),
                              DataCell(Text('${r.unknown}')),
                            ])),
                        // Totals row
                        DataRow(
                          color: WidgetStateProperty.all(AppTheme.primary.withOpacity(0.06)),
                          cells: [
                            const DataCell(Text('TOTAL', style: TextStyle(fontWeight: FontWeight.bold))),
                            const DataCell(Text('')),
                            DataCell(Text(
                              '${report.byTurma.fold(0, (s, r) => s + r.total)}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            )),
                            DataCell(Text(
                              '${report.byTurma.fold(0, (s, r) => s + r.male)}',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                            )),
                            DataCell(Text(
                              '${report.byTurma.fold(0, (s, r) => s + r.female)}',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.pink),
                            )),
                            DataCell(Text('${report.byTurma.fold(0, (s, r) => s + r.unknown)}')),
                          ],
                        ),
                      ],
                    ),
                  ),
          ),

          const SizedBox(height: 24),

          // Quadro II — By Age Group
          _SectionTitle('Quadro II — Alunos por Faixa Etária e Sexo'),
          const SizedBox(height: 8),
          _SectionCard(
            child: report.byAgeGroup.isEmpty
                ? const _EmptyRow()
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columnSpacing: 24,
                      headingRowHeight: 36,
                      dataRowMinHeight: 36,
                      dataRowMaxHeight: 36,
                      columns: const [
                        DataColumn(label: Text('Faixa Etária', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Total', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                        DataColumn(label: Text('M', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)), numeric: true),
                        DataColumn(label: Text('F', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.pink)), numeric: true),
                      ],
                      rows: [
                        ...report.byAgeGroup.map((r) => DataRow(cells: [
                              DataCell(Text(r.group)),
                              DataCell(Text('${r.total}', style: const TextStyle(fontWeight: FontWeight.bold))),
                              DataCell(Text('${r.male}', style: const TextStyle(color: Colors.blue))),
                              DataCell(Text('${r.female}', style: const TextStyle(color: Colors.pink))),
                            ])),
                        DataRow(
                          color: WidgetStateProperty.all(AppTheme.primary.withOpacity(0.06)),
                          cells: [
                            const DataCell(Text('TOTAL', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataCell(Text(
                              '${report.byAgeGroup.fold(0, (s, r) => s + r.total)}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            )),
                            DataCell(Text(
                              '${report.byAgeGroup.fold(0, (s, r) => s + r.male)}',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                            )),
                            DataCell(Text(
                              '${report.byAgeGroup.fold(0, (s, r) => s + r.female)}',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.pink),
                            )),
                          ],
                        ),
                      ],
                    ),
                  ),
          ),

          const SizedBox(height: 24),

          // Quadro III & IV — Staff
          _SectionTitle('Quadro III/IV — Pessoal por Categoria e Sexo'),
          const SizedBox(height: 8),
          _SectionCard(
            child: report.byStaff.isEmpty
                ? const _EmptyRow()
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columnSpacing: 24,
                      headingRowHeight: 36,
                      dataRowMinHeight: 36,
                      dataRowMaxHeight: 36,
                      columns: const [
                        DataColumn(label: Text('Categoria', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Total', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                        DataColumn(label: Text('M', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)), numeric: true),
                        DataColumn(label: Text('F', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.pink)), numeric: true),
                      ],
                      rows: [
                        ...report.byStaff.map((r) => DataRow(cells: [
                              DataCell(Text(r.category, style: const TextStyle(fontWeight: FontWeight.w500))),
                              DataCell(Text('${r.total}', style: const TextStyle(fontWeight: FontWeight.bold))),
                              DataCell(Text('${r.male}', style: const TextStyle(color: Colors.blue))),
                              DataCell(Text('${r.female}', style: const TextStyle(color: Colors.pink))),
                            ])),
                        DataRow(
                          color: WidgetStateProperty.all(AppTheme.primary.withOpacity(0.06)),
                          cells: [
                            const DataCell(Text('TOTAL', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataCell(Text(
                              '${report.byStaff.fold(0, (s, r) => s + r.total)}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            )),
                            DataCell(Text(
                              '${report.byStaff.fold(0, (s, r) => s + r.male)}',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                            )),
                            DataCell(Text(
                              '${report.byStaff.fold(0, (s, r) => s + r.female)}',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.pink),
                            )),
                          ],
                        ),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helper widgets
// ---------------------------------------------------------------------------

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppTheme.primary,
          ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final Widget child;
  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: child,
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}

class _EmptyRow extends StatelessWidget {
  const _EmptyRow();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Text('Sem dados para este período', style: TextStyle(color: AppTheme.textSecondary)),
      ),
    );
  }
}
