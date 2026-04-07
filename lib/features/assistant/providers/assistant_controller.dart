import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harmonia_ai/features/assistant/services/ai_service.dart';

class ChatMessage {
  const ChatMessage({required this.role, required this.content, required this.isStreaming});

  final String role;
  final String content;
  final bool isStreaming;

  ChatMessage copyWith({String? role, String? content, bool? isStreaming}) {
    return ChatMessage(
      role: role ?? this.role,
      content: content ?? this.content,
      isStreaming: isStreaming ?? this.isStreaming,
    );
  }
}

class AssistantState {
  const AssistantState({required this.messages, required this.isTyping, this.errorMessage = ''});

  final List<ChatMessage> messages;
  final bool isTyping;
  final String errorMessage;

  AssistantState copyWith({List<ChatMessage>? messages, bool? isTyping, String? errorMessage}) {
    return AssistantState(
      messages: messages ?? this.messages,
      isTyping: isTyping ?? this.isTyping,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class AssistantController extends AsyncNotifier<AssistantState> {
  final AIService _aiService = AIService();

  @override
  Future<AssistantState> build() async {
    // Load chat history from Firestore on init
    try {
      final history = await _aiService.loadChatHistory();
      final messages = history.map((msg) {
        return ChatMessage(
          role: msg['role'] ?? 'assistant',
          content: msg['content'] ?? '',
          isStreaming: false,
        );
      }).toList();
      
      return AssistantState(messages: messages, isTyping: false);
    } catch (e) {
      return const AssistantState(messages: [], isTyping: false);
    }
  }

  Future<void> sendMessage(String content) async {
    final AssistantState current = await future;
    
    // Add user message to state and save it
    final userMessage = ChatMessage(role: 'user', content: content, isStreaming: false);
    state = AsyncData(
      current.copyWith(
        isTyping: true,
        messages: [...current.messages, userMessage],
        errorMessage: '',
      ),
    );
    
    // Save user message to Firestore
    await _aiService.saveChatMessage(role: 'user', content: content);

    try {
      // Call the AI service to get a response
      final reply = await _aiService.sendMessage(content);
      
      final AssistantState afterTyping = await future;
      final assistantMessage = ChatMessage(
        role: 'assistant',
        content: reply,
        isStreaming: false,
      );
      
      state = AsyncData(
        afterTyping.copyWith(
          isTyping: false,
          messages: [...afterTyping.messages, assistantMessage],
        ),
      );
    } catch (e) {
      final AssistantState error = await future;
      state = AsyncData(
        error.copyWith(
          isTyping: false,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  Future<void> clearHistory() async {
    await _aiService.clearChatHistory();
    state = AsyncData(const AssistantState(messages: [], isTyping: false));
  }
}

final assistantControllerProvider =
    AsyncNotifierProvider<AssistantController, AssistantState>(AssistantController.new);
