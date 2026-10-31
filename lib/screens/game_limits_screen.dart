import 'package:flutter/material.dart';
import '../models/installed_app_model.dart';
import '../services/native_bridge.dart';
import '../widgets/duration_picker_dialog.dart';

class GameLimitsScreen extends StatefulWidget {
  const GameLimitsScreen({Key? key}) : super(key: key);

  @override
  State<GameLimitsScreen> createState() => _GameLimitsScreenState();
}

class _GameLimitsScreenState extends State<GameLimitsScreen> {
  int _gameLimitMinutes = 20;
  List<InstalledAppModel> _allApps = [];
  List<InstalledAppModel> _filteredApps = [];
  bool _isLoading = true;
  bool _showGamesOnly = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await NativeBridge.getDashboardData();
    final apps = await NativeBridge.getInstalledApps();
    if (mounted) {
      setState(() {
        _gameLimitMinutes = data.gameLimitMinutes;
        _allApps = apps;
        _filterApps(_searchController.text);
        _isLoading = false;
      });
    }
  }

  void _filterApps(String query) {
    var source = _allApps;
    if (_showGamesOnly) {
      final games = _allApps.where((app) => app.isGame || app.isRestricted).toList();
      // If OS reports games or restricted apps, use them; otherwise show all
      source = games.isNotEmpty ? games : _allApps;
    }
    if (query.trim().isEmpty) {
      _filteredApps = List.from(source);
    } else {
      _filteredApps = source
          .where((app) =>
              app.name.toLowerCase().contains(query.toLowerCase()) ||
              app.packageName.toLowerCase().contains(query.toLowerCase()))
          .toList();
    }
  }

  Future<void> _updateLimit(int minutes) async {
    setState(() => _gameLimitMinutes = minutes);
    await NativeBridge.setGameLimitMinutes(minutes);
  }

  Future<void> _toggleApp(InstalledAppModel app) async {
    await NativeBridge.toggleRestrictedApp(app.packageName);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final restrictedCount = _allApps.where((a) => a.isRestricted).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAFC),
        elevation: 0,
        title: const Text('Game & App Time Limits', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF3B82F6)))
          : Column(
              children: [
                // Top Limit Slider Card
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Session Time Limit',
                            style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          InkWell(
                            onTap: () async {
                              final selected = await DurationPickerDialog.show(
                                context,
                                title: 'Game Session Limit',
                                description: 'Scroll hours and minutes allowed for games before lockdown.',
                                initialMinutes: _gameLimitMinutes,
                                minMinutes: 1,
                                maxMinutes: 300,
                                quickPresets: [10, 15, 20, 30, 45, 60, 90, 120],
                              );
                              if (selected != null) {
                                _updateLimit(selected);
                              }
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF3B82F6).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.4)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '$_gameLimitMinutes min',
                                    style: const TextStyle(color: Color(0xFF3B82F6), fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.edit, size: 12, color: Color(0xFF3B82F6)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Marked games will be auto-locked once played for $_gameLimitMinutes minutes during Kids Mode.',
                        style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                      ),
                      const SizedBox(height: 10),
                      Slider(
                        value: _gameLimitMinutes.toDouble(),
                        min: 5,
                        max: 60,
                        divisions: 11,
                        activeColor: const Color(0xFF3B82F6),
                        inactiveColor: const Color(0xFF334155),
                        label: '$_gameLimitMinutes min',
                        onChanged: (val) => _updateLimit(val.round()),
                      ),
                    ],
                  ),
                ),

                // Search Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (q) => setState(() => _filterApps(q)),
                    style: const TextStyle(color: Color(0xFF0F172A), fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Search installed games or apps...',
                      hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
                      prefixIcon: const Icon(Icons.search, color: Color(0xFF64748B)),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),

                // Filter Tabs: Games Only vs All Installed
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      _buildTypeFilterChip('🎮 Games Only', _showGamesOnly, () {
                        setState(() {
                          _showGamesOnly = true;
                          _filterApps(_searchController.text);
                        });
                      }),
                      const SizedBox(width: 8),
                      _buildTypeFilterChip('📱 All Installed Apps', !_showGamesOnly, () {
                        setState(() {
                          _showGamesOnly = false;
                          _filterApps(_searchController.text);
                        });
                      }),
                    ],
                  ),
                ),

                // Header Info
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _showGamesOnly
                            ? 'INSTALLED GAMES (${_filteredApps.length})'
                            : 'INSTALLED APPS (${_filteredApps.length})',
                        style: const TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '$restrictedCount restricted',
                        style: const TextStyle(color: Color(0xFF3B82F6), fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),

                // Apps List
                Expanded(
                  child: _filteredApps.isEmpty
                      ? const Center(
                          child: Text(
                            'No apps found',
                            style: TextStyle(color: Color(0xFF64748B)),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          itemCount: _filteredApps.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final app = _filteredApps[index];
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: app.isRestricted
                                      ? const Color(0xFF3B82F6)
                                      : const Color(0xFFE2E8F0),
                                  width: app.isRestricted ? 1.5 : 1.0,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.02),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: app.isRestricted
                                          ? const Color(0xFF3B82F6).withOpacity(0.12)
                                          : const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      Icons.sports_esports_rounded,
                                      color: app.isRestricted ? const Color(0xFF3B82F6) : const Color(0xFF64748B),
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                app.name,
                                                style: const TextStyle(
                                                  color: Color(0xFF0F172A),
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (app.isGame) ...[
                                              const SizedBox(width: 6),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF8B5CF6).withOpacity(0.12),
                                                  borderRadius: BorderRadius.circular(4),
                                                  border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.3)),
                                                ),
                                                child: const Text(
                                                  'GAME',
                                                  style: TextStyle(
                                                    color: Color(0xFF7C3AED),
                                                    fontSize: 8.5,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Played today: ${app.usedMinutes} min',
                                          style: TextStyle(
                                            color: app.usedMinutes >= _gameLimitMinutes
                                                ? const Color(0xFFEF4444)
                                                : const Color(0xFF64748B),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Switch(
                                    value: app.isRestricted,
                                    activeColor: const Color(0xFF3B82F6),
                                    onChanged: (_) => _toggleApp(app),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildTypeFilterChip(String label, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF3B82F6) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xFF3B82F6) : const Color(0xFFE2E8F0),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF64748B),
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
