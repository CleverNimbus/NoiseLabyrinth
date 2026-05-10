import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noiselabyrinth_core/models/configs/generation_config.dart';
import 'package:noiselabyrinth_gui/my_app.dart';
import 'package:noiselabyrinth_gui/persistence/generation_config_repository.dart';
import 'package:noiselabyrinth_gui/persistence/stored_generation_config.dart';
import 'package:noiselabyrinth_gui/state/app_persisted_state.dart';
import 'package:noiselabyrinth_gui/state/editor/editor_providers.dart';
import 'package:noiselabyrinth_gui/widgets/quick_start_panel.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _InMemoryGenerationConfigRepository implements GenerationConfigRepository {
  final List<StoredGenerationConfig> _items = <StoredGenerationConfig>[];

  @override
  List<GenerationConfig> getAllConfigs() {
    return getAllStored().map((item) => item.toConfig()).toList(growable: false);
  }

  @override
  List<StoredGenerationConfig> getAllStored() {
    final items = List<StoredGenerationConfig>.from(_items);
    items.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return items;
  }

  @override
  List<String> getAllTags() {
    final tags = <String>{};
    for (final item in _items) {
      tags.addAll(item.tags);
    }
    final sorted = tags.toList()..sort();
    return sorted;
  }

  @override
  List<GenerationConfig> getConfigsByTag(String tag) {
    final normalizedTag = tag.trim().toLowerCase();
    return _items
        .where((item) => item.tags.any((itemTag) => itemTag.trim().toLowerCase() == normalizedTag))
        .map((item) => item.toConfig())
        .toList(growable: false);
  }

  @override
  Future<int> save(GenerationConfig config) async {
    final index = _items.indexWhere((item) => item.name == config.metadata.name);
    final stored = StoredGenerationConfig.fromConfig(config);
    if (index == -1) {
      _items.add(stored);
      return _items.length;
    }

    _items[index] = stored;
    return index + 1;
  }

  @override
  Future<void> saveAll(Iterable<GenerationConfig> configs) async {
    for (final config in configs) {
      await save(config);
    }
  }

  @override
  Future<void> seedIfEmpty(Iterable<GenerationConfig> configs) async {
    if (_items.isEmpty) {
      await saveAll(configs);
    }
  }
}

void main() {
  testWidgets('shows welcome on first run and switches to main panel', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = _InMemoryGenerationConfigRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs), repositoryProvider.overrideWithValue(repo)],
        child: const MyApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Welcome'), findsOneWidget);

    await tester.tap(find.byTooltip('Quick start'));
    await tester.pumpAndSettle();

    expect(find.text('Welcome'), findsNothing);
    expect(find.byType(QuickStartPanel), findsOneWidget);
  });
}
