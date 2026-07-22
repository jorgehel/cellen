/// Platform-admin school configuration screen.
///
/// Lets platform admins fine-tune every feature flag and role availability
/// for a school, on top of the segment defaults.
///
/// Flow:
///   1. Load school → GET /platform/schools/{id}  (returns resolved_features)
///   2. User edits toggles → local state
///   3. Save → PATCH /platform/schools/{id} with {segment, features: {...overrides}}
///
/// Only values that differ from the current segment default are sent as
/// overrides. When the user explicitly sets a feature equal to its default,
/// the override key is cleared (set to null in the patch so the server
/// removes it), keeping the config clean.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/theme/app_theme.dart';

// ---------------------------------------------------------------------------
// Segment defaults (mirrors app/models/school.py — keep in sync)
// ---------------------------------------------------------------------------

const _segmentDefaults = <String, Map<String, bool>>{
  'preschool': {
    'checkin': true, 'caderneta': true, 'evaluations': true,
    'activities': true, 'timetable_k12': false, 'grades': false,
    'subjects': false, 'health': true, 'immunizations': true,
    'med_report': false, 'meal_orders': true, 'trip_auth': true,
    'pickup_auth': true, 'role_coordinator': true,
    'role_finance_officer': true, 'role_secretary': true,
    'role_nurse': true, 'role_student': false,
  },
  'primary': {
    'checkin': false, 'caderneta': false, 'evaluations': false,
    'activities': false, 'timetable_k12': true, 'grades': true,
    'subjects': true, 'health': true, 'immunizations': true,
    'med_report': true, 'meal_orders': true, 'trip_auth': true,
    'pickup_auth': true, 'role_coordinator': true,
    'role_finance_officer': true, 'role_secretary': true,
    'role_nurse': true, 'role_student': false,
  },
  'secondary': {
    'checkin': false, 'caderneta': false, 'evaluations': false,
    'activities': false, 'timetable_k12': true, 'grades': true,
    'subjects': true, 'health': true, 'immunizations': false,
    'med_report': true, 'meal_orders': false, 'trip_auth': false,
    'pickup_auth': false, 'role_coordinator': true,
    'role_finance_officer': true, 'role_secretary': true,
    'role_nurse': false, 'role_student': true,
  },
  'combined': {
    'checkin': false, 'caderneta': false, 'evaluations': false,
    'activities': false, 'timetable_k12': true, 'grades': true,
    'subjects': true, 'health': true, 'immunizations': true,
    'med_report': true, 'meal_orders': true, 'trip_auth': true,
    'pickup_auth': true, 'role_coordinator': true,
    'role_finance_officer': true, 'role_secretary': true,
    'role_nurse': true, 'role_student': true,
  },
  'full': {
    'checkin': true, 'caderneta': true, 'evaluations': true,
    'activities': true, 'timetable_k12': true, 'grades': true,
    'subjects': true, 'health': true, 'immunizations': true,
    'med_report': true, 'meal_orders': true, 'trip_auth': true,
    'pickup_auth': true, 'role_coordinator': true,
    'role_finance_officer': true, 'role_secretary': true,
    'role_nurse': true, 'role_student': true,
  },
};

// ---------------------------------------------------------------------------
// Feature catalogue (label, description, category, icon)
// ---------------------------------------------------------------------------

enum _Category { pedagogical, health, operational, roles }

class _FeatureDef {
  final String key;
  final String label;
  final String description;
  final _Category category;
  final IconData icon;
  const _FeatureDef(this.key, this.label, this.description, this.category, this.icon);
}

const _features = <_FeatureDef>[
  // ── Pedagógico ──────────────────────────────────────────────────────────
  _FeatureDef('checkin',      'Entradas / Saídas',      'Registo de entradas e saídas de alunos pelo encarregado',          _Category.pedagogical, Icons.login_outlined),
  _FeatureDef('caderneta',    'Caderneta Diária',        'Relatório diário preenchido pelo educador / professor',            _Category.pedagogical, Icons.menu_book_outlined),
  _FeatureDef('evaluations',  'Avaliações de Desenvolvimento', 'Fichas de avaliação por dimensões (Cognitivo, Motor, …)',   _Category.pedagogical, Icons.school_outlined),
  _FeatureDef('activities',   'Gestão de Actividades',   'Planificação de actividades e horário semanal por grupo',         _Category.pedagogical, Icons.sports_soccer_outlined),
  _FeatureDef('timetable_k12','Horário Lectivo (K-12)',  'Grade de horário: período × dia × disciplina × professor',        _Category.pedagogical, Icons.table_chart_outlined),
  _FeatureDef('grades',       'Notas e Avaliações',      'Lançamento de notas por disciplina e geração de boletins',        _Category.pedagogical, Icons.grade_outlined),
  _FeatureDef('subjects',     'Disciplinas',             'Cadastro de disciplinas e afectação por turma',                   _Category.pedagogical, Icons.book_outlined),
  // ── Saúde ───────────────────────────────────────────────────────────────
  _FeatureDef('health',       'Registos de Saúde',       'Ocorrências de saúde: febre, medicamentos, bem-estar',            _Category.health, Icons.health_and_safety_outlined),
  _FeatureDef('immunizations','Vacinação',                'Calendário vacinal e registos de imunização',                    _Category.health, Icons.vaccines_outlined),
  _FeatureDef('med_report',   'Relatório Médico',        'Relatório de saúde escolar e ficha médica do aluno',              _Category.health, Icons.assignment_outlined),
  // ── Operacional ─────────────────────────────────────────────────────────
  _FeatureDef('meal_orders',  'Gestão de Refeições',     'Encomenda de refeições e gestão de cantina',                     _Category.operational, Icons.restaurant_menu_outlined),
  _FeatureDef('trip_auth',    'Autorizações de Visita',  'Autorizações digitais para visitas de estudo',                   _Category.operational, Icons.directions_bus_outlined),
  _FeatureDef('pickup_auth',  'Autorizações de Levantamento', 'Controlo de quem pode levantar o aluno',                   _Category.operational, Icons.transfer_within_a_station_outlined),
  // ── Funções disponíveis ─────────────────────────────────────────────────
  _FeatureDef('role_coordinator',    'Coordenador Pedagógico', 'Acesso à gestão académica e relatórios pedagógicos',       _Category.roles, Icons.manage_accounts_outlined),
  _FeatureDef('role_finance_officer','Director Financeiro',    'Acesso completo ao módulo financeiro',                     _Category.roles, Icons.account_balance_outlined),
  _FeatureDef('role_secretary',      'Secretaria',             'Gestão de matrículas, comunicação e dados de alunos',      _Category.roles, Icons.badge_outlined),
  _FeatureDef('role_nurse',          'Enfermagem',             'Acesso ao módulo de saúde e registos médicos',             _Category.roles, Icons.medical_services_outlined),
  _FeatureDef('role_student',        'Portal do Aluno',        'Acesso self-service para alunos (boletim, documentos)',    _Category.roles, Icons.person_outlined),
];

const _categoryLabels = {
  _Category.pedagogical: 'Pedagógico',
  _Category.health:      'Saúde',
  _Category.operational: 'Operacional',
  _Category.roles:       'Funções Disponíveis',
};

const _categoryIcons = {
  _Category.pedagogical: Icons.menu_book_outlined,
  _Category.health:      Icons.health_and_safety_outlined,
  _Category.operational: Icons.settings_outlined,
  _Category.roles:       Icons.people_outline,
};

const _segments = [
  (value: 'preschool', label: 'Pré-Escolar',           icon: Icons.child_care_outlined,    color: Colors.pink),
  (value: 'primary',   label: 'Ensino Primário',        icon: Icons.menu_book_outlined,     color: Colors.blue),
  (value: 'secondary', label: 'Ensino Secundário',      icon: Icons.school_outlined,        color: Colors.indigo),
  (value: 'combined',  label: 'Primário + Secundário',  icon: Icons.account_balance_outlined, color: Colors.teal),
  (value: 'full',      label: 'Escola Completa',        icon: Icons.domain_outlined,        color: Colors.deepPurple),
];

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final _schoolDetailProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, String>(
  (ref, id) async {
    final data = await ref.read(apiClientProvider).get('/platform/schools/$id');
    return data as Map<String, dynamic>;
  },
);

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class SchoolConfigScreen extends ConsumerStatefulWidget {
  final String schoolId;
  final String schoolName;

  const SchoolConfigScreen({
    super.key,
    required this.schoolId,
    required this.schoolName,
  });

  @override
  ConsumerState<SchoolConfigScreen> createState() => _SchoolConfigScreenState();
}

class _SchoolConfigScreenState extends ConsumerState<SchoolConfigScreen> {
  String _segment = 'preschool';
  // Per-feature override: null = follow segment default, bool = explicit override
  final Map<String, bool?> _overrides = {};
  bool _saving = false;
  String? _error;
  bool _initialised = false;

  void _initFromSchool(Map<String, dynamic> school) {
    if (_initialised) return;
    _initialised = true;
    _segment = school['segment'] as String? ?? 'preschool';
    // The server returns `features` (only overrides) — not `resolved_features`
    // so we can see what's overridden vs what's default
    final raw = school['features'] as Map<String, dynamic>? ?? {};
    for (final key in raw.keys) {
      final v = raw[key];
      if (v is bool) _overrides[key] = v;
    }
  }

  bool _effective(String key) {
    if (_overrides.containsKey(key)) return _overrides[key]!;
    return (_segmentDefaults[_segment] ?? {})[key] ?? true;
  }

  bool _isOverridden(String key) {
    if (!_overrides.containsKey(key)) return false;
    final def = (_segmentDefaults[_segment] ?? {})[key] ?? true;
    return _overrides[key] != def;
  }

  void _toggle(String key, bool value) {
    setState(() {
      final def = (_segmentDefaults[_segment] ?? {})[key] ?? true;
      if (value == def) {
        _overrides.remove(key); // back to default → no override needed
      } else {
        _overrides[key] = value;
      }
    });
  }

  void _changeSegment(String seg) {
    setState(() {
      _segment = seg;
      // Clear overrides that are now equal to the new segment's default
      _overrides.removeWhere((k, v) {
        final def = (_segmentDefaults[seg] ?? {})[k] ?? true;
        return v == def;
      });
    });
  }

  Future<void> _save() async {
    setState(() { _saving = true; _error = null; });
    try {
      // Build features dict: only keys that differ from segment default
      final featureOverrides = <String, dynamic>{};
      for (final f in _features) {
        final def = (_segmentDefaults[_segment] ?? {})[f.key] ?? true;
        final eff = _effective(f.key);
        if (eff != def) {
          featureOverrides[f.key] = eff;
        } else {
          // Explicitly nullify to clear any previous override
          featureOverrides[f.key] = null;
        }
      }

      await ref.read(apiClientProvider).patch(
        '/platform/schools/${widget.schoolId}',
        data: {
          'segment': _segment,
          'features': featureOverrides,
        },
      );

      ref.invalidate(_schoolDetailProvider(widget.schoolId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Configuração guardada'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_schoolDetailProvider(widget.schoolId));

    return async.when(
      loading: () => Scaffold(
        appBar: AppBar(title: Text(widget.schoolName)),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: Text(widget.schoolName)),
        body: Center(child: Text('Erro: $e')),
      ),
      data: (school) {
        _initFromSchool(school);
        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.schoolName),
                const Text('Configuração da Escola',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w400)),
              ],
            ),
            actions: [
              if (_saving)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save_outlined, size: 18),
                  label: const Text('Guardar'),
                ),
              const SizedBox(width: 8),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 80),
            children: [
              if (_error != null) ...[
                _ErrorBanner(message: _error!),
                const SizedBox(height: 16),
              ],

              // ── Segment selector ──────────────────────────────────────
              _SectionHeader(
                icon: Icons.category_outlined,
                label: 'Tipo de Escola',
                subtitle: 'Define os valores predefinidos para todas as funcionalidades',
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _segments.map((seg) {
                  final sel = _segment == seg.value;
                  return GestureDetector(
                    onTap: () => _changeSegment(seg.value),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: sel ? seg.color.withOpacity(0.12) : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: sel ? seg.color : Colors.grey.shade300,
                          width: sel ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(seg.icon, size: 18,
                              color: sel ? seg.color : Colors.grey.shade600),
                          const SizedBox(width: 8),
                          Text(seg.label,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: sel ? FontWeight.w700 : FontWeight.normal,
                                color: sel ? seg.color : null,
                              )),
                          if (sel) ...[
                            const SizedBox(width: 6),
                            Icon(Icons.check_circle, size: 16, color: seg.color),
                          ],
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 28),
              const Divider(),
              const SizedBox(height: 8),

              // ── Feature sections ──────────────────────────────────────
              for (final cat in _Category.values) ...[
                const SizedBox(height: 16),
                _SectionHeader(
                  icon: _categoryIcons[cat]!,
                  label: _categoryLabels[cat]!,
                ),
                const SizedBox(height: 8),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: _features
                        .where((f) => f.category == cat)
                        .map((f) => _FeatureRow(
                              feature: f,
                              value: _effective(f.key),
                              isOverridden: _isOverridden(f.key),
                              segmentDefault: (_segmentDefaults[_segment] ?? {})[f.key] ?? true,
                              onChanged: (v) => _toggle(f.key, v),
                            ))
                        .toList(),
                  ),
                ),
              ],

              const SizedBox(height: 32),
              // ── Legend ───────────────────────────────────────────────
              Row(
                children: [
                  _LegendChip(color: Colors.blue, label: 'Predefinido pelo tipo de escola'),
                  const SizedBox(width: 12),
                  _LegendChip(color: Colors.orange, label: 'Valor personalizado'),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Sub-widgets
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  const _SectionHeader({required this.icon, required this.label, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppTheme.primary),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(
                fontWeight: FontWeight.w700, fontSize: 15)),
            if (subtitle != null)
              Text(subtitle!, style: TextStyle(
                  fontSize: 12, color: AppTheme.textSecondary)),
          ],
        ),
      ],
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final _FeatureDef feature;
  final bool value;
  final bool isOverridden;
  final bool segmentDefault;
  final ValueChanged<bool> onChanged;

  const _FeatureRow({
    required this.feature,
    required this.value,
    required this.isOverridden,
    required this.segmentDefault,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(feature.icon,
          color: value ? AppTheme.primary : Colors.grey.shade400, size: 22),
      title: Row(
        children: [
          Text(feature.label,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
          const SizedBox(width: 8),
          if (isOverridden)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.orange.withOpacity(0.4)),
              ),
              child: const Text('personalizado',
                  style: TextStyle(fontSize: 10, color: Colors.orange,
                      fontWeight: FontWeight.w600)),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                segmentDefault ? 'activo por defeito' : 'inactivo por defeito',
                style: TextStyle(fontSize: 10,
                    color: segmentDefault ? Colors.blue : Colors.grey.shade500,
                    fontWeight: FontWeight.w500),
              ),
            ),
        ],
      ),
      subtitle: Text(feature.description,
          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
      trailing: Switch(value: value, onChanged: onChanged),
      isThreeLine: false,
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.danger.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.danger.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: AppTheme.danger, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(message,
              style: TextStyle(color: AppTheme.danger, fontSize: 13))),
        ],
      ),
    );
  }
}

class _LegendChip extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendChip({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
      ],
    );
  }
}
