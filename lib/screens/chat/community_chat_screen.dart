import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/community_chat_service.dart';

class CommunityChatScreen extends StatefulWidget {
  final Map<String, dynamic> property;

  const CommunityChatScreen({
    super.key,
    required this.property,
  });

  @override
  State<CommunityChatScreen> createState() => _CommunityChatScreenState();
}

class _CommunityChatScreenState extends State<CommunityChatScreen> {
  final CommunityChatService _chatService = CommunityChatService.instance;
  final TextEditingController _groupMsgController = TextEditingController();
  final TextEditingController _directMsgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  String? _selectedPeerEmail;
  String? _selectedPeerName;
  bool _isSending = false;

  @override
  void dispose() {
    _groupMsgController.dispose();
    _directMsgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendGroupMessage() async {
    final text = _groupMsgController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    _groupMsgController.clear();

    try {
      await _chatService.sendMessage(
        propertyId: widget.property['id'].toString(),
        recipientId: 'group',
        message: text,
      );
    } catch (_) {}

    if (mounted) setState(() => _isSending = false);
  }

  Future<void> _sendDirectMessage() async {
    final text = _directMsgController.text.trim();
    if (text.isEmpty || _isSending || _selectedPeerEmail == null) return;

    setState(() => _isSending = true);
    _directMsgController.clear();

    try {
      await _chatService.sendMessage(
        propertyId: widget.property['id'].toString(),
        recipientId: _selectedPeerEmail!,
        message: text,
      );
    } catch (_) {}

    if (mounted) setState(() => _isSending = false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final propName = widget.property['name']?.toString() ?? 'Community';
    final currentUser = Supabase.instance.client.auth.currentUser;
    final currentUserId = currentUser?.id ?? '';
    final currentUserEmail = currentUser?.email ?? '';

    final tenantName = widget.property['tenant_name']?.toString().trim() ?? 'Neighbor';
    final tenantEmail = widget.property['tenant_email']?.toString().trim() ?? '';

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('$propName Community Chat'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.groups_outlined), text: 'Building Group'),
              Tab(icon: Icon(Icons.person_outline), text: 'Tenant 1-on-1'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Tab 1: Building Group Chat
            Column(
              children: [
                Expanded(
                  child: StreamBuilder<List<CommunityMessage>>(
                    stream: _chatService.getGroupMessagesStream(widget.property['id'].toString()),
                    builder: (context, snapshot) {
                      final messages = snapshot.data ?? [];

                      if (messages.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.groups_outlined, size: 56, color: colors.primary),
                                const SizedBox(height: 12),
                                Text('Building Community Chat', style: Theme.of(context).textTheme.titleMedium),
                                const SizedBox(height: 6),
                                const Text('Chat with all residents & neighbors in your building.', textAlign: TextAlign.center),
                              ],
                            ),
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final msg = messages[index];
                          final isMe = msg.senderId == currentUserId || msg.senderName == currentUserEmail;

                          return Align(
                            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                              decoration: BoxDecoration(
                                color: isMe ? colors.primary : colors.secondaryContainer,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                children: [
                                  if (!isMe)
                                    Text(
                                      msg.senderName,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: colors.onSecondaryContainer,
                                      ),
                                    ),
                                  Text(
                                    msg.message,
                                    style: TextStyle(
                                      color: isMe ? colors.onPrimary : colors.onSecondaryContainer,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                SafeArea(
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _groupMsgController,
                            decoration: const InputDecoration(
                              hintText: 'Message building residents...',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          onPressed: _sendGroupMessage,
                          icon: const Icon(Icons.send),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // Tab 2: 1-on-1 Private Tenant Chat
            Column(
              children: [
                if (tenantEmail.isNotEmpty && tenantEmail != currentUserEmail) ...[
                  ListTile(
                    tileColor: colors.surfaceContainerHighest,
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: Text(tenantName),
                    subtitle: Text(tenantEmail),
                    trailing: FilledButton.tonal(
                      onPressed: () {
                        setState(() {
                          _selectedPeerEmail = tenantEmail;
                          _selectedPeerName = tenantName;
                        });
                      },
                      child: const Text('Start Chat'),
                    ),
                  ),
                  const Divider(height: 1),
                ],
                Expanded(
                  child: _selectedPeerEmail == null
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.chat_bubble_outline, size: 52, color: colors.primary),
                              const SizedBox(height: 12),
                              const Text('Select a neighbor above to start a private 1-on-1 chat.'),
                            ],
                          ),
                        )
                      : StreamBuilder<List<CommunityMessage>>(
                          stream: _chatService.getDirectMessagesStream(
                            propertyId: widget.property['id'].toString(),
                            myId: currentUserEmail,
                            peerId: _selectedPeerEmail!,
                          ),
                          builder: (context, snapshot) {
                            final messages = snapshot.data ?? [];

                            return ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: messages.length,
                              itemBuilder: (context, index) {
                                final msg = messages[index];
                                final isMe = msg.senderId == currentUserEmail || msg.senderId == currentUserId;

                                return Align(
                                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                                  child: Container(
                                    margin: const EdgeInsets.symmetric(vertical: 4),
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: isMe ? colors.primary : colors.tertiaryContainer,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      msg.message,
                                      style: TextStyle(
                                        color: isMe ? colors.onPrimary : colors.onTertiaryContainer,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                ),
                if (_selectedPeerEmail != null)
                  SafeArea(
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _directMsgController,
                              decoration: InputDecoration(
                                hintText: 'Private message to $_selectedPeerName...',
                                border: const OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filled(
                            onPressed: _sendDirectMessage,
                            icon: const Icon(Icons.send),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
