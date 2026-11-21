import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/services/network_db_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/state_views.dart';

class NetworkSettingsCard extends ConsumerStatefulWidget {
  const NetworkSettingsCard({super.key});

  @override
  ConsumerState<NetworkSettingsCard> createState() => _NetworkSettingsCardState();
}

class _NetworkSettingsCardState extends ConsumerState<NetworkSettingsCard> {
  late NetworkRole _selectedRole;
  late TextEditingController _ipController;
  late TextEditingController _portController;

  List<String> _localIps = <String>[];
  bool _isLoading = true;
  bool _isTesting = false;
  String? _testResult;
  bool _testSuccess = false;

  @override
  void initState() {
    super.initState();
    _selectedRole = NetworkDbService.instance.config.role;
    _ipController = TextEditingController(text: NetworkDbService.instance.config.serverIp);
    _portController = TextEditingController(text: NetworkDbService.instance.config.port.toString());
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final config = await NetworkDbService.instance.loadConfig();
    final ips = await NetworkDbService.instance.getLocalIpAddresses();

    if (mounted) {
      setState(() {
        _selectedRole = config.role;
        _ipController.text = config.serverIp;
        _portController.text = config.port.toString();
        _localIps = ips;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _ipController.dispose();
    _portController.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    final ip = _ipController.text.trim();
    final port = int.tryParse(_portController.text.trim()) ?? NetworkDbService.defaultPort;

    if (ip.isEmpty) {
      AppSnackbar.showError(context, 'يرجى كتابة عنوان IP الجهاز الرئيسي أولاً');
      return;
    }

    setState(() {
      _isTesting = true;
      _testResult = null;
    });

    final success = await NetworkDbService.instance.testConnection(ip, port);

    if (mounted) {
      setState(() {
        _isTesting = false;
        _testSuccess = success;
        _testResult = success
            ? 'تم الاتصال بالسيرفر بنجاح! الجهاز الرئيسي متصل وجاهز.'
            : 'تعذر الاتصال بالجهاز الرئيسي. تأكد أن التطبيق مفتوح على الجهاز الرئيسي، وأن الجهازين متصلان بنفس الراوتر.';
      });
    }
  }

  Future<void> _saveConfig() async {
    final port = int.tryParse(_portController.text.trim()) ?? NetworkDbService.defaultPort;
    final config = NetworkConfig(
      role: _selectedRole,
      serverIp: _ipController.text.trim(),
      port: port,
    );

    await NetworkDbService.instance.saveConfig(config);

    if (mounted) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: AppColors.success),
              SizedBox(width: 8),
              Text('تم حفظ إعدادات الشبكة'),
            ],
          ),
          content: Text(
            _selectedRole == NetworkRole.server
                ? 'تم ضبط هذا الجهاز كـ (جهاز رئيسي / سيرفر المركز).\n\nيرجى إعادة تشغيل التطبيق لتفعيل وضع السيرفر واستقبال باقي الأجهزة.'
                : 'تم ضبط هذا الجهاز كـ (جهاز فرعي متصل بالمركز).\n\nيرجى إعادة تشغيل التطبيق للاتصال المباشر بقاعدة بيانات الجهاز الرئيسي.',
            style: const TextStyle(height: 1.5),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('حسناً'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      );
    }

    final isServerRunning = NetworkDbService.instance.isServerRunning;
    final clientsCount = NetworkDbService.instance.connectedClients;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // Header
            Row(
              children: <Widget>[
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.lan_outlined, color: AppColors.primary, size: 24),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'إعدادات الربط والشبكة الداخلية (LAN)',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'تشغيل البرنامج على عدة أجهزة كمبيوتر في المركز متصلة بنفس قاعدة البيانات',
                        style: TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'تحديث بيانات الشبكة',
                  onPressed: _loadData,
                ),
              ],
            ),
            const Divider(height: 32),

            // Role Selector
            const Text(
              'حدد دور هذا الجهاز في شبكة المركز:',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            Row(
              children: <Widget>[
                Expanded(
                  child: _RoleCard(
                    title: 'الجهاز الرئيسي (سيرفر المركز)',
                    subtitle: 'يخزن قاعدة البيانات الأصلية ويستقبل اتصالات الأجهزة الأخرى',
                    icon: Icons.dns_outlined,
                    isSelected: _selectedRole == NetworkRole.server,
                    onTap: () => setState(() => _selectedRole = NetworkRole.server),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _RoleCard(
                    title: 'جهاز فرعي (كلاينت)',
                    subtitle: 'يتصل بقاعدة بيانات الجهاز الرئيسي عبر شبكة المركز (الراوتر)',
                    icon: Icons.computer_outlined,
                    isSelected: _selectedRole == NetworkRole.client,
                    onTap: () => setState(() => _selectedRole = NetworkRole.client),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Server View
            if (_selectedRole == NetworkRole.server) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: [
                        Icon(
                          isServerRunning ? Icons.check_circle : Icons.info_outline,
                          color: isServerRunning ? AppColors.success : AppColors.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isServerRunning
                              ? 'سيرفر الشبكة يعمل وجاهز لاستقبال الأجهزة الفرعية'
                              : 'وضع الجهاز الرئيسي مفعل (سيعمل السيرفر عند فتح التطبيق)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: isServerRunning ? AppColors.success : AppColors.primary,
                          ),
                        ),
                        const Spacer(),
                        if (isServerRunning)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.successContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'الأجهزة المتصلة: $clientsCount',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.success),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'عناوين IP الخاصة بهذا الجهاز في شبكة المركز (اكتب أي منها في الأجهزة الفرعية):',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _localIps.map((ip) {
                        return ActionChip(
                          avatar: const Icon(Icons.wifi, size: 16),
                          label: Text(ip, style: const TextStyle(fontWeight: FontWeight.bold)),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: ip));
                            AppSnackbar.showSuccess(context, 'تم نسخ عنوان IP: $ip');
                          },
                          tooltip: 'انقر للنسخ',
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'رقم المنفذ الافتراضي (Port): ${_portController.text}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],

            // Client View
            if (_selectedRole == NetworkRole.client) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'بيانات الاتصال بالجهاز الرئيسي (Server IP):',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            controller: _ipController,
                            decoration: const InputDecoration(
                              labelText: 'عنوان IP الجهاز الرئيسي',
                              hintText: 'مثال: 192.168.1.50',
                              prefixIcon: Icon(Icons.dns_outlined),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 1,
                          child: TextFormField(
                            controller: _portController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'المنفذ (Port)',
                              prefixIcon: Icon(Icons.numbers),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        FilledButton.tonalIcon(
                          onPressed: _isTesting ? null : _testConnection,
                          icon: _isTesting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.network_check_outlined, size: 18),
                          label: const Text('فحص الاتصال'),
                        ),
                      ],
                    ),
                    if (_testResult != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _testSuccess ? AppColors.successContainer : AppColors.dangerContainer,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _testSuccess ? Icons.check_circle : Icons.error_outline,
                              color: _testSuccess ? AppColors.success : AppColors.danger,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _testResult!,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: _testSuccess ? AppColors.success : AppColors.danger,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Save Action
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FilledButton.icon(
                  onPressed: _saveConfig,
                  icon: const Icon(Icons.save_outlined, size: 18),
                  label: const Text('حفظ إعدادات الربط'),
                ),
              ],
            ),

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),

            // Instructions Box
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.border),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '💡 خطوات الربط السريع في المركز:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  SizedBox(height: 6),
                  Text(
                    '1. تأكد أن كل أجهزة الكمبيوتر متصلة بنفس شبكة الراوتر (سواء كابل أو Wi-Fi).\n'
                    '2. في الجهاز الرئيسي (السيرفر)، اترك الإعداد على "الجهاز الرئيسي" وانسخ عنوان الـ IP المكتوب أعلاه.\n'
                    '3. في الأجهزة الفرعية الأخرى، اختر "جهاز فرعي" والصق عنوان الـ IP ثم اضغط "فحص الاتصال" و"حفظ".\n'
                    '4. سيتم حفظ أي تعديل أو أمر شغل أو فاتورة في نفس قاعدة البيانات لحظياً عبر جميع الأجهزة!',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.6),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryContainer.withAlpha(80) : AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 32,
              color: isSelected ? AppColors.primary : AppColors.onSurfaceVariant,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? AppColors.primary : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: AppColors.primary, size: 20),
          ],
        ),
      ),
    );
  }
}

