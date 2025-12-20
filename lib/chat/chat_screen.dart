import 'package:flutter/material.dart';

import 'package:qr_scanner_app/chat/chat_service.dart';
import 'package:qr_scanner_app/constants/colors.dart';
import 'package:qr_scanner_app/models/chat_message.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late Future<ChatResponse> chatResponse;
  final TextEditingController _messageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Initialize chat messages by calling the API
    chatResponse = ChatService().fetchChatMessages(page: 1, sortOrder: 'asc');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: primaryColor,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () {
            Navigator.pop(context); // Close the screen
          },
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "ALICE-Antimicrobial Leadership",
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 6),
            Text(
              "Initiative & Care Expert",
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
          ],
        ),
        elevation: 0,
        toolbarHeight: 66,
      ),
      body: FutureBuilder<ChatResponse>(
        future: chatResponse,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.total == 0) {
            return const Center(child: Text('No chat messages available.'));
          }

          final chatMessages = snapshot.data!.data;

          return Column(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ListView.builder(
                    itemCount: chatMessages.length,
                    itemBuilder: (context, index) {
                      final chatData = chatMessages[index];
                      return _buildChatMessage(
                        context: context,
                        isSender: false,
                        profilePic: "assets/images/chat.png",
                        message: chatData.name, // Displaying the chat message
                        options:
                            chatData.children, // Handling options if available
                        yesNoButtons: chatData.status ==
                            'pending', // Example for handling Yes/No buttons
                      );
                    },
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _messageController, // Set the controller
                          decoration: InputDecoration(
                            hintText: "Message",
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.send, color: primaryColor),
                              onPressed: () {
                                _sendMessage(); // Call the send message function
                              },
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _sendMessage() async {
    String message = _messageController.text.trim();
    if (message.isNotEmpty) {
      // Here you can call your API to send the message
      // For example, you might want to call a method in ChatService to send the message
      // await ChatService().sendMessage(message); // Assuming sendMessage is a method in ChatService

      // Clear the input field after sending the message
      _messageController.clear();

      // Optionally, you can refresh the chat messages
      setState(() {
        chatResponse = ChatService().fetchChatMessages(
            page: 1, sortOrder: 'asc'); // Refresh chat messages
      });
    }
  }

  Widget _buildChatMessage({
    required BuildContext context,
    required bool isSender,
    required String profilePic,
    required String message,
    List<String>? options,
    bool yesNoButtons = false,
  }) {
    return Align(
      alignment: isSender ? Alignment.centerRight : Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: 0.5, // Set width to half of the screen
        child: Column(
          crossAxisAlignment:
              isSender ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isSender)
              CircleAvatar(
                backgroundImage: AssetImage(profilePic),
                radius: 18,
              ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: isSender ? Colors.blue[50] : Colors.white,
                border: Border.all(
                  color: isSender ? Colors.transparent : Colors.pink.shade100,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black,
                ),
              ),
            ),
            if (options != null)
              Column(
                children: options.map((option) {
                  return Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.pink[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      option,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.pink,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                }).toList(),
              ),
            if (yesNoButtons)
              Row(
                mainAxisAlignment:
                    isSender ? MainAxisAlignment.end : MainAxisAlignment.start,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      // Yes button action
                    },
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.pink[50]),
                    child: const Text(
                      "Yes",
                      style: TextStyle(color: Colors.pink),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      // No button action
                    },
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.pink[50]),
                    child: const Text(
                      "No",
                      style: TextStyle(color: Colors.pink),
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
