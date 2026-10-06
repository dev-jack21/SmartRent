import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/chat_service.dart';
import '../../services/community_chat_service.dart';

class ChatScreen extends StatefulWidget {
  final String propertyId;
  final String propertyName;
  final String? counterpartyName;
  final String currentUserRole; // 'owner', 'tenant', or 'caretaker'
  final Map<String, dynamic>? property;

  const ChatScreen({
    super.key,
    required this.propertyId,
    required this.propertyName,
    this.counterpartyName,
    required this.currentUserRole,
    this.property,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _primaryMsgController = TextEditingController();
  final TextEditingController _groupMsgController = TextEditingController();
  final TextEditingController _secondaryMsgController = TextEditingController();

  final ChatService _chatService = ChatService.instance;
  final CommunityChatService _communityService = CommunityChatService.instance;

  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _chatService.markAsRead(propertyId: widget.propertyId);
  }

  @override
  void dispose() {
    _primaryMsgController.dispose();
    _groupMsgController.dispose();
    _secondaryMsgController.dispose();
    super.dispose();
  }

  Future<void> _sendPrimaryMessage([String? customText]) async {
    final text = (customText ?? _primaryMsgController.text).trim();
    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    if (customText == null) _primaryMsgController.clear();

    try {
      await _chatService.sendMessage(
        propertyId: widget.propertyId,
        message: text,
        senderRole: widget.currentUserRole,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send message: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _sendGroupMessage() async {
    final text = _groupMsgController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    _groupMsgController.clear();

    try {
      await _communityService.sendMessage(
        propertyId: widget.propertyId,
        recipientId: 'group',
        message: text,
      );
    } catch (_) {}

    if (mounted) setState(() => _isSending = false);
  }

  Future<void> _sendSecondaryMessage() async {
    final text = _secondaryMsgController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    _secondaryMsgController.clear();

    final targetRole = widget.currentUserRole == 'owner'
        ? 'caretaker'
        : (widget.currentUserRole == 'tenant' ? 'caretaker' : 'landlord');

    try {
      await _communityService.sendMessage(
        propertyId: widget.propertyId,
        recipientId: targetRole,
        message: text,
      );
    } catch (_) {}

    if (mounted) setState(() => _isSending = false);
  }

  List<String> _getQuickTemplates() {
    if (widget.currentUserRole == 'owner') {
      return [
        'Friendly reminder: Rent is due soon.',
        'Payment received, thank you!',
        'Checking in regarding your maintenance request.',
        'Please share the payment receipt when ready.',
      ];
    } else {
      return [
        'I have submitted the rent payment.',
        'When will the maintenance team visit?',
        'Can I request an extension for rent?',
        'Thank you for confirming!',
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final currentUser = Supabase.instance.client.auth.currentUser;
    final currentUserId = currentUser?.id ?? '';
    final currentUserEmail = currentUser?.email ?? '';

    final isOwner = widget.currentUserRole == 'owner';
    final isTenant = widget.currentUserRole == 'tenant';

    final tab1Label = isOwner ? 'Tenant' : 'Landlord';
    final tab3Label = isOwner
        ? 'Caretaker'
        : (isTenant ? 'Caretaker' : 'Landlord');

    final partnerRoleText = isOwner ? 'Tenant' : 'Landlord';
    final partnerName = widget.counterpartyName != null &&
            widget.counterpartyName!.trim().isNotEmpty
        ? widget.counterpartyName!.trim()
        : partnerRoleText;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text('${widget.propertyName} Chat'),
          bottom: TabBar(
            isScrollable: false,
            tabs: [
              Tab(icon: const Icon(Icons.person_outlined), text: tab1Label),
              const Tab(icon: Icon(Icons.groups_outlined), text: 'All Tenants'),
              Tab(icon: const Icon(Icons.engineering_outlined), text: tab3Label),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // TAB 1: Primary Direct Chat (Landlord <-> Tenant)
            Column(
              children: [
                Expanded(
                  child: StreamBuilder<List<ChatMessage>>(
                    stream: _chatService.getMessagesStream(widget.propertyId),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting &&
                          !snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final messages = snapshot.data ?? [];

                      if (messages.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.chat_bubble_outline,
                                  size: 56,
                                  color: colors.primary.withValues(alpha: 0.5),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No messages yet',
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Direct chat with $partnerName ($tab1Label) for ${widget.propertyName}.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: colors.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final msg = messages[index];
                          final isMe = msg.senderId == currentUserId ||
                              msg.senderRole == widget.currentUserRole;

                          return _MessageBubble(message: msg, isMe: isMe);
                        },
                      );
                    },
                  ),
                ),

                // Quick templates
                Container(
                  height: 38,
                  margin: const EdgeInsets.only(bottom: 4),
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: _getQuickTemplates().map((template) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ActionChip(
                          labelStyle: TextStyle(
                            fontSize: 11,
                            color: colors.onSurfaceVariant,
                          ),
                          label: Text(template),
                          onPressed: () => _sendPrimaryMessage(template),
                        ),
                      );
                    }).toList(),
                  ),
                ),

                // Input bar
                SafeArea(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      border: Border(
                        top: BorderSide(
                          color: colors.outlineVariant.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _primaryMsgController,
                            textCapitalization: TextCapitalization.sentences,
                            maxLines: 4,
                            minLines: 1,
                            decoration: InputDecoration(
                              hintText: 'Message $partnerName ($tab1Label)...',
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide.none,
                              ),
                              filled: true,
                              fillColor: colors.surfaceContainerHighest,
                            ),
                            onSubmitted: (_) => _sendPrimaryMessage(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          onPressed: _isSending ? null : () => _sendPrimaryMessage(),
                          icon: _isSending
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.send_rounded),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // TAB 2: All Tenants (Building Group Chat)
            Column(
              children: [
                Expanded(
                  child: StreamBuilder<List<CommunityMessage>>(
                    stream: _communityService.getGroupMessagesStream(widget.propertyId),
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
                                Text('Building Tenants Group Chat', style: Theme.of(context).textTheme.titleMedium),
                                const SizedBox(height: 6),
                                const Text('Broadcast chat for all residents & tenants in your building.', textAlign: TextAlign.center),
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
                              hintText: 'Broadcast message to all building tenants...',
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

            // TAB 3: Caretaker Chat / Secondary Direct Chat
            Column(
              children: [
                Expanded(
                  child: StreamBuilder<List<CommunityMessage>>(
                    stream: _communityService.getGroupMessagesStream(widget.propertyId),
                    builder: (context, snapshot) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.engineering_outlined, size: 56, color: colors.primary),
                              const SizedBox(height: 12),
                              Text('Direct Chat with $tab3Label', style: Theme.of(context).textTheme.titleMedium),
                              const SizedBox(height: 6),
                              Text('Send on-site repair and maintenance instructions directly to $tab3Label.', textAlign: TextAlign.center),
                            ],
                          ),
                        ),
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
                            controller: _secondaryMsgController,
                            decoration: InputDecoration(
                              hintText: 'Message $tab3Label...',
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          onPressed: _sendSecondaryMessage,
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

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;

  const _MessageBubble({
    required this.message,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final timeStr =
        '${message.createdAt.hour.toString().padLeft(2, '0')}:${message.createdAt.minute.toString().padLeft(2, '0')}';

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? colors.primary : colors.secondaryContainer,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 2),
            bottomRight: Radius.circular(isMe ? 2 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isMe) ...[
              Text(
                message.senderRole == 'owner' ? 'Landlord' : 'Tenant',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: colors.onSecondaryContainer.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: 2),
            ],
            Text(
              message.message,
              style: TextStyle(
                color: isMe ? colors.onPrimary : colors.onSecondaryContainer,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  timeStr,
                  style: TextStyle(
                    fontSize: 10,
                    color: isMe
                        ? colors.onPrimary.withValues(alpha: 0.7)
                        : colors.onSecondaryContainer.withValues(alpha: 0.6),
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    message.isRead ? Icons.done_all : Icons.done,
                    size: 12,
                    color: colors.onPrimary.withValues(alpha: 0.7),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
