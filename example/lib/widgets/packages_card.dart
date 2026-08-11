import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../tracking_provider.dart';

/// Manual entry for the payload's top-level `packages` field.
///
/// Codes are staged locally first and only reach the SDK when "Áp dụng" is
/// pressed — mirroring how the SDK works, where the list is captured per GPS
/// point at the moment it is recorded. The card makes that boundary visible:
/// a staged-but-not-applied list is not on the wire yet.
class PackagesCard extends StatelessWidget {
  final TextEditingController inputController;

  const PackagesCard({super.key, required this.inputController});

  @override
  Widget build(BuildContext context) {
    return Consumer<TrackingProvider>(builder: (_, p, __) {
      final dirty = p.packagesDirty;

      void snack(String msg, Color bg) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: bg),
        );
      }

      void add() {
        final raw = inputController.text;
        if (raw.trim().isEmpty) return;
        final added = p.addPackages(raw);
        inputController.clear();
        if (added == 0) {
          snack('⚠️ Không có mã mới nào được thêm (trùng hoặc rỗng)',
              Colors.orange);
        }
      }

      return Card(
        color: Colors.indigo.shade50,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('📦 Package Codes',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text(
                'Mã kiện hàng gắn kèm mỗi điểm GPS. Không nhập thì SDK không '
                'gửi gì thêm.',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
              const SizedBox(height: 12),

              // ── Nhập tay ────────────────────────────────────────────────
              TextField(
                controller: inputController,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: 'Mã kiện hàng',
                  hintText: '#10001, #10002',
                  helperText: 'Ngăn cách bằng dấu phẩy, xuống dòng hoặc khoảng trắng',
                  helperMaxLines: 2,
                  prefixIcon: const Icon(Icons.inventory_2_outlined),
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.white,
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.add),
                    tooltip: 'Thêm mã',
                    onPressed: add,
                  ),
                ),
                onSubmitted: (_) => add(),
              ),
              const SizedBox(height: 12),

              // ── Danh sách đã nhập ───────────────────────────────────────
              if (p.packages.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: const Text('Chưa có mã nào',
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                )
              else
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final code in p.packages)
                      Chip(
                        label: Text(code,
                            style: const TextStyle(
                                fontSize: 12, fontFamily: 'monospace')),
                        backgroundColor: Colors.white,
                        deleteIcon: const Icon(Icons.close, size: 16),
                        onDeleted: () => p.removePackage(code),
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
              const SizedBox(height: 12),

              // ── Trạng thái staged vs applied ────────────────────────────
              // The SDK tags each point at capture time, so what matters is
              // what was last applied — not what is sitting in the text field.
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: dirty ? Colors.orange.shade100 : Colors.green.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(children: [
                  Icon(dirty ? Icons.edit_note : Icons.check_circle,
                      size: 18,
                      color: dirty
                          ? Colors.orange.shade900
                          : Colors.green.shade900),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      dirty
                          ? 'Có thay đổi chưa áp dụng — điểm GPS vẫn đang gắn '
                              '${_describe(p.appliedPackages)}'
                          : 'Đang áp dụng: ${_describe(p.appliedPackages)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: dirty
                            ? Colors.orange.shade900
                            : Colors.green.shade900,
                      ),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 12),

              Row(children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: dirty
                        ? () async {
                            await p.applyPackages();
                            snack(
                              p.appliedPackages.isEmpty
                                  ? '✅ Đã bỏ toàn bộ mã'
                                  : '✅ Đã áp dụng ${p.appliedPackages.length} mã',
                              Colors.green,
                            );
                          }
                        : null,
                    icon: const Icon(Icons.cloud_done),
                    label: const Text('Áp dụng'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: (p.packages.isEmpty && p.appliedPackages.isEmpty)
                        ? null
                        : () async {
                            await p.clearPackages();
                            inputController.clear();
                            snack('🗑️ Đã xoá toàn bộ mã', Colors.orange);
                          },
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Xoá hết'),
                  ),
                ),
              ]),
            ],
          ),
        ),
      );
    });
  }

  static String _describe(List<String> codes) =>
      codes.isEmpty ? 'không có mã nào' : codes.join(', ');
}
