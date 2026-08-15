import 'package:flutter/material.dart';

void main() {
  runApp(const TelegramXApp());
}

/*
============================================================
Telegram X-style Flutter UI
Pixel-perfect refinements applied.
============================================================
*/

abstract class TgColors {
  static const accent = Color(0xFF54A9EB);
  static const active = Color(0xFF3D9BE0);
  static const green = Color(0xFF4FAE66);
  static const red = Color(0xFFE53935);
  static const textPrimary = Color(0xFF111111);
  static const textSecondary = Color(0xFF707579);
  static const time = Color(0xFF8A9099);
  static const separator = Color(0xFFE9EBEE);
  static const chatBackground = Color(0xFFD9E7EC);
  static const outgoingBubble = Color(0xFFEEFFDE); // TGX specific green
  static const incomingBubble = Colors.white;
  static const darkBg = Color(0xFF10161D);
  static const darkSurface = Color(0xFF1B232D);
  static const mutedBadge = Color(0xFFB8C1C9);
}

abstract class TgMetrics {
  static const double listTextSize = 16.0;
  static const double captionSize = 14.0;
  static const double creditSize = 12.0;

  static const double chatListAvatar3Line = 54.0; 
  static const double chatListAvatar2Line = 54.0;
  static const double chatListAvatar3LineBig = 60.0;

  static const double chatListHeight2Line = 72.0;
  static const double chatListHeight3Line = 78.0;
  static const double chatListHeight3LineBig = 84.0;

  static const double chatListLeftPadding = 12.0;
  static const double chatListContentLeft = 72.0; // 12 + 54 + 6
  static const double instantViewTextHorizontalOffset = 21.0;
  static const double cropPaddingHorizontal = 22.0;
  static const double bubbleRadius = 12.0;
}

ThemeData tgLightTheme() {
  return ThemeData(
    useMaterial3: false,
    brightness: Brightness.light,
    scaffoldBackgroundColor: Colors.white,
    canvasColor: Colors.white,
    primaryColor: TgColors.accent,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: Colors.black,
      elevation: 0,
      titleTextStyle: TextStyle(
        color: Colors.black,
        fontSize: 19,
        fontWeight: FontWeight.w600,
      ),
    ),
    colorScheme: const ColorScheme.light(
      primary: TgColors.accent,
      secondary: TgColors.accent,
    ),
    dividerColor: TgColors.separator,
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Colors.white,
      selectedItemColor: TgColors.accent,
      unselectedItemColor: TgColors.textSecondary,
      type: BottomNavigationBarType.fixed,
      selectedLabelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
      unselectedLabelStyle: TextStyle(fontSize: 12),
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: TgColors.textSecondary,
    ),
    splashColor: Colors.black12,
    highlightColor: Colors.transparent,
  );
}

ThemeData tgDarkTheme() {
  return ThemeData(
    useMaterial3: false,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: TgColors.darkBg,
    canvasColor: TgColors.darkBg,
    primaryColor: TgColors.accent,
    appBarTheme: const AppBarTheme(
      backgroundColor: TgColors.darkSurface,
      foregroundColor: Colors.white,
      elevation: 0,
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 19,
        fontWeight: FontWeight.w600,
      ),
    ),
    colorScheme: const ColorScheme.dark(
      primary: TgColors.accent,
      secondary: TgColors.accent,
    ),
    dividerColor: const Color(0xFF232B36),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: TgColors.darkSurface,
      selectedItemColor: TgColors.accent,
      unselectedItemColor: Color(0xFF8A94A3),
      type: BottomNavigationBarType.fixed,
      selectedLabelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
      unselectedLabelStyle: TextStyle(fontSize: 12),
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: Color(0xFF8A94A3),
    ),
    splashColor: Colors.white10,
    highlightColor: Colors.transparent,
  );
}

class TelegramXApp extends StatelessWidget {
  const TelegramXApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Telegram X Style',
      debugShowCheckedModeBanner: false,
      theme: tgLightTheme(),
      darkTheme: tgDarkTheme(),
      themeMode: ThemeMode.light,
      home: const HomeShell(),
    );
  }
}

void pushPage(BuildContext context, Widget page) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => page,
    ),
  );
}

String initialsOf(String text) {
  final words = text.trim().split(RegExp(r'\s+'));
  if (words.isEmpty || words.first.isEmpty) return '?';
  if (words.length == 1) {
    return words.first.substring(0, 1).toUpperCase();
  }
  return '${words[0].substring(0, 1)}${words[1].substring(0, 1)}'.toUpperCase();
}

/*
============================================================
Models
============================================================
*/

class ChatListItem {
  final String title;
  final String time;
  final String message;
  final int unread;
  final bool muted;
  final bool isDraft;
  final bool isVerified;
  final bool isSecret;
  final IconData? avatarIcon;
  final Color avatarStart;
  final Color avatarEnd;

  const ChatListItem({
    required this.title,
    required this.time,
    required this.message,
    this.unread = 0,
    this.muted = false,
    this.isDraft = false,
    this.isVerified = false,
    this.isSecret = false,
    this.avatarIcon,
    required this.avatarStart,
    required this.avatarEnd,
  });
}

class Message {
  final String text;
  final String time;
  final bool outgoing;
  final bool read;

  const Message({
    required this.text,
    required this.time,
    required this.outgoing,
    required this.read,
  });
}

class CallItem {
  final String name;
  final String time;
  final bool incoming;
  final bool missed;
  final bool video;
  final Color avatarStart;
  final Color avatarEnd;

  const CallItem({
    required this.name,
    required this.time,
    required this.incoming,
    required this.missed,
    required this.video,
    required this.avatarStart,
    required this.avatarEnd,
  });
}

class ContactItem {
  final String name;
  final String status;
  final Color avatarStart;
  final Color avatarEnd;

  const ContactItem({
    required this.name,
    required this.status,
    required this.avatarStart,
    required this.avatarEnd,
  });
}

/*
============================================================
Demo data
============================================================
*/

final List<ChatListItem> demoChats = [
  const ChatListItem(
    title: 'Saved Messages',
    time: '12:45',
    message: 'Photo',
    avatarIcon: Icons.bookmark,
    avatarStart: Color(0xFF6FB1E9),
    avatarEnd: Color(0xFF4C91D7),
  ),
  const ChatListItem(
    title: 'Telegram',
    time: '12:30',
    message: 'Telegram 10.0 is out with stories, reactions and more.',
    unread: 1,
    isVerified: true,
    avatarStart: Color(0xFF54A9EB),
    avatarEnd: Color(0xFF2F77C0),
  ),
  const ChatListItem(
    title: 'Flutter Dev Group',
    time: '11:58',
    message: 'Sarah: Has anyone tried the new Sliver APIs?',
    unread: 14,
    avatarStart: Color(0xFF7BC862),
    avatarEnd: Color(0xFF4CAF50),
  ),
  const ChatListItem(
    title: 'Ali Rezaei',
    time: '11:20',
    message: 'Voice message (0:12)',
    avatarStart: Color(0xFFFFB74D),
    avatarEnd: Color(0xFFFF9800),
  ),
  const ChatListItem(
    title: 'Maryam Hosseini',
    time: '10:05',
    message: 'See you tomorrow!',
    avatarStart: Color(0xFFBA68C8),
    avatarEnd: Color(0xFF9C27B0),
  ),
  const ChatListItem(
    title: 'Support',
    time: 'Yesterday',
    message: 'Please send your order number.',
    isDraft: true,
    muted: true,
    avatarStart: Color(0xFF90A4AE),
    avatarEnd: Color(0xFF607D8B),
  ),
  const ChatListItem(
    title: 'Secret Chat',
    time: 'Yesterday',
    message: 'Message disappeared',
    isSecret: true,
    avatarStart: Color(0xFF4DB6AC),
    avatarEnd: Color(0xFF00897B),
  ),
  const ChatListItem(
    title: 'Design Team',
    time: 'Tue',
    message: 'Amir: Upload the final icons please.',
    unread: 3,
    muted: true,
    avatarStart: Color(0xFFE57373),
    avatarEnd: Color(0xFFD32F2F),
  ),
];

final List<Message> demoMessages = [
  const Message(
    text: 'Hi! How is the Flutter project going?',
    time: '12:20',
    outgoing: false,
    read: true,
  ),
  const Message(
    text: 'It is going great. I am building the Telegram X style UI now.',
    time: '12:21',
    outgoing: true,
    read: true,
  ),
  const Message(
    text: 'Nice! Can you make the chat list pixel-perfect?',
    time: '12:22',
    outgoing: false,
    read: true,
  ),
  const Message(
    text: 'Yes, but we need to tune each screen step by step.',
    time: '12:23',
    outgoing: true,
    read: true,
  ),
  const Message(
    text: 'Also add the conversation page, profile and settings.',
    time: '12:24',
    outgoing: false,
    read: true,
  ),
];

final List<CallItem> demoCalls = [
  const CallItem(
    name: 'Ali Rezaei',
    time: 'Today, 12:10',
    incoming: true,
    missed: false,
    video: false,
    avatarStart: Color(0xFFFFB74D),
    avatarEnd: Color(0xFFFF9800),
  ),
  const CallItem(
    name: 'Maryam Hosseini',
    time: 'Today, 10:41',
    incoming: false,
    missed: false,
    video: true,
    avatarStart: Color(0xFFBA68C8),
    avatarEnd: Color(0xFF9C27B0),
  ),
  const CallItem(
    name: 'Design Team',
    time: 'Yesterday, 18:22',
    incoming: true,
    missed: true,
    video: false,
    avatarStart: Color(0xFFE57373),
    avatarEnd: Color(0xFFD32F2F),
  ),
  const CallItem(
    name: 'Flutter Dev Group',
    time: 'Yesterday, 15:03',
    incoming: false,
    missed: false,
    video: true,
    avatarStart: Color(0xFF7BC862),
    avatarEnd: Color(0xFF4CAF50),
  ),
];

final List<ContactItem> demoContacts = [
  const ContactItem(
    name: 'Ali Rezaei',
    status: 'online',
    avatarStart: Color(0xFFFFB74D),
    avatarEnd: Color(0xFFFF9800),
  ),
  const ContactItem(
    name: 'Maryam Hosseini',
    status: 'last seen recently',
    avatarStart: Color(0xFFBA68C8),
    avatarEnd: Color(0xFF9C27B0),
  ),
  const ContactItem(
    name: 'Amir Karimi',
    status: 'last seen 2 hours ago',
    avatarStart: Color(0xFF4DB6AC),
    avatarEnd: Color(0xFF00897B),
  ),
  const ContactItem(
    name: 'Sara Mohammadi',
    status: 'online',
    avatarStart: Color(0xFF54A9EB),
    avatarEnd: Color(0xFF2F77C0),
  ),
];

/*
============================================================
Shared widgets
============================================================
*/

class Avatar extends StatelessWidget {
  final String? title;
  final IconData? icon;
  final double size;
  final Color start;
  final Color end;

  const Avatar({
    super.key,
    this.title,
    this.icon,
    required this.size,
    required this.start,
    required this.end,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [start, end],
        ),
      ),
      child: Center(
        child: icon != null
            ? Icon(
                icon,
                color: Colors.white,
                size: size * 0.44,
              )
            : Text(
                initialsOf(title ?? ''),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: size * 0.34,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }
}

class UnreadBadge extends StatelessWidget {
  final int count;
  final bool muted;
  final bool mini;

  const UnreadBadge({
    super.key,
    required this.count,
    this.muted = false,
    this.mini = false,
  });

  @override
  Widget build(BuildContext context) {
    final text = count > 99 ? '99+' : '$count';

    return Container(
      constraints: BoxConstraints(
        minWidth: mini ? 16 : 22,
        minHeight: mini ? 16 : 22,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: mini ? 4 : 6,
        vertical: mini ? 1 : 2,
      ),
      decoration: BoxDecoration(
        color: muted ? TgColors.mutedBadge : TgColors.green,
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white,
          fontSize: mini ? 10 : 13,
          fontWeight: FontWeight.w600,
          height: 1.1,
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;

  const SectionHeader({
    super.key,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: TgColors.accent,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 64,
              color: TgColors.textSecondary.withOpacity(0.65),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: TgColors.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class SimplePage extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget? child;

  const SimplePage({
    super.key,
    required this.title,
    this.icon = Icons.layers_outlined,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: child ??
          EmptyState(
            icon: icon,
            title: title,
            subtitle:
                'This screen is included in the project catalog and should be fine-tuned next.',
          ),
    );
  }
}

/*
============================================================
Home shell
============================================================
*/

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  final List<Widget> _pages = const [
    ChatsPage(),
    CallsPage(),
    ContactsPage(),
    SettingsPage(),
  ];

  Widget _tabIcon(IconData icon, int badgeCount) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon),
        if (badgeCount > 0)
          Positioned(
            right: -6,
            top: -4,
            child: UnreadBadge(
              count: badgeCount,
              mini: true,
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (value) {
          setState(() {
            _index = value;
          });
        },
        items: [
          BottomNavigationBarItem(
            icon: _tabIcon(Icons.chat_bubble_outline, 18),
            label: 'Chats',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.call_outlined),
            label: 'Calls',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'Contacts',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

/*
============================================================
Chats
============================================================
*/

class ChatsPage extends StatelessWidget {
  const ChatsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Chats'),
          actions: [
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () {
                pushPage(context, const SearchScreen());
              },
            ),
            IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: () {},
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            labelColor: TgColors.accent,
            unselectedLabelColor: TgColors.textPrimary,
            indicatorColor: TgColors.accent,
            indicatorWeight: 3,
            labelStyle: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
            unselectedLabelStyle: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
            tabs: [
              Tab(text: 'All'),
              Tab(text: 'Unread'),
              Tab(text: 'Personal'),
              Tab(text: 'Channels'),
              Tab(text: 'Bots'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: TgColors.accent,
          onPressed: () {
            pushPage(
              context,
              const SimplePage(
                title: 'New Message',
                icon: Icons.edit,
              ),
            );
          },
          child: const Icon(
            Icons.edit,
            color: Colors.white,
          ),
        ),
        body: TabBarView(
          children: List.generate(
            5,
            (_) => const ChatListView(),
          ),
        ),
      ),
    );
  }
}

class ChatListView extends StatelessWidget {
  const ChatListView({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.only(top: 8, bottom: 96),
      itemCount: demoChats.length,
      separatorBuilder: (_, __) => const Divider(
        height: 1,
        thickness: 1,
        indent: TgMetrics.chatListContentLeft,
        color: TgColors.separator,
      ),
      itemBuilder: (context, index) {
        return ChatTile(chat: demoChats[index]);
      },
    );
  }
}

class ChatTile extends StatelessWidget {
  final ChatListItem chat;

  const ChatTile({
    super.key,
    required this.chat,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        pushPage(
          context,
          ChatScreen(chat: chat),
        );
      },
      child: SizedBox(
        height: TgMetrics.chatListHeight3Line,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.only(
                left: TgMetrics.chatListLeftPadding,
                right: 8,
              ),
              child: Avatar(
                title: chat.title,
                icon: chat.avatarIcon,
                size: TgMetrics.chatListAvatar3Line,
                start: chat.avatarStart,
                end: chat.avatarEnd,
              ),
            ),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      if (chat.isSecret)
                        const Padding(
                          padding: EdgeInsets.only(right: 4),
                          child: Icon(
                            Icons.lock,
                            size: 14,
                            color: TgColors.textSecondary,
                          ),
                        ),
                      Expanded(
                        child: Text(
                          chat.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w500,
                            color: TgColors.textPrimary,
                          ),
                        ),
                      ),
                      if (chat.isVerified)
                        const Padding(
                          padding: EdgeInsets.only(left: 4),
                          child: Icon(
                            Icons.verified,
                            size: 16,
                            color: TgColors.accent,
                          ),
                        ),
                      const SizedBox(width: 8),
                      Text(
                        chat.time,
                        style: const TextStyle(
                          fontSize: 12,
                          color: TgColors.time,
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            children: [
                              if (chat.isDraft)
                                const TextSpan(
                                  text: 'Draft: ',
                                  style: TextStyle(
                                    color: TgColors.red,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              TextSpan(
                                text: chat.message,
                                style: const TextStyle(
                                  color: TgColors.textSecondary,
                                  fontSize: 15,
                                  height: 1.2,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (chat.unread > 0)
                        UnreadBadge(
                          count: chat.unread,
                          muted: chat.muted,
                        )
                      else if (chat.muted)
                        const Icon(
                          Icons.volume_off,
                          size: 18,
                          color: TgColors.textSecondary,
                        ),
                      const SizedBox(width: 12),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/*
============================================================
Chat / Conversation
============================================================
*/

class ChatScreen extends StatefulWidget {
  final ChatListItem chat;

  const ChatScreen({
    super.key,
    required this.chat,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  late List<Message> _messages;
  bool _pinnedVisible = true;

  @override
  void initState() {
    super.initState();
    _messages = List<Message>.from(demoMessages);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final now = DateTime.now();
    final time =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    setState(() {
      _messages.insert(
        0,
        Message(
          text: text,
          time: time,
          outgoing: true,
          read: false,
        ),
      );
      _controller.clear();
    });
  }

  Widget _bubble(Message message) {
    final outgoing = message.outgoing;
    final maxWidth = MediaQuery.of(context).size.width * 0.75;

    return Align(
      alignment: outgoing ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: BoxConstraints(maxWidth: maxWidth),
        decoration: BoxDecoration(
          color: outgoing
              ? TgColors.outgoingBubble
              : TgColors.incomingBubble,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(TgMetrics.bubbleRadius),
            topRight: const Radius.circular(TgMetrics.bubbleRadius),
            bottomLeft: Radius.circular(outgoing ? 12 : 2),
            bottomRight: Radius.circular(outgoing ? 2 : 12),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message.text,
              style: const TextStyle(
                fontSize: 16,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  message.time,
                  style: const TextStyle(
                    fontSize: 11,
                    color: TgColors.time,
                  ),
                ),
                if (outgoing) ...[
                  const SizedBox(width: 3),
                  Icon(
                    message.read ? Icons.done_all : Icons.done,
                    size: 14,
                    color: TgColors.accent,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _pinnedBar() {
    if (!_pinnedVisible) return const SizedBox.shrink();

    return Container(
      color: Colors.white,
      child: Row(
        children: [
          const SizedBox(width: 16),
          const Icon(
            Icons.push_pin,
            size: 20,
            color: TgColors.accent,
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Pinned message',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: TgColors.accent,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Please review the latest UI changes.',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    color: TgColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              setState(() {
                _pinnedVisible = false;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _inputBar() {
    final hasText = _controller.text.trim().isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.emoji_emotions_outlined),
                onPressed: () {},
              ),
              IconButton(
                icon: const Icon(Icons.attach_file),
                onPressed: () {},
              ),
              Expanded(
                child: TextField(
                  controller: _controller,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(fontSize: 16),
                  decoration: const InputDecoration.collapsed(
                    hintText: 'Message',
                    hintStyle: TextStyle(color: TgColors.textSecondary),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (hasText)
                IconButton(
                  icon: const Icon(
                    Icons.send,
                    color: TgColors.accent,
                  ),
                  onPressed: _sendMessage,
                )
              else
                IconButton(
                  icon: const Icon(Icons.mic_outlined),
                  onPressed: () {},
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: InkWell(
          onTap: () {
            pushPage(
              context,
              ProfileScreen(chat: widget.chat),
            );
          },
          child: Row(
            children: [
              Avatar(
                title: widget.chat.title,
                icon: widget.chat.avatarIcon,
                size: 40,
                start: widget.chat.avatarStart,
                end: widget.chat.avatarEnd,
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.chat.title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Text(
                    'online',
                    style: TextStyle(
                      fontSize: 13,
                      color: TgColors.accent,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.call),
            onPressed: () {
              pushPage(
                context,
                CallScreen(name: widget.chat.title),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.videocam),
            onPressed: () {
              pushPage(
                context,
                CallScreen(name: widget.chat.title),
              );
            },
          ),
          PopupMenuButton(
            itemBuilder: (_) => const [
              PopupMenuItem(child: Text('Mute')),
              PopupMenuItem(child: Text('Search')),
              PopupMenuItem(child: Text('Wallpaper')),
              PopupMenuItem(child: Text('Add to folder')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              color: TgColors.chatBackground,
              child: ListView.builder(
                reverse: true,
                padding: const EdgeInsets.symmetric(vertical: 12),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  return _bubble(_messages[index]);
                },
              ),
            ),
          ),
          _pinnedBar(),
          _inputBar(),
        ],
      ),
    );
  }
}

/*
============================================================
Profile
============================================================
*/

class ProfileScreen extends StatelessWidget {
  final ChatListItem chat;

  const ProfileScreen({
    super.key,
    required this.chat,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: Text(chat.title),
          actions: [
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () {},
            ),
            PopupMenuButton(
              itemBuilder: (_) => const [
                PopupMenuItem(child: Text('Notifications')),
                PopupMenuItem(child: Text('Block')),
                PopupMenuItem(child: Text('Delete chat')),
              ],
            ),
          ],
        ),
        body: Column(
          children: [
            const SizedBox(height: 16),
            Avatar(
              title: chat.title,
              icon: chat.avatarIcon,
              size: 96,
              start: chat.avatarStart,
              end: chat.avatarEnd,
            ),
            const SizedBox(height: 12),
            Text(
              chat.title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'online',
              style: TextStyle(
                fontSize: 14,
                color: TgColors.accent,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _ProfileAction(
                  icon: Icons.notifications_none,
                  label: 'Mute',
                  onTap: () {},
                ),
                _ProfileAction(
                  icon: Icons.search,
                  label: 'Search',
                  onTap: () {},
                ),
                _ProfileAction(
                  icon: Icons.call,
                  label: 'Call',
                  onTap: () {
                    pushPage(context, CallScreen(name: chat.title));
                  },
                ),
                _ProfileAction(
                  icon: Icons.more_horiz,
                  label: 'More',
                  onTap: () {},
                ),
              ],
            ),
            const SizedBox(height: 12),
            const TabBar(
              labelColor: TgColors.accent,
              unselectedLabelColor: TgColors.textSecondary,
              indicatorColor: TgColors.accent,
              indicatorWeight: 3,
              tabs: [
                Tab(text: 'Media'),
                Tab(text: 'Files'),
                Tab(text: 'Links'),
                Tab(text: 'Voice'),
                Tab(text: 'Members'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _MediaGrid(chat: chat),
                  const _FilesList(),
                  const _LinksList(),
                  const _VoiceList(),
                  const _MembersList(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ProfileAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: TgColors.accent,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: TgColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MediaGrid extends StatelessWidget {
  final ChatListItem chat;

  const _MediaGrid({required this.chat});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: 18,
      itemBuilder: (context, index) {
        final t = index / 18;
        return Container(
          color: Color.lerp(chat.avatarStart, chat.avatarEnd, t),
        );
      },
    );
  }
}

class _FilesList extends StatelessWidget {
  const _FilesList();

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: const [
        ListTile(
          leading: Icon(Icons.insert_drive_file, color: TgColors.accent),
          title: Text('design_spec.pdf'),
          subtitle: Text('2.4 MB · Yesterday'),
        ),
        ListTile(
          leading: Icon(Icons.archive, color: TgColors.accent),
          title: Text('assets.zip'),
          subtitle: Text('18 MB · Monday'),
        ),
        ListTile(
          leading: Icon(Icons.description, color: TgColors.accent),
          title: Text('ui_notes.docx'),
          subtitle: Text('310 KB · Last week'),
        ),
      ],
    );
  }
}

class _LinksList extends StatelessWidget {
  const _LinksList();

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: const [
        ListTile(
          leading: Icon(Icons.link, color: TgColors.accent),
          title: Text('flutter.dev'),
          subtitle: Text('Flutter documentation'),
        ),
        ListTile(
          leading: Icon(Icons.link, color: TgColors.accent),
          title: Text('github.com'),
          subtitle: Text('Telegram X repository'),
        ),
        ListTile(
          leading: Icon(Icons.link, color: TgColors.accent),
          title: Text('figma.com'),
          subtitle: Text('UI design file'),
        ),
      ],
    );
  }
}

class _VoiceList extends StatelessWidget {
  const _VoiceList();

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: const [
        ListTile(
          leading: Icon(Icons.mic, color: TgColors.accent),
          title: Text('Voice message'),
          subtitle: Text('0:12 · Today'),
        ),
        ListTile(
          leading: Icon(Icons.mic, color: TgColors.accent),
          title: Text('Voice message'),
          subtitle: Text('0:47 · Yesterday'),
        ),
        ListTile(
          leading: Icon(Icons.mic, color: TgColors.accent),
          title: Text('Voice message'),
          subtitle: Text('1:05 · Monday'),
        ),
      ],
    );
  }
}

class _MembersList extends StatelessWidget {
  const _MembersList();

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: const [
        ListTile(
          leading: CircleAvatar(child: Text('A')),
          title: Text('Ali Rezaei'),
          subtitle: Text('online'),
        ),
        ListTile(
          leading: CircleAvatar(child: Text('M')),
          title: Text('Maryam Hosseini'),
          subtitle: Text('last seen recently'),
        ),
        ListTile(
          leading: CircleAvatar(child: Text('S')),
          title: Text('Sarah'),
          subtitle: Text('last seen 1 hour ago'),
        ),
      ],
    );
  }
}

/*
============================================================
Calls
============================================================
*/

class CallsPage extends StatelessWidget {
  const CallsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calls'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              pushPage(context, const SearchScreen());
            },
          ),
          IconButton(
            icon: const Icon(Icons.add_ic_call),
            onPressed: () {},
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: TgColors.accent,
        onPressed: () {},
        child: const Icon(Icons.add_ic_call, color: Colors.white),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.only(top: 8, bottom: 96),
        itemCount: demoCalls.length,
        separatorBuilder: (_, __) => const Divider(
          height: 1,
          thickness: 1,
          indent: 72,
          color: TgColors.separator,
        ),
        itemBuilder: (context, index) {
          final call = demoCalls[index];

          return ListTile(
            onTap: () {
              pushPage(context, CallScreen(name: call.name));
            },
            leading: Avatar(
              title: call.name,
              size: 52,
              start: call.avatarStart,
              end: call.avatarEnd,
            ),
            title: Text(
              call.name,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Row(
              children: [
                Icon(
                  call.incoming
                      ? Icons.arrow_downward
                      : Icons.arrow_upward,
                  size: 15,
                  color: call.missed ? TgColors.red : TgColors.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(call.time),
              ],
            ),
            trailing: Icon(
              call.video ? Icons.videocam : Icons.call,
              color: TgColors.accent,
            ),
          );
        },
      ),
    );
  }
}

class CallScreen extends StatelessWidget {
  final String name;

  const CallScreen({
    super.key,
    required this.name,
  });

  Widget _control(IconData icon, bool active) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? Colors.white : Colors.white12,
      ),
      child: Icon(
        icon,
        color: active ? Colors.black : Colors.white,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TgColors.darkBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(name),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 24),
            const Avatar(
              title: 'User',
              size: 112,
              start: TgColors.accent,
              end: TgColors.active,
            ),
            const SizedBox(height: 16),
            Text(
              name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Ringing...',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 15,
              ),
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _control(Icons.mic_off, false),
                const SizedBox(width: 24),
                _control(Icons.volume_up, true),
                const SizedBox(width: 24),
                _control(Icons.videocam, false),
              ],
            ),
            const SizedBox(height: 32),
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: TgColors.red,
              ),
              child: const Icon(
                Icons.call_end,
                color: Colors.white,
                size: 34,
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

/*
============================================================
Contacts
============================================================
*/

class ContactsPage extends StatelessWidget {
  const ContactsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contacts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              pushPage(context, const SearchScreen());
            },
          ),
          IconButton(
            icon: const Icon(Icons.person_add_alt_1),
            onPressed: () {},
          ),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.only(top: 8, bottom: 24),
        itemCount: demoContacts.length,
        separatorBuilder: (_, __) => const Divider(
          height: 1,
          thickness: 1,
          indent: 72,
          color: TgColors.separator,
        ),
        itemBuilder: (context, index) {
          final contact = demoContacts[index];

          return ListTile(
            leading: Avatar(
              title: contact.name,
              size: 52,
              start: contact.avatarStart,
              end: contact.avatarEnd,
            ),
            title: Text(
              contact.name,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(contact.status),
          );
        },
      ),
    );
  }
}

/*
============================================================
Settings
============================================================
*/

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  Widget _item({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    Color iconColor = TgColors.accent,
  }) {
    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle),
      trailing: const Icon(
        Icons.chevron_right,
        color: TgColors.textSecondary,
      ),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          InkWell(
            onTap: () {
              pushPage(
                context,
                const SimplePage(
                  title: 'Edit Profile',
                  icon: Icons.person_outline,
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Row(
                children: [
                  const Avatar(
                    title: 'Demo User',
                    size: 64,
                    start: TgColors.accent,
                    end: TgColors.active,
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Demo User',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          '+1 555 123 4567',
                          style: TextStyle(
                            fontSize: 14,
                            color: TgColors.textSecondary,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          '@demo_user',
                          style: TextStyle(
                            fontSize: 14,
                            color: TgColors.accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.edit, color: TgColors.accent),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          const SectionHeader(title: 'Telegram'),
          _item(
            icon: Icons.bookmark_border,
            title: 'Saved Messages',
            onTap: () {
              pushPage(
                context,
                const SimplePage(
                  title: 'Saved Messages',
                  icon: Icons.bookmark_border,
                ),
              );
            },
          ),
          _item(
            icon: Icons.archive,
            title: 'Archived Chats',
            subtitle: '12',
            onTap: () {
              pushPage(
                context,
                const SimplePage(
                  title: 'Archived Chats',
                  icon: Icons.archive,
                ),
              );
            },
          ),
          _item(
            icon: Icons.star_outline,
            title: 'Telegram Premium',
            onTap: () {
              pushPage(
                context,
                const SimplePage(
                  title: 'Telegram Premium',
                  icon: Icons.star_outline,
                ),
              );
            },
          ),
          _item(
            icon: Icons.person_add_alt_1,
            title: 'Invite Friends',
            onTap: () {
              pushPage(
                context,
                const SimplePage(
                  title: 'Invite Friends',
                  icon: Icons.person_add_alt_1,
                ),
              );
            },
          ),
          const SectionHeader(title: 'Settings'),
          _item(
            icon: Icons.notifications_none,
            title: 'Notifications and Sounds',
            onTap: () {
              pushPage(context, const NotificationsScreen());
            },
          ),
          _item(
            icon: Icons.lock_outline,
            title: 'Privacy and Security',
            onTap: () {
              pushPage(context, const PrivacyScreen());
            },
          ),
          _item(
            icon: Icons.data_usage,
            title: 'Data and Storage',
            onTap: () {
              pushPage(context, const DataStorageScreen());
            },
          ),
          _item(
            icon: Icons.palette,
            title: 'Appearance',
            onTap: () {
              pushPage(context, const AppearanceScreen());
            },
          ),
          _item(
            icon: Icons.language,
            title: 'Language',
            subtitle: 'English',
            onTap: () {
              pushPage(context, const LanguageScreen());
            },
          ),
          _item(
            icon: Icons.sticky_note_2,
            title: 'Stickers and Emoji',
            onTap: () {
              pushPage(context, const StickersScreen());
            },
          ),
          _item(
            icon: Icons.folder,
            title: 'Chat Folders',
            onTap: () {
              pushPage(context, const FoldersScreen());
            },
          ),
          _item(
            icon: Icons.devices,
            title: 'Devices',
            onTap: () {
              pushPage(context, const DevicesScreen());
            },
          ),
          _item(
            icon: Icons.help_outline,
            title: 'Telegram FAQ',
            onTap: () {
              pushPage(context, const HelpScreen());
            },
          ),
          const SectionHeader(title: 'Developer'),
          _item(
            icon: Icons.grid_view,
            title: 'All demo pages',
            subtitle: 'Catalog of remaining screens',
            onTap: () {
              pushPage(context, const PagesCatalogScreen());
            },
          ),
        ],
      ),
    );
  }
}

/*
============================================================
Settings subpages
============================================================
*/

class AppearanceScreen extends StatefulWidget {
  const AppearanceScreen({super.key});

  @override
  State<AppearanceScreen> createState() => _AppearanceScreenState();
}

class _AppearanceScreenState extends State<AppearanceScreen> {
  int theme = 0;
  int accent = 0;
  bool animatedStickers = true;
  bool autoNightMode = false;
  int chatMode = 1;

  final List<Color> accentColors = const [
    TgColors.accent,
    Colors.red,
    Colors.orange,
    Colors.green,
    Colors.teal,
    Colors.purple,
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Appearance')),
      body: ListView(
        children: [
          const SectionHeader(title: 'Theme'),
          RadioListTile<int>(
            value: 0,
            groupValue: theme,
            onChanged: (v) => setState(() => theme = v!),
            title: const Text('Light'),
            activeColor: TgColors.accent,
          ),
          RadioListTile<int>(
            value: 1,
            groupValue: theme,
            onChanged: (v) => setState(() => theme = v!),
            title: const Text('Dark'),
            activeColor: TgColors.accent,
          ),
          RadioListTile<int>(
            value: 2,
            groupValue: theme,
            onChanged: (v) => setState(() => theme = v!),
            title: const Text('System'),
            activeColor: TgColors.accent,
          ),
          const SectionHeader(title: 'Accent color'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: List.generate(accentColors.length, (index) {
                final selected = accent == index;
                return GestureDetector(
                  onTap: () => setState(() => accent = index),
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: accentColors[index],
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected ? Colors.black : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: selected
                        ? const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 20,
                          )
                        : null,
                  ),
                );
              }),
            ),
          ),
          const SectionHeader(title: 'Chat list'),
          RadioListTile<int>(
            value: 0,
            groupValue: chatMode,
            onChanged: (v) => setState(() => chatMode = v!),
            title: const Text('2-line'),
            activeColor: TgColors.accent,
          ),
          RadioListTile<int>(
            value: 1,
            groupValue: chatMode,
            onChanged: (v) => setState(() => chatMode = v!),
            title: const Text('3-line'),
            activeColor: TgColors.accent,
          ),
          RadioListTile<int>(
            value: 2,
            groupValue: chatMode,
            onChanged: (v) => setState(() => chatMode = v!),
            title: const Text('3-line big'),
            activeColor: TgColors.accent,
          ),
          const SectionHeader(title: 'Other'),
          SwitchListTile(
            value: animatedStickers,
            onChanged: (v) => setState(() => animatedStickers = v),
            title: const Text('Animated Stickers'),
            activeColor: TgColors.accent,
          ),
          SwitchListTile(
            value: autoNightMode,
            onChanged: (v) => setState(() => autoNightMode = v),
            title: const Text('Auto Night Mode'),
            subtitle: const Text('Based on light sensor'),
            activeColor: TgColors.accent,
          ),
        ],
      ),
    );
  }
}

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  Widget _item(BuildContext context, String title, IconData icon) {
    return ListTile(
      leading: Icon(icon, color: TgColors.accent),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        pushPage(
          context,
          SimplePage(title: title, icon: icon),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy and Security')),
      body: ListView(
        children: [
          const SectionHeader(title: 'Privacy'),
          _item(context, 'Phone Number', Icons.phone),
          _item(context, 'Last Seen & Online', Icons.access_time),
          _item(context, 'Profile Photo', Icons.person_outline),
          _item(context, 'Calls', Icons.call),
          _item(context, 'Groups & Channels', Icons.group),
          _item(context, 'Messages', Icons.message),
          const SectionHeader(title: 'Security'),
          _item(context, 'Passcode Lock', Icons.lock_outline),
          _item(context, 'Two-Step Verification', Icons.security),
          _item(context, 'Active Sessions', Icons.devices),
          _item(context, 'Blocked Users', Icons.block),
        ],
      ),
    );
  }
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool privateChats = true;
  bool groups = true;
  bool channels = false;
  bool showPreview = true;
  bool inAppSounds = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications and Sounds')),
      body: ListView(
        children: [
          const SectionHeader(title: 'Chats'),
          SwitchListTile(
            value: privateChats,
            onChanged: (v) => setState(() => privateChats = v),
            title: const Text('Private Chats'),
            activeColor: TgColors.accent,
          ),
          SwitchListTile(
            value: groups,
            onChanged: (v) => setState(() => groups = v),
            title: const Text('Groups'),
            activeColor: TgColors.accent,
          ),
          SwitchListTile(
            value: channels,
            onChanged: (v) => setState(() => channels = v),
            title: const Text('Channels'),
            activeColor: TgColors.accent,
          ),
          const SectionHeader(title: 'Message notifications'),
          SwitchListTile(
            value: showPreview,
            onChanged: (v) => setState(() => showPreview = v),
            title: const Text('Message Preview'),
            activeColor: TgColors.accent,
          ),
          SwitchListTile(
            value: inAppSounds,
            onChanged: (v) => setState(() => inAppSounds = v),
            title: const Text('In-App Sounds'),
            activeColor: TgColors.accent,
          ),
        ],
      ),
    );
  }
}

class DataStorageScreen extends StatefulWidget {
  const DataStorageScreen({super.key});

  @override
  State<DataStorageScreen> createState() => _DataStorageScreenState();
}

class _DataStorageScreenState extends State<DataStorageScreen> {
  bool autoplayGif = true;
  bool autoplayVideo = false;
  bool saveToGallery = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Data and Storage')),
      body: ListView(
        children: [
          const SectionHeader(title: 'Storage'),
          ListTile(
            leading: const Icon(Icons.storage, color: TgColors.accent),
            title: const Text('Storage Usage'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              pushPage(
                context,
                const SimplePage(
                  title: 'Storage Usage',
                  icon: Icons.storage,
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.cloud_upload, color: TgColors.accent),
            title: const Text('Auto-Download Media'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              pushPage(
                context,
                const SimplePage(
                  title: 'Auto-Download Media',
                  icon: Icons.cloud_download,
                ),
              );
            },
          ),
          const SectionHeader(title: 'Autoplay'),
          SwitchListTile(
            value: autoplayGif,
            onChanged: (v) => setState(() => autoplayGif = v),
            title: const Text('GIF'),
            activeColor: TgColors.accent,
          ),
          SwitchListTile(
            value: autoplayVideo,
            onChanged: (v) => setState(() => autoplayVideo = v),
            title: const Text('Video'),
            activeColor: TgColors.accent,
          ),
          const SectionHeader(title: 'Other'),
          SwitchListTile(
            value: saveToGallery,
            onChanged: (v) => setState(() => saveToGallery = v),
            title: const Text('Save to Gallery'),
            activeColor: TgColors.accent,
          ),
          ListTile(
            leading: const Icon(Icons.vpn_key, color: TgColors.accent),
            title: const Text('Proxy'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              pushPage(
                context,
                const SimplePage(
                  title: 'Proxy',
                  icon: Icons.vpn_key,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class FoldersScreen extends StatelessWidget {
  const FoldersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chat Folders')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: TgColors.accent,
        onPressed: () {},
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Create Folder',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: ListView(
        children: const [
          ListTile(
            leading: Icon(Icons.folder, color: TgColors.accent),
            title: Text('All'),
            subtitle: Text('Automatically includes all chats'),
          ),
          ListTile(
            leading: Icon(Icons.folder, color: TgColors.accent),
            title: Text('Unread'),
            subtitle: Text('Chats with unread messages'),
          ),
          ListTile(
            leading: Icon(Icons.folder, color: TgColors.accent),
            title: Text('Personal'),
            subtitle: Text('Contacts and private chats'),
          ),
          ListTile(
            leading: Icon(Icons.folder, color: TgColors.accent),
            title: Text('Channels'),
            subtitle: Text('Channels only'),
          ),
        ],
      ),
    );
  }
}

class LanguageScreen extends StatefulWidget {
  const LanguageScreen({super.key});

  @override
  State<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends State<LanguageScreen> {
  int selected = 0;

  final languages = const [
    'English',
    'فارسی',
    'Русский',
    'Deutsch',
    'Español',
    'Français',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Language')),
      body: ListView(
        children: List.generate(languages.length, (index) {
          return RadioListTile<int>(
            value: index,
            groupValue: selected,
            onChanged: (v) => setState(() => selected = v!),
            title: Text(languages[index]),
            activeColor: TgColors.accent,
          );
        }),
      ),
    );
  }
}

class StickersScreen extends StatelessWidget {
  const StickersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Stickers and Emoji')),
      body: ListView(
        children: const [
          ListTile(
            leading: Icon(Icons.star, color: TgColors.accent),
            title: Text('Trending'),
            trailing: Icon(Icons.chevron_right),
          ),
          ListTile(
            leading: Icon(Icons.sticky_note_2, color: TgColors.accent),
            title: Text('Animals'),
            subtitle: Text('48 stickers'),
            trailing: Switch(value: true, onChanged: null),
          ),
          ListTile(
            leading: Icon(Icons.sticky_note_2, color: TgColors.accent),
            title: Text('Technology'),
            subtitle: Text('32 stickers'),
            trailing: Switch(value: false, onChanged: null),
          ),
        ],
      ),
    );
  }
}

class DevicesScreen extends StatelessWidget {
  const DevicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Devices')),
      body: ListView(
        children: const [
          ListTile(
            leading: Icon(Icons.smartphone, color: TgColors.accent),
            title: Text('Current device'),
            subtitle: Text('Pixel 9 · Android 15'),
          ),
          Divider(height: 1),
          SectionHeader(title: 'Other sessions'),
          ListTile(
            leading: Icon(Icons.computer, color: TgColors.textSecondary),
            title: Text('Windows Desktop'),
            subtitle: Text('Last active: 2 hours ago'),
            trailing: Icon(Icons.close, color: TgColors.red),
          ),
          ListTile(
            leading: Icon(Icons.tablet, color: TgColors.textSecondary),
            title: Text('iPad'),
            subtitle: Text('Last active: yesterday'),
            trailing: Icon(Icons.close, color: TgColors.red),
          ),
        ],
      ),
    );
  }
}

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Telegram FAQ')),
      body: ListView(
        children: const [
          ListTile(
            leading: Icon(Icons.question_answer, color: TgColors.accent),
            title: Text('Ask a Question'),
          ),
          ListTile(
            leading: Icon(Icons.article, color: TgColors.accent),
            title: Text('Telegram FAQ'),
          ),
          ListTile(
            leading: Icon(Icons.privacy_tip, color: TgColors.accent),
            title: Text('Privacy Policy'),
          ),
          ListTile(
            leading: Icon(Icons.info_outline, color: TgColors.accent),
            title: Text('About'),
          ),
        ],
      ),
    );
  }
}

/*
============================================================
Search
============================================================
*/

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _controller,
          autofocus: true,
          style: const TextStyle(fontSize: 17),
          decoration: const InputDecoration.collapsed(
            hintText: 'Search',
            hintStyle: TextStyle(color: TgColors.textSecondary),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () {
              _controller.clear();
            },
          ),
        ],
      ),
      body: ListView(
        children: [
          const SectionHeader(title: 'Recent'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: const [
                Chip(label: Text('flutter')),
                Chip(label: Text('telegram')),
                Chip(label: Text('design')),
                Chip(label: Text('ui')),
              ],
            ),
          ),
          const SectionHeader(title: 'Global search'),
          ...demoChats.take(4).map(
                (chat) => ListTile(
                  leading: Avatar(
                    title: chat.title,
                    icon: chat.avatarIcon,
                    size: 48,
                    start: chat.avatarStart,
                    end: chat.avatarEnd,
                  ),
                  title: Text(
                    chat.title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(chat.message),
                  onTap: () {
                    pushPage(context, ChatScreen(chat: chat));
                  },
                ),
              ),
        ],
      ),
    );
  }
}

/*
============================================================
Auth / Intro
============================================================
*/

class IntroScreen extends StatelessWidget {
  const IntroScreen({super.key});

  Widget _page(IconData icon, String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 96, color: TgColors.accent),
          const SizedBox(height: 24),
          Text(
            title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                color: TgColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                children: [
                  _page(
                    Icons.chat_bubble_outline,
                    'Telegram X',
                    'Fast, secure and beautiful messaging experience.',
                  ),
                  _page(
                    Icons.cloud_outlined,
                    'Cloud Sync',
                    'Access your messages from all your devices.',
                  ),
                  _page(
                    Icons.security,
                    'Privacy',
                    'Private chats, secret chats and advanced controls.',
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: TgColors.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    pushPage(context, const PhoneScreen());
                  },
                  child: const Text(
                    'Start Messaging',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PhoneScreen extends StatelessWidget {
  const PhoneScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Your phone')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Please choose your country and enter your full phone number.',
              style: TextStyle(
                fontSize: 15,
                color: TgColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            const TextField(
              decoration: InputDecoration(
                labelText: 'Country',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            const TextField(
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Phone number',
                border: OutlineInputBorder(),
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: TgColors.accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  pushPage(context, const CodeScreen());
                },
                child: const Text('Next'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CodeScreen extends StatelessWidget {
  const CodeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Enter code')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Text(
              'We have sent an SMS with the confirmation code to your phone.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: TgColors.textSecondary,
              ),
            ),
            const SizedBox(height: 32),
            const TextField(
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 28,
                letterSpacing: 8,
              ),
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                hintText: '12345',
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: TgColors.accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  pushPage(context, const TwoFactorScreen());
                },
                child: const Text('Next'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TwoFactorScreen extends StatelessWidget {
  const TwoFactorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Two-step verification')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Text(
              'This account is protected by an additional password.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: TgColors.textSecondary,
              ),
            ),
            const SizedBox(height: 32),
            const TextField(
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: TgColors.accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  pushPage(context, const HomeShell());
                },
                child: const Text('Sign In'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/*
============================================================
Camera
============================================================
*/

class CameraScreen extends StatelessWidget {
  const CameraScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Icon(Icons.flash_on, color: Colors.white),
          ),
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Icon(Icons.settings, color: Colors.white),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              color: Colors.black,
              child: const Center(
                child: Icon(
                  Icons.camera_alt,
                  size: 96,
                  color: Colors.white24,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.white24,
                  ),
                  child: const Icon(Icons.photo, color: Colors.white),
                ),
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 5),
                  ),
                  child: Container(
                    margin: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                  ),
                ),
                Container(
                  width: 52,
                  height: 52,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white24,
                  ),
                  child: const Icon(Icons.cameraswitch, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/*
============================================================
Pages catalog
============================================================
*/

class PagesCatalogScreen extends StatelessWidget {
  const PagesCatalogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final items = <MapEntry<String, WidgetBuilder>>[
      MapEntry('Intro', (_) => const IntroScreen()),
      MapEntry('Phone', (_) => const PhoneScreen()),
      MapEntry('Code', (_) => const CodeScreen()),
      MapEntry('Two-Step Verification', (_) => const TwoFactorScreen()),
      MapEntry('Chat', (_) => ChatScreen(chat: demoChats[1])),
      MapEntry('Profile', (_) => ProfileScreen(chat: demoChats[1])),
      MapEntry('Search', (_) => const SearchScreen()),
      MapEntry('Call', (_) => const CallScreen(name: 'Ali Rezaei')),
      MapEntry('Camera', (_) => const CameraScreen()),
      MapEntry(
        'Photo Editor',
        (_) => const SimplePage(title: 'Photo Editor', icon: Icons.edit),
      ),
      MapEntry(
        'Instant View',
        (_) => const SimplePage(title: 'Instant View', icon: Icons.article),
      ),
      MapEntry(
        'Location',
        (_) => const SimplePage(title: 'Location', icon: Icons.location_on),
      ),
      MapEntry(
        'Payment',
        (_) => const SimplePage(title: 'Payment', icon: Icons.payment),
      ),
      MapEntry(
        'Poll',
        (_) => const SimplePage(title: 'Poll', icon: Icons.poll),
      ),
      MapEntry(
        'Bot Start',
        (_) => const SimplePage(title: 'Bot Start', icon: Icons.smart_toy),
      ),
      MapEntry(
        'Join Requests',
        (_) => const SimplePage(title: 'Join Requests', icon: Icons.group_add),
      ),
      MapEntry(
        'Hashtag',
        (_) => const SimplePage(title: 'Hashtag', icon: Icons.tag),
      ),
      MapEntry(
        'Wallpaper',
        (_) => const SimplePage(title: 'Wallpaper', icon: Icons.wallpaper),
      ),
      MapEntry(
        'Passcode',
        (_) => const SimplePage(title: 'Passcode', icon: Icons.lock_outline),
      ),
      MapEntry(
        'Archived Chats',
        (_) => const SimplePage(title: 'Archived Chats', icon: Icons.archive),
      ),
      MapEntry(
        'Blocked Users',
        (_) => const SimplePage(title: 'Blocked Users', icon: Icons.block),
      ),
      MapEntry(
        'Proxy',
        (_) => const SimplePage(title: 'Proxy', icon: Icons.vpn_key),
      ),
      MapEntry(
        'Storage Usage',
        (_) => const SimplePage(title: 'Storage Usage', icon: Icons.storage),
      ),
      MapEntry(
        'Auto-download',
        (_) => const SimplePage(title: 'Auto-download', icon: Icons.cloud_download),
      ),
      MapEntry(
        'Exceptions',
        (_) => const SimplePage(title: 'Exceptions', icon: Icons.rule),
      ),
      MapEntry(
        'Edit Profile',
        (_) => const SimplePage(title: 'Edit Profile', icon: Icons.person_outline),
      ),
      MapEntry(
        'Username',
        (_) => const SimplePage(title: 'Username', icon: Icons.alternate_email),
      ),
      MapEntry(
        'Bio',
        (_) => const SimplePage(title: 'Bio', icon: Icons.info_outline),
      ),
      MapEntry(
        'Phone Number',
        (_) => const SimplePage(title: 'Phone Number', icon: Icons.phone),
      ),
      MapEntry(
        'Add Account',
        (_) => const SimplePage(title: 'Add Account', icon: Icons.person_add_alt_1),
      ),
      MapEntry(
        'QR',
        (_) => const SimplePage(title: 'QR', icon: Icons.qr_code),
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('All demo pages')),
      body: ListView.separated(
        itemCount: items.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final item = items[index];
          return ListTile(
            title: Text(item.key),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: item.value),
              );
            },
          );
        },
      ),
    );
  }
}