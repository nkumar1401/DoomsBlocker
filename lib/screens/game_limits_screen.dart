import 'package:flutter/material.dart';
import '../models/installed_app_model.dart';
import '../services/native_bridge.dart';

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
    if (query.trim().isEmpty) {
      _filteredApps = List.from(_allApps);
    } else {
      _filteredApps = _allApps
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
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        title: const Text('Game & App Time Limits', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
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
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Session Time Limit',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF3B82F6).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$_gameLimitMinutes min',
                              style: const TextStyle(color: Color(0xFF3B82F6), fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Marked games will be auto-locked once your nephew plays for $_gameLimitMinutes minutes.',
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
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Search installed games or apps...',
                      hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
                      prefixIcon: const Icon(Icons.search, color: Color(0xFF64748B)),
                      filled: true,
                      fillColor: const Color(0xFF1E293B),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),

                // Header Info
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'INSTALLED APPS (${_filteredApps.length})',
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
                                color: app.isRestricted
                                    ? const Color(0xFF1E293B)
                                    : const Color(0xFF161F2E),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: app.isRestricted
                                      ? const Color(0xFF3B82F6).withOpacity(0.5)
                                      : const Color(0xFF243044),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: app.isRestricted
                                          ? const Color(0xFF3B82F6).withOpacity(0.2)
                                          : const Color(0xFF0F172A),
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
                                        Text(
                                          app.name,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Played today: ${app.usedMinutes} min',
                                          style: TextStyle(
                                            color: app.usedMinutes >= _gameLimitMinutes
                                                ? const Color(0xFFEF4444)
                                                : const Color(0xFF94A3B8),
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
}
