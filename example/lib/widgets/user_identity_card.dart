import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../tracking_provider.dart';

class UserIdentityCard extends StatelessWidget {
  final TextEditingController emailController;
  final bool isEditing;
  final VoidCallback onToggleEdit;
  final VoidCallback onSave;

  const UserIdentityCard({
    super.key,
    required this.emailController,
    required this.isEditing,
    required this.onToggleEdit,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<TrackingProvider>(builder: (_, p, __) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('👤 User Identity',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text(
              'Email được dùng làm User ID để theo dõi tracking của từng người.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            if (isEditing) ...[
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  hintText: 'name@example.com',
                  prefixIcon: Icon(Icons.email_outlined),
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => onSave(),
              ),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onSave,
                    icon: const Icon(Icons.check),
                    label: const Text('Save'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onToggleEdit,
                    icon: const Icon(Icons.close),
                    label: const Text('Cancel'),
                  ),
                ),
              ]),
            ] else ...[
              Row(children: [
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.userEmail.isNotEmpty
                              ? p.userEmail
                              : '(chưa nhập email)',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: p.userEmail.isNotEmpty
                                ? Colors.black87
                                : Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text('User ID: ${p.effectiveUserId}',
                            style: const TextStyle(
                                fontSize: 11, color: Colors.blueGrey)),
                        Text('Device ID: ${p.deviceId}',
                            style: const TextStyle(
                                fontSize: 11, color: Colors.blueGrey)),
                      ]),
                ),
                IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: onToggleEdit,
                    tooltip: 'Chỉnh sửa email'),
              ]),
            ],
          ]),
        ),
      );
    });
  }
}
