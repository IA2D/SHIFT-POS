// ignore_for_file: require_trailing_commas

import 'package:flutter/material.dart';

import '../../../app/app_state_scope.dart';
import '../../../core/database/backup_coordinator.dart';
import '../../../shared/theme/app_theme.dart';
import '../domain/pos_settings.dart';

class ManagerSettingsPanel extends StatefulWidget {
  const ManagerSettingsPanel({
    required this.settings,
    required this.onChanged,
    required this.onLog,
    super.key,
  });

  final PosSettings settings;
  final VoidCallback onChanged;
  final Future<void> Function(String action, String details) onLog;

  @override
  State<ManagerSettingsPanel> createState() => _ManagerSettingsPanelState();
}

class _ManagerSettingsPanelState extends State<ManagerSettingsPanel> {
  _SettingsTab _tab = _SettingsTab.general;
  bool _saving = false;

  late final TextEditingController _restaurant;
  late final TextEditingController _currency;
  late final TextEditingController _phone;
  late final TextEditingController _footer;
  late final TextEditingController _tax;
  late final TextEditingController _service;
  late final TextEditingController _delivery;
  late final TextEditingController _discountLimit;
  late final TextEditingController _primaryColor;
  late final TextEditingController _autoLock;
  late final TextEditingController _networkPort;
  late final TextEditingController _logoData;
  late final TextEditingController _logoThreshold;
  late final TextEditingController _logoWidth;
  late final TextEditingController _logoMaxWidth;
  late final TextEditingController _backupDirectory;
  late final TextEditingController _extraBackupDirectories;
  late final TextEditingController _backupInterval;
  late final TextEditingController _backupRetention;
  late final TextEditingController _restoreFile;
  late Map<String, TextEditingController> _shortcuts;
  late bool _pinEnabled;
  late NetworkMode _networkMode;
  late ReceiptPrintRoute _printRoute;
  late List<ReceiptSection> _receiptOrder;
  late Set<ReceiptSection> _hiddenSections;
  late bool _showItemNotes;
  late bool _compactReceipt;
  late bool _logoEnabled;
  late ReceiptLogoMode _logoMode;
  late ReceiptLogoAlign _logoAlign;
  late bool _logoInvert;
  late bool _autoBackup;
  late bool _backupOnClose;

  static const _shortcutLabels = <String, String>{
    'newOrder': 'طلب جديد',
    'checkoutCash': 'دفع نقدي',
    'checkoutCard': 'دفع بطاقة',
    'holdOrder': 'تعليق الطلب',
    'focusSearch': 'بحث الأصناف',
    'openManager': 'لوحة الإدارة',
    'logout': 'تسجيل الخروج',
  };

  static const _shortcutDefaults = <String, String>{
    'newOrder': 'ctrl+n',
    'checkoutCash': 'f2',
    'checkoutCard': 'f3',
    'holdOrder': 'f4',
    'focusSearch': 'ctrl+f',
    'openManager': 'ctrl+m',
    'logout': 'ctrl+shift+l',
  };

  @override
  void initState() {
    super.initState();
    final settings = widget.settings;
    _restaurant = TextEditingController(text: settings.restaurantNameAr);
    _currency = TextEditingController(text: settings.currencySymbol);
    _phone = TextEditingController(text: settings.phoneNumber ?? '');
    _footer = TextEditingController(text: settings.receiptFooterAr ?? '');
    _tax = TextEditingController(text: '${settings.taxRate}');
    _service = TextEditingController(text: '${settings.serviceRate}');
    _delivery = TextEditingController(text: '${settings.deliveryFee}');
    _discountLimit = TextEditingController(
        text: settings.maxCashierDiscountPct?.toString() ?? '');
    _primaryColor = TextEditingController(text: settings.primaryColor);
    _autoLock = TextEditingController(text: '${settings.autoLockMinutes}');
    _networkPort = TextEditingController(text: '${settings.masterServerPort}');
    _logoData = TextEditingController(text: settings.receiptLogoDataUrl ?? '');
    _logoThreshold =
        TextEditingController(text: '${settings.receiptLogoThreshold}');
    _logoWidth = TextEditingController(text: '${settings.receiptLogoWidth}');
    _logoMaxWidth =
        TextEditingController(text: '${settings.receiptLogoMaxWidthPercent}');
    _backupDirectory =
        TextEditingController(text: settings.backupDirectory ?? '');
    _extraBackupDirectories =
        TextEditingController(text: settings.backupDirectories.join(';'));
    _backupInterval =
        TextEditingController(text: '${settings.autoBackupIntervalDays}');
    _backupRetention =
        TextEditingController(text: '${settings.backupRetentionDays}');
    _restoreFile = TextEditingController();
    _shortcuts = {
      for (final entry in _shortcutLabels.entries)
        entry.key: TextEditingController(
          text: settings.keyboardShortcuts[entry.key] ??
              _shortcutDefaults[entry.key] ??
              '',
        ),
    };
    _pinEnabled = settings.pinEnabled;
    _networkMode = settings.networkMode;
    _printRoute = settings.receiptPrintRoute;
    _receiptOrder = [...settings.receiptSectionOrder];
    _hiddenSections = {...settings.receiptHiddenSections};
    _showItemNotes = settings.receiptShowItemNotes;
    _compactReceipt = settings.receiptCompactMode;
    _logoEnabled = settings.receiptLogoEnabled;
    _logoMode = settings.receiptLogoMode;
    _logoAlign = settings.receiptLogoAlign;
    _logoInvert = settings.receiptLogoInvert;
    _autoBackup = settings.autoBackupEnabled;
    _backupOnClose = settings.autoBackupOnClose;
  }

  @override
  void dispose() {
    for (final controller in [
      _restaurant,
      _currency,
      _phone,
      _footer,
      _tax,
      _service,
      _delivery,
      _discountLimit,
      _primaryColor,
      _autoLock,
      _networkPort,
      _logoData,
      _logoThreshold,
      _logoWidth,
      _logoMaxWidth,
      _backupDirectory,
      _extraBackupDirectories,
      _backupInterval,
      _backupRetention,
      _restoreFile,
      ..._shortcuts.values,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save(PosSettings settings, String detail) async {
    setState(() => _saving = true);
    try {
      final dependencies = AppStateScope.of(context);
      await dependencies.settingsRepository.savePosSettings(settings);
      dependencies.settingsNotifier.value = settings;
      await widget.onLog('settings_updated', detail);
      widget.onChanged();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حفظ الإعدادات.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر الحفظ: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveGeneral() {
    return _save(
      widget.settings.copyWith(
        restaurantNameAr: _restaurant.text.trim(),
        currencySymbol: _currency.text.trim(),
        phoneNumber: _phone.text.trim(),
        receiptFooterAr: _footer.text.trim(),
        taxRate: double.tryParse(_tax.text) ?? 0,
        serviceRate: double.tryParse(_service.text) ?? 0,
        deliveryFee: double.tryParse(_delivery.text) ?? 0,
        maxCashierDiscountPct: double.tryParse(_discountLimit.text),
      ),
      'الإعدادات العامة',
    );
  }

  Future<void> _saveTheme() => _save(
        widget.settings
            .copyWith(primaryColor: _normalizeColor(_primaryColor.text)),
        'لون التطبيق',
      );

  Future<void> _savePin() => _save(
        widget.settings.copyWith(
          pinEnabled: _pinEnabled,
          autoLockMinutes: (int.tryParse(_autoLock.text) ?? 5).clamp(0, 240),
        ),
        'PIN والقفل',
      );

  Future<void> _saveNetwork() => _save(
        widget.settings.copyWith(
          networkMode: _networkMode,
          masterServerPort:
              (int.tryParse(_networkPort.text) ?? 47831).clamp(1024, 65535),
          receiptPrintRoute: _printRoute,
        ),
        'إعدادات الشبكة',
      );

  Future<void> _saveReceipt() => _save(
        widget.settings.copyWith(
          receiptSectionOrder: _receiptOrder,
          receiptHiddenSections: _hiddenSections,
          receiptShowItemNotes: _showItemNotes,
          receiptCompactMode: _compactReceipt,
          receiptLogoEnabled: _logoEnabled,
          receiptLogoDataUrl: _logoData.text.trim(),
          receiptLogoMode: _logoMode,
          receiptLogoThreshold:
              (int.tryParse(_logoThreshold.text) ?? 176).clamp(0, 255),
          receiptLogoWidth:
              (int.tryParse(_logoWidth.text) ?? 96).clamp(32, 384),
          receiptLogoInvert: _logoInvert,
          receiptLogoAlign: _logoAlign,
          receiptLogoMaxWidthPercent:
              (int.tryParse(_logoMaxWidth.text) ?? 100).clamp(20, 100),
        ),
        'تصميم الإيصال',
      );

  Future<void> _saveShortcuts() => _save(
        widget.settings.copyWith(
          keyboardShortcuts: {
            for (final entry in _shortcuts.entries)
              entry.key: entry.value.text.trim().toLowerCase(),
          },
        ),
        'اختصارات لوحة المفاتيح',
      );

  Future<void> _saveBackupSettings() => _save(
        widget.settings.copyWith(
          backupDirectory: _backupDirectory.text.trim(),
          backupDirectories: _extraBackupDirectories.text
              .split(';')
              .map((value) => value.trim())
              .where((value) => value.isNotEmpty)
              .take(2)
              .toList(),
          autoBackupEnabled: _autoBackup,
          autoBackupIntervalDays:
              (int.tryParse(_backupInterval.text) ?? 1).clamp(1, 7),
          autoBackupOnClose: _backupOnClose,
          backupRetentionDays:
              (int.tryParse(_backupRetention.text) ?? 7).clamp(0, 90),
        ),
        'إعدادات النسخ الاحتياطي',
      );

  Future<void> _backupNow() async {
    final dependencies = AppStateScope.of(context);
    final gateway = dependencies.databaseGateway;
    if (gateway == null) return;
    setState(() => _saving = true);
    try {
      final settings = widget.settings.copyWith(
        backupDirectory: _backupDirectory.text.trim(),
        backupDirectories: _extraBackupDirectories.text
            .split(';')
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .take(2)
            .toList(),
        autoBackupEnabled: _autoBackup,
        autoBackupIntervalDays:
            (int.tryParse(_backupInterval.text) ?? 1).clamp(1, 7),
        autoBackupOnClose: _backupOnClose,
        backupRetentionDays:
            (int.tryParse(_backupRetention.text) ?? 7).clamp(0, 90),
      );
      final files = await BackupCoordinator(
        gateway: gateway,
        settingsRepository: dependencies.settingsRepository,
        settingsNotifier: dependencies.settingsNotifier,
      ).runConfiguredBackup(settings);
      final file = files.join(', ');
      if (!mounted) return;
      widget.onChanged();
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('تم إنشاء النسخة: $file')));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('فشل النسخ: $error')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _restore() async {
    final gateway = AppStateScope.of(context).databaseGateway;
    final file = _restoreFile.text.trim();
    if (gateway == null || file.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('استعادة نسخة احتياطية'),
        content: const Text('سيتم استبدال قاعدة البيانات الحالية بالكامل.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('استعادة'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _saving = true);
    try {
      await gateway.restoreBackup(file);
      widget.onChanged();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تمت استعادة قاعدة البيانات.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('فشل الاستعادة: $error')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _normalizeColor(String value) {
    final trimmed = value.trim().toUpperCase();
    final withHash = trimmed.startsWith('#') ? trimmed : '#$trimmed';
    return RegExp(r'^#[0-9A-F]{6}$').hasMatch(withHash) ? withHash : '#008C95';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border.all(color: AppTheme.border, width: 2),
      ),
      child: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SegmentedButton<_SettingsTab>(
              showSelectedIcon: false,
              segments: _SettingsTab.values
                  .map((tab) => ButtonSegment(
                        value: tab,
                        icon: Icon(tab.icon),
                        label: Text(tab.label),
                      ))
                  .toList(),
              selected: {_tab},
              onSelectionChanged: (value) => setState(() => _tab = value.first),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(14),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              child: KeyedSubtree(
                key: ValueKey(_tab),
                child: switch (_tab) {
                  _SettingsTab.general => _generalTab(),
                  _SettingsTab.theme => _themeTab(),
                  _SettingsTab.pin => _pinTab(),
                  _SettingsTab.receipt => _receiptTab(),
                  _SettingsTab.network => _networkTab(),
                  _SettingsTab.backup => _backupTab(),
                  _SettingsTab.shortcuts => _shortcutsTab(),
                },
              ),
            ),
          ),
          if (_saving) const LinearProgressIndicator(minHeight: 3),
        ],
      ),
    );
  }

  Widget _generalTab() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(spacing: 10, runSpacing: 10, children: [
            _field(_restaurant, 'اسم المطعم'),
            _field(_currency, 'العملة', width: 140),
            _field(_phone, 'رقم الهاتف'),
            _field(_tax, 'الضريبة %', number: true),
            _field(_service, 'الخدمة %', number: true),
            _field(_delivery, 'رسوم الدليفري', number: true),
            _field(_discountLimit, 'حد خصم الكاشير %', number: true),
          ]),
          const SizedBox(height: 10),
          TextField(
            controller: _footer,
            decoration: const InputDecoration(labelText: 'تذييل الإيصال'),
            maxLines: 2,
          ),
          _saveButton(_saveGeneral),
        ],
      );

  Widget _themeTab() {
    const colors = [
      '#008C95',
      '#15803D',
      '#1D4ED8',
      '#7C3AED',
      '#B8430A',
      '#B91C1C'
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: colors.map((color) {
            final selected = _primaryColor.text.toUpperCase() == color;
            return InkWell(
              onTap: () => setState(() => _primaryColor.text = color),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Color(int.parse('FF${color.substring(1)}', radix: 16)),
                  border: Border.all(
                    color: selected ? Colors.black : Colors.white,
                    width: selected ? 4 : 2,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        _field(_primaryColor, 'لون مخصص HEX', width: 220),
        _saveButton(_saveTheme),
      ],
    );
  }

  Widget _pinTab() => Column(
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _pinEnabled,
            title: const Text('تفعيل PIN والقفل التلقائي'),
            onChanged: (value) => setState(() => _pinEnabled = value),
          ),
          _field(_autoLock, 'القفل بعد (دقيقة، 0 = أبداً)', number: true),
          _saveButton(_savePin),
        ],
      );

  Widget _networkTab() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<NetworkMode>(
            segments: const [
              ButtonSegment(
                  value: NetworkMode.standalone, label: Text('مستقل')),
              ButtonSegment(value: NetworkMode.master, label: Text('Master')),
              ButtonSegment(value: NetworkMode.side, label: Text('Side')),
            ],
            selected: {_networkMode},
            onSelectionChanged: (value) =>
                setState(() => _networkMode = value.first),
          ),
          const SizedBox(height: 12),
          _field(_networkPort, 'منفذ Master', number: true),
          const SizedBox(height: 12),
          SegmentedButton<ReceiptPrintRoute>(
            segments: const [
              ButtonSegment(
                  value: ReceiptPrintRoute.side, label: Text('طباعة Side')),
              ButtonSegment(
                  value: ReceiptPrintRoute.master, label: Text('طباعة Master')),
            ],
            selected: {_printRoute},
            onSelectionChanged: (value) =>
                setState(() => _printRoute = value.first),
          ),
          _saveButton(_saveNetwork),
        ],
      );

  Widget _receiptTab() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = 0; index < _receiptOrder.length; index++)
            Row(children: [
              Checkbox(
                value: !_hiddenSections.contains(_receiptOrder[index]),
                onChanged: (visible) => setState(() {
                  visible == true
                      ? _hiddenSections.remove(_receiptOrder[index])
                      : _hiddenSections.add(_receiptOrder[index]);
                }),
              ),
              Expanded(child: Text(_receiptSectionLabel(_receiptOrder[index]))),
              IconButton(
                tooltip: 'أعلى',
                onPressed: index == 0
                    ? null
                    : () => setState(() {
                          final section = _receiptOrder.removeAt(index);
                          _receiptOrder.insert(index - 1, section);
                        }),
                icon: const Icon(Icons.arrow_upward),
              ),
              IconButton(
                tooltip: 'أسفل',
                onPressed: index == _receiptOrder.length - 1
                    ? null
                    : () => setState(() {
                          final section = _receiptOrder.removeAt(index);
                          _receiptOrder.insert(index + 1, section);
                        }),
                icon: const Icon(Icons.arrow_downward),
              ),
            ]),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _showItemNotes,
            title: const Text('إظهار ملاحظات الأصناف'),
            onChanged: (value) => setState(() => _showItemNotes = value),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _compactReceipt,
            title: const Text('وضع إيصال مضغوط'),
            onChanged: (value) => setState(() => _compactReceipt = value),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _logoEnabled,
            title: const Text('إظهار الشعار'),
            onChanged: (value) => setState(() => _logoEnabled = value),
          ),
          if (_logoEnabled) ...[
            TextField(
              controller: _logoData,
              decoration: const InputDecoration(labelText: 'بيانات الشعار'),
              maxLines: 2,
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<ReceiptLogoMode>(
              initialValue: _logoMode,
              decoration: const InputDecoration(labelText: 'نمط الشعار'),
              items: ReceiptLogoMode.values
                  .map((mode) => DropdownMenuItem(
                        value: mode,
                        child: Text(mode.name),
                      ))
                  .toList(),
              onChanged: (value) => setState(() => _logoMode = value!),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<ReceiptLogoAlign>(
              initialValue: _logoAlign,
              decoration: const InputDecoration(labelText: 'محاذاة الشعار'),
              items: ReceiptLogoAlign.values
                  .map((align) => DropdownMenuItem(
                        value: align,
                        child: Text(align.name),
                      ))
                  .toList(),
              onChanged: (value) => setState(() => _logoAlign = value!),
            ),
            Wrap(spacing: 10, runSpacing: 10, children: [
              _field(_logoThreshold, 'Threshold', number: true),
              _field(_logoWidth, 'عرض الشعار', number: true),
              _field(_logoMaxWidth, 'أقصى عرض %', number: true),
            ]),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _logoInvert,
              title: const Text('عكس ألوان الشعار'),
              onChanged: (value) => setState(() => _logoInvert = value),
            ),
          ],
          _saveButton(_saveReceipt),
        ],
      );

  Widget _backupTab() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _backupDirectory,
            decoration: const InputDecoration(labelText: 'مجلد النسخ الرئيسي'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _extraBackupDirectories,
            decoration: const InputDecoration(
              labelText: 'مجلدات إضافية',
              hintText: 'افصل المسارات بعلامة ;',
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _autoBackup,
            title: const Text('نسخ احتياطي تلقائي'),
            onChanged: (value) => setState(() => _autoBackup = value),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _backupOnClose,
            title: const Text('نسخة عند إغلاق التطبيق'),
            onChanged: (value) => setState(() => _backupOnClose = value),
          ),
          Wrap(spacing: 10, runSpacing: 10, children: [
            _field(_backupInterval, 'كل (يوم)', number: true),
            _field(_backupRetention, 'الاحتفاظ (يوم)', number: true),
          ]),
          Wrap(spacing: 8, runSpacing: 8, children: [
            FilledButton.icon(
              onPressed: _saving ? null : _saveBackupSettings,
              icon: const Icon(Icons.save_outlined),
              label: const Text('حفظ'),
            ),
            OutlinedButton.icon(
              onPressed: _saving ? null : _backupNow,
              icon: const Icon(Icons.backup_outlined),
              label: const Text('نسخ الآن'),
            ),
          ]),
          const Divider(height: 28),
          TextField(
            controller: _restoreFile,
            decoration:
                const InputDecoration(labelText: 'ملف النسخة المراد استعادتها'),
          ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: OutlinedButton.icon(
              onPressed: _saving ? null : _restore,
              icon: const Icon(Icons.restore),
              label: const Text('استعادة'),
            ),
          ),
        ],
      );

  Widget _shortcutsTab() => Column(
        children: [
          for (final entry in _shortcutLabels.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                Expanded(child: Text(entry.value)),
                SizedBox(
                  width: 220,
                  child: TextField(
                    controller: _shortcuts[entry.key],
                    textDirection: TextDirection.ltr,
                    decoration: const InputDecoration(labelText: 'Shortcut'),
                  ),
                ),
                IconButton(
                  tooltip: 'الافتراضي',
                  onPressed: () => setState(() {
                    _shortcuts[entry.key]!.text =
                        _shortcutDefaults[entry.key] ?? '';
                  }),
                  icon: const Icon(Icons.restart_alt),
                ),
              ]),
            ),
          _saveButton(_saveShortcuts),
        ],
      );

  Widget _field(
    TextEditingController controller,
    String label, {
    double width = 210,
    bool number = false,
  }) {
    return SizedBox(
      width: width,
      child: TextField(
        controller: controller,
        keyboardType: number ? TextInputType.number : null,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }

  Widget _saveButton(Future<void> Function() onPressed) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: FilledButton.icon(
          onPressed: _saving ? null : onPressed,
          icon: const Icon(Icons.save_outlined),
          label: const Text('حفظ'),
        ),
      ),
    );
  }

  String _receiptSectionLabel(ReceiptSection section) => switch (section) {
        ReceiptSection.logo => 'الشعار',
        ReceiptSection.restaurant => 'بيانات المطعم',
        ReceiptSection.orderMeta => 'بيانات الطلب',
        ReceiptSection.customer => 'بيانات العميل',
        ReceiptSection.items => 'الأصناف',
        ReceiptSection.totals => 'الإجماليات',
        ReceiptSection.payment => 'الدفع',
        ReceiptSection.footer => 'التذييل',
      };
}

enum _SettingsTab {
  general('عام', Icons.tune),
  theme('المظهر', Icons.palette_outlined),
  pin('PIN والقفل', Icons.lock_outline),
  receipt('الإيصال', Icons.receipt_long_outlined),
  network('Network', Icons.devices_outlined),
  backup('نسخ احتياطي', Icons.backup_outlined),
  shortcuts('الاختصارات', Icons.keyboard_outlined);

  const _SettingsTab(this.label, this.icon);

  final String label;
  final IconData icon;
}
