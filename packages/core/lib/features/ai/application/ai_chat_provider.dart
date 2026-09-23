import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final bool isError;

  const ChatMessage({
    required this.text,
    required this.isUser,
    this.isError = false,
  });

  ChatMessage copyWith({String? text, bool? isUser, bool? isError}) {
    return ChatMessage(
      text: text ?? this.text,
      isUser: isUser ?? this.isUser,
      isError: isError ?? this.isError,
    );
  }
}

class AiChatState {
  final List<ChatMessage> messages;
  final bool isGenerating;

  const AiChatState({
    this.messages = const [],
    this.isGenerating = false,
  });

  AiChatState copyWith({
    List<ChatMessage>? messages,
    bool? isGenerating,
  }) {
    return AiChatState(
      messages: messages ?? this.messages,
      isGenerating: isGenerating ?? this.isGenerating,
    );
  }
}

class AiChatNotifier extends Notifier<AiChatState> {
  static const String _functionName = 'haven-faith-ai';
  bool _isInitialized = false;

  @override
  AiChatState build() {
    Future.microtask(_initChat);
    return const AiChatState();
  }

  void _initChat() {
    _isInitialized = true;
    state = state.copyWith(
      messages: const [
        ChatMessage(
          text: '¡Hola! Soy Haven Faith, tu asesor espiritual y físico. ¿En qué puedo ayudarte hoy?',
          isUser: false,
        ),
      ],
    );
  }

  Future<void> _ensureSecureSession() async {
    final client = Supabase.instance.client;
    if (client.auth.currentSession != null) return;

    await client.auth.signInAnonymously();
    if (client.auth.currentSession == null) {
      throw const AuthException('No se pudo crear una sesión segura.');
    }
  }

  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.isGenerating) return;

    if (!_isInitialized) {
      _initChat();
    }

    final previousMessages = state.messages
        .where((message) => message.text.isNotEmpty && !message.isError)
        .toList();
    final historyStart = previousMessages.length > 8
        ? previousMessages.length - 8
        : 0;
    final recentHistory = previousMessages.sublist(historyStart);

    final userMessage = ChatMessage(text: trimmed, isUser: true);
    final aiMessageIndex = state.messages.length + 1;

    state = state.copyWith(
      messages: [
        ...state.messages,
        userMessage,
        const ChatMessage(text: '', isUser: false),
      ],
      isGenerating: true,
    );

    try {
      await _ensureSecureSession();

      final response = await Supabase.instance.client.functions.invoke(
        _functionName,
        body: {
          'message': trimmed,
          'history': recentHistory
              .map(
                (message) => {
                  'role': message.isUser ? 'user' : 'assistant',
                  'text': message.text,
                },
              )
              .toList(),
        },
        abortSignal: Future<void>.delayed(const Duration(seconds: 30)),
      );

      final decoded = _decodeResponse(response.data);
      final responseText = (decoded['text'] ?? decoded['response'])
          ?.toString()
          .trim();
      if (responseText == null || responseText.isEmpty) {
        throw const FormatException('Respuesta de IA vacía.');
      }

      final updatedMessages = List<ChatMessage>.from(state.messages);
      updatedMessages[aiMessageIndex] = ChatMessage(
        text: responseText,
        isUser: false,
      );
      state = state.copyWith(messages: updatedMessages);
    } on http.RequestAbortedException {
      _handleError(
        aiMessageIndex,
        'La respuesta tardó demasiado. Inténtalo nuevamente.',
      );
    } on AuthException {
      _handleError(
        aiMessageIndex,
        'No se pudo iniciar la sesión segura de Haven Faith. Inténtalo nuevamente.',
      );
    } on FunctionsFetchException {
      _handleError(
        aiMessageIndex,
        'Error de conexión. Verifica tu internet.',
      );
    } on FunctionsHttpException catch (error) {
      _handleFunctionError(aiMessageIndex, error.status);
    } on FunctionsRelayException {
      _handleError(
        aiMessageIndex,
        'Haven Faith no está disponible en este momento.',
      );
    } on FunctionException catch (error) {
      _handleFunctionError(aiMessageIndex, error.status);
    } on FormatException {
      _handleError(
        aiMessageIndex,
        'El servidor devolvió una respuesta inválida.',
      );
    } catch (_) {
      _handleError(aiMessageIndex, 'Ocurrió un error inesperado.');
    } finally {
      state = state.copyWith(isGenerating: false);
    }
  }

  Map<String, dynamic> _decodeResponse(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    if (data is String) {
      final decoded = jsonDecode(data);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    }
    throw const FormatException('Respuesta de IA inválida.');
  }

  void _handleFunctionError(int index, int status) {
    final message = switch (status) {
      400 => 'No pude procesar ese mensaje. Inténtalo de otra forma.',
      401 => 'La sesión de Haven Faith expiró. Inténtalo nuevamente.',
      429 => 'Haven Faith está recibiendo muchas solicitudes. Inténtalo en un momento.',
      502 || 503 || 504 => 'Haven Faith no está disponible en este momento.',
      _ => 'Haven Faith no está disponible en este momento.',
    };
    _handleError(index, message);
  }

  void _handleError(int index, String errorMessage) {
    final updatedMessages = List<ChatMessage>.from(state.messages);
    if (index >= 0 && index < updatedMessages.length) {
      updatedMessages[index] = ChatMessage(
        text: errorMessage,
        isUser: false,
        isError: true,
      );
      state = state.copyWith(messages: updatedMessages);
    }
  }

  void clearChat() {
    _isInitialized = false;
    _initChat();
  }
}

final aiChatProvider = NotifierProvider<AiChatNotifier, AiChatState>(() {
  return AiChatNotifier();
});
