import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../tracking_provider.dart';

class CacheCard extends StatelessWidget {
  final TextEditingController maxRecordsController;
  final TextEditingController maxDbSizeMbController;
  final TextEditingController batchSizeController;

  const CacheCard({
    super.key,
    required this.maxRecordsController,
    required this.maxDbSizeMbController,
    required this.batchSizeController,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<TrackingProvider>(builder: (_, p, __) {
      final dbLabel = p.dbSizeBytes < 1024 * 1024
          ? '${(p.dbSizeBytes / 1024).toStringAsFixed(1)} KB'
          : '${(p.dbSizeBytes / (1024 * 1024)).toStringAsFixed(2)} MB';

      return Card(
        color: Colors.teal.shade50,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  const Expanded(
                      child: Text('💾 Cache & Offline Storage',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold))),
                  IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: () => p.refreshCacheStats(),
                      tooltip: 'Refresh stats'),
                ]),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: Colors.teal.shade100,
                      borderRadius: BorderRadius.circular(8)),
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(children: [
                          Text('${p.cachedLocationsCount}',
                              style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold)),
                          const Text('Pending records',
                              style: TextStyle(
                                  fontSize: 11, color: Colors.black54)),
                        ]),
                        Column(children: [
                          Text(dbLabel,
                              style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold)),
                          const Text('DB size',
                              style: TextStyle(
                                  fontSize: 11, color: Colors.black54)),
                        ]),
                      ]),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final ok = await p.manualUploadCache();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(SnackBar(
                            content: Text(ok
                                ? '✅ Cache uploaded'
                                : '⚠️ Upload failed'),
                            backgroundColor:
                                ok ? Colors.green : Colors.orange,
                          ));
                        }
                      },
                      icon: const Icon(Icons.cloud_upload),
                      label: const Text('Upload Cache'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final ok = await p.clearCache();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(SnackBar(
                            content: Text(
                                ok ? '✅ Cache cleared' : '⚠️ Failed'),
                            backgroundColor:
                                ok ? Colors.green : Colors.orange,
                          ));
                        }
                      },
                      icon: const Icon(Icons.delete_sweep),
                      label: const Text('Clear Cache'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red),
                    ),
                  ),
                ]),
                const SizedBox(height: 8),
                ExpansionTile(
                  title: const Text('Configure DB Limits',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                  initiallyExpanded: p.cacheConfigExpanded,
                  onExpansionChanged: p.setCacheConfigExpanded,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Text(
                          'Call before startTracking(). Pass 0 to keep SDK defaults.',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey)),
                    ),
                    _CacheLimitRow(
                        'Max records',
                        maxRecordsController,
                        'records',
                        (v) =>
                            p.setMaxRecords(int.tryParse(v) ?? 5000)),
                    const SizedBox(height: 8),
                    _CacheLimitRow(
                        'Max DB size',
                        maxDbSizeMbController,
                        'MB',
                        (v) =>
                            p.setMaxDbSizeMb(int.tryParse(v) ?? 50)),
                    const SizedBox(height: 8),
                    _CacheLimitRow(
                        'Batch size',
                        batchSizeController,
                        'records/batch',
                        (v) =>
                            p.setBatchSize(int.tryParse(v) ?? 50)),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () async {
                        final ok =
                            await p.applyConfigureCacheLimits();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(SnackBar(
                            content: Text(ok
                                ? '✅ Cache limits applied'
                                : '⚠️ Failed'),
                            backgroundColor:
                                ok ? Colors.green : Colors.orange,
                          ));
                        }
                      },
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          minimumSize: const Size.fromHeight(40)),
                      child: const Text('Apply Limits'),
                    ),
                  ],
                ),
              ]),
        ),
      );
    });
  }
}

class _CacheLimitRow extends StatelessWidget {
  final String label, unit;
  final TextEditingController ctrl;
  final void Function(String) onChange;
  const _CacheLimitRow(this.label, this.ctrl, this.unit, this.onChange);

  @override
  Widget build(BuildContext context) => Row(children: [
        SizedBox(
            width: 110,
            child: Text(label,
                style: const TextStyle(fontSize: 13))),
        Expanded(
          child: TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            onChanged: onChange,
            decoration: InputDecoration(
              suffixText: unit,
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 8),
            ),
          ),
        ),
      ]);
}
