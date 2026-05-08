import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../tracking_provider.dart';

class LocationHistoryCard extends StatefulWidget {
  const LocationHistoryCard({super.key});

  @override
  State<LocationHistoryCard> createState() => _LocationHistoryCardState();
}

class _LocationHistoryCardState extends State<LocationHistoryCard> {
  final _scrollController = ScrollController();
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

    // Initial fetch after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startAutoRefresh();
    });
  }

  void _startAutoRefresh() {
    // Fetch immediately, then every 20s
    context.read<TrackingProvider>().fetchServerHistory();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) {
        context.read<TrackingProvider>().fetchServerHistory();
      }
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 100) {
      context.read<TrackingProvider>().fetchMoreServerHistory();
    }
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TrackingProvider>(builder: (_, p, __) {
      return Column(children: [
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ──
                Row(children: [
                  const Expanded(
                    child: Text(
                      '📝 Server Location History',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (p.isFetchingHistory)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    IconButton(
                      icon: const Icon(Icons.refresh, size: 20),
                      tooltip: 'Refresh now',
                      onPressed: () => p.fetchServerHistory(),
                    ),
                ]),

                // ── Subtitle ──
                Builder(builder: (_) {
                  final now = DateTime.now();
                  final from = p.sessionStartTime ??
                      now.subtract(const Duration(hours: 24));
                  final rangeLabel = p.sessionStartTime != null
                      ? 'Session start → now'
                      : 'Last 24 hours';
                  return Text(
                    '$rangeLabel  ·  userId: ${p.effectiveUserId}  ·  auto-refresh 20s',
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade600),
                  );
                }),
                const SizedBox(height: 12),

                // ── Error banner ──
                if (p.historyFetchError != null)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.red.shade200)),
                    child: Text(
                      '❌ ${p.historyFetchError}',
                      style: TextStyle(
                          fontSize: 12, color: Colors.red.shade700),
                    ),
                  ),

                // ── Empty state ──
                if (p.serverHistory.isEmpty && !p.isFetchingHistory)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'No history yet. Waiting for data...',
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                  ),

                // ── Scroll list ──
                if (p.serverHistory.isNotEmpty)
                  SizedBox(
                    height: 280,
                    child: ListView.builder(
                      controller: _scrollController,
                      itemCount: p.serverHistory.length +
                          (p.isFetchingMoreHistory || p.hasMoreHistory ? 1 : 0),
                      itemBuilder: (context, index) {
                        // Loading footer
                        if (index == p.serverHistory.length) {
                          return Padding(
                            padding:
                                const EdgeInsets.symmetric(vertical: 12),
                            child: Center(
                              child: p.isFetchingMoreHistory
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                  : const Text(
                                      'Scroll down to load more',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey),
                                    ),
                            ),
                          );
                        }

                        final loc = p.serverHistory[index];
                        final speed = loc.speed;
                        final kmh = speed != null && speed >= 0
                            ? '${speed.toStringAsFixed(1)} km/h'
                            : 'N/A';
                        final ts = loc.timestamp;
                        final timeLabel = ts != null
                            ? '${ts.hour.toString().padLeft(2, '0')}:'
                              '${ts.minute.toString().padLeft(2, '0')}:'
                              '${ts.second.toString().padLeft(2, '0')}'
                            : '--:--:--';

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(6)),
                            child: Text(
                              '#${index + 1}  '
                              '${loc.latitude?.toStringAsFixed(6) ?? '?'}, '
                              '${loc.longitude?.toStringAsFixed(6) ?? '?'}  |  '
                              '$kmh  |  $timeLabel',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                // ── Footer stats ──
                if (p.serverHistory.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    '${p.serverHistory.length} points loaded'
                    '${p.hasMoreHistory ? ' · more available ↓' : ' · all loaded'}',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue),
                  ),
                ],
              ],
            ),
          ),
        ),
      ]);
    });
  }
}
