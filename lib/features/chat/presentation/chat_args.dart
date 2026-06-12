/// Passed via GoRouter's `extra` parameter to open /chat with a seed message.
class ChatArgs {
  const ChatArgs({required this.seedText});

  /// The opening message Trombl sends before the user types anything.
  final String seedText;
}
