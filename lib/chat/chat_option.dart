import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:qr_scanner_app/chat/chat_api_service.dart';
import 'package:qr_scanner_app/chat/chat_manager.dart';
import 'package:qr_scanner_app/constants/colors.dart';
import 'package:qr_scanner_app/constants/strings.dart';

class ChatOptionScreen extends StatefulWidget {
  const ChatOptionScreen({super.key});

  @override
  _ChatOptionScreenState createState() => _ChatOptionScreenState();
}

class _ChatOptionScreenState extends State<ChatOptionScreen> {
  late ChatManager chatManager;
  late ChatApiService chatApiService;

  @override
  void initState() {
    super.initState();
    chatManager = ChatManager();
    chatApiService = ChatApiService(Strings.baseUrl);
    _initializeChat();
  }

  void _initializeChat() {
    setState(() {
      chatManager.chatMessages = [
        {
          'sender': 'bot',
          'message':
              "Hello! I'm Anica, your friendly Antimicrobial Stewardship assistant. How can I help?",
        }
      ];
      chatManager.dynamicOptions = chatManager.staticOptions;
      chatManager.showDynamicOptions = true;
      chatManager.isInitialResponse = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pushReplacementNamed(context, '/home');
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: primaryColor,
          leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.pushReplacementNamed(context, '/home'),
          ),
          title: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "ANICA - Antimicrobial Stewardship and",
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500),
              ),
              SizedBox(height: 6),
              Text(
                "Information for Clinical Assistance",
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
            ],
          ),
          elevation: 0,
          toolbarHeight: 66,
        ),
        body: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  ...chatManager.chatMessages.map((message) {
                    final isSender = message['sender'] == 'user';
                    return Column(
                      crossAxisAlignment: isSender
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                      children: [
                        _buildChatMessage(
                          context: context,
                          isSender: isSender,
                          profilePic: "assets/images/chat.png",
                          message: message['message'],
                        ),
                        const SizedBox(height: 8),
                        if (!isSender &&
                            message == chatManager.chatMessages.last &&
                            chatManager.showDynamicOptions) ...[
                          const SizedBox(height: 1),
                          Padding(
                            padding: const EdgeInsets.only(left: 56.0),
                            child: _buildOptionsLayout(),
                          ),
                        ],
                      ],
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionsLayout() {
    bool isYesNo = chatManager.dynamicOptions.length >= 2 &&
        chatManager.dynamicOptions.contains("Yes") &&
        chatManager.dynamicOptions.contains("No");

    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.7,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: isYesNo
            ? [
                Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: SizedBox(
                        width: 100,
                        child: _buildOptionButton("Yes"),
                      ),
                    ),
                    SizedBox(
                      width: 100,
                      child: _buildOptionButton("No"),
                    ),
                  ],
                ),
                ...chatManager.dynamicOptions
                    .where((option) => option != "Yes" && option != "No")
                    .map((option) => _buildOptionButton(option)),
              ]
            : chatManager.dynamicOptions
                .map((option) => _buildOptionButton(option))
                .toList(),
      ),
    );
  }

  Widget _buildOptionButton(String option) {
    bool isYesNoOption = option == "Yes" || option == "No";

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.0),
      child: ElevatedButton(
        onPressed: () =>
            chatManager.handleOptionSelection(option, setState, chatApiService),
        style: ElevatedButton.styleFrom(
          backgroundColor: chatManager.navigationOptions.contains(option)
              ? Colors.grey[200]
              : Colors.pink[50],
          padding: const EdgeInsets.symmetric(
            horizontal: 20.0,
            vertical: 8.0,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10.0),
            side: BorderSide(
              color: chatManager.navigationOptions.contains(option)
                  ? Colors.grey[300]!
                  : Colors.pink[100]!,
            ),
          ),
        ),
        child: Text(
          option,
          style: TextStyle(
            fontSize: 14,
            color: chatManager.navigationOptions.contains(option)
                ? Colors.black
                : Colors.pink,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildChatMessage({
    required BuildContext context,
    required bool isSender,
    required String profilePic,
    required dynamic message,
  }) {
    return Align(
      alignment: isSender ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isSender) ...[
              CircleAvatar(
                backgroundImage: AssetImage(profilePic),
                radius: 18,
              ),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Container(
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: isSender ? Colors.blue[50] : Colors.white,
                  border: Border.all(
                    color: isSender ? Colors.blue : Colors.pink.shade100,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: message is Html
                    ? message
                    : Text(
                        message,
                        style: TextStyle(
                          fontSize: 14,
                          color: isSender ? Colors.blue.shade900 : Colors.black,
                          fontWeight:
                              isSender ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
              ),
            ),
            if (isSender) const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}
