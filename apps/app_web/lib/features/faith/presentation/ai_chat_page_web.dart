import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/features/ai/application/ai_chat_provider.dart';
import 'package:core/features/faith/application/reflection_journal_provider.dart';

import '../../../../core/theme/app_colors.dart';

class AiChatPageWeb extends ConsumerStatefulWidget {
  final bool embedded;

  const AiChatPageWeb({super.key, this.embedded = false});

  @override
  ConsumerState<AiChatPageWeb> createState() => _AiChatPageWebState();
}

class _AiChatPageWebState extends ConsumerState<AiChatPageWeb> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    await ref.read(aiChatProvider.notifier).sendMessage(text);
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  Future<void> _sendQuickAction(FaithQuickAction action) async {
    _controller.text = action.prompt;
    await _sendMessage();
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(aiChatProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (state.messages.isNotEmpty) _scrollToBottom();
    });

    final content = Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: Column(
          children: [
            if (state.messages.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 22, 16, 6),
                child: Column(
                  children: [
                    Text('¿Cómo quieres comenzar?', style: AppTypography.headlineSmall),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: havenFaithQuickActions.map((action) => ActionChip(
                        avatar: const Icon(Icons.bolt_outlined, size: 17),
                        label: Text(action.label),
                        onPressed: state.isGenerating ? null : () => _sendQuickAction(action),
                      )).toList(growable: false),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: state.messages.isEmpty
                  ? Center(
                      child: Text('Elige una acción rápida o escribe lo que tengas en mente.', style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary), textAlign: TextAlign.center),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
                      itemCount: state.messages.length,
                      itemBuilder: (context, index) {
                        final message = state.messages[index];
                        if (message.text.isEmpty && state.isGenerating) return const _GeneratingBubble();
                        return _ChatMessage(text: message.text, isUser: message.isUser, isError: message.isError);
                      },
                    ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: Row(
                children: havenFaithQuickActions.map((action) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(label: Text(action.label), onPressed: state.isGenerating ? null : () => _sendQuickAction(action)),
                )).toList(growable: false),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
              decoration: BoxDecoration(color: AppColors.surface, border: Border(top: BorderSide(color: AppColors.border))),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        enabled: !state.isGenerating,
                        minLines: 1,
                        maxLines: 4,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendMessage(),
                        decoration: InputDecoration(
                          hintText: state.isGenerating ? 'Haven Faith está respondiendo...' : 'Escribe un mensaje...',
                          filled: true,
                          fillColor: AppColors.background,
                          border: OutlineInputBorder(borderRadius: AppRadius.lg_, borderSide: BorderSide(color: AppColors.border)),
                          enabledBorder: OutlineInputBorder(borderRadius: AppRadius.lg_, borderSide: BorderSide(color: AppColors.border)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    IconButton.filled(
                      onPressed: state.isGenerating ? null : _sendMessage,
                      icon: state.isGenerating
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.send_rounded),
                      tooltip: 'Enviar',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (widget.embedded) return content;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Haven Faith', style: AppTypography.headlineMedium),
        actions: [
          IconButton(onPressed: () => ref.read(aiChatProvider.notifier).clearChat(), icon: const Icon(Icons.delete_outline), tooltip: 'Limpiar conversación'),
        ],
      ),
      body: content,
    );
  }
}

class _ChatMessage extends StatelessWidget {
  final String text;
  final bool isUser;
  final bool isError;
  const _ChatMessage({required this.text, required this.isUser, required this.isError});

  @override
  Widget build(BuildContext context) {
    final bubbleColor = isUser ? AppColors.primary : isError ? AppColors.error.withValues(alpha: 0.14) : AppColors.surfaceHigh;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 650),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(topLeft: const Radius.circular(18), topRight: const Radius.circular(18), bottomLeft: Radius.circular(isUser ? 18 : 4), bottomRight: Radius.circular(isUser ? 4 : 18)),
          border: isError ? Border.all(color: AppColors.error.withValues(alpha: 0.35)) : null,
        ),
        child: SelectableText(text, style: AppTypography.bodyLarge.copyWith(color: AppColors.textPrimary, height: 1.45)),
      ),
    );
  }
}

class _GeneratingBubble extends StatelessWidget {
  const _GeneratingBubble();

  @override
  Widget build(BuildContext context) {
    return const Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.only(bottom: 12),
        child: DecoratedBox(
          decoration: BoxDecoration(color: AppColors.surfaceHigh, borderRadius: BorderRadius.all(Radius.circular(18))),
          child: Padding(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12), child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))),
        ),
      ),
    );
  }
}
