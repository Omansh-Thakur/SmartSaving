import 'package:flutter/material.dart';

import '../services/chat_service.dart';
import '../utils/constants.dart';

class ChatScreenArgs {
  const ChatScreenArgs({
    required this.productId,
    required this.productName,
  });

  final int productId;
  final String productName;
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.productId,
    required this.productName,
  });

  final int productId;
  final String productName;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _messages.add(
      _ChatMessage.bot(
        'Hi! I am your Smart Assistant for ${widget.productName}. '
        'Ask me if you should buy now or wait.',
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final userText = _messageController.text.trim();
    if (userText.isEmpty) {
      _showSnackBar('Please enter a message.');
      return;
    }
    if (_isLoading) return;

    setState(() {
      _messages.add(_ChatMessage.user(userText));
      _messageController.clear();
      _isLoading = true;
    });
    _scrollToBottom();

    try {
      final reply = await chatService.sendMessage(
        message: userText,
        productId: widget.productId,
      );

      if (!mounted) return;
      setState(() {
        _messages.add(_ChatMessage.bot(reply));
      });
    } catch (error) {
      if (!mounted) return;
      final message = _friendlyError(error);
      _showSnackBar(message);
      setState(() {
        _messages.add(
          _ChatMessage.bot(
            'Sorry, I could not fetch a response right now. $message',
          ),
        );
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  String _friendlyError(Object error) {
    if (error is ChatServiceException) return error.message;
    return 'Something went wrong. Please try again.';
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalItems = _messages.length + (_isLoading ? 1 : 0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Assistant'),
        backgroundColor: const Color(AppColors.primary),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(AppDimensions.paddingM),
              itemCount: totalItems,
              itemBuilder: (context, index) {
                if (_isLoading && index == totalItems - 1) {
                  return const _TypingBubble();
                }

                final message = _messages[index];
                return _MessageBubble(
                  text: message.text,
                  isUser: message.isUser,
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimensions.paddingM,
                AppDimensions.paddingS,
                AppDimensions.paddingM,
                AppDimensions.paddingM,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      textInputAction: TextInputAction.send,
                      minLines: 1,
                      maxLines: 4,
                      onSubmitted: (_) => _sendMessage(),
                      decoration: InputDecoration(
                        hintText: 'Ask about best time to buy...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppDimensions.borderRadiusL,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppDimensions.paddingS),
                  IconButton.filled(
                    onPressed: _isLoading ? null : _sendMessage,
                    icon: const Icon(Icons.send),
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(AppColors.primary),
                      foregroundColor: Colors.white,
                    ),
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

class _ChatMessage {
  const _ChatMessage({
    required this.text,
    required this.isUser,
  });

  factory _ChatMessage.user(String text) =>
      _ChatMessage(text: text, isUser: true);

  factory _ChatMessage.bot(String text) =>
      _ChatMessage(text: text, isUser: false);

  final String text;
  final bool isUser;
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.text,
    required this.isUser,
  });

  final String text;
  final bool isUser;

  @override
  Widget build(BuildContext context) {
    final bubbleColor = isUser ? Colors.blue : Colors.grey.shade300;
    final textColor = isUser ? Colors.white : Colors.black87;
    final alignment = isUser ? Alignment.centerRight : Alignment.centerLeft;

    return Align(
      alignment: alignment,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppDimensions.paddingS),
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingM,
          vertical: AppDimensions.paddingS,
        ),
        constraints: const BoxConstraints(maxWidth: 300),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusL),
        ),
        child: Text(
          text,
          style: TextStyle(color: textColor),
        ),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppDimensions.paddingS),
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingM,
          vertical: AppDimensions.paddingS,
        ),
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusL),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: AppDimensions.paddingS),
            Text('Thinking...'),
          ],
        ),
      ),
    );
  }
}
