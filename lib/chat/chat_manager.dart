import 'package:qr_scanner_app/chat/chat_api_service.dart';

class ChatManager {
  List<Map<String, dynamic>> chatMessages = [];
  List<String> staticOptions = ["Antibiotic Policy", "Antibiogram"];
  List<String> dynamicOptions = [];
  bool showDynamicOptions = false;
  List<String> fetchedReasons = [];
  bool isFinalYesNo = false;
  List<Map<String, dynamic>> chatHistory = [];
  List<String> navigationOptions = ["Go Back", "Main Menu"];
  bool isInitialResponse = true;
  bool isSecondResponse = false;

  void handleOptionSelection(
      String option, Function setState, ChatApiService chatApiService) async {
    if (isInitialResponse) {
      isInitialResponse = false;
      if (option == "Antibiotic Policy" || option == "Antibiogram") {
        isSecondResponse = true;
      }
    } else {
      isSecondResponse = false;
    }

    // Handle navigation options
    if (option == "Go Back" && chatHistory.isNotEmpty) {
      goBack(setState);
      return;
    } else if (option == "Main Menu") {
      goToMainMenu(setState);
      return;
    }

    // Store current state in history before updating
    if (!navigationOptions.contains(option)) {
      chatHistory.add({
        'messages': List.from(chatMessages),
        'options': List.from(dynamicOptions),
        'showOptions': showDynamicOptions,
        'isFinalYesNo': isFinalYesNo,
      });
    }

    setState(() {
      chatMessages.add({'sender': 'user', 'message': option});
      showDynamicOptions = false;
    });

    // Handle final Yes/No response
    if (isFinalYesNo) {
      if (option == "Yes") {
        goToMainMenu(setState);
        return;
      } else if (option == "No") {
        setState(() {
          chatMessages.add({
            'sender': 'bot',
            'message': "Thank you for using ANICA. Have a great day!",
          });
          showDynamicOptions = false;
          dynamicOptions = ["Main Menu"];
          showDynamicOptions = true;
        });
        return;
      }
    }

    // Regular chat flow handling
    if (option == "Yes") {
      setState(() {
        chatMessages.add({
          'sender': 'bot',
          'message': "Thank you for your suggestion!",
        });
        dynamicOptions = ["Go Back", "Main Menu"];
        showDynamicOptions = true;
      });
      return;
    } else if (option == "No") {
      setState(() {
        chatMessages.add({
          'sender': 'bot',
          'message': "Please provide a reason:",
        });
      });
      await chatApiService.fetchReasonsFromApi(setState, this);
      addNavigationOptions(setState);
    } else if (option == "Antibiotic Policy") {
      await chatApiService.fetchInfectionsFromApi(setState, this);
      addNavigationOptions(setState);
    } else if (option == "Antibiogram") {
      setState(() {
        chatMessages.add({
          'sender': 'bot',
          'message': "Antibiogram selected. What would you like to know?",
        });
      });

      final antibiogramData = await chatApiService.fetchAntibiogramData();

      if (antibiogramData['status'] == 200) {
        final data = antibiogramData['data'];
        final List<dynamic> categoryList = data['categorys'];

        setState(() {
          dynamicOptions = categoryList
              .map<String>((category) => category['name'] as String)
              .toList();
          dynamicOptions.add("Main Menu");
          showDynamicOptions = true;
        });
      } else {
        setState(() {
          chatMessages.add({
            'sender': 'bot',
            'message': "Failed to fetch antibiogram data.",
          });
        });
      }
    } else if (!staticOptions.contains(option)) {
      // Check if the option is from antibiogram categories
      final antibiogramData = await chatApiService.fetchAntibiogramData();
      if (antibiogramData['status'] == 200) {
        final data = antibiogramData['data'];
        final List<dynamic> categoryList = data['categorys'];
        final selectedCategory = categoryList.firstWhere(
          (category) => category['name'] == option,
          orElse: () => null,
        );

        if (selectedCategory != null) {
          // Extract unique subcategories from antibiograms_data
          final List<dynamic> antibiogramsData =
              selectedCategory['antibiograms_data'] ?? [];
          final Set<String> uniqueSubcategories = antibiogramsData
              .map<String>((item) => item['sub_category'] as String)
              .toSet();

          if (uniqueSubcategories.isNotEmpty) {
            setState(() {
              chatMessages.add({
                'sender': 'bot',
                'message': "Please select a subcategory:",
              });

              dynamicOptions = uniqueSubcategories.toList();
              showDynamicOptions = true;
              addNavigationOptions(setState);
            });
          } else {
            setState(() {
              chatMessages.add({
                'sender': 'bot',
                'message': "No subcategories found for $option",
              });
              dynamicOptions = ["Main Menu"];
              showDynamicOptions = true;
            });
          }
        } else if (fetchedReasons.contains(option)) {
          setState(() {
            chatMessages.add({
              'sender': 'bot',
              'message': "Thank you for your response",
            });
            chatMessages.add({
              'sender': 'bot',
              'message': "Do you need any further help?",
            });

            dynamicOptions = ["Yes", "No"];
            showDynamicOptions = true;
            isFinalYesNo = true;
            addNavigationOptions(setState);
          });
        } else {
          // If it's a subcategory selection
          bool subcategoryFound = false;
          Map<String, List<Map<String, dynamic>>> subcategoryData = {};

          // Find the category that contains this subcategory
          for (var category in categoryList) {
            final List<dynamic> antibiogramsData =
                category['antibiograms_data'] ?? [];
            final matchingData = antibiogramsData
                .where((item) => item['sub_category'] == option)
                .toList();

            if (matchingData.isNotEmpty) {
              subcategoryFound = true;
              // Group data by type (gram positive/negative)
              for (var item in matchingData) {
                final String type = item['type'];
                if (!subcategoryData.containsKey(type)) {
                  subcategoryData[type] = [];
                }
                subcategoryData[type]!.add(item);
              }
              break;
            }
          }

          if (subcategoryFound) {
            setState(() {
              // Display the data in a formatted way
              chatMessages.add({
                'sender': 'bot',
                'message': "Data for $option:",
              });

              // Prepare options for Gram types
              dynamicOptions = [];
              if (subcategoryData.containsKey("gram positive")) {
                dynamicOptions.add("Gram Positive");
              }
              if (subcategoryData.containsKey("gram negative")) {
                dynamicOptions.add("Gram Negative");
              }

              if (dynamicOptions.isNotEmpty) {
                chatMessages.add({
                  'sender': 'bot',
                  'message': "Please select the option",
                });
                showDynamicOptions = true;
              } else {
                chatMessages.add({
                  'sender': 'bot',
                  'message': "No Gram data available for $option.",
                });
                dynamicOptions = ["Main Menu"];
                showDynamicOptions = true;
              }
            });
          } else {
            // Handle antibiotic subcategories if not an antibiogram subcategory
            await chatApiService.fetchSubcategoriesFromApi(
                option, setState, this);
            addNavigationOptions(setState);
          }
        }
      }
    }
  }

  void goBack(Function setState) {
    if (chatHistory.isNotEmpty) {
      final previousState = chatHistory.removeLast();
      setState(() {
        chatMessages = List.from(previousState['messages']);
        dynamicOptions = List.from(previousState['options']);
        showDynamicOptions = previousState['showOptions'];
        isFinalYesNo = previousState['isFinalYesNo'];
        isSecondResponse = false;
        addNavigationOptions(setState);
      });
    }
  }

  void goToMainMenu(Function setState) {
    setState(() {
      chatHistory.clear();
      chatMessages.clear();
      dynamicOptions.clear();
      isFinalYesNo = false;
      showDynamicOptions = false;
      isInitialResponse = true;
      isSecondResponse = false;
    });
    // Initialize chat or any other necessary setup
  }

  void addNavigationOptions(Function setState) {
    if (!isInitialResponse) {
      List<String> currentOptions = List.from(dynamicOptions);
      if (!currentOptions.contains("Go Back") &&
          !currentOptions.contains("Main Menu")) {
        if (isSecondResponse) {
          currentOptions.add("Main Menu");
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
}
