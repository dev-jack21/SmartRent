import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final Set<String> _hiddenMessageIds = {};
  final Map<String, String> _messageReactions = {};

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

  void _openStickerDrawer(TextEditingController controller) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Container(
            padding: const EdgeInsets.all(16),
            height: 280,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Property Quick Emojis & Stickers',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    '👍', '❤️', '😊', '🙏', '🔑', '🏠', '💰', '🛠️', '✅', '⚠️', '👏', '🔥'
                  ].map((e) {
                    return InkWell(
                      onTap: () {
                        controller.text += e;
                        Navigator.pop(ctx);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(e, style: const TextStyle(fontSize: 22)),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                const Text('Quick Property Stickers',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    'Rent Paid ✅',
                    'Receipt Shared 🧾',
                    'Maintenance Needed 🛠️',
                    'Lease Signed ✍️',
                    'Thank You! 🙏',
                  ].map((sticker) {
                    return ActionChip(
                      label: Text('[STICKER: $sticker]'),
                      onPressed: () {
                        controller.text = '[STICKER: $sticker]';
                        Navigator.pop(ctx);
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showMessageOptions(ChatMessage msg) {
    final currentUser = Supabase.instance.client.auth.currentUser;
    final isMe = msg.senderId == currentUser?.id || msg.senderEmail == currentUser?.email;
    final editCtrl = TextEditingController(text: msg.message);

    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Wrap(
            children: [
              // WhatsApp Quick Reaction Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: ['👍', '❤️', '😂', '😮', '😢', '🙏'].map((emoji) {
                    return InkWell(
                      onTap: () {
                        setState(() {
                          _messageReactions[msg.id] = emoji;
                        });
                        Navigator.pop(ctx);
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Text(emoji, style: const TextStyle(fontSize: 26)),
                      ),
                    );
                  }).toList(),
                ),
              ),

              ListTile(
                leading: const Icon(Icons.reply_outlined),
                title: const Text('Reply'),
                onTap: () {
                  Navigator.pop(ctx);
                  _primaryMsgController.text = 'Replying to "${msg.message}": ';
                },
              ),
              ListTile(
                leading: const Icon(Icons.copy_outlined),
                title: const Text('Copy Text'),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: msg.message));
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Message copied to clipboard!')),
                  );
                },
              ),
              if (isMe)
                ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: const Text('Edit Message'),
                  onTap: () {
                    Navigator.pop(ctx);
                    showDialog(
                      context: context,
                      builder: (dlgCtx) => AlertDialog(
                        title: const Text('Edit Message'),
                        content: TextField(
                          controller: editCtrl,
                          maxLines: 3,
                          decoration: const InputDecoration(border: OutlineInputBorder()),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(dlgCtx),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            onPressed: () async {
                              Navigator.pop(dlgCtx);
                              await _chatService.editMessage(
                                messageId: msg.id,
                                propertyId: widget.propertyId,
                                newText: editCtrl.text.trim(),
                              );
                              if (mounted) setState(() {});
                            },
                            child: const Text('Save Edit'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ListTile(
                leading: const Icon(Icons.delete_sweep_outlined, color: Colors.orange),
                title: const Text('Delete for Me'),
                subtitle: const Text('Remove from your view only'),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _hiddenMessageIds.add(msg.id);
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Message deleted for you.')),
                  );
                },
              ),
              if (isMe)
                ListTile(
                  leading: const Icon(Icons.delete_forever, color: Colors.red),
                  title: const Text('Delete for Everyone', style: TextStyle(color: Colors.red)),
                  subtitle: const Text('Permanently delete for all participants'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _chatService.deleteMessage(
                      messageId: msg.id,
                      propertyId: widget.propertyId,
                    );
                    setState(() {
                      _hiddenMessageIds.add(msg.id);
                    });
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  void _showCommunityMessageOptions(CommunityMessage msg) {
    final user = Supabase.instance.client.auth.currentUser;
    final isMe = msg.senderId == user?.id || msg.senderName == user?.email;
    final editCtrl = TextEditingController(text: msg.message);

    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Wrap(
            children: [
              // WhatsApp Quick Reaction Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: ['👍', '❤️', '😂', '😮', '😢', '🙏'].map((emoji) {
                    return InkWell(
                      onTap: () {
                        setState(() {
                          _messageReactions[msg.id] = emoji;
                        });
                        Navigator.pop(ctx);
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Text(emoji, style: const TextStyle(fontSize: 26)),
                      ),
                    );
                  }).toList(),
                ),
              ),

              ListTile(
                leading: const Icon(Icons.reply_outlined),
                title: const Text('Reply'),
                onTap: () {
                  Navigator.pop(ctx);
                  _groupMsgController.text = 'Replying to "${msg.message}": ';
                },
              ),
              ListTile(
                leading: const Icon(Icons.copy_outlined),
                title: const Text('Copy Text'),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: msg.message));
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Message copied to clipboard!')),
                  );
                },
              ),
              if (isMe)
                ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: const Text('Edit Message'),
                  onTap: () {
                    Navigator.pop(ctx);
                    showDialog(
                      context: context,
                      builder: (dlgCtx) => AlertDialog(
                        title: const Text('Edit Message'),
                        content: TextField(
                          controller: editCtrl,
                          maxLines: 3,
                          decoration: const InputDecoration(border: OutlineInputBorder()),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(dlgCtx),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            onPressed: () async {
                              Navigator.pop(dlgCtx);
                              await _communityService.editMessage(
                                messageId: msg.id,
                                newText: editCtrl.text.trim(),
                              );
                              if (mounted) setState(() {});
                            },
                            child: const Text('Save Edit'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ListTile(
                leading: const Icon(Icons.delete_sweep_outlined, color: Colors.orange),
                title: const Text('Delete for Me'),
                subtitle: const Text('Remove from your view only'),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _hiddenMessageIds.add(msg.id);
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Message deleted for you.')),
                  );
                },
              ),
              if (isMe)
                ListTile(
                  leading: const Icon(Icons.delete_forever, color: Colors.red),
                  title: const Text('Delete for Everyone', style: TextStyle(color: Colors.red)),
                  subtitle: const Text('Permanently delete for all participants'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _communityService.deleteMessage(messageId: msg.id);
                    setState(() {
                      _hiddenMessageIds.add(msg.id);
                    });
                  },
                ),
            ],
          ),
        );
      },
    );
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

                      final messages = (snapshot.data ?? [])
                          .where((m) => !_hiddenMessageIds.contains(m.id))
                          .toList();

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

                          return GestureDetector(
                            onTap: () => _showMessageOptions(msg),
                            onLongPress: () => _showMessageOptions(msg),
                            child: _MessageBubble(
                              message: msg,
                              isMe: isMe,
                              reaction: _messageReactions[msg.id],
                            ),
                          );
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
                        IconButton(
                          icon: const Icon(Icons.emoji_emotions_outlined),
                          onPressed: () => _openStickerDrawer(_primaryMsgController),
                        ),
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
                      final messages = (snapshot.data ?? [])
                          .where((m) => !_hiddenMessageIds.contains(m.id))
                          .toList();

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
                          final rx = _messageReactions[msg.id];

                          return GestureDetector(
                            onTap: () => _showCommunityMessageOptions(msg),
                            onLongPress: () => _showCommunityMessageOptions(msg),
                            child: Align(
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
                                    if (rx != null) ...[
                                      const SizedBox(height: 2),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: colors.surfaceContainerHighest,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(rx, style: const TextStyle(fontSize: 12)),
                                      ),
                                    ],
                                  ],
                                ),
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
                        IconButton(
                          icon: const Icon(Icons.emoji_emotions_outlined),
                          onPressed: () => _openStickerDrawer(_groupMsgController),
                        ),
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
                    stream: _communityService.getRoleMessagesStream(
                      propertyId: widget.propertyId,
                      role: widget.currentUserRole == 'owner'
                          ? 'caretaker'
                          : (widget.currentUserRole == 'tenant' ? 'caretaker' : 'landlord'),
                    ),
                    builder: (context, snapshot) {
                      final messages = (snapshot.data ?? [])
                          .where((m) => !_hiddenMessageIds.contains(m.id))
                          .toList();

                      if (messages.isEmpty) {
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
                                Text('Send on-site repair and maintenance messages directly to $tab3Label.', textAlign: TextAlign.center),
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
                          final rx = _messageReactions[msg.id];

                          return GestureDetector(
                            onTap: () => _showCommunityMessageOptions(msg),
                            onLongPress: () => _showCommunityMessageOptions(msg),
                            child: Align(
                              alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                              child: Container(
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                                decoration: BoxDecoration(
                                  color: isMe ? colors.primary : colors.tertiaryContainer,
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
                                          color: colors.onTertiaryContainer,
                                        ),
                                      ),
                                    Text(
                                      msg.message,
                                      style: TextStyle(
                                        color: isMe ? colors.onPrimary : colors.onTertiaryContainer,
                                      ),
                                    ),
                                    if (rx != null) ...[
                                      const SizedBox(height: 2),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: colors.surfaceContainerHighest,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(rx, style: const TextStyle(fontSize: 12)),
                                      ),
                                    ],
                                  ],
                                ),
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
                        IconButton(
                          icon: const Icon(Icons.emoji_emotions_outlined),
                          onPressed: () => _openStickerDrawer(_secondaryMsgController),
                        ),
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
  final String? reaction;

  const _MessageBubble({
    required this.message,
    required this.isMe,
    this.reaction,
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
            if (reaction != null) ...[
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(reaction!, style: const TextStyle(fontSize: 12)),
              ),
            ],
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
