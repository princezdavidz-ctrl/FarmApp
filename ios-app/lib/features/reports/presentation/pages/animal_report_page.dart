import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:proj/app/theme/app_dimensions.dart';
import 'package:proj/features/auth/presentation/providers/auth_provider.dart';
import 'package:proj/features/herd/domain/entities/animal.dart';
import 'package:proj/features/herd/presentation/providers/herd_provider.dart';
import 'package:proj/features/reports/data/report_export_service.dart';
import 'package:proj/features/reports/domain/entities/animal_report.dart';
import 'package:proj/features/reports/presentation/providers/reports_providers.dart';

class AnimalReportPage extends ConsumerStatefulWidget {
  const AnimalReportPage({super.key, required this.reportType});

  final String reportType;

  @override
  ConsumerState<AnimalReportPage> createState() => _AnimalReportPageState();
}

class _AnimalReportPageState extends ConsumerState<AnimalReportPage> {
  String? _animalId;

  @override
  Widget build(BuildContext context) {
    final animals = ref.watch(herdProvider);
    final farmId = ref.watch(authProvider).valueOrNull?.selectedFarm?.id;
    final dateRange = ref.watch(selectedDateRangeProvider);
    final report = farmId == null || _animalId == null
        ? null
        : ref.watch(
            animalReportProvider((
              farmId: farmId,
              animalId: _animalId!,
              dateRange: dateRange,
            )),
          );
    final reportData = report?.valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Individual pig report'),
        actions: [
          IconButton(
            tooltip: 'Refresh herd and report',
            onPressed: () {
              ref.invalidate(herdProvider);
              if (farmId != null && _animalId != null) {
                ref.invalidate(
                  animalReportProvider((
                    farmId: farmId,
                    animalId: _animalId!,
                    dateRange: dateRange,
                  )),
                );
              }
            },
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Export pig report as PDF',
            onPressed: reportData == null
                ? null
                : () => _exportReport(context, reportData, 'pdf'),
            icon: const Icon(Icons.picture_as_pdf_outlined),
          ),
          PopupMenuButton<String>(
            tooltip: 'Export report',
            enabled: reportData != null,
            onSelected: (format) => _exportReport(context, reportData!, format),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'pdf', child: Text('Export PDF')),
              PopupMenuItem(value: 'xlsx', child: Text('Export Excel')),
              PopupMenuItem(value: 'doc', child: Text('Export Word')),
            ],
          ),
        ],
      ),
      body: animals.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _MessageState(
          message: 'Could not load the herd: $error',
          actionLabel: 'Retry',
          onAction: () => ref.invalidate(herdProvider),
        ),
        data: (items) {
          if (farmId == null) {
            return const _MessageState(
              message: 'Select a farm to view its pigs.',
            );
          }
          if (items.isEmpty) {
            return const _MessageState(
              message: 'No pigs are registered for this farm yet.',
            );
          }
          if (_animalId != null &&
              !items.any((animal) => animal.id == _animalId)) {
            _animalId = null;
          }

          return ListView(
            padding: const EdgeInsets.all(AppDimensions.pagePadding),
            children: [
              DropdownMenu<String>(
                key: ValueKey(_animalId),
                initialSelection: _animalId,
                enableFilter: true,
                requestFocusOnTap: true,
                expandedInsets: EdgeInsets.zero,
                label: const Text('Select a pig'),
                leadingIcon: const Icon(Icons.search),
                dropdownMenuEntries: items
                    .map(
                      (animal) => DropdownMenuEntry<String>(
                        value: animal.id,
                        label: _animalLabel(animal),
                      ),
                    )
                    .toList(),
                onSelected: (id) => setState(() => _animalId = id),
              ),
              const SizedBox(height: AppDimensions.spacingMedium),
              _DateRangeSelector(
                selectedRange: dateRange,
                onChanged: (range) {
                  ref.read(selectedDateRangeProvider.notifier).state = range;
                },
              ),
              const SizedBox(height: AppDimensions.spacingLarge),
              if (_animalId == null)
                const _MessageState(
                  message: 'Choose a pig to load its recorded information.',
                  icon: Icons.pets_outlined,
                )
              else if (report == null)
                const Center(child: CircularProgressIndicator())
              else
                report.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(AppDimensions.spacingLarge),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (error, _) => _MessageState(
                    message: 'Could not load this pig report: $error',
                    actionLabel: 'Retry',
                    onAction: () {
                      ref.invalidate(
                        animalReportProvider((
                          farmId: farmId,
                          animalId: _animalId!,
                          dateRange: dateRange,
                        )),
                      );
                    },
                  ),
                  data: (data) => _ReportSections(report: data),
                ),
            ],
          );
        },
      ),
    );
  }

  String _animalLabel(Animal animal) =>
      '${animal.tag} · ${animal.type} · ${animal.status}';

  Future<void> _exportReport(
    BuildContext context,
    AnimalReport report,
    String format,
  ) async {
    try {
      final filePath = await ReportExportService().exportReport(
        reportName: 'Pig_${report.animal.tag}_${widget.reportType}',
        format: format,
        data: report.toExportJson(),
      );
      if (!context.mounted) return;
      final renderObject = context.findRenderObject();
      final box = renderObject is RenderBox ? renderObject : null;
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(filePath)],
          subject: 'Pig ${report.animal.tag} ${widget.reportType} report',
          sharePositionOrigin: box == null
              ? null
              : box.localToGlobal(Offset.zero) & box.size,
        ),
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Pig report downloaded: $filePath')),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export failed: $error'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }
}

class _DateRangeSelector extends StatelessWidget {
  const _DateRangeSelector({
    required this.selectedRange,
    required this.onChanged,
  });

  final String selectedRange;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    children: [
      for (final range in const ['today', 'week', 'month', 'year'])
        ChoiceChip(
          label: Text(range[0].toUpperCase() + range.substring(1)),
          selected: selectedRange == range,
          onSelected: (_) => onChanged(range),
        ),
    ],
  );
}

class _ReportSections extends StatelessWidget {
  const _ReportSections({required this.report});

  final AnimalReport report;

  @override
  Widget build(BuildContext context) {
    final animal = report.animal;
    final latestWeight = report.latestGrowthRecord;
    final periodLabel =
        '${_formatDate(report.startDate)} – ${_formatDate(report.endDate)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.spacingLarge),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const CircleAvatar(child: Icon(Icons.pets)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        animal.tag.isEmpty ? 'Pig ${animal.id}' : animal.tag,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    Chip(label: Text(animal.status)),
                  ],
                ),
                const Divider(height: 28),
                _InfoRow(label: 'Type', value: animal.type),
                _InfoRow(label: 'Sex', value: animal.sex),
                _InfoRow(
                  label: 'Birth date',
                  value: animal.birthDate == null
                      ? 'Not recorded'
                      : _formatDate(animal.birthDate!),
                ),
                _InfoRow(
                  label: 'Latest recorded weight',
                  value: latestWeight == null
                      ? 'No measurement in this period'
                      : '${latestWeight.currentWeight.toStringAsFixed(1)} kg · ${_formatDate(latestWeight.measurementDate)}',
                ),
                _InfoRow(label: 'Reporting period', value: periodLabel),
                if (animal.notes?.isNotEmpty ?? false)
                  _InfoRow(label: 'Notes', value: animal.notes!),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppDimensions.spacingMedium),
        _SectionCard(
          title: 'Growth history',
          icon: Icons.trending_up,
          emptyMessage: 'No weight measurements recorded for this period.',
          isEmpty: report.growthRecords.isEmpty,
          children: report.growthRecords
              .map(
                (record) => _HistoryTile(
                  title: '${record.currentWeight.toStringAsFixed(1)} kg',
                  subtitle: [
                    _formatDate(record.measurementDate),
                    if (record.weightGain != null)
                      'Gain ${record.weightGain!.toStringAsFixed(1)} kg',
                    if (record.notes?.isNotEmpty ?? false) record.notes!,
                  ].join(' · '),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: AppDimensions.spacingMedium),
        _SectionCard(
          title: 'Health history',
          icon: Icons.health_and_safety_outlined,
          emptyMessage:
              'No health, treatment, or vaccination records for this period.',
          isEmpty: report.healthRecords.isEmpty,
          children: report.healthRecords
              .map(
                (record) => _HistoryTile(
                  title:
                      '${_titleCase(record.type)} · ${_titleCase(record.status)}',
                  subtitle: [
                    _formatDate(record.visitDate),
                    if (record.diagnosis?.isNotEmpty ?? false)
                      record.diagnosis!,
                    if (record.medication?.isNotEmpty ?? false)
                      record.medication!,
                    if (record.notes?.isNotEmpty ?? false) record.notes!,
                  ].join(' · '),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: AppDimensions.spacingMedium),
        _SectionCard(
          title: 'Breeding history',
          icon: Icons.favorite_border,
          emptyMessage:
              'No breeding records for this pig in the selected period.',
          isEmpty: report.pregnancies.isEmpty,
          children: report.pregnancies
              .map(
                (pregnancy) => _HistoryTile(
                  title: 'Mating · ${_titleCase(pregnancy.status)}',
                  subtitle: [
                    'Mated ${_formatDate(pregnancy.matingDate)}',
                    'Expected farrowing ${_formatDate(pregnancy.expectedFarrowingDate)}',
                    if (pregnancy.actualFarrowingDate != null)
                      'Farrowed ${_formatDate(pregnancy.actualFarrowingDate!)}',
                    if (pregnancy.bornAlive != null)
                      '${pregnancy.bornAlive} born alive',
                    if (pregnancy.notes?.isNotEmpty ?? false) pregnancy.notes!,
                  ].join(' · '),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: AppDimensions.spacingMedium),
        const Card(
          child: ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Individual feed data unavailable'),
            subtitle: Text(
              'Feed usage is recorded for the farm, not assigned to individual pigs, so farm totals are not attributed here.',
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.emptyMessage,
    required this.isEmpty,
    required this.children,
  });

  final String title;
  final IconData icon;
  final String emptyMessage;
  final bool isEmpty;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppDimensions.spacingMedium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 8),
          if (isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(emptyMessage),
            )
          else
            ...children,
        ],
      ),
    ),
  );
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(title),
    subtitle: subtitle.isEmpty ? null : Text(subtitle),
  );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 132, child: Text(label)),
        Expanded(child: Text(value, textAlign: TextAlign.end)),
      ],
    ),
  );
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.message,
    this.icon = Icons.info_outline,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppDimensions.spacingLarge),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 36),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    ),
  );
}

String _formatDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

String _titleCase(String value) => value
    .split(RegExp(r'[_\s]+'))
    .where((part) => part.isNotEmpty)
    .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
    .join(' ');
