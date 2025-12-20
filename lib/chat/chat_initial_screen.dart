import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:qr_scanner_app/constants/colors.dart';
import 'package:qr_scanner_app/constants/strings.dart';
import 'package:qr_scanner_app/keycloak/api_client.dart';
import 'package:qr_scanner_app/models/antibiogram_data.dart';
import 'package:qr_scanner_app/models/antibiotic.dart';
import 'package:qr_scanner_app/models/helpful_context.dart';
import 'package:qr_scanner_app/models/reasons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:collection/collection.dart';

import '../utilities/utilities.dart';

class ChatInitialScreen extends StatefulWidget {
  const ChatInitialScreen({super.key});

  @override
  ChatInitialScreenState createState() => ChatInitialScreenState();
}

class ChatInitialScreenState extends State<ChatInitialScreen> {
  String? selectedAntibioticId;
  Category? selectedCategoryId;
  String? selectedSubCategory;
  String? selectedType;
  List<ChatMessage> chatMessages = [];
  List<ChatItem> antibioticChat = [];

  List<ChatItem> staticOptions = [];
  List<ChatItem> dynamicOptions = [];
  bool showDynamicOptions = false;
  List<ChatItem> fetchedReasons = [];
  bool isFinalYesNo = false;
  List<Map<String, dynamic>> chatHistory = [];
  bool isInitialResponse = true;
  bool isSecondResponse = false;
  final TextEditingController _textSearchController = TextEditingController();
  final TextEditingController _textPrescribedController =
      TextEditingController();
  final TextEditingController _textSpecifyController = TextEditingController();
  bool showTextField = false;
  bool reasonTextFieldLabel = false;
  bool specifyNoTextFieldLabel = false;

  Map<String, dynamic>? _pendingLineContext;

  String? othersReasonId;

  Map<String, String> reasonIdMap = {};
  ChatItem yesChatItem = ChatItem(id: "0", name: "Yes");
  ChatItem noChatItem = ChatItem(id: "1", name: "No");
  ChatItem mainMenuChatItem = ChatItem(id: "2", name: "Main Menu");
  ChatItem goBackChatItem = ChatItem(id: "3", name: "Go Back");
  ChatItem antibioticChatItem = ChatItem(id: "4", name: "Antibiotic Policy");
  // ChatItem antibiogramChatItem = ChatItem(id: "5", name: "Antibiogram");
  bool isConnected = true;
  List<ChatItem> navigationOptions = [];

  late ChatItem mainOptionSelected = antibioticChatItem;

  final ScrollController _scrollController = ScrollController();

  HelpfulContext? _pendingHelpfulContext;

  List<String> selectedLineItemIds = [];
  String? selectedLineType; // <-- track line type globally
  String? _pendingReasonId;

  String? _currentReasonCategory;
  bool _isComplianceNoFlow = false;

  String? _prescribedDrugs; // to store the entered prescribed drugs
  bool _isOtherDrugsFlow =
      false; // to indicate that we are now in the other_drugs reason selection

  String? otherDrugsMessage;

  String? _pendingOtherDrugsMessage;

  String? _prescribedMessage;
  String? _prescribedReasonId;

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    // staticOptions.addAll([antibioticChatItem, antibiogramChatItem]);
    staticOptions.addAll([antibioticChatItem]);
    navigationOptions.addAll([goBackChatItem, mainMenuChatItem]);
    _initializeChat();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _checkConnectivity() async {
    var connectivityResult = await (Connectivity().checkConnectivity());
    setState(() {
      isConnected = connectivityResult != ConnectivityResult.none;
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _handleOptionSelection(ChatItem option) async {
    // Manage initial and second response states
    if (isInitialResponse) {
      isInitialResponse = false;
      if (option.name == "Antibiotic Policy") {
        isSecondResponse = true;
        mainOptionSelected = antibioticChatItem;
      }
      // else if (option.name == "Antibiogram") {
      //   isSecondResponse = true;
      //   mainOptionSelected = antibiogramChatItem;
      // }
    } else {
      isSecondResponse = false;
    }

    // Handle navigation options
    if (_handleNavigationOptions(option)) return;

    // Save current state before updating
    if (!navigationOptions.contains(option)) {
      _saveCurrentState();
    }

    // Add user message to chat
    _addUserMessage(option);

    // ✅ Check if last bot message was "helpful"
    final lastBotMessage = chatMessages.lastWhere(
      (msg) => msg.sender == 'bot',
      orElse: () =>
          ChatMessage(sender: '', chatItem: ChatItem(id: '', name: '')),
    );

    if (lastBotMessage.chatItem.id == "helpful") {
      if (option.name == "Yes") {
        await _handleHelpfulYes(option);
        return;
      } else if (option.name == "No") {
        await _handleHelpfulNo(option);
        return;
      }
    }

    print("Option---$option");
    // Handle main options
    switch (option.name) {
      case "Antibiotic Policy":
        await _handleAntibioticPolicy();
        break;

      case "Antibiogram":
        await _handleAntibiogram();
        break;

      case "Yes":
        await _handleYesResponse(option);
        break;

      case "No":
        await _handleNoResponse();
        break;

      default:
        if (option.isReason) {
          _handleReasonSubmission(option);
        } else {
          await _handleOtherOptions(option);
        }
        break;
    }
  }

  bool showLineItems = false;
  List<Antibiotic> lineItems = [];
  // Set<String> selectedLineItemIds = {};

  _handleYesResponse(ChatItem option, {bool? compiled = true}) async {
    List<Antibiotic> fetchedLineItems =
        await _fetchLineItems(selectedAntibioticId!);

    setState(() {
      if (fetchedLineItems.isNotEmpty) {
        lineItems = fetchedLineItems;
        showLineItems = true;
        // Add bot message and navigation options

        // ✅ Clear previous selections when showing line items
        selectedLineItemIds.clear();
        noAbxSelected = false;
        selectedGroup = null;
        chatMessages.addAll([
          ChatMessage(
            sender: 'bot',
            chatItem: ChatItem(
              id: 'line_items',
              name: 'Choose drugs:',
            ),
          ),
        ]);
        // Set navigation options
        dynamicOptions = [goBackChatItem, mainMenuChatItem];
        showDynamicOptions = true;
      } else {
        chatMessages.add(ChatMessage(
          sender: 'bot',
          chatItem: ChatItem(
            id: 'no_line_items',
            name: 'No line items available for this policy.',
          ),
        ));
        dynamicOptions = [mainMenuChatItem];
        showDynamicOptions = true;
      }
    });
    _scrollToBottom();
    debugPrint("Compiled flag in YesResponse: $compiled");
  }

  Future<List<Antibiotic>> _fetchLineItems(String antibioticId) async {
    final baseUrl = Strings.baseUrl;
    final prefs = await SharedPreferences.getInstance();
    String siteId = prefs.getString('site_id') ?? '';

    try {
      final response =
          await ApiClient(baseUrl: baseUrl).get('antibiotics?site_id=$siteId');
      debugPrint("antibiotic response _fetchLineItems -- ${response.body}");

      final utf8Body = utf8.decode(response.bodyBytes);

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(utf8Body);
        // final Map<String, dynamic> responseData = json.decode(response.body);
        if (responseData.containsKey('data')) {
          List<dynamic> data = responseData['data'];
          final antibiotics =
              data.map((json) => Antibiotic.fromJson(json)).toList();

          debugPrint("🔎 Filtering for antibioticId (policy): $antibioticId");

          for (var abx in antibiotics) {
            debugPrint("💊 DB Antibiotic: id=${abx.antibioticId}, "
                "name=${abx.name}, type=${abx.type}, "
                "parent=${abx.parent}");
          }

          // 1️⃣ Find the selected policy
          final policy = antibiotics.firstWhereOrNull(
            (a) => a.antibioticId == antibioticId,
          );

          List<Antibiotic> policyAntibiotics = [];
          if (policy != null) {
            // 2️⃣ Get only children of this policy (by parent)
            policyAntibiotics = antibiotics
                .where((a) => a.parent == policy.antibioticId)
                .toList();
          }

          // 3️⃣ Group into lines
          final line1 =
              policyAntibiotics.where((a) => a.type == "line_1").toList();
          final line2 =
              policyAntibiotics.where((a) => a.type == "line_2").toList();
          final line3 =
              policyAntibiotics.where((a) => a.type == "line_3").toList();

          debugPrint("📂 Line 1 count: ${line1.length}");
          line1.forEach(
              (a) => debugPrint("Line1 -> ${a.antibioticId} - ${a.name}"));

          debugPrint("📂 Line 2 count: ${line2.length}");
          line2.forEach(
              (a) => debugPrint("Line2 -> ${a.antibioticId} - ${a.name}"));

          debugPrint("📂 Line 3 count: ${line3.length}");
          line3.forEach(
              (a) => debugPrint("Line3 -> ${a.antibioticId} - ${a.name}"));

          // ✅ Return merged list so UI works as before
          return [...line1, ...line2, ...line3];
        } else {
          debugPrint('❌ No "data" key in response');
          return [];
        }
      } else if (response.statusCode == 401) {
        Fluttertoast.showToast(
            msg: 'Account Disabled. Please contact support.');
        await unregisterDeviceFromPushNotificationServer();
        if (mounted) navigateToLoginScreen(context);
        return [];
      } else {
        debugPrint('❌ Failed to fetch line items: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      debugPrint('❌ Error fetching line items: $e');
      return [];
    }
  }

  String? selectedGroup; // Track which line group is active
  // Set<String> selectedLineItemIds = {}; // Track selected items
  // final selectedLineItemIds = <String>{};
  void _toggleLineItemSelection(String group, String id) {
    setState(() {
      // Handle "No Abx" selection
      if (id == "no_abx") {
        if (noAbxSelected) {
          // If already selected, uncheck it
          noAbxSelected = false;
          selectedGroup = null;
        } else {
          // Select "No Abx" and clear everything else
          noAbxSelected = true;
          selectedLineItemIds.clear();
          selectedGroup = "no_abx";
        }
      } else {
        // Handle antibiotic selection

        // If "No Abx" is selected, uncheck it first
        if (noAbxSelected) {
          noAbxSelected = false;
        }

        // If selecting from a different group, clear previous selections
        if (selectedGroup != null &&
            selectedGroup != group &&
            selectedGroup != "no_abx") {
          selectedLineItemIds.clear();
        }

        // Toggle the selected item
        if (selectedLineItemIds.contains(id)) {
          // Item is already selected, remove it
          selectedLineItemIds.remove(id);

          // If no items left, clear the selected group
          if (selectedLineItemIds.isEmpty) {
            selectedGroup = null;
          }
        } else {
          // Add the item to selection
          selectedLineItemIds.add(id);
          selectedGroup = group;
        }
      }
    });
  }

  void _submitLineItems() async {
    // Check if nothing is selected
    if (selectedLineItemIds.isEmpty && !noAbxSelected) {
      // Show toast message without hiding the selection UI
      Fluttertoast.showToast(
        msg: "Please select from the given list",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.black,
        textColor: Colors.white,
        fontSize: 16.0,
      );
      return; // Exit early without hiding the selection UI
    }

    // Capture selected items BEFORE setState
    final selectedItems = lineItems
        .where((item) => selectedLineItemIds.contains(item.antibioticId))
        .toList();

    // Update UI and chat messages
    setState(() {
      if (noAbxSelected) {
        chatMessages.add(ChatMessage(
          sender: 'user',
          chatItem: ChatItem(
            id: 'no_abx_selected',
            name: 'Selected: No Abx as recommended in the policy',
          ),
        ));
      } else if (selectedItems.isNotEmpty) {
        String selectedNames =
            selectedItems.map((item) => item.name).join(', ');
        chatMessages.add(ChatMessage(
          sender: 'user',
          chatItem: ChatItem(
            id: 'selected_items',
            name: 'Selected: $selectedNames',
          ),
        ));
      }

      // Reset selection UI only when valid selection is made
      showLineItems = false;
      selectedLineItemIds.clear();
    });

    // Logic based on line type
    if (noAbxSelected) {
      // ✅ Only helpful options, no thank you or main menu
      _showHelpfulOptions(
        ChatItem(
          id: 'no_abx',
          name: 'No Abx selected',
        ),
        "",
        antibioticId: selectedAntibioticId,
        complied: true, // ✅ force true
        source: "user_flow",
      );
    } else if (selectedItems.isNotEmpty) {
      bool hasLine1 = selectedItems.any((item) => item.type == 'line_1');
      bool hasLine2Or3 = selectedItems
          .any((item) => item.type == 'line_2' || item.type == 'line_3');

      if (hasLine1) {
        // ✅ Only helpful options, no thank you or main menu
        _showHelpfulOptions(
          ChatItem(id: 'line1_selected', name: 'Line 1 item selected'),
          "",
          antibioticId: selectedAntibioticId,
          lineItemIds: selectedItems.map((e) => e.antibioticId).toList(),
          complied: true,
          lineType: "line_1",
          source: "user_flow",
        );
      }

      if (hasLine2Or3) {
        final line2or3Items = selectedItems
            .where((item) => item.type == 'line_2' || item.type == 'line_3')
            .toList();

        // Show reason popup instead of thank you
        setState(() {
          chatMessages.add(ChatMessage(
            sender: 'bot',
            chatItem: ChatItem(
              id: 'reason',
              name: 'Please provide the reason:',
            ),
          ));
        });

        // ✅ Store line context for later use in reason selection
        _pendingLineContext = {
          "antibioticId": selectedAntibioticId,
          "lineItemIds": line2or3Items.map((e) => e.antibioticId).toList(),
          "lineTypes": line2or3Items.map((e) => e.type).toSet().toList(),
          "complied": true,
          "source": "user_flow",
        };

        // Fetch and show reasons
        await _fetchReasonsFromApi(category: "compliance_yes", complied: true);
        _addNavigationOptions();
        _scrollToBottom();
      }
    }
  }

  _handleNoResponse({bool? compiled}) async {
    setState(() {
      chatMessages.add(ChatMessage(
          sender: 'bot',
          chatItem:
              ChatItem(id: 'reason', name: 'Please provide the reason:')));
      _isComplianceNoFlow = true;
      _isOtherDrugsFlow = false; // ✅ Reset other_drugs flow flag
      _pendingOtherDrugsMessage = null;
      _prescribedReasonId = null;
    });
    await _fetchReasonsFromApi(category: "compliance_no", complied: false);
    _addNavigationOptions();
    _scrollToBottom();
    debugPrint("Compiled flag in NoResponse: $compiled");
  }

  void _resetFlowFlags() {
    _isComplianceNoFlow = false;
    _isOtherDrugsFlow = false;
    _pendingOtherDrugsMessage = null;
    _pendingReasonId = null;
    _prescribedReasonId = null;
  }

  _handleReasonSubmission(ChatItem option) async {
    _pendingReasonId = option.id;

    if (option.name == "Others") {
      if (_isComplianceNoFlow) {
        // ✅ Compliance_no + Others
        setState(() {
          chatMessages.add(ChatMessage(
            sender: 'bot',
            chatItem: ChatItem(
              id: 'nav_prompt',
              name: 'Others:',
            ),
          ));
          dynamicOptions = [goBackChatItem, mainMenuChatItem];
          showDynamicOptions = true;
          showTextField = true;
        });
      } else {
        // ✅ Compliance_yes → Others
        setState(() {
          chatMessages.add(ChatMessage(
            sender: 'bot',
            chatItem: ChatItem(
              id: 'nav_prompt',
              name: 'Others:',
            ),
          ));
          dynamicOptions = [goBackChatItem, mainMenuChatItem];
          showDynamicOptions = true;
          showTextField = true;
        });
      }
    } else if (option.name == "Prescribing another drug(s)") {
      _prescribedReasonId = option.id;
      setState(() {
        chatMessages.add(ChatMessage(
          sender: 'bot',
          chatItem: ChatItem(
            id: 'nav_prompt',
            name: 'Prescribing another drug:',
          ),
        ));
        dynamicOptions = [goBackChatItem, mainMenuChatItem];
        showDynamicOptions = true;
        reasonTextFieldLabel = true;
      });
    } else {
      if (_isComplianceNoFlow) {
        // ✅ Check if this is a reason from other_drugs category after prescribing
        if (_isOtherDrugsFlow && option.type == "other_drugs") {
          // This is a reason selected from other_drugs list
          _showHelpfulOptions(
            option,
            "",
            antibioticId: selectedAntibioticId,
            complied: false,
            source: "user_flow",
            reasonId: _prescribedReasonId,
            // reasonId: option.id,
            // ✅ Set other_durgs fields for other_drugs category reasons
            category: "other_drugs",
            otherDrugs: _pendingOtherDrugsMessage, // prescribed drug text
            otherDrugsReasonId: option.id, // selected reason from other_drugs
            // otherDrugsMessage:
            //     _pendingOtherDrugsMessage, // prescribed drug text
          );
        } else {
          // Regular compliance_no reason
          _showHelpfulOptions(
            option,
            "",
            antibioticId: selectedAntibioticId,
            complied: false,
            source: "user_flow",
            reasonId: option.id,
          );
        }
        // ✅ For any compliance_no reason selection, show helpful options
        // _showHelpfulOptions(
        //   option,
        //   "",
        //   antibioticId: selectedAntibioticId,
        //   complied: false,
        //   source: "user_flow",
        //   reasonId: option.id,
        // );
      } else if (_pendingLineContext != null) {
        // ✅ For compliance_yes
        _showHelpfulOptions(
          option,
          "",
          antibioticId: _pendingLineContext!["antibioticId"],
          lineItemIds: List<String>.from(_pendingLineContext!["lineItemIds"]),
          lineType:
              (Set<String>.from(_pendingLineContext!["lineTypes"])).join(","),
          complied: _pendingLineContext!["complied"],
          source: _pendingLineContext!["source"],
          reasonId: option.id,
        );
      }
    }

    _scrollToBottom();
  }
  //     if (_isComplianceNoFlow) {
  //       // ✅ For compliance_no
  //       if (option.type == "other_drugs" && option.source == "prescribed") {
  //         // Only when reason is other_drugs
  //         _showHelpfulOptions(
  //           option,
  //           "",
  //           antibioticId: selectedAntibioticId,
  //           complied: false,
  //           source: "user_flow",
  //           reasonId: option.id,
  //           category: "other_drugs",
  //           otherDrugs:
  //               _textSearchController.text.trim(), // 👈 typed prescribed msg
  //           otherDrugsReasonId: option.id,
  //         );
  //       } else {
  //         // Normal compliance_no reason
  //         _showHelpfulOptions(
  //           option,
  //           "",
  //           antibioticId: selectedAntibioticId,
  //           complied: false,
  //           source: "user_flow",
  //           reasonId: option.id,
  //         );
  //       }
  //     } else if (_pendingLineContext != null) {
  //       // ✅ For compliance_yes
  //       _showHelpfulOptions(
  //         option,
  //         "",
  //         antibioticId: _pendingLineContext!["antibioticId"],
  //         lineItemIds: List<String>.from(_pendingLineContext!["lineItemIds"]),
  //         lineType:
  //             (Set<String>.from(_pendingLineContext!["lineTypes"])).join(","),
  //         complied: _pendingLineContext!["complied"],
  //         source: _pendingLineContext!["source"],
  //         reasonId: option.id,
  //       );
  //     }
  //   }

  //   _scrollToBottom();
  // }

  // _handleReasonSubmission(ChatItem option) async {
  //   _pendingReasonId = option.id;

  //   if (option.name == "Others") {
  //     if (_isComplianceNoFlow) {
  //       // ✅ Compliance_no + Others
  //       setState(() {
  //         chatMessages.add(ChatMessage(
  //           sender: 'bot',
  //           chatItem: ChatItem(
  //             id: 'nav_prompt',
  //             name: 'Others:',
  //           ),
  //         ));
  //         dynamicOptions = [goBackChatItem, mainMenuChatItem];
  //         showDynamicOptions = true;
  //         showTextField = true;
  //       });
  //     } else {
  //       // ✅ Compliance_yes → Others
  //       setState(() {
  //         chatMessages.add(ChatMessage(
  //           sender: 'bot',
  //           chatItem: ChatItem(
  //             id: 'nav_prompt',
  //             name: 'Others:',
  //           ),
  //         ));
  //         dynamicOptions = [goBackChatItem, mainMenuChatItem];
  //         showDynamicOptions = true;
  //         showTextField = true;
  //       });
  //     }
  //   } else if (option.name == "Prescribing another drug(s)") {
  //     setState(() {
  //       chatMessages.add(ChatMessage(
  //         sender: 'bot',
  //         chatItem: ChatItem(
  //           id: 'nav_prompt',
  //           name: 'Prescribing another drug:',
  //         ),
  //       ));
  //       dynamicOptions = [goBackChatItem, mainMenuChatItem];
  //       showDynamicOptions = true;
  //       reasonTextFieldLabel = true;
  //     });
  //   } else {
  //     if (_isComplianceNoFlow) {
  //       // ✅ For compliance_no
  //       if (option.type == "other_drugs" && option.source == "prescribed") {
  //         // Only when reason is other_drugs
  //         _showHelpfulOptions(
  //           option,
  //           "",
  //           antibioticId: selectedAntibioticId,
  //           complied: false,
  //           source: "user_flow",
  //           reasonId: option.id,
  //           category: "other_drugs",
  //           otherDrugs: "true",
  //           otherDrugsReasonId: option.id,
  //           otherDrugsMessage: option.extra?["otherDrugsMessage"],
  //         );
  //       } else {
  //         // Normal compliance_no reason
  //         _showHelpfulOptions(
  //           option,
  //           "",
  //           antibioticId: selectedAntibioticId,
  //           complied: false,
  //           source: "user_flow",
  //           reasonId: option.id,
  //         );
  //       }
  //     } else if (_pendingLineContext != null) {
  //       // ✅ For compliance_yes
  //       _showHelpfulOptions(
  //         option,
  //         "",
  //         antibioticId: _pendingLineContext!["antibioticId"],
  //         lineItemIds: List<String>.from(_pendingLineContext!["lineItemIds"]),
  //         lineType:
  //             (Set<String>.from(_pendingLineContext!["lineTypes"])).join(","),
  //         complied: _pendingLineContext!["complied"],
  //         source: _pendingLineContext!["source"],
  //         reasonId: option.id,
  //       );
  //     }
  //   }

  //   _scrollToBottom();
  // }

  // _handleReasonSubmission(ChatItem option) async {
  //   _pendingReasonId = option.id;

  //   if (option.name == "Others") {
  //     if (_currentReasonCategory == "compliance_no") {
  //       // ✅ Special case: compliance_no + Others
  //       setState(() {
  //         chatMessages.add(ChatMessage(
  //           sender: 'bot',
  //           chatItem: ChatItem(
  //             id: 'nav_prompt',
  //             name: 'Others:',
  //           ),
  //         ));
  //         dynamicOptions = [goBackChatItem, mainMenuChatItem];
  //         showDynamicOptions = true;
  //         showTextField = true; // user will type reason text
  //       });

  //       // 👉 Do not call _showHelpfulOptions here
  //       // 👉 And when you send to API, ensure complied=false, no lineIds, no lineType
  //     } else {
  //       // ✅ compliance_yes → Others
  //       setState(() {
  //         chatMessages.add(ChatMessage(
  //           sender: 'bot',
  //           chatItem: ChatItem(
  //             id: 'nav_prompt',
  //             name: 'Others:',
  //           ),
  //         ));
  //         dynamicOptions = [goBackChatItem, mainMenuChatItem];
  //         showDynamicOptions = true;
  //         showTextField = true;
  //       });

  //       // ❌ Do not call _showHelpfulOptions yet, wait until user types
  //     }
  //   } else if (option.name == "Prescribing another drug(s)") {
  //     setState(() {
  //       chatMessages.add(ChatMessage(
  //         sender: 'bot',
  //         chatItem: ChatItem(
  //           id: 'nav_prompt',
  //           name: 'Prescribing another drug:',
  //         ),
  //       ));
  //       dynamicOptions = [goBackChatItem, mainMenuChatItem];
  //       showDynamicOptions = true;
  //       reasonTextFieldLabel = true; // user will type drug name
  //     });

  //     // ❌ no _showHelpfulOptions yet
  //   } else {
  //     if (_pendingLineContext != null) {
  //       if (_currentReasonCategory == "compliance_no") {
  //         // ✅ for compliance_no, normal reasons → complied=false
  //         _showHelpfulOptions(
  //           option,
  //           "",
  //           antibioticId: _pendingLineContext!["antibioticId"],
  //           complied: false,
  //           source: _pendingLineContext!["source"],
  //           reasonId: option.id,
  //         );
  //       } else {
  //         // ✅ for compliance_yes
  //         _showHelpfulOptions(
  //           option,
  //           "",
  //           antibioticId: _pendingLineContext!["antibioticId"],
  //           lineItemIds: List<String>.from(_pendingLineContext!["lineItemIds"]),
  //           lineType:
  //               (Set<String>.from(_pendingLineContext!["lineTypes"])).join(","),
  //           complied: _pendingLineContext!["complied"],
  //           source: _pendingLineContext!["source"],
  //           reasonId: option.id,
  //         );
  //       }
  //     }
  //   }

  //   _scrollToBottom();
  // }

  Future<void> _handleHelpfulYes(option) async {
    if (_pendingHelpfulContext == null) {
      debugPrint("⚠️ No HelpfulContext found!");
      return;
    }

    final ctx = _pendingHelpfulContext!;

    bool isSuccess = await _sendCompileResponse(
      selectedAntibioticId.toString(),
      // ctx.antibioticId ?? selectedAntibioticId.toString(),
      option,
      ctx.complied, // default false
      true, // helpful always true
      ctx.source,
      ctx.reasonId,
      ctx.lineItemsIds ?? [],
      lineType: ctx.lineTypes,
      message: ctx.message,
      otherDrugs: ctx.otherDrugs,
      otherDrugsReasonId: ctx.otherDrugsReasonId,
      otherDrugsMessage: ctx.otherDrugsMessage,
      category: ctx.category,
    );
    if (isSuccess) {
      _showFinalResponse();
    } else if (!isSuccess && option.name == "Others") {
      setState(() {
        chatMessages.add(ChatMessage(
            sender: 'bot',
            chatItem: ChatItem(id: 'error', name: 'Please enter reason')));
      });
    } else {
      _showDataFetchError();
    }
  }

  Map<String, List<Antibiotic>> _groupLineItemsByType() {
    return groupBy(lineItems, (ab) => ab.type!);
  }

  Future<void> _handleHelpfulNo(option) async {
    if (_pendingHelpfulContext == null) {
      debugPrint("⚠️ No HelpfulContext found for No flow!");
      return;
    }

    setState(() {
      chatMessages.add(ChatMessage(
        sender: 'bot',
        chatItem: ChatItem(
          id: 'nav_prompt',
          name: 'Please specify:',
        ),
      ));
      dynamicOptions = [goBackChatItem, mainMenuChatItem];
      showDynamicOptions = true;

      specifyNoTextFieldLabel = true;
    });
  }

  Future<void> _sendSpecify(ChatItem option) async {
    final helpfulMessage = _textSpecifyController.text.trim();
    if (helpfulMessage.isEmpty) {
      Fluttertoast.showToast(
        msg: "Please Specify",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.black,
        textColor: Colors.white,
        fontSize: 16.0,
      );
      return;
    }

    final ctx = _pendingHelpfulContext; // ✅ reuse same context
    if (ctx == null) {
      debugPrint("⚠️ No HelpfulContext found for Specify!");
      return;
    }

    setState(() {
      // 🔹 Then enable prescribed drug text field
      // reasonTextFieldLabel = true;
      // 🔹 Add user reply
      chatMessages.add(ChatMessage(
        sender: 'user',
        chatItem: ChatItem(id: 'specify_input', name: helpfulMessage),
      ));

      // ✅ Hide all textfields immediately after submission
      specifyNoTextFieldLabel = false;
      reasonTextFieldLabel = false;
      showTextField = false;
      showLineItems = false; // hide textfield after submission
    });

    _textSpecifyController.clear();

    try {
      final isSuccess = await _sendCompileResponse(
        ctx.antibioticId ?? selectedAntibioticId.toString(), // antibioticId
        option, // ChatItem
        ctx.complied ?? true, // complied
        false, // helpful
        ctx.source, // source
        ctx.reasonId ?? option.id, // reasonId
        ctx.lineItemsIds ?? [], // lineItemsIds
        lineType: ctx.lineTypes, // lineType
        message: ctx.message, // message
        otherDrugs: ctx.otherDrugs,
        otherDrugsReasonId: ctx.otherDrugsReasonId,
        otherDrugsMessage: ctx.otherDrugsMessage,
        category: ctx.category,
        helpfulMessage: helpfulMessage,
      );

      if (isSuccess) {
        debugPrint("✅ Specify request success");
        _showFinalResponse();
      } else {
        debugPrint("❌ Specify request failed (API returned false)");
        _showDataFetchError();
      }
    } catch (e) {
      debugPrint("💥 Error in _sendSpecify: $e");
      _showDataFetchError();
    }
  }

  void _showHelpfulOptions(
    ChatItem option,
    String? message, {
    BuildContext? context,
    String? antibioticId,
    List<String>? lineItemIds,
    Function? submitForm,
    bool? redirectHome,
    String? lineType,
    String? reasonId,
    bool? complied,
    String? otherDrugs,
    String? otherDrugsReasonId,
    String? otherDrugsMessage,
    String? source,
    String? category,
    bool? helpful,
    String? helpfulMessage,
  }) {
    setState(() {
      chatMessages.add(ChatMessage(
        sender: 'bot',
        chatItem: ChatItem(
          id: 'helpful',
          name: 'Was this content helpful?',
        ),
      ));

      // Show No first, then Yes
      dynamicOptions = [noChatItem, yesChatItem];
      showDynamicOptions = true;
      _addNavigationOptions();
    });

    // Store the pending helpful context
    _pendingHelpfulContext = HelpfulContext(
        antibioticId: antibioticId,
        lineItemsIds: lineItemIds,
        complied: complied,
        lineTypes: lineType,
        reasonId: reasonId,
        message: message,
        // otherDrugs: otherDrugs,
        // otherDrugsReasonId: otherDrugsReasonId,
        // otherDrugsMessage: otherDrugsMessage,
        // ✅ Only pass if compliance_no + other_drugs
        otherDrugs: (_isComplianceNoFlow &&
                _isOtherDrugsFlow &&
                category == "other_drugs")
            ? otherDrugs
            : (_isComplianceNoFlow ? null : null),
        otherDrugsReasonId: (_isComplianceNoFlow &&
                _isOtherDrugsFlow &&
                category == "other_drugs")
            ? otherDrugsReasonId
            : (_isComplianceNoFlow ? null : null),
        otherDrugsMessage: (_isComplianceNoFlow &&
                _isOtherDrugsFlow &&
                category == "other_drugs")
            ? otherDrugsMessage
            : (_isComplianceNoFlow ? null : null),
        // otherDrugs:
        //     _isComplianceNoFlow ? (_isOtherDrugsFlow ? "true" : null) : null,
        // otherDrugsReasonId:
        //     _isComplianceNoFlow ? (_isOtherDrugsFlow ? reasonId : null) : null,
        // otherDrugsMessage: _isComplianceNoFlow
        //     ? (_isOtherDrugsFlow ? _pendingOtherDrugsMessage : null)
        //     : null,

        // otherDrugs:
        //     (_isComplianceNoFlow && category == "other_drugs") ? "true" : null,
        // otherDrugsReasonId: (_isComplianceNoFlow && category == "other_drugs")
        //     ? reasonId
        //     : null,
        // otherDrugsMessage: (_isComplianceNoFlow && category == "other_drugs")
        //     ? otherDrugsMessage
        //     : null,
        source: source,
        category: category,
        helpful: helpful,
        helpfulMessage: helpfulMessage);

    _scrollToBottom();

    Map<String, dynamic> toJson() => {
          'antibioticId': antibioticId,
          'lineItemIds': lineItemIds,
          'complied': complied,
          'lineType': lineType,
          'reasonId': reasonId,
          'message': message,
          'otherDrugs': otherDrugs,
          'otherDrugsReasonId': otherDrugsReasonId,
          'otherDrugsMessage': otherDrugsMessage,
          'source': source,
          'category': category,
          'helpful': helpful,
          'helpfulMessage': helpfulMessage,
        };

    print(">>> Stored HelpfulContext: $_pendingHelpfulContext");
  }

  bool _handleNavigationOptions(ChatItem option) {
    if (option.name == "Go Back" && chatHistory.isNotEmpty) {
      _goBack();
      _scrollToBottom();
      return true;
    } else if (option.name == "Main Menu") {
      _goToMainMenu();
      _scrollToBottom();
      return true;
    }
    return false;
  }

  void _saveCurrentState() {
    chatHistory.add({
      'messages': List.from(chatMessages),
      'options': List.from(dynamicOptions),
      'showOptions': showDynamicOptions,
      'isFinalYesNo': isFinalYesNo,
    });
  }

  void _addUserMessage(ChatItem message) {
    setState(() {
      chatMessages.add(ChatMessage(sender: 'user', chatItem: message));
      showDynamicOptions = false;
    });
    _scrollToBottom();
  }

  void _showFinalResponse() {
    setState(() {
      chatMessages.add(ChatMessage(
          sender: 'bot',
          chatItem: ChatItem(
              id: "thanks",
              name: 'Thank you for using ANICA. Have a great day!')));
      dynamicOptions = [mainMenuChatItem];
      showDynamicOptions = true;
    });
    _scrollToBottom();
  }

  Future<void> _handleAntibioticPolicy() async {
    List<Antibiotic> policyData = await _fetchInfectionsFromApi();

    if (policyData.isNotEmpty) {
      _displayAntibioticPolicyData(policyData);
    } else {
      _showDataFetchError();
    }
  }

  void _displayAntibioticPolicyData(List<Antibiotic> policyData) {
    List<ChatItem> chatItem = policyData
        .where((antibiotic) => antibiotic.parent == 'root')
        .map((antibiotic) => ChatItem(
              id: antibiotic.antibioticId,
              name: antibiotic.name,
            ))
        .toList();

    setState(() {
      chatMessages.add(ChatMessage(
          sender: 'bot',
          chatItem: ChatItem(
              id: 'Enter disease',
              // name:
              //     'Enter the disease for which you need the antibiotic policy.')));
              name: 'Please select the category relevant to your query')));
      dynamicOptions = chatItem;
      dynamicOptions.addAll([mainMenuChatItem]);
      showDynamicOptions = true;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  Future<void> _handleAntibiogram() async {
    setState(() {
      chatMessages.add(ChatMessage(
          sender: 'bot',
          chatItem: ChatItem(
              id: 'biogram selected',
              // name: 'Antibiogram selected. What would you like to know?')));
              name: 'Please select the category relevant to your query')));
    });

    List<Category> antibiogramData = await _fetchAntibiogramData();

    if (antibiogramData.isNotEmpty) {
      _displayAntibiogramCategories(antibiogramData);
    } else {
      _showDataFetchError();
    }
  }

  void _displayAntibiogramCategories(List<Category> categories) {
    setState(() {
      List<ChatItem> chatItems = categories.map((cat) {
        return ChatItem(id: cat.categoryId, name: cat.name, type: 'categories');
      }).toList();
      dynamicOptions = chatItems;
      dynamicOptions.add(mainMenuChatItem);
      showDynamicOptions = true;
    });
    _scrollToBottom();
  }

  Future<void> _handleOtherOptions(ChatItem option) async {
    if (mainOptionSelected.name == "Antibiotic Policy") {
      List<Antibiotic> policyData = await _fetchInfectionsFromApi();
      Antibiotic selectedAntibiotic = policyData.firstWhere(
        (antibiotic) => antibiotic.antibioticId == option.id,
        orElse: () => Antibiotic(
            antibioticId: '',
            name: '',
            parent: '',
            ancestors: [],
            siteId: '',
            status: ''),
      );

      if (selectedAntibiotic.antibioticId.isNotEmpty) {
        selectedAntibioticId = selectedAntibiotic.antibioticId;
        if (selectedAntibiotic.type! == 'policy') {
          await _sendViewAPI(selectedAntibiotic.antibioticId);

          // ✅ Fetch line items immediately after getting the policy
          List<Antibiotic> fetchedLineItems =
              await _fetchLineItems(selectedAntibioticId!);
          setState(() {
            // Store the fetched line items
            lineItems = fetchedLineItems;
            chatMessages.add(ChatMessage(
              sender: 'bot',
              chatItem: ChatItem(
                id: 'html',
                name: selectedAntibiotic.data.toString(),
              ),
            ));
          });
          _scrollToBottom();
          _askFollowUpQuestion();
        } else {
          List<ChatItem> childrenData = policyData
              .where((antibiotic) => antibiotic.parent == option.id)
              .map((antibiotic) => ChatItem(
                    id: antibiotic.antibioticId,
                    name: antibiotic.name,
                  ))
              .toList();

          // Check if this is the last option before the policy
          bool isLastBeforePolicy = childrenData.isNotEmpty &&
              policyData
                  .where((antibiotic) => antibiotic.parent == option.id)
                  .any((child) => child.type == 'policy') &&
              !policyData
                  .where((antibiotic) => antibiotic.parent == option.id)
                  .any((child) =>
                      policyData.any((a) => a.parent == child.antibioticId));

          if (childrenData.isEmpty) {
            setState(() {
              chatMessages.add(ChatMessage(
                  sender: 'bot',
                  chatItem: ChatItem(
                      id: 'no subcategories',
                      name: 'No subcategories available for ${option.name}.')));
              dynamicOptions = [goBackChatItem, mainMenuChatItem];
              showDynamicOptions = true;
            });
            _scrollToBottom();
          } else {
            setState(() {
              chatMessages.add(ChatMessage(
                  sender: 'bot',
                  chatItem: ChatItem(
                      // id: 'choice', name: 'Choose from the options below:')));
                      id: 'choice',
                      // name: 'Kindly Choose from the options below:')));
                      name: isLastBeforePolicy
                          ? "Kindly choose the specific disease for which you need the antibiotic policy."
                          : "Kindly Choose from the options below:")));
              dynamicOptions = childrenData;
              dynamicOptions.addAll([goBackChatItem, mainMenuChatItem]);
              showDynamicOptions = true;
            });
            _scrollToBottom();
          }
        }
      } else {
        setState(() {
          chatMessages.add(ChatMessage(
              sender: 'bot',
              chatItem: ChatItem(
                  id: 'antibiotic not found',
                  name: 'No matching antibiotic found.')));
          dynamicOptions = [goBackChatItem, mainMenuChatItem];
          showDynamicOptions = true;
        });
        _scrollToBottom();
      }
    } else if (mainOptionSelected.name == "Antibiogram") {
      List<Category> categoriesList = await _fetchAntibiogramData();

      if (categoriesList.isNotEmpty) {
        if (option.type == 'categories') {
          Category selectedCategory = categoriesList.firstWhere(
            (category) => category.categoryId == option.id,
            orElse: () => Category(
                categoryId: '',
                name: '',
                siteId: '',
                status: '',
                auditLog: null,
                antibiogramsData: []),
          );

          if (selectedCategory.categoryId.isNotEmpty) {
            selectedCategoryId = selectedCategory;

            // Filter to get unique subcategories
            List<ChatItem> antibiogramTypeList = [];
            Set<String> seenSubCategories = {};

            antibiogramTypeList =
                selectedCategory.antibiogramsData.where((antibiogram) {
              final subCategory = antibiogram.subCategory;
              if (seenSubCategories.contains(subCategory)) {
                return false;
              } else {
                seenSubCategories.add(subCategory);
                return true;
              }
            }).map((antibiogram) {
              return ChatItem(
                id: antibiogram.antibiogramId,
                name: antibiogram.subCategory,
                type: 'sub_categories',
              );
            }).toList();

            if (antibiogramTypeList.isEmpty) {
              setState(() {
                chatMessages.add(ChatMessage(
                    sender: 'bot',
                    chatItem: ChatItem(
                        id: 'no sub categories',
                        name:
                            'No sub categories available for ${option.name}.')));
                dynamicOptions = [goBackChatItem, mainMenuChatItem];
                showDynamicOptions = true;
              });
              _scrollToBottom();
            } else {
              setState(() {
                chatMessages.add(ChatMessage(
                    sender: 'bot',
                    chatItem: ChatItem(
                        id: 'choice',
                        // name:
                        //     'Choose a sub category from the options below:')));
                        name: 'Choose from the Samples below:')));
                dynamicOptions = antibiogramTypeList;
                dynamicOptions.addAll([goBackChatItem, mainMenuChatItem]);
                showDynamicOptions = true;
              });
              _scrollToBottom();
            }
          } else {
            setState(() {
              chatMessages.add(ChatMessage(
                  sender: 'bot',
                  chatItem: ChatItem(
                      id: 'category not found',
                      name: 'No matching category found.')));
              dynamicOptions = [goBackChatItem, mainMenuChatItem];
              showDynamicOptions = true;
            });
            _scrollToBottom();
          }
        } else if (option.type == 'sub_categories') {
          // Store the selected sub-category
          selectedSubCategory = option.name;

          // Filter the antibiogram data based on selected sub-category
          List<Antibiogram> filteredData = selectedCategoryId!.antibiogramsData
              .where((antibiogram) =>
                  antibiogram.subCategory == selectedSubCategory)
              .toList();

          // Generate unique types for the selected sub-category
          Set<String> uniqueTypes = {};
          List<ChatItem> typeChatItems = [];

          for (var antibiogram in filteredData) {
            if (!uniqueTypes.contains(antibiogram.type)) {
              uniqueTypes.add(antibiogram.type);
              typeChatItems.add(ChatItem(
                id: antibiogram.antibiogramId,
                name: antibiogram.type,
                type: 'type',
              ));
            }
          }

          if (typeChatItems.isEmpty) {
            setState(() {
              chatMessages.add(ChatMessage(
                  sender: 'bot',
                  chatItem: ChatItem(
                      id: 'no types',
                      name:
                          'No types available for the selected sub-category.')));
              dynamicOptions = [goBackChatItem, mainMenuChatItem];
              showDynamicOptions = true;
            });
            _scrollToBottom();
          } else {
            setState(() {
              chatMessages.add(ChatMessage(
                  sender: 'bot',
                  chatItem: ChatItem(
                      id: 'choice',
                      name: 'Choose a type from the options below:')));
              dynamicOptions = typeChatItems;
              dynamicOptions.addAll([goBackChatItem, mainMenuChatItem]);
              showDynamicOptions = true;
            });
            _scrollToBottom();
          }
        } else if (option.type == 'type') {
          // Store the selected type
          selectedType = option.name;

          await postAntibiogram(); //Posting the antibiogram view:

          // Filter the data based on the selected type and sub-category
          List<Antibiogram> filteredData = selectedCategoryId!.antibiogramsData
              .where((antibiogram) =>
                  antibiogram.subCategory == selectedSubCategory &&
                  antibiogram.type == selectedType)
              .toList();

          // Generate unique axis pairs
          Set<String> uniqueAxisPairs = {};
          List<ChatItem> axisChatItems = [];

          for (var antibiogram in filteredData) {
            String axisPair =
                '${antibiogram.xAxisName}-${antibiogram.yAxisName}';
            if (!uniqueAxisPairs.contains(axisPair)) {
              uniqueAxisPairs.add(axisPair);

              axisChatItems.add(ChatItem(
                id: axisPair,
                name:
                    'X: ${antibiogram.xAxisName}, \nY: ${antibiogram.yAxisName}',
                type: 'axis',
              ));
            }
          }

          if (axisChatItems.isEmpty) {
            setState(() {
              chatMessages.add(ChatMessage(
                  sender: 'bot',
                  chatItem: ChatItem(
                      id: 'no axis',
                      name: 'No axis data available for the selected type.')));
              dynamicOptions = [goBackChatItem, mainMenuChatItem];
              showDynamicOptions = true;
            });
            _scrollToBottom();
            // await postAntibiogram(); //Posting the antibiogram view:
          } else {
            setState(() {
              chatMessages.add(ChatMessage(
                  sender: 'bot',
                  chatItem: ChatItem(
                      id: 'axis choice',
                      // name: 'Choose an axis pair from the options below:')));
                      name: 'Pick an option to see the susceptibility data.')));
              dynamicOptions = axisChatItems;
              dynamicOptions.addAll([goBackChatItem, mainMenuChatItem]);
              showDynamicOptions = true;
            });
            _scrollToBottom();
          }
        } else if (option.type == 'axis') {
          // Filter by the selected axis pair
          String selectedAxisPair = option.id;
          List<Antibiogram> selectedAxisData = selectedCategoryId!
              .antibiogramsData
              .where((antibiogram) =>
                  antibiogram.subCategory == selectedSubCategory &&
                  antibiogram.type == selectedType &&
                  '${antibiogram.xAxisName}-${antibiogram.yAxisName}' ==
                      selectedAxisPair)
              .toList();

          List<ChatItem> axisDetailsChatItems =
              selectedAxisData.map((antibiogram) {
            return ChatItem(
              id: antibiogram.antibiogramId,
              name:
                  'X: ${antibiogram.xAxisName}, \nY: ${antibiogram.yAxisName}, '
                  // '\nNew Value: ${antibiogram.newValue}, \nOld Value: ${antibiogram.oldValue}',
                  '\nNew Value: ${antibiogram.newValue.isNotEmpty == true ? antibiogram.newValue : 'N/A'}, '
                  '\nOld Value: ${antibiogram.oldValue.isNotEmpty == true ? antibiogram.oldValue : 'N/A'}',
              type: 'axis-details',
            );
          }).toList();

          if (axisDetailsChatItems.isEmpty) {
            setState(() {
              chatMessages.add(ChatMessage(
                  sender: 'bot',
                  chatItem: ChatItem(
                      id: 'no details',
                      name: 'No details available for this axis pair.')));
              dynamicOptions = [goBackChatItem, mainMenuChatItem];
              showDynamicOptions = true;
            });
            _scrollToBottom();
          } else {
            // await postAntibiogram();
            setState(() {
              chatMessages.add(ChatMessage(
                  sender: 'bot',
                  chatItem: ChatItem(
                      id: 'axis details choice',
                      name:
                          'Here are the details for the selected axis pair:')));
              for (var axisDetail in axisDetailsChatItems) {
                chatMessages.add(ChatMessage(
                  sender: 'bot',
                  chatItem: axisDetail,
                ));
              }
              dynamicOptions = [goBackChatItem, mainMenuChatItem];
              showDynamicOptions = true;
            });
            _scrollToBottom();
          }
        }
      } else {
        _showDataFetchError();
      }
    }
  }

  void _showDataFetchError() {
    setState(() {
      chatMessages.add(ChatMessage(
          sender: 'bot',
          chatItem: ChatItem(
              id: 'failed', name: 'Failed to fetch data. Please try again.')));
      // dynamicOptions.add(mainMenuChatItem);
      dynamicOptions = [mainMenuChatItem];
      showDynamicOptions = true;
    });
  }

  Future<bool> _sendCompileResponse(
    String antibioticId,
    ChatItem option,
    bool? compliedFromPrescribe,
    bool? helpful,
    String? source,
    String? reasonId,
    List<String>? lineItemsIds, {
    String? lineType,
    String? message,
    String? helpfulMessage,
    String? otherDrugs,
    String? otherDrugsReasonId,
    String? otherDrugsMessage,
    String? category,
  }) async {
    final requestBody = [
      {
        "date": getCurrentEpochTime(),
        "antibiotic_id": antibioticId,
        "complied": compliedFromPrescribe ?? false,
        "line_items_ids": lineItemsIds ?? [],
        "line_types": lineType,
        "reason_id": reasonId,
        "message": message ?? "",
        "chat": true,
        "other_durgs": otherDrugs,
        "other_durgs_reason_id": otherDrugsReasonId,
        "other_durgs_message": otherDrugsMessage,
        "helpful": helpful,
        "helpful_message": helpfulMessage,
      }
    ];

    // ✅ Handle "Others" reason
    if (option.name == "Others") {
      final inputText = _textSearchController.text.trim();
      if (inputText.isEmpty) {
        Fluttertoast.showToast(
          msg: "Please enter reason",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.black,
          textColor: Colors.white,
          fontSize: 16.0,
        );
        return false;
      }

      requestBody[0]['complied'] = compliedFromPrescribe ?? true;
      requestBody[0]['reason_id'] = option.id;
      requestBody[0]['message'] = inputText;
    } else if (option.isReason) {
      requestBody[0]['complied'] = compliedFromPrescribe ?? true;
      requestBody[0]['reason_id'] = option.id;
    }

    // ✅ Handle "other_drugs" reason explicitly
    if (_isComplianceNoFlow &&
        option.type == "other_drugs" &&
        option.source == "prescribed") {
      requestBody[0]['other_durgs'] = true;
      requestBody[0]['other_durgs_reason_id'] =
          otherDrugsReasonId ?? "RES_4BCBERO";
      requestBody[0]['other_durgs_message'] = otherDrugsMessage ?? "ggg";
    }

    try {
      debugPrint('Request URL compile: ${Strings.baseUrl}antibiotics/compile');
      debugPrint('Request Body compile: $requestBody');

      final response = await ApiClient(baseUrl: Strings.baseUrl)
          .post('antibiotics/compile', body: requestBody);

      debugPrint('API Response Status Code compile: ${response.statusCode}');
      debugPrint('API Response Body compile: ${response.body}');

      final responseBody = json.decode(response.body);

      if (response.statusCode == 200) {
        final message = responseBody['message'] ?? "Submission successful";
        _showToast(message);
        debugPrint("Success chat submit: $message");
        return true;
      } else if (response.statusCode == 401) {
        debugPrint('Received 401. Response body: ${response.body}');
        Fluttertoast.showToast(
            msg: 'Account Disabled. Please contact support.');
        await unregisterDeviceFromPushNotificationServer();
        if (mounted) navigateToLoginScreen(context);
        return false;
      } else {
        final errorMessage =
            responseBody['message'] ?? "Submission failed. Try again.";
        debugPrint("❌ API call failed with status ${response.statusCode}");
        debugPrint("❌ API call failed with status response ${response}");
        debugPrint("Error Message: $errorMessage");
        return false;
      }
    } catch (e) {
      debugPrint('Error during submission: $e');
      return false;
    }
  }

  Future<List<Category>> _fetchAntibiogramData() async {
    const String endpoint = 'bulk/antibiogram';

    try {
      final response = await ApiClient(
              baseUrl: Strings.baseUrl,
              customTimeout: const Duration(seconds: 40))
          .get(endpoint);

      if (response.statusCode == 200) {
        // final Map<String, dynamic> responseData = json.decode(response.body);
        final Map<String, dynamic> responseData = json
            .decode(utf8.decode(response.bodyBytes) // 👈 Fix encoding here too
                );
        final dynamic jsonData = responseData['data'];
        final List<dynamic> categories = jsonData['categorys'];
        List<Category> categoriesList = categories
            .map((categoryJson) =>
                Category.fromJson(categoryJson as Map<String, dynamic>))
            .toList();
        debugPrint("ANTIBIOGRAM : $responseData");
        return categoriesList;
      } else {
        throw Exception(
            'HTTP Error: ${response.statusCode}. Unable to fetch data.');
      }
    } catch (error) {
      throw Exception('Failed to fetch antibiogram data: $error');
    }
  }

  void _addNavigationOptions() {
    if (!isInitialResponse) {
      List<ChatItem> currentOptions = List.from(dynamicOptions);
      if (!currentOptions.contains(goBackChatItem) &&
          !currentOptions.contains(mainMenuChatItem)) {
        if (isSecondResponse) {
          currentOptions.add(mainMenuChatItem);
        } else {
          currentOptions.addAll(navigationOptions);
        }
        setState(() {
          dynamicOptions = currentOptions;
          showDynamicOptions = true;
        });
      }
    }
  }

  void _goBack() {
    if (chatHistory.isNotEmpty) {
      final previousState = chatHistory.removeLast();
      setState(() {
        chatMessages = List.from(previousState['messages']);
        dynamicOptions = List.from(previousState['options']);
        showDynamicOptions = previousState['showOptions'];
        isFinalYesNo = previousState['isFinalYesNo'];
        isSecondResponse = false;
        showTextField = false;
        showLineItems = false;
        reasonTextFieldLabel = false;
        specifyNoTextFieldLabel = false;

        selectedLineItemIds.clear();
        noAbxSelected = false;
        selectedGroup = null;
        _addNavigationOptions();
      });
    }
  }

  void _goToMainMenu() {
    setState(() {
      chatHistory.clear();
      chatMessages.clear();
      dynamicOptions.clear();
      isFinalYesNo = false;
      showDynamicOptions = false;
      isInitialResponse = true;
      isSecondResponse = false;
      showTextField = false;
      showLineItems = false;
      reasonTextFieldLabel = false;
      specifyNoTextFieldLabel = false;
      selectedLineItemIds.clear();
      noAbxSelected = false;
      selectedGroup = null;

      _resetFlowFlags();
    });
    _initializeChat();
  }

  void _initializeChat() {
    setState(() {
      chatMessages = [
        ChatMessage(
            sender: 'bot',
            chatItem: ChatItem(
                id: 'intro',
                name:
                    'Hello! I\'m Anica, your friendly Antimicrobial Stewardship assistant. How can I help?'))
      ];
      dynamicOptions = staticOptions;
      showDynamicOptions = true;
      isInitialResponse = true;
    });
  }

  Future<void> _fetchReasonsFromApi({
    required String category,
    required bool complied,
    String? otherDrugsMessage,
  }) async {
    _currentReasonCategory = category;
    try {
      final baseUrl = Strings.baseUrl;
      final prefs = await SharedPreferences.getInstance();
      String siteId = prefs.getString('site_id') ?? '';

      final response = await ApiClient(baseUrl: baseUrl).get(
          'reasons?site_id=$siteId&page=1&sort_order=asc&limit=10000&category=$category');

      final jsonResponse = response.body;
      debugPrint("REASONS : $jsonResponse");

      final utf8Body = utf8.decode(response.bodyBytes);

      if (response.statusCode == 200) {
        // final List<dynamic> jsonList = jsonDecode(response.body)['data'];
        final List<dynamic> jsonList = jsonDecode(utf8Body)['data'];
        List<Reason> reasonsList =
            jsonList.map((json) => Reason.fromJson(json)).toList();

        reasonsList =
            reasonsList.where((reason) => reason.category == category).toList();

        if (reasonsList.isNotEmpty) {
          if (category == "other_drugs") {
            // ✅ Mark reasons from other_drugs category with proper type
            fetchedReasons = reasonsList
                .map<ChatItem>((reason) => ChatItem(
                    id: reason.reasonId,
                    name: reason.reason,
                    isReason: true,
                    type: "other_drugs", // ✅ Mark as other_drugs type
                    source: "prescribed"))
                .toList();

            setState(() {
              reasonTextFieldLabel = false;
              specifyNoTextFieldLabel = false;
              showTextField = false;
              _isOtherDrugsFlow = true; // ✅ Ensure flag is set

              chatMessages.add(ChatMessage(
                sender: 'bot',
                chatItem: ChatItem(
                  id: 'reason_prompt',
                  name: 'Please select the reason:',
                ),
              ));

              dynamicOptions = fetchedReasons;
              dynamicOptions.addAll([goBackChatItem, mainMenuChatItem]);
              showDynamicOptions = true;
            });
          } else {
            // Regular reasons (compliance_no, compliance_yes)
            fetchedReasons = reasonsList
                .map<ChatItem>((reason) => ChatItem(
                    id: reason.reasonId, name: reason.reason, isReason: true))
                .toList();

            setState(() {
              dynamicOptions = fetchedReasons;
              showDynamicOptions = true;
            });
          }

          final othersReason = reasonsList.firstWhere(
            (reason) => reason.reason == 'Others',
            orElse: () =>
                Reason(reasonId: '', reason: '', siteId: '', status: ''),
          );

          if (othersReason.reasonId.isNotEmpty) {
            othersReasonId = othersReason.reasonId;
          }
        }
      } else if (response.statusCode == 401) {
        debugPrint('Received 401. Response body: ${response.body}');
        Fluttertoast.showToast(
            msg: 'Account Disabled. Please contact support.');
        await unregisterDeviceFromPushNotificationServer();
        if (mounted) navigateToLoginScreen(context);
      }
    } catch (e) {
      setState(() {
        chatMessages.add(ChatMessage(
            sender: 'bot',
            chatItem: ChatItem(
                id: 'fetch failed',
                name: 'Failed to fetch reasons. Please try again later.')));
      });
    }
  }

  Future<List<Antibiotic>> _fetchInfectionsFromApi() async {
    try {
      final baseUrl = Strings.baseUrl;
      final prefs = await SharedPreferences.getInstance();
      String siteId = prefs.getString('site_id') ?? '';

      final response = await ApiClient(
              baseUrl: baseUrl, customTimeout: const Duration(seconds: 40))
          .get('antibiotics?site_id=$siteId');

      final utf8Body = utf8.decode(response.bodyBytes);

      print("antibiotic response--${response.body}");
      if (response.statusCode == 200) {
        // final List<dynamic> jsonList = jsonDecode(response.body)['data'];
        final List<dynamic> jsonList = jsonDecode(utf8Body)['data'];
        return jsonList.map((json) => Antibiotic.fromJson(json)).toList();
      } else if (response.statusCode == 401) {
        Fluttertoast.showToast(
            msg: 'Account Disabled. Please contact support.');
        await unregisterDeviceFromPushNotificationServer();
        if (mounted) navigateToLoginScreen(context);
        throw Exception("Unauthorized");
      } else {
        setState(() {
          chatMessages.add(ChatMessage(
              sender: 'bot',
              chatItem: ChatItem(
                  id: 'failed fetch',
                  name: 'Failed to fetch data. Please try again later.')));
          dynamicOptions.addAll([goBackChatItem, mainMenuChatItem]);
          showDynamicOptions = true;
        });
        throw Exception("Failed to fetch data");
      }
    } catch (e) {
      setState(() {
        chatMessages.add(ChatMessage(
            sender: 'bot',
            chatItem: ChatItem(
                id: 'error occured',
                name:
                    'An error occurred while fetching data. Please try again later.')));
        dynamicOptions = [goBackChatItem, mainMenuChatItem];
        showDynamicOptions = true;
      });
      throw Exception("Failed to fetch data");
    }
  }

  void _askFollowUpQuestion() {
    setState(() {
      chatMessages.add(ChatMessage(
          sender: 'bot',
          chatItem: ChatItem(
              id: 'feedback',
              name:
                  'Would you prescribe based on the suggestion provided by the app?')));
      dynamicOptions = [noChatItem, yesChatItem];
      dynamicOptions.addAll([goBackChatItem, mainMenuChatItem]);
      showDynamicOptions = true;
    });
    // _scrollToBottom();
    Future.delayed(const Duration(milliseconds: 200), () {
      _scrollToBottom();
    });
  }

  int getCurrentEpochTime() {
    final now = DateTime.now(); // Get the current date and time
    return now.millisecondsSinceEpoch ~/
        1000; // Convert milliseconds to seconds
  }

  void _showToast(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.black,
      textColor: Colors.white,
      fontSize: 16.0,
    );
  }

  Future<void> _sendViewAPI(String selectedAntibioticId) async {
    final baseUrl = Strings.baseUrl;
    final requestBody = [
      {
        "action": "view",
        "antibiotic_id": selectedAntibioticId,
        "view": true,
        "chat": true,
        "date": getCurrentEpochTime()
      }
    ];
    debugPrint('Calling antibiotic view API with body: $requestBody');

    try {
      final response = await ApiClient(baseUrl: baseUrl)
          .post('antibiotics/view', body: requestBody);
      debugPrint('API Response antibiotic chat view ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _showToast(data['message'] ?? "API call successful");
      } else if (response.statusCode == 401) {
        debugPrint('Received 401. Response body: ${response.body}');
        Fluttertoast.showToast(
            msg: 'Account Disabled. Please contact support.');
        await unregisterDeviceFromPushNotificationServer();
        if (mounted) navigateToLoginScreen(context);
      } else {
        _showToast("Failed: ${response.statusCode}");
      }
    } catch (e) {
      // _showToast("Error: $e");
      debugPrint('Error in antibiotic view: $e');
    }
  }

  Future<bool> postAntibiogram() async {
    const String endpoint = 'view/antibiogram';
    final baseUrl = Strings.baseUrl;
    debugPrint('Posting data from chat to antibiogram API...');

    final requestBody = [
      {
        "category_id":
            selectedCategoryId != null ? selectedCategoryId!.categoryId : '',
        "sub_category": selectedSubCategory,
        "type": selectedType,
        "view": true,
        "chat": true,
        "date": DateTime.now().millisecondsSinceEpoch ~/ 1000
      }
    ];

    try {
      // Use the API client's post method
      final response =
          await ApiClient(baseUrl: baseUrl).post(endpoint, body: requestBody);
      debugPrint('Response Status Code: ${response.statusCode}');
      debugPrint('Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        if (responseData['status'] == 200) {
          return true;
        } else {
          throw Exception(
              responseData['message'] ?? 'Unexpected response from the server');
        }
      } else {
        throw Exception(
            'HTTP Error: ${response.statusCode}. Unable to post data.');
      }
    } catch (error) {
      // Catch and rethrow exceptions for error handling
      debugPrint('Error posting antibiogram data: $error');
      throw Exception('Failed to post antibiogram data: $error');
    }
  }

  Future<void> _sendPrescribedDrug() async {
    final inputText = _textPrescribedController.text.trim();
    if (inputText.isEmpty) {
      Fluttertoast.showToast(
        msg: "Please enter prescribed drug(s)",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.black,
        textColor: Colors.white,
        fontSize: 16.0,
      );
      return;
    }

    setState(() {
      // Add user reply
      chatMessages.add(ChatMessage(
        sender: 'user',
        chatItem: ChatItem(id: 'prescribed_input', name: inputText),
      ));

      reasonTextFieldLabel = false;
    });

    _textPrescribedController.clear();

    // Handle based on flow type
    if (_isComplianceNoFlow) {
      _pendingOtherDrugsMessage = inputText;
      _isOtherDrugsFlow = true;
      // otherDrugsMessage = inputText;

      // ✅ Fetch reasons for other_drugs instead of helpful options
      await _fetchReasonsFromApi(
        category: "other_drugs",
        complied: false,
        otherDrugsMessage: _pendingOtherDrugsMessage,
      );
    } else {
      // For compliance_yes, fetch reasons
      // await _fetchReasonsFromApi(category: "other_drugs", complied: false);
    }

    _scrollToBottom();
  }

  Future<void> _sendReasonOthers() async {
    final message = _textSearchController.text.trim();
    if (message.isEmpty) {
      Fluttertoast.showToast(
        msg: "Please enter reason",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.black,
        textColor: Colors.white,
        fontSize: 16.0,
      );
      return;
    }

    setState(() {
      chatMessages.add(ChatMessage(
        sender: 'user',
        chatItem: ChatItem(id: 'input', name: message),
      ));
      _textSearchController.clear();
      showTextField = false;
    });

    // Handle based on flow type
    if (_isComplianceNoFlow) {
      if (_isOtherDrugsFlow) {
        // ✅ This is "Others" from other_drugs category after prescribing
        _showHelpfulOptions(
          ChatItem(id: 'reason_others', name: 'Others'),
          "",
          antibioticId: selectedAntibioticId,
          complied: false,
          source: "user_flow",
          reasonId: _prescribedReasonId,
          // reasonId: _pendingReasonId ?? "RES_OTHERS",
          category: "other_drugs",
          otherDrugs: _pendingOtherDrugsMessage, // ✅ prescribed drug text
          otherDrugsReasonId:
              _pendingReasonId ?? "RES_OTHERS", // ✅ "Others" reason ID
          otherDrugsMessage: message, // ✅ The "Others" reason text user typed
        );
      } else {
        // Regular compliance_no "Others" reason
        _showHelpfulOptions(
          ChatItem(id: 'reason_others', name: 'Others'),
          message,
          antibioticId: selectedAntibioticId,
          complied: false,
          source: "user_flow",
          reasonId: _pendingReasonId ?? "RES_OTHERS",
        );
      }
      // For compliance_no
      // _showHelpfulOptions(
      //   ChatItem(id: 'reason_others', name: 'Others'),
      //   message,
      //   antibioticId: selectedAntibioticId,
      //   complied: false,
      //   source: "user_flow",
      //   reasonId: _pendingReasonId ?? "RES_OTHERS",
      //   // category: "other_drugs",
      //   // otherDrugs: "true",
      //   // otherDrugsReasonId: _pendingReasonId ?? "RES_OTHERS",
      //   // otherDrugsMessage: otherDrugsMessage, // ✅ prescribed input
      // );
    } else if (_pendingLineContext != null) {
      // For compliance_yes
      _showHelpfulOptions(
        ChatItem(id: 'reason_others', name: 'Others'),
        message,
        antibioticId: _pendingLineContext!["antibioticId"],
        lineItemIds: List<String>.from(_pendingLineContext!["lineItemIds"]),
        lineType:
            (Set<String>.from(_pendingLineContext!["lineTypes"])).join(","),
        complied: _pendingLineContext!["complied"],
        source: _pendingLineContext!["source"],
        reasonId: _pendingReasonId ?? "RES_OTHERS",
      );
    }
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
        body: isConnected
            ? Column(
                children: [
                  Expanded(
                    child: ListView(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16.0),
                      children: [
                        ...chatMessages.map((message) {
                          final isSender = message.sender == 'user';
                          return Column(
                            crossAxisAlignment: isSender
                                ? CrossAxisAlignment.end
                                : CrossAxisAlignment.start,
                            children: [
                              _buildChatMessage(
                                context: context,
                                isSender: isSender,
                                profilePic: "assets/images/chat.png",
                                message: message.chatItem,
                              ),
                              const SizedBox(height: 8),
                              if (!isSender &&
                                  message == chatMessages.last &&
                                  showDynamicOptions) ...[
                                const SizedBox(height: 1),
                                Padding(
                                  padding: const EdgeInsets.only(left: 56.0),
                                  child: _buildOptionsLayout(),
                                ),
                              ],
                            ],
                          );
                        }),

// Add line items selection here
                        if (showLineItems) _buildLineItemsSelection(),
                      ],
                    ),
                  ),
                  if (showTextField)
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _textSearchController,
                              decoration: InputDecoration(
                                hintText: 'Enter your reason here',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8.0),
                                  borderSide:
                                      BorderSide(color: Colors.grey.shade300),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8.0),
                                  borderSide:
                                      BorderSide(color: Colors.grey.shade300),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8.0),
                                  borderSide:
                                      BorderSide(color: Colors.grey.shade400),
                                ),
                                filled: true,
                                fillColor: Colors.white,
                                suffixIcon: IconButton(
                                  icon: Icon(Icons.send,
                                      color: Colors.grey.shade600),
                                  onPressed: _sendReasonOthers,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (reasonTextFieldLabel)
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _textPrescribedController,
                              decoration: InputDecoration(
                                hintText:
                                    'Please specify the prescribed antibiotic(s) / antibiotic(s)',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8.0),
                                  borderSide:
                                      BorderSide(color: Colors.grey.shade300),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8.0),
                                  borderSide:
                                      BorderSide(color: Colors.grey.shade300),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8.0),
                                  borderSide:
                                      BorderSide(color: Colors.grey.shade400),
                                ),
                                filled: true,
                                fillColor: Colors.white,
                                suffixIcon: IconButton(
                                  icon: Icon(Icons.send,
                                      color: Colors.grey.shade600),
                                  // onPressed: _sendReasonOthers,
                                  // onPressed: () {
                                  //   _fetchReasonsFromApi(
                                  //       category: "other_drugs",
                                  //       complied: false);
                                  // }),
                                  onPressed: _sendPrescribedDrug,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (specifyNoTextFieldLabel)
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _textSpecifyController,
                              decoration: InputDecoration(
                                hintText: 'Please specify',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8.0),
                                  borderSide:
                                      BorderSide(color: Colors.grey.shade300),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8.0),
                                  borderSide:
                                      BorderSide(color: Colors.grey.shade300),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8.0),
                                  borderSide:
                                      BorderSide(color: Colors.grey.shade400),
                                ),
                                filled: true,
                                fillColor: Colors.white,
                                suffixIcon: IconButton(
                                  icon: Icon(Icons.send,
                                      color: Colors.grey.shade600),
                                  // onPressed: _sendReasonOthers,
                                  // onPressed: () {
                                  //   _fetchReasonsFromApi(
                                  //       category: "other_drugs",
                                  //       complied: false);
                                  // }),
                                  onPressed: () => _sendSpecify(
                                    ChatItem(
                                      id: _pendingReasonId ?? "",
                                      name: _textSpecifyController.text.trim(),
                                      isReason: true,
                                    ), // dummy ChatItem
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              )
            : const Center(
                child: Text(
                  "Internet is not available",
                  style: TextStyle(fontSize: 18),
                ),
              ),
      ),
    );
  }

  Widget _buildLineItemsSelection() {
    final groupedItems = groupBy(lineItems, (ab) => ab.type!);

    // Define the order and display names for line types
    final typeOrder = ['line_1', 'line_2', 'line_3'];
    final typeDisplayNames = {
      'line_1': 'First Line Antibiotics',
      'line_2': 'Second Line Antibiotics',
      'line_3': 'Third Line Antibiotics',
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0)
          .copyWith(left: 50, top: 16, bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(
            color: Colors.pink.shade100,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Display grouped line items
            ...typeOrder.map((type) {
              if (!groupedItems.containsKey(type) ||
                  groupedItems[type]!.isEmpty) {
                return const SizedBox.shrink();
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Heading for each line type
                  Text(
                    typeDisplayNames[type] ?? type.toUpperCase(),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Antibiotics in this line
                  ...groupedItems[type]!.map((item) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 24,
                            height: 24,
                            child: Checkbox(
                              value: selectedLineItemIds
                                  .contains(item.antibioticId),
                              onChanged: (_) => _toggleLineItemSelection(
                                  item.type ?? "", item.antibioticId),
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              item.name,
                              style: const TextStyle(fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 12),
                ],
              );
            }),

            // "No Abx as recommended in the policy" option
            Row(
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: noAbxSelected,
                    onChanged: (value) {
                      setState(() {
                        noAbxSelected = value ?? false;
                        if (noAbxSelected) {
                          selectedLineItemIds.clear();
                        }
                      });
                    },
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    "No Abx as recommended in the policy",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Submit button styled similar to Go Back button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitLineItems,
                style: ElevatedButton.styleFrom(
                  backgroundColor: backgroundColors,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20.0,
                    vertical: 8.0,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.0),
                    side: const BorderSide(
                      color: optionBorderColor,
                    ),
                  ),
                ),
                child: const Text(
                  'Submit Selection',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool noAbxSelected = false;

  Widget _buildOptionsLayout() {
    bool isYesNo = dynamicOptions.length >= 2 &&
        dynamicOptions.contains(yesChatItem) &&
        dynamicOptions.contains(noChatItem);

    return Container(
      constraints: BoxConstraints(
        maxWidth:
            MediaQuery.of(context).size.width * 0.7, // Match message width
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
                        child: _buildOptionButton(noChatItem),
                      ),
                    ),
                    SizedBox(
                      width: 100,
                      child: _buildOptionButton(yesChatItem),
                    ),
                  ],
                ),
                ...dynamicOptions
                    .where((option) =>
                        option != yesChatItem && option != noChatItem)
                    .map((option) => _buildOptionButton(option)),
              ]
            : dynamicOptions
                .map((option) => _buildOptionButton(option))
                .toList(),
      ),
    );
  }

  Widget _buildOptionButton(ChatItem option) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.0),
      child: ElevatedButton(
        onPressed: () => _handleOptionSelection(option),
        style: ElevatedButton.styleFrom(
          backgroundColor: navigationOptions.contains(option)
              ? Colors.grey[200]
              : backgroundColors,
          padding: const EdgeInsets.symmetric(
            horizontal: 20.0,
            vertical: 8.0,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10.0),
            side: BorderSide(
              color: navigationOptions.contains(option)
                  ? Colors.grey[300]!
                  : optionBorderColor,
            ),
          ),
        ),
        child: Text(
          option.name,
          style: TextStyle(
            fontSize: 14,
            color: navigationOptions.contains(option)
                ? Colors.black
                : Colors.black,
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
    required ChatItem message,
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
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color: isSender ? replyColor : Colors.white,
                  border: Border.all(
                    color: isSender ? replyColor : Colors.pink.shade100,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Show line items if this is an HTML message
                    if (message.id == "html" && lineItems.isNotEmpty) ...[
                      _buildLineItemsDisplay(),
                    ],
                    // Show "Other Instructions" heading for HTML content
                    if (message.id == "html") ...[
                      const Text(
                        "Other Instructions",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                    // Original message content
                    message.id == "html"
                        ? Html(data: message.name)
                        : Text(
                            message.name,
                            style: TextStyle(
                              fontSize: 14,
                              color: isSender ? Colors.white : Colors.black,
                              fontWeight: isSender
                                  ? FontWeight.w500
                                  : FontWeight.normal,
                            ),
                          ),
                  ],
                ),
              ),
            ),
            if (isSender) const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildLineItemsDisplay() {
    // Group line items by type
    final groupedItems = <String, List<Antibiotic>>{};

    for (var item in lineItems) {
      final type = item.type ?? 'unknown';
      if (!groupedItems.containsKey(type)) {
        groupedItems[type] = [];
      }
      groupedItems[type]!.add(item);
    }

    // Define the order and display names for line types
    final typeOrder = ['line_1', 'line_2', 'line_3'];
    final typeDisplayNames = {
      'line_1': 'First Line Antibiotics',
      'line_2': 'Second Line Antibiotics',
      'line_3': 'Third Line Antibiotics',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (String type in typeOrder)
          if (groupedItems.containsKey(type) &&
              groupedItems[type]!.isNotEmpty) ...[
            Text(
              typeDisplayNames[type] ?? type.toUpperCase(),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            ...groupedItems[type]!.map((item) => Padding(
                  padding: const EdgeInsets.only(left: 8.0, bottom: 2.0),
                  child: Row(
                    children: [
                      const Text('• ', style: TextStyle(color: Colors.black54)),
                      Expanded(
                        child: Text(
                          item.name,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
            const SizedBox(height: 8),
          ],
      ],
    );
  }
}

class ChatItem {
  final String id;
  final String name;
  final bool isReason;
  final String type;
  final String? source;
  final Map<String, dynamic>? extra;

  ChatItem({
    required this.id,
    required this.name,
    this.isReason = false,
    this.type = 'antibiotic',
    this.source,
    this.extra,
  });
}

class ChatMessage {
  final String sender;
  final ChatItem chatItem;
  final bool isHtml;

  ChatMessage(
      {required this.sender, required this.chatItem, this.isHtml = false});
}
