import 'package:flutter/material.dart';
import '../services/native_bridge.dart';

class BlockedChannelsScreen extends StatefulWidget {
  const BlockedChannelsScreen({Key? key}) : super(key: key);

  @override
  State<BlockedChannelsScreen> createState() => _BlockedChannelsScreenState();
}

class _BlockedChannelsScreenState extends State<BlockedChannelsScreen> {
  final TextEditingController _channelController = TextEditingController();
  List<String> _channels = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await NativeBridge.getBlockedChannels();
    if (mounted) {
      setState(() {
        _channels = list;
        _isLoading = false;
      });
    }
  }

  Future<void> _addChannel(String name) async {
    final clean = name.trim();
    if (clean.isEmpty) return;

    await NativeBridge.addBlockedChannel(clean);
    _channelController.clear();
    await _load();
  }

  Future<void> _removeChannel(String name) async {
    await NativeBridge.removeBlockedChannel(name);
    await _load();
  }

  Future<void> _editChannel(String oldChannel) async {
    final editController = TextEditingController(text: oldChannel);
    final updated = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Edit Blocked Channel', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Update channel name or handle. (The @ symbol is optional; both match automatically).',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: editController,
              autofocus: true,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Channel name (e.g. Firstpost or @Firstpost)',
                hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                filled: true,
                fillColor: const Color(0xFF0F172A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF334155)),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEC4899),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              final text = editController.text.trim();
              if (text.isNotEmpty) {
                Navigator.of(ctx).pop(text);
              }
            },
            child: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (updated != null && updated.isNotEmpty && updated != oldChannel) {
      await NativeBridge.removeBlockedChannel(oldChannel);
      await NativeBridge.addBlockedChannel(updated);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        title: const Text('Blocked YouTube Channels', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFEC4899)))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Info Card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.shield_outlined, color: Color(0xFFEC4899), size: 24),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Whenever YouTube plays a video or opens a channel page matching these names, DoomsBlocker immediately backs out and blocks the screen.',
                          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Add Channel Input
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _channelController,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Enter YouTube channel name...',
                          hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
                          filled: true,
                          fillColor: const Color(0xFF1E293B),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF334155)),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                        onSubmitted: _addChannel,
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: () => _addChannel(_channelController.text),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEC4899),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Add', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'BLACKLISTED CHANNELS',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${_channels.length} blocked',
                      style: const TextStyle(color: Color(0xFFEC4899), fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                if (_channels.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(32),
                    alignment: Alignment.center,
                    child: const Column(
                      children: [
                        Icon(Icons.tv_off_rounded, color: Color(0xFF475569), size: 48),
                        SizedBox(height: 12),
                        Text(
                          'No channels blocked yet.',
                          style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
                        ),
                      ],
                    ),
                  )
                else
                  ..._channels.map(
                    (channel) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF334155)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.block, color: Color(0xFFEC4899), size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              channel,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, color: Color(0xFF94A3B8), size: 19),
                            tooltip: 'Edit channel name',
                            onPressed: () => _editChannel(channel),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Color(0xFFF43F5E), size: 19),
                            tooltip: 'Delete channel',
                            onPressed: () => _removeChannel(channel),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
