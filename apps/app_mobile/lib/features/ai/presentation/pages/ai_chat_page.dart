import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gym_tracker/core/theme/app_colors.dart';
import 'package:core/features/ai/application/ai_chat_provider.dart';
import 'package:core/features/faith/application/reflection_journal_provider.dart';

class AiChatPage extends ConsumerStatefulWidget {
  const AiChatPage({super.key});

  @override
  ConsumerState<AiChatPage> createState() => _AiChatPageState();
}

class _AiChatPageState extends ConsumerState<AiChatPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _controller.text;
    if (text.trim().isEmpty) return;
    _controller.clear();
    ref.read(aiChatProvider.notifier).sendMessage(text);
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendQuickAction(FaithQuickAction action) {
    _controller.text = action.prompt;
    _sendMessage();
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(aiChatProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_awesome,
              color: AppColors.of(context).primary,
              size: 20,
            ),
            const SizedBox(height: 8),
            Text('Haven Faith', style: AppTypography.headlineMedium),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.delete_sweep_rounded,
              color: AppColors.of(context).textSecondary,
            ),
            tooltip: 'Limpiar Chat',
            onPressed: () => ref.read(aiChatProvider.notifier).clearChat(),
          ),
        ],
        backgroundColor: AppColors.of(context).background,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: chatState.messages.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.auto_awesome,
                            size: 64,
                            color: AppColors.of(context).surfaceBorder,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Bienvenido a Haven Faith',
                            style: AppTypography.headlineMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tu espacio de reflexión y acompañamiento.',
                            textAlign: TextAlign.center,
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.of(context).textSecondary,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            alignment: WrapAlignment.center,
                            children: havenFaithQuickActions
                                .map(
                                  (action) => ActionChip(
                                    avatar: const Icon(
                                      Icons.bolt_outlined,
                                      size: 17,
                                    ),
                                    label: Text(action.label),
                                    onPressed: chatState.isGenerating
                                        ? null
                                        : () => _sendQuickAction(action),
                                  ),
                                )
                                .toList(growable: false),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: chatState.messages.length,
                    itemBuilder: (context, index) =>
                        _ChatBubble(message: chatState.messages[index]),
                  ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            color: AppColors.of(context).surface,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: havenFaithQuickActions
                    .map(
                      (action) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ActionChip(
                          label: Text(action.label),
                          onPressed: chatState.isGenerating
                              ? null
                              : () => _sendQuickAction(action),
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(
              16,
            ).copyWith(bottom: MediaQuery.of(context).padding.bottom + 16),
            decoration: BoxDecoration(
              color: AppColors.of(context).surface,
              border: Border(
                top: BorderSide(color: AppColors.of(context).surfaceBorder),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppColors.of(context).surfaceHigh,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: AppColors.of(context).surfaceBorder,
                      ),
                    ),
                    child: TextField(
                      controller: _controller,
                      decoration: const InputDecoration(
                        hintText: 'Escribe un mensaje...',
                        border: InputBorder.none,
                      ),
                      onSubmitted: (_) => _sendMessage(),
                      textInputAction: TextInputAction.send,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: chatState.isGenerating ? null : _sendMessage,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: chatState.isGenerating
                          ? AppColors.of(context).surfaceHigh
                          : AppColors.of(context).primary,
                      shape: BoxShape.circle,
                    ),
                    child: chatState.isGenerating
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.of(context).primary,
                            ),
                          )
                        : Icon(
                            Icons.send,
                            color: AppColors.of(context).onPrimary,
                            size: 20,
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final ChatMessage message;
  const _ChatBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        decoration: BoxDecoration(
          color: message.isUser
              ? AppColors.of(context).primary
              : AppColors.of(context).surfaceHigh,
          borderRadius: BorderRadius.circular(20).copyWith(
            bottomRight: message.isUser
                ? const Radius.circular(0)
                : const Radius.circular(20),
            bottomLeft: !message.isUser
                ? const Radius.circular(0)
                : const Radius.circular(20),
          ),
          border: message.isError
              ? Border.all(color: AppColors.of(context).error)
              : null,
        ),
        child: Text(
          message.text,
          style: AppTypography.bodyLarge.copyWith(
            color: message.isUser
                ? AppColors.of(context).onPrimary
                : (message.isError
                      ? AppColors.of(context).error
                      : AppColors.of(context).textPrimary),
            height: 1.5,
          ),
        ),
      ),
    );
  }
}
