import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final n = ref.read(settingsProvider.notifier);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('الإعدادات', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Text('النموذج', style: TextStyle(color: Colors.grey[400])),
            DropdownButton<String>(
              value: s.model,
              dropdownColor: const Color(0xFF1A1A1A),
              isExpanded: true,
              items: const [
                DropdownMenuItem(value: 'glm', child: Text('GLM-5.3', style: TextStyle(color: Colors.white))),
                DropdownMenuItem(value: 'gemini', child: Text('Gemini 3.8', style: TextStyle(color: Colors.white))),
              ],
              onChanged: (v) {
                if (v != null) {
                  n.update(AppSettings(
                    model: v,
                    systemPrompt: s.systemPrompt,
                    temperature: s.temperature,
                    voiceSpeed: s.voiceSpeed,
                    useSearch: s.useSearch,
                    useThinking: s.useThinking,
                  ));
                }
              },
            ),
            const SizedBox(height: 12),
            Text('درجة الإبداع', style: TextStyle(color: Colors.grey[400])),
            Slider(
              value: s.temperature,
              min: 0,
              max: 1,
              activeColor: Colors.grey,
              onChanged: (v) => n.update(AppSettings(
                model: s.model,
                systemPrompt: s.systemPrompt,
                temperature: v,
                voiceSpeed: s.voiceSpeed,
                useSearch: s.useSearch,
                useThinking: s.useThinking,
              )),
            ),
            Text('سرعة الصوت', style: TextStyle(color: Colors.grey[400])),
            Slider(
              value: s.voiceSpeed,
              min: 0.1,
              max: 1,
              activeColor: Colors.grey,
              onChanged: (v) => n.update(AppSettings(
                model: s.model,
                systemPrompt: s.systemPrompt,
                temperature: s.temperature,
                voiceSpeed: v,
                useSearch: s.useSearch,
                useThinking: s.useThinking,
              )),
            ),
          ],
        ),
      ),
    );
  }
}
