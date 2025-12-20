import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:qr_scanner_app/constants/colors.dart';
import 'package:qr_scanner_app/constants/strings.dart';
import 'package:qr_scanner_app/keycloak/api_client.dart';
import 'package:qr_scanner_app/utilities/connectivity_helper.dart';
import 'package:webview_flutter/webview_flutter.dart';

class WebViewPage extends StatefulWidget {
  const WebViewPage({super.key});

  @override
  WebViewPageState createState() => WebViewPageState();
}

class WebViewPageState extends State<WebViewPage> {
  late final WebViewController _controller;
  bool _isWebViewReady = false;
  final ValueNotifier<bool> _canGoForward = ValueNotifier(false);
  final ValueNotifier<bool> _canGoBack = ValueNotifier(false);
  bool _hasInternet = true;

  get apiClient => null;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
    _checkInternetConnection();
  }

  Future<Map<String, dynamic>> postTreatmentGuidelines() async {
    const String endpoint = 'treatment_guidelines';
    debugPrint('API called for treatment guidelines; endpoint: $endpoint');
    try {
      final response = await ApiClient(baseUrl: Strings.baseUrl).post(endpoint);
      debugPrint(
          'Response Status Code for treatment guidelines: ${response.statusCode}');
      debugPrint('Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        if (responseData['status'] == 200) {
          return responseData;
        } else {
          throw Exception(
              responseData['message'] ?? 'Unexpected response from the server');
        }
      } else {
        throw Exception(
            'HTTP Error: ${response.statusCode}. Unable to post data.');
      }
    } catch (error) {
      debugPrint('Error posting treatment guidelines data: $error');
      throw Exception('Failed to post treatment guidelines data: $error');
    }
  }

  Future<void> _initializeWebView() async {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(Uri.parse('https://amrtg.icmr.org.in/chapters.html'))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (url) {
            _controller.runJavaScript(
                "document.getElementById('sidebar').style.display='none';"
                "document.getElementById('homebt').style.display='none';");
            setState(() {
              _isWebViewReady = true;
            });
            _updateNavigationState();
          },
          onNavigationRequest: (NavigationRequest request) {
            _updateNavigationState();
            return NavigationDecision.navigate;
          },
        ),
      );
  }

  Future<void> _checkInternetConnection() async {
    _hasInternet = await ConnectivityHelper.isOffline() ? false : true;
    if (_hasInternet) {
      postTreatmentGuidelines();
      debugPrint('API clled for treatment');
    }
    setState(() {});
  }

  Future<void> _updateNavigationState() async {
    final canGoBack = await _controller.canGoBack();
    final canGoForward = await _controller.canGoForward();
    _canGoBack.value = canGoBack;
    _canGoForward.value = canGoForward;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        titleSpacing: 12.5,
        title: const Text(
          'ICMR Treatment Guidelines',
          style: TextStyle(
              fontWeight: FontWeight.w500, fontSize: 16, color: Colors.white),
        ),
        actions: <Widget>[
          NavigationControls(_controller, _canGoBack, _canGoForward),
        ],
      ),
      body: _hasInternet
          ? _isWebViewReady
              ? WebViewWidget(controller: _controller)
              : const Center(
                  child: CircularProgressIndicator(),
                )
          : const Center(
              child: Text(
                'No Internet Available',
                style: TextStyle(fontSize: 18),
              ),
            ),
    );
  }
}

class NavigationControls extends StatelessWidget {
  final WebViewController controller;
  final ValueNotifier<bool> canGoBack;
  final ValueNotifier<bool> canGoForward;

  const NavigationControls(this.controller, this.canGoBack, this.canGoForward,
      {super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        ValueListenableBuilder<bool>(
          valueListenable: canGoBack,
          builder: (context, value, child) {
            return IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: value
                  ? () async {
                      if (await controller.canGoBack()) {
                        await controller.goBack();
                        await (context
                            .findAncestorStateOfType<WebViewPageState>()
                            ?._updateNavigationState());
                      }
                    }
                  : null, // Disable the button if value is false
            );
          },
        ),
        ValueListenableBuilder<bool>(
          valueListenable: canGoForward,
          builder: (context, value, child) {
            return IconButton(
              icon: const Icon(Icons.arrow_forward, color: Colors.white),
              onPressed: value
                  ? () async {
                      if (await controller.canGoForward()) {
                        await controller.goForward();
                        await (context
                            .findAncestorStateOfType<WebViewPageState>()
                            ?._updateNavigationState());
                      }
                    }
                  : null, // Disable the button if value is false
            );
          },
        ),
      ],
    );
  }
}
