/// Platform-admin school configuration screen — full feature + role control.
///
/// What's configurable:
///   1. School segment (drives all defaults)
///   2. Every feature flag (all school-level capabilities)
///   3. Per-role feature permissions (which role can access which feature)
///
/// Persistence: PATCH /platform/schools/{id}
///   {segment, features: {key: bool|null, role_permissions: {role: {feature: bool}}}}
///
/// Design principle: defaults are defined by segment. Any explicit override is
/// stored in school.features. resolved_features = merge(defaults, overrides).
/// Resetting a toggle to its segment default removes the override (sends null).
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
    'checkin': true, 'caderneta': true, 'evaluations': true, 'activities': true,
    'timetable_k12': false, 'lesson_attendance': false, 'grades': false, 'subjects': false,
    'report_cards': false, 'appointments': true,
    'health': true, 'immunizations': true, 'med_report': false, 'incidents': true,
    'meal_orders': true, 'trip_auth': true, 'pickup_auth': true,
    'photos': true, 'events': true, 'documents': true,
    'announcements': true, 'messages': true, 'finance': true,
    'role_coordinator': true, 'role_finance_officer': true,
    'role_secretary': true, 'role_nurse': true, 'role_student': false,
  },
  'primary': {
    'checkin': false, 'caderneta': false, 'evaluations': false, 'activities': false,
    'timetable_k12': true, 'lesson_attendance': true, 'grades': true, 'subjects': true,
    'report_cards': true, 'appointments': true,
    'health': true, 'immunizations': true, 'med_report': true, 'incidents': true,
    'meal_orders': true, 'trip_auth': true, 'pickup_auth': true,
    'photos': true, 'events': true, 'documents': true,
    'announcements': true, 'messages': true, 'finance': true,
    'role_coordinator': true, 'role_finance_officer': true,
    'role_secretary': true, 'role_nurse': true, 'role_student': false,
  },
  'secondary': {
    'checkin': false, 'caderneta': false, 'evaluations': false, 'activities': false,
    'timetable_k12': true, 'lesson_attendance': true, 'grades': true, 'subjects': true,
    'report_cards': true, 'appointments': false,
    'health': true, 'immunizations': false, 'med_report': true, 'incidents': true,
    'meal_orders': false, 'trip_auth': false, 'pickup_auth': false,
    'photos': false, 'events': true, 'documents': true,
    'announcements': true, 'messages': true, 'finance': true,
    'role_coordinator': true, 'role_finance_officer': true,
    'role_secretary': true, 'role_nurse': false, 'role_student': true,
  },
  'combined': {
    'checkin': false, 'caderneta': false, 'evaluations': false, 'activities': false,
    'timetable_k12': true, 'lesson_attendance': true, 'grades': true, 'subjects': true,
    'report_cards': true, 'appointments': true,
    'health': true, 'immunizations': true, 'med_report': true, 'incidents': true,
    'meal_orders': true, 'trip_auth': true, 'pickup_auth': true,
    'photos': true, 'events': true, 'documents': true,
    'announcements': true, 'messages': true, 'finance': true,
    'role_coordinator': true, 'role_finance_officer': true,
    'role_secretary': true, 'role_nurse': true, 'role_student': true,
  },
  'full': {
    'checkin': true, 'caderneta': true, 'evaluations': true, 'activities': true,
    'timetable_k12': true, 'lesson_attendance': true, 'grades': true, 'subjects': true,
    'report_cards': true, 'appointments': true,
    'health': true, 'immunizations': true, 'med_report': true, 'incidents': true,
    'meal_orders': true, 'trip_auth': true, 'pickup_auth': true,
    'photos': true, 'events': true, 'documents': true,
    'announcements': true, 'messages': true, 'finance': true,
    'role_coordinator': true, 'role_finance_officer': true,
    'role_secretary': true, 'role_nurse': true, 'role_student': true,
  },
};

// ---------------------------------------------------------------------------
// Feature catalogue
// ---------------------------------------------------------------------------

enum _Cat { pedagogical, health, operational, comms, finance, roles }

class _Feat {
  final String key;
  final String label;
  final String description;
  final _Cat cat;
  final IconData icon;
  const _Feat(this.key, this.label, this.description, this.cat, this.icon);
}

const _allFeatures = <_Feat>[
  // Pedagógico
  _Feat('checkin',      'Entradas / Saídas',           'Registo de entradas e saídas pelo encarregado',                  _Cat.pedagogical, Icons.login_outlined),
  _Feat('caderneta',    'Caderneta Diária',             'Relatório diário do educador / professor',                        _Cat.pedagogical, Icons.menu_book_outlined),
  _Feat('evaluations',  'Avaliações de Desenvolvimento','Fichas de avaliação por dimensões (Cognitivo, Motor…)',           _Cat.pedagogical, Icons.school_outlined),
  _Feat('activities',   'Actividades',                  'Planificação de actividades e horário semanal por grupo',         _Cat.pedagogical, Icons.sports_soccer_outlined),
  _Feat('timetable_k12',     'Horário Lectivo',          'Grade de horário: período × dia × disciplina × professor',        _Cat.pedagogical, Icons.table_chart_outlined),
  _Feat('lesson_attendance', 'Presenças / Faltas',      'Livro de ponto: registo de presenças e faltas por aula',          _Cat.pedagogical, Icons.how_to_reg_outlined),
  _Feat('grades',            'Notas',                   'Lançamento de notas por disciplina',                              _Cat.pedagogical, Icons.grade_outlined),
  _Feat('subjects',     'Disciplinas',                  'Cadastro de disciplinas e afectação por turma',                   _Cat.pedagogical, Icons.book_outlined),
  _Feat('report_cards', 'Boletins',                     'Geração e exportação de boletins escolares',                      _Cat.pedagogical, Icons.assignment_outlined),
  _Feat('appointments', 'Marcações',                    'Marcações e consultas com professores / coordenação',             _Cat.pedagogical, Icons.event_available_outlined),
  // Saúde
  _Feat('health',       'Saúde',                        'Registos de saúde, febre, medicamentos e bem-estar',              _Cat.health, Icons.health_and_safety_outlined),
  _Feat('immunizations','Vacinação',                    'Calendário vacinal e registos de imunização',                     _Cat.health, Icons.vaccines_outlined),
  _Feat('med_report',   'Relatório Médico',             'Relatório de saúde escolar e ficha médica',                       _Cat.health, Icons.medical_information_outlined),
  _Feat('incidents',    'Ocorrências',                  'Incidentes, acidentes e comportamentos notáveis',                 _Cat.health, Icons.report_outlined),
  // Operacional
  _Feat('meal_orders',  'Refeições',                    'Gestão de cantina e encomenda de refeições',                      _Cat.operational, Icons.restaurant_menu_outlined),
  _Feat('trip_auth',    'Autorizações de Visita',       'Autorizações digitais para visitas de estudo',                    _Cat.operational, Icons.directions_bus_outlined),
  _Feat('pickup_auth',  'Autorizações de Levantamento', 'Controlo de quem pode levantar o aluno',                         _Cat.operational, Icons.transfer_within_a_station_outlined),
  _Feat('photos',       'Galeria de Fotos',             'Galeria partilhada de fotos da escola',                           _Cat.operational, Icons.photo_library_outlined),
  _Feat('events',       'Calendário',                   'Eventos escolares e calendário partilhado',                       _Cat.operational, Icons.calendar_month_outlined),
  _Feat('documents',    'Documentos',                   'Repositório de documentos e circulares',                          _Cat.operational, Icons.folder_outlined),
  // Comunicação
  _Feat('announcements','Comunicados',                  'Anúncios e comunicados enviados a toda a comunidade',             _Cat.comms, Icons.campaign_outlined),
  _Feat('messages',     'Mensagens',                    'Mensagens privadas entre utilizadores',                           _Cat.comms, Icons.chat_bubble_outline),
  // Financeiro
  _Feat('finance',      'Módulo Financeiro',            'Facturas, contratos, despesas, caixa e exportação SAF-T',        _Cat.finance, Icons.account_balance_wallet_outlined),
  // Funções disponíveis
  _Feat('role_coordinator',    'Coordenador Pedagógico','Acesso à gestão académica e relatórios pedagógicos',             _Cat.roles, Icons.manage_accounts_outlined),
  _Feat('role_finance_officer','Director Financeiro',   'Acesso completo ao módulo financeiro',                            _Cat.roles, Icons.account_balance_outlined),
  _Feat('role_secretary',      'Secretaria',            'Matrículas, comunicação e dados de alunos',                      _Cat.roles, Icons.badge_outlined),
  _Feat('role_nurse',          'Enfermagem',            'Módulo de saúde, ocorrências e registos médicos',                 _Cat.roles, Icons.medical_services_outlined),
  _Feat('role_student',        'Portal do Aluno',       'Acesso self-service: boletim, documentos, calendário',           _Cat.roles, Icons.person_outlined),
];

const _catLabels = {
  _Cat.pedagogical: 'Pedagógico',
  _Cat.health:      'Saúde & Incidentes',
  _Cat.operational: 'Operacional',
  _Cat.comms:       'Comunicação',
  _Cat.finance:     'Financeiro',
  _Cat.roles:       'Funções Disponíveis',
};

const _catIcons = {
  _Cat.pedagogical: Icons.menu_book_outlined,
  _Cat.health:      Icons.health_and_safety_outlined,
  _Cat.operational: Icons.settings_outlined,
  _Cat.comms:       Icons.forum_outlined,
  _Cat.finance:     Icons.account_balance_wallet_outlined,
  _Cat.roles:       Icons.people_outline,
};

// ---------------------------------------------------------------------------
// Role × feature permission definitions
// Defines which features each role can potentially access (in their sidebar).
// Platform admin can restrict any of these per-school.
// ---------------------------------------------------------------------------

class _RoleDef {
  final String key;
  final String label;
  final IconData icon;
  final Color color;
  final List<String> features; // feature keys this role can access
  const _RoleDef(this.key, this.label, this.icon, this.color, this.features);
}

const _rolePermDefs = <_RoleDef>[
  _RoleDef('teacher', 'Professor / Educador', Icons.school_outlined, Colors.blue, [
    'checkin', 'lesson_attendance', 'caderneta', 'grades', 'evaluations', 'timetable_k12',
    'health', 'immunizations', 'incidents', 'announcements', 'messages',
    'photos', 'events', 'trip_auth', 'pickup_auth', 'meal_orders', 'appointments', 'documents',
  ]),
  _RoleDef('coordinator', 'Coordenador Pedagógico', Icons.manage_accounts_outlined, Colors.teal, [
    'timetable_k12', 'grades', 'subjects', 'report_cards', 'evaluations',
    'health', 'incidents', 'announcements', 'messages', 'documents', 'events', 'appointments',
  ]),
  _RoleDef('finance_officer', 'Director Financeiro', Icons.account_balance_outlined, Colors.green, [
    'finance', 'announcements', 'messages', 'documents',
  ]),
  _RoleDef('secretary', 'Secretaria', Icons.badge_outlined, Colors.orange, [
    'announcements', 'messages', 'documents', 'events', 'appointments',
  ]),
  _RoleDef('nurse', 'Enfermagem', Icons.medical_services_outlined, Colors.red, [
    'health', 'immunizations', 'med_report', 'incidents', 'messages',
  ]),
  _RoleDef('parent', 'Encarregado de Educação', Icons.family_restroom_outlined, Colors.purple, [
    'caderneta', 'grades', 'report_cards', 'health', 'incidents',
    'meal_orders', 'appointments', 'trip_auth', 'pickup_auth',
    'photos', 'events', 'announcements', 'messages', 'documents', 'finance',
  ]),
  _RoleDef('student', 'Aluno', Icons.person_outlined, Colors.indigo, [
    'grades', 'report_cards', 'documents', 'events', 'announcements',
  ]),
];

// Feature labels for the role permission matrix (shorter, for chips/cells)
const _featLabel = <String, String>{
  'checkin': 'Entradas/Saídas', 'caderneta': 'Caderneta',
  'evaluations': 'Avaliações Dev.', 'activities': 'Actividades',
  'timetable_k12': 'Horário', 'grades': 'Notas',
  'subjects': 'Disciplinas', 'report_cards': 'Boletins',
  'appointments': 'Marcações', 'health': 'Saúde',
  'immunizations': 'Vacinas', 'med_report': 'Rel. Médico',
  'incidents': 'Ocorrências', 'meal_orders': 'Refeições',
  'trip_auth': 'Visit. Estudo', 'pickup_auth': 'Levantamento',
  'photos': 'Galeria', 'events': 'Calendário',
  'documents': 'Documentos', 'announcements': 'Comunicados',
  'messages': 'Mensagens', 'finance': 'Financeiro',
  'lesson_attendance': 'Livro de Ponto',
};

const _segments = [
  (value: 'preschool', label: 'Pré-Escolar',          icon: Icons.child_care_outlined,    color: Colors.pink),
  (value: 'primary',   label: 'Ensino Primário',       icon: Icons.menu_book_outlined,     color: Colors.blue),
  (value: 'secondary', label: 'Ensino Secundário',     icon: Icons.school_outlined,        color: Colors.indigo),
  (value: 'combined',  label: 'Primário + Secundário', icon: Icons.account_balance_outlined, color: Colors.teal),
  (value: 'full',      label: 'Escola Completa',       icon: Icons.domain_outlined,        color: Colors.deepPurple),
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

class _SchoolConfigScreenState extends ConsumerState<SchoolConfigScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  String _segment = 'preschool';
  // Feature overrides: null = follow segment default, bool = explicit value
  final Map<String, bool?> _featureOverrides = {};
  // Role permission overrides: role → feature → bool (false = denied)
  final Map<String, Map<String, bool>> _rolePerms = {};
  bool _saving = false;
  String? _error;
  bool _initialised = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _initFromSchool(Map<String, dynamic> school) {
    if (_initialised) return;
    _initialised = true;
    _segment = school['segment'] as String? ?? 'preschool';
    final raw = school['features'] as Map<String, dynamic>? ?? {};
    for (final entry in raw.entries) {
      if (entry.key == 'role_permissions') {
        final rp = entry.value;
        if (rp is Map) {
          for (final roleEntry in rp.entries) {
            final roleMap = roleEntry.value;
            if (roleMap is Map) {
              _rolePerms[roleEntry.key.toString()] = {
                for (final e in roleMap.entries)
                  if (e.value is bool) e.key.toString(): e.value as bool,
              };
            }
          }
        }
      } else if (entry.value is bool) {
        _featureOverrides[entry.key] = entry.value as bool;
      }
    }
  }

  bool _effectiveFeat(String key) {
    if (_featureOverrides.containsKey(key)) return _featureOverrides[key]!;
    return (_segmentDefaults[_segment] ?? {})[key] ?? true;
  }

  bool _isOverridden(String key) {
    if (!_featureOverrides.containsKey(key)) return false;
    final def = (_segmentDefaults[_segment] ?? {})[key] ?? true;
    return _featureOverrides[key] != def;
  }

  void _toggleFeat(String key, bool value) {
    setState(() {
      final def = (_segmentDefaults[_segment] ?? {})[key] ?? true;
      if (value == def) {
        _featureOverrides.remove(key);
      } else {
        _featureOverrides[key] = value;
      }
    });
  }

  void _changeSegment(String seg) {
    setState(() {
      _segment = seg;
      _featureOverrides.removeWhere((k, v) {
        final def = (_segmentDefaults[seg] ?? {})[k] ?? true;
        return v == def;
      });
    });
  }

  // Role permissions
  bool _roleCanAccess(String roleKey, String featureKey) =>
      _rolePerms[roleKey]?[featureKey] ?? true;

  bool _isRolePermOverridden(String roleKey, String featureKey) =>
      _rolePerms[roleKey]?.containsKey(featureKey) ?? false;

  void _toggleRolePerm(String roleKey, String featureKey, bool value) {
    setState(() {
      if (value) {
        // Granting access = remove override (default is true)
        _rolePerms[roleKey]?.remove(featureKey);
        if (_rolePerms[roleKey]?.isEmpty ?? false) _rolePerms.remove(roleKey);
      } else {
        _rolePerms.putIfAbsent(roleKey, () => {})[featureKey] = false;
      }
    });
  }

  Future<void> _save() async {
    setState(() { _saving = true; _error = null; });
    try {
      // Build feature overrides dict
      final featOverrides = <String, dynamic>{};
      for (final f in _allFeatures) {
        final def = (_segmentDefaults[_segment] ?? {})[f.key] ?? true;
        final eff = _effectiveFeat(f.key);
        featOverrides[f.key] = (eff != def) ? eff : null; // null clears override
      }
      // Add role_permissions
      if (_rolePerms.isNotEmpty) {
        featOverrides['role_permissions'] = {
          for (final e in _rolePerms.entries)
            if (e.value.isNotEmpty) e.key: e.value,
        };
      } else {
        featOverrides['role_permissions'] = null; // clear
      }

      await ref.read(apiClientProvider).patch(
        '/platform/schools/${widget.schoolId}',
        data: {'segment': _segment, 'features': featOverrides},
      );

      ref.invalidate(_schoolDetailProvider(widget.schoolId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Configuração guardada'),
          backgroundColor: Colors.green,
        ));
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
      loading: () => Scaffold(appBar: AppBar(title: Text(widget.schoolName)),
          body: const Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(appBar: AppBar(title: Text(widget.schoolName)),
          body: Center(child: Text('Erro: $e'))),
      data: (school) {
        _initFromSchool(school);
        return Scaffold(
          appBar: AppBar(
            title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.schoolName),
              const Text('Configuração da Escola',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w400)),
            ]),
            bottom: TabBar(
              controller: _tabs,
              tabs: const [
                Tab(icon: Icon(Icons.tune, size: 18), text: 'Funcionalidades'),
                Tab(icon: Icon(Icons.people_outline, size: 18), text: 'Permissões por Função'),
              ],
            ),
            actions: [
              if (_saving)
                const Padding(padding: EdgeInsets.all(16),
                    child: SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2)))
              else
                FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save_outlined, size: 18),
                  label: const Text('Guardar'),
                ),
              const SizedBox(width: 8),
            ],
          ),
          body: TabBarView(
            controller: _tabs,
            children: [
              _FeaturesTab(
                segment: _segment,
                onSegmentChange: _changeSegment,
                error: _error,
                effectiveFeat: _effectiveFeat,
                isOverridden: _isOverridden,
                toggleFeat: _toggleFeat,
              ),
              _RolePermsTab(
                enabledFeatures: {
                  for (final f in _allFeatures)
                    if (_effectiveFeat(f.key)) f.key,
                },
                roleCanAccess: _roleCanAccess,
                isRolePermOverridden: _isRolePermOverridden,
                toggleRolePerm: _toggleRolePerm,
              ),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Tab 1: Features
// ---------------------------------------------------------------------------

class _FeaturesTab extends StatelessWidget {
  final String segment;
  final ValueChanged<String> onSegmentChange;
  final String? error;
  final bool Function(String) effectiveFeat;
  final bool Function(String) isOverridden;
  final void Function(String, bool) toggleFeat;

  const _FeaturesTab({
    required this.segment,
    required this.onSegmentChange,
    required this.error,
    required this.effectiveFeat,
    required this.isOverridden,
    required this.toggleFeat,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 80),
      children: [
        if (error != null) ...[
          _ErrorBanner(message: error!),
          const SizedBox(height: 16),
        ],

        // Segment selector
        _SectionHeader(icon: Icons.category_outlined, label: 'Tipo de Escola',
            subtitle: 'Define os valores predefinidos para todas as funcionalidades'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: _segments.map((seg) {
            final sel = segment == seg.value;
            return GestureDetector(
              onTap: () => onSegmentChange(seg.value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: sel ? seg.color.withOpacity(0.12) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: sel ? seg.color : Colors.grey.shade300, width: sel ? 2 : 1),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(seg.icon, size: 18, color: sel ? seg.color : Colors.grey.shade600),
                  const SizedBox(width: 8),
                  Text(seg.label, style: TextStyle(fontSize: 13,
                      fontWeight: sel ? FontWeight.w700 : FontWeight.normal,
                      color: sel ? seg.color : null)),
                  if (sel) ...[const SizedBox(width: 6),
                    Icon(Icons.check_circle, size: 16, color: seg.color)],
                ]),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 24),
        const Divider(),

        // Feature categories
        for (final cat in _Cat.values) ...[
          const SizedBox(height: 20),
          _SectionHeader(icon: _catIcons[cat]!, label: _catLabels[cat]!),
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Column(
              children: _allFeatures.where((f) => f.cat == cat).map((f) {
                final val = effectiveFeat(f.key);
                final overridden = isOverridden(f.key);
                final def = (_segmentDefaults[segment] ?? {})[f.key] ?? true;
                return ListTile(
                  leading: Icon(f.icon, color: val ? AppTheme.primary : Colors.grey.shade400, size: 22),
                  title: Row(children: [
                    Expanded(child: Text(f.label, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14))),
                    const SizedBox(width: 8),
                    _StatusChip(overridden: overridden, defaultValue: def),
                  ]),
                  subtitle: Text(f.description, style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  trailing: Switch(value: val, onChanged: (v) => toggleFeat(f.key, v)),
                );
              }).toList(),
            ),
          ),
        ],

        const SizedBox(height: 24),
        Row(children: [
          _LegendChip(color: Colors.blue, label: 'Valor predefinido pelo tipo de escola'),
          const SizedBox(width: 16),
          _LegendChip(color: Colors.orange, label: 'Valor personalizado'),
        ]),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Tab 2: Role Permissions
// ---------------------------------------------------------------------------

class _RolePermsTab extends StatelessWidget {
  final Set<String> enabledFeatures;
  final bool Function(String role, String feat) roleCanAccess;
  final bool Function(String role, String feat) isRolePermOverridden;
  final void Function(String role, String feat, bool val) toggleRolePerm;

  const _RolePermsTab({
    required this.enabledFeatures,
    required this.roleCanAccess,
    required this.isRolePermOverridden,
    required this.toggleRolePerm,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 80),
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.blue.withOpacity(0.2)),
          ),
          child: const Row(children: [
            Icon(Icons.info_outline, size: 18, color: Colors.blue),
            SizedBox(width: 8),
            Expanded(child: Text(
              'Por defeito, cada função acede a todas as funcionalidades activas que tem no seu menu. '
              'Use os controlos abaixo para restringir o acesso de funções específicas a determinadas funcionalidades nesta escola.',
              style: TextStyle(fontSize: 12, color: Colors.blue),
            )),
          ]),
        ),
        const SizedBox(height: 16),

        for (final role in _rolePermDefs) ...[
          const SizedBox(height: 8),
          _RolePermCard(
            role: role,
            enabledFeatures: enabledFeatures,
            roleCanAccess: roleCanAccess,
            isOverridden: isRolePermOverridden,
            onToggle: toggleRolePerm,
          ),
        ],
      ],
    );
  }
}

class _RolePermCard extends StatefulWidget {
  final _RoleDef role;
  final Set<String> enabledFeatures;
  final bool Function(String, String) roleCanAccess;
  final bool Function(String, String) isOverridden;
  final void Function(String, String, bool) onToggle;

  const _RolePermCard({
    required this.role,
    required this.enabledFeatures,
    required this.roleCanAccess,
    required this.isOverridden,
    required this.onToggle,
  });

  @override
  State<_RolePermCard> createState() => _RolePermCardState();
}

class _RolePermCardState extends State<_RolePermCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final relevantFeats = widget.role.features
        .where((f) => widget.enabledFeatures.contains(f))
        .toList();
    final restrictedCount = relevantFeats
        .where((f) => !widget.roleCanAccess(widget.role.key, f))
        .length;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: restrictedCount > 0
              ? Colors.orange.withOpacity(0.4)
              : Colors.grey.shade200,
        ),
      ),
      child: Column(children: [
        InkWell(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: widget.role.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(widget.role.icon, color: widget.role.color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.role.label,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                Text(
                  restrictedCount > 0
                      ? '$restrictedCount restrição(ões) activa(s)'
                      : 'Acesso completo às funcionalidades activas',
                  style: TextStyle(
                    fontSize: 12,
                    color: restrictedCount > 0 ? Colors.orange : AppTheme.textSecondary,
                    fontWeight: restrictedCount > 0 ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ])),
              Icon(_expanded ? Icons.expand_less : Icons.expand_more,
                  color: Colors.grey.shade600),
            ]),
          ),
        ),
        if (_expanded && relevantFeats.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Text(
              'Nenhuma funcionalidade activa nesta escola é relevante para esta função.',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
          ),
        if (_expanded && relevantFeats.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Wrap(
              spacing: 8, runSpacing: 8,
              children: relevantFeats.map((f) {
                final allowed = widget.roleCanAccess(widget.role.key, f);
                final overridden = widget.isOverridden(widget.role.key, f);
                return FilterChip(
                  avatar: Icon(
                    allowed ? Icons.check_circle_outline : Icons.block_outlined,
                    size: 16,
                    color: allowed
                        ? (overridden ? Colors.orange : Colors.green)
                        : Colors.red,
                  ),
                  label: Text(_featLabel[f] ?? f,
                      style: TextStyle(
                        fontSize: 12,
                        color: allowed ? null : Colors.red,
                        decoration: allowed ? null : TextDecoration.lineThrough,
                      )),
                  selected: allowed,
                  selectedColor: overridden
                      ? Colors.orange.withOpacity(0.15)
                      : Colors.green.withOpacity(0.12),
                  checkmarkColor: Colors.green,
                  onSelected: (v) => widget.onToggle(widget.role.key, f, v),
                  side: BorderSide(
                    color: allowed
                        ? (overridden ? Colors.orange.withOpacity(0.5) : Colors.green.withOpacity(0.4))
                        : Colors.red.withOpacity(0.4),
                  ),
                );
              }).toList(),
            ),
          ),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared helpers
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  const _SectionHeader({required this.icon, required this.label, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 20, color: AppTheme.primary),
      const SizedBox(width: 8),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        if (subtitle != null)
          Text(subtitle!, style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
      ]),
    ]);
  }
}

class _StatusChip extends StatelessWidget {
  final bool overridden;
  final bool defaultValue;
  const _StatusChip({required this.overridden, required this.defaultValue});

  @override
  Widget build(BuildContext context) {
    if (overridden) {
      return _chip('personalizado', Colors.orange);
    }
    return _chip(defaultValue ? 'activo por defeito' : 'inactivo por defeito',
        defaultValue ? Colors.blue : Colors.grey.shade500);
  }

  Widget _chip(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: color.withOpacity(0.3)),
    ),
    child: Text(text, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
  );
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
      child: Row(children: [
        Icon(Icons.error_outline, color: AppTheme.danger, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(message, style: TextStyle(color: AppTheme.danger, fontSize: 13))),
      ]),
    );
  }
}

class _LegendChip extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendChip({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 10, height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 6),
      Text(label, style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
    ]);
  }
}
