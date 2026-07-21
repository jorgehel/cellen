import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api/api_client.dart';
import '../../core/models/school.dart';
import '../../core/providers/currency_provider.dart';
import '../../core/theme/app_theme.dart';

class SchoolProfileScreen extends ConsumerStatefulWidget {
  const SchoolProfileScreen({super.key});

  @override
  ConsumerState<SchoolProfileScreen> createState() =>
      _SchoolProfileScreenState();
}

class _SchoolProfileScreenState extends ConsumerState<SchoolProfileScreen> {
  final _nameCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _nameLoaded = false;
  bool _saving = false;
  bool _uploading = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  // Pre-fill the name field once school data arrives
  void _populateName(String name) {
    if (!_nameLoaded) {
      _nameCtrl.text = name;
      _nameLoaded = true;
    }
  }

  Future<void> _pickAndUploadLogo() async {
    final picker = ImagePicker();
    final xFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 90,
    );
    if (xFile == null) return;

    setState(() {
      _uploading = true;
      _error = null;
    });
    try {
      await ref.read(apiClientProvider).uploadFile('/schools/logo', xFile);
      ref.invalidate(schoolInfoProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Logótipo actualizado')),
        );
      }
    } catch (e) {
      setState(() => _error = 'Erro ao carregar logótipo: $e');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _saveName() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(apiClientProvider).patch(
        '/schools/me',
        data: {'name': _nameCtrl.text.trim()},
      );
      ref.invalidate(schoolInfoProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dados guardados')),
        );
      }
    } catch (e) {
      setState(() => _error = 'Erro ao guardar: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final schoolAsync = ref.watch(schoolInfoProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil da Escola'),
      ),
      body: schoolAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline,
                  size: 48, color: AppTheme.danger),
              const SizedBox(height: 8),
              Text(e.toString(), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => ref.invalidate(schoolInfoProvider),
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
        data: (school) {
          _populateName(school.name);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ----- Logo section -----
                    Text(
                      'Logótipo',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _LogoPreview(
                          logoUrl: school.logoUrl,
                          uploading: _uploading,
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ElevatedButton.icon(
                                onPressed:
                                    _uploading ? null : _pickAndUploadLogo,
                                icon: const Icon(Icons.upload_outlined,
                                    size: 18),
                                label: Text(_uploading
                                    ? 'A carregar…'
                                    : 'Carregar Logótipo'),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'JPEG ou PNG, máx. 5 MB.\nRecomendado: 512 × 512 px.',
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),
                    const Divider(),
                    const SizedBox(height: 24),

                    // ----- Name section -----
                    Text(
                      'Dados da Escola',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 16),
                    Form(
                      key: _formKey,
                      child: TextFormField(
                        controller: _nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Nome da Escola *',
                          prefixIcon: Icon(Icons.school_outlined),
                        ),
                        validator: (v) =>
                            v == null || v.trim().isEmpty
                                ? 'Obrigatório'
                                : null,
                      ),
                    ),

                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.danger.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline,
                                color: AppTheme.danger, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _error!,
                                style: const TextStyle(
                                    color: AppTheme.danger, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _saving ? null : _saveName,
                        child: _saving
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Guardar'),
                      ),
                    ),

                    const SizedBox(height: 48),

                    // ----- Preview -----
                    Text(
                      'Pré-visualização',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    _SidebarPreview(
                      schoolName: school.name,
                      logoUrl: school.logoUrl,
                    ),

                    const SizedBox(height: 48),
                    const Divider(),
                    const SizedBox(height: 24),

                    // ----- WhatsApp section -----
                    _WhatsAppSection(school: school),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Logo preview widget
// ---------------------------------------------------------------------------
class _LogoPreview extends StatelessWidget {
  final String? logoUrl;
  final bool uploading;

  const _LogoPreview({this.logoUrl, required this.uploading});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 90,
      height: 90,
      decoration: BoxDecoration(
        color: AppTheme.primary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: _buildContent(),
    );
  }

  Widget _buildContent() {
    if (uploading) {
      return const Center(
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white));
    }
    if (logoUrl != null && logoUrl!.isNotEmpty) {
      final full =
          logoUrl!.startsWith('http') ? logoUrl! : '$kMediaBase$logoUrl';
      return CachedNetworkImage(
        imageUrl: full,
        fit: BoxFit.cover,
        width: 90,
        height: 90,
        placeholder: (_, __) => const Center(
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
        errorWidget: (_, __, ___) => const Icon(
            Icons.school_rounded, color: Colors.white, size: 40),
      );
    }
    return const Icon(Icons.school_rounded, color: Colors.white, size: 40);
  }
}

// ---------------------------------------------------------------------------
// Sidebar preview
// ---------------------------------------------------------------------------
class _SidebarPreview extends StatelessWidget {
  final String schoolName;
  final String? logoUrl;

  const _SidebarPreview({required this.schoolName, this.logoUrl});

  @override
  Widget build(BuildContext context) {
    Widget avatar;
    if (logoUrl != null && logoUrl!.isNotEmpty) {
      final full =
          logoUrl!.startsWith('http') ? logoUrl! : '$kMediaBase$logoUrl';
      avatar = ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: CachedNetworkImage(
          imageUrl: full,
          width: 28,
          height: 28,
          fit: BoxFit.cover,
          errorWidget: (_, __, ___) => _defaultAvatar(),
        ),
      );
    } else {
      avatar = _defaultAvatar();
    }

    return Container(
      width: 200,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppTheme.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                avatar,
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    schoolName,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Fake nav items
          for (final label in ['Dashboard', 'Crianças', 'Finanças'])
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              child: Row(
                children: [
                  Container(
                      width: 14,
                      height: 14,
                      color: AppTheme.border,
                      margin: const EdgeInsets.only(right: 8)),
                  Text(label,
                      style: const TextStyle(
                          fontSize: 11, color: AppTheme.textSecondary)),
                ],
              ),
            ),
          const Divider(height: 1),
          // Footer
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Powered by ',
                    style: TextStyle(
                        color: Colors.grey.shade400, fontSize: 9)),
                Text('Cellen',
                    style: TextStyle(
                        color: AppTheme.primary.withOpacity(0.6),
                        fontSize: 9,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _defaultAvatar() => Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: AppTheme.primary,
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Icon(Icons.school_rounded, color: Colors.white, size: 14),
      );
}

// ---------------------------------------------------------------------------
// WhatsApp Settings Section
// ---------------------------------------------------------------------------
class _WhatsAppSection extends ConsumerStatefulWidget {
  final School school;
  const _WhatsAppSection({required this.school});

  @override
  ConsumerState<_WhatsAppSection> createState() => _WhatsAppSectionState();
}

class _WhatsAppSectionState extends ConsumerState<_WhatsAppSection> {
  late bool _waEnabled;
  final _pidCtrl = TextEditingController();
  final _tokenCtrl = TextEditingController();
  final _testPhoneCtrl = TextEditingController();
  bool _saving = false;
  bool _testing = false;
  String? _error;
  String? _testResult;

  @override
  void initState() {
    super.initState();
    _waEnabled = widget.school.waEnabled;
    _pidCtrl.text = widget.school.waPhoneNumberId ?? '';
  }

  @override
  void dispose() {
    _pidCtrl.dispose();
    _tokenCtrl.dispose();
    _testPhoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() { _saving = true; _error = null; _testResult = null; });
    try {
      final data = <String, dynamic>{
        'wa_enabled': _waEnabled,
        'wa_phone_number_id': _pidCtrl.text.trim().isEmpty ? null : _pidCtrl.text.trim(),
      };
      if (_tokenCtrl.text.trim().isNotEmpty) {
        data['wa_access_token'] = _tokenCtrl.text.trim();
      }
      await ref.read(apiClientProvider).patch('/schools/me', data: data);
      ref.invalidate(schoolInfoProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Configurações WhatsApp guardadas')),
        );
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _test() async {
    final phone = _testPhoneCtrl.text.trim();
    if (phone.isEmpty) {
      setState(() => _error = 'Introduza um número para testar');
      return;
    }
    setState(() { _testing = true; _error = null; _testResult = null; });
    try {
      await ref.read(apiClientProvider).post('/schools/me/whatsapp/test', data: {'phone': phone});
      setState(() => _testResult = 'Mensagem enviada com sucesso!');
    } catch (e) {
      setState(() => _error = 'Falha ao enviar: $e');
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.chat_outlined, color: Color(0xFF25D366), size: 22),
            const SizedBox(width: 8),
            Text(
              'Notificações WhatsApp',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Integração com Meta WhatsApp Cloud API para enviar mensagens automáticas aos encarregados.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 16),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Activar notificações WhatsApp'),
          value: _waEnabled,
          onChanged: (v) => setState(() => _waEnabled = v),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _pidCtrl,
          decoration: const InputDecoration(
            labelText: 'Phone Number ID (Meta)',
            hintText: 'Ex: 123456789012345',
            prefixIcon: Icon(Icons.tag),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _tokenCtrl,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Access Token (deixe em branco para manter)',
            hintText: 'EAA...',
            prefixIcon: Icon(Icons.key_outlined),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!, style: const TextStyle(color: AppTheme.danger, fontSize: 13)),
        ],
        if (_testResult != null) ...[
          const SizedBox(height: 10),
          Text(_testResult!, style: const TextStyle(color: Colors.green, fontSize: 13)),
        ],
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Guardar configurações WhatsApp'),
          ),
        ),
        const SizedBox(height: 24),
        Text('Testar configuração', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _testPhoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Número de telefone',
                  hintText: '923 456 789',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.tonal(
              onPressed: _testing ? null : _test,
              child: _testing
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Testar'),
            ),
          ],
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}
