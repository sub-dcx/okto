import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final GlobalKey webViewKey = GlobalKey();

  InAppWebViewController? webViewController;

  InAppWebViewGroupOptions options = InAppWebViewGroupOptions(
    crossPlatform: InAppWebViewOptions(
      useShouldOverrideUrlLoading: true,
      mediaPlaybackRequiresUserGesture: false,
    ),
    android: AndroidInAppWebViewOptions(
      useHybridComposition: true,
    ),
    ios: IOSInAppWebViewOptions(
      allowsInlineMediaPlayback: true,
    ),
  );

// cannot have null value
  late PullToRefreshController pullToRefreshController;
  String url = "";
  double progress = 0;

// input field controller
  final urlController = TextEditingController();
  late String jsCode;

  Future<void> loadJsCode() async {
    jsCode = await rootBundle.loadString('assets/bundle.js');
    print("converted build to string");
  }

  void onSubmitted(String value) {
    var url = Uri.parse(value);
    if (url.scheme.isEmpty) {
      url = Uri.parse("https://www.google.com/search?q=$value");
    }

    webViewController?.loadUrl(
      urlRequest: URLRequest(url: url),
    );

    webViewController?.reload();
    print("URL $url");
  }

  @override
  void initState() {
    super.initState();
    loadJsCode();
    pullToRefreshController = PullToRefreshController(
      options: PullToRefreshOptions(
        color: Colors.green,
      ),
      onRefresh: () async {
        if (Platform.isAndroid) {
          webViewController?.reload();
        } else if (Platform.isIOS) {
          webViewController?.loadUrl(
            urlRequest: URLRequest(url: await webViewController?.getUrl()),
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("OKTO Wallet Cosmos-Kit")),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            //
            TextField(
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search)),
              controller: urlController,
              keyboardType: TextInputType.url,
              // onSubmitted: (value) {
              //   var url = Uri.parse(value);
              //   if (url.scheme.isEmpty) {
              //     url = Uri.parse("https://www.google.com/search?q=$value");
              //   }

              //   webViewController?.loadUrl(
              //     urlRequest: URLRequest(url: url),
              //   );
              //   print("URL $url");
              // },
              onSubmitted: (value) {
                onSubmitted(value);
              },
            ),
            Expanded(
              child: Stack(
                children: [
                  InAppWebView(
                    key: webViewKey,
                    // initialUrlRequest:
                    //     URLRequest(url: Uri.parse("https://osmosis.zone/")),
                    initialData: InAppWebViewInitialData(data: "JS Injection"),

                    initialOptions: options,
                    pullToRefreshController: pullToRefreshController,
                    onWebViewCreated: (controller) {
                      webViewController = controller;

                      print("webview created");
                      controller.addJavaScriptHandler(
                        handlerName: 'customEvent',
                        callback: (args) {
                          print(args);
                          String signDoc = args[0];
                          String signerAddress = args[1];

                          print(
                              'Received customEvent: signDoc=$signDoc, signerAddress=$signerAddress');
                        },
                      );
                    },
                    onLoadStart: (controller, url) {
                      setState(() {
                        this.url = url.toString();
                        urlController.text = this.url;
                      });
                    },
                    shouldOverrideUrlLoading:
                        (controller, navigationAction) async {
                      var uri = navigationAction.request.url!;
                      if (![
                        "http",
                        "https",
                        "file",
                        "chrome",
                        "data",
                        "javascript",
                        "about"
                      ].contains(uri.scheme)) {
                        Uri url = Uri.parse(uri.toString());
                        print("url $url");
                        if (await canLaunchUrl(url)) {
                          await launchUrl(url);
                          return NavigationActionPolicy.CANCEL;
                        }
                      }
                      return NavigationActionPolicy.ALLOW;
                    },

                    onLoadStop: (controller, url) async {
                      pullToRefreshController.endRefreshing();
                      setState(() {
                        this.url = url.toString();
                        urlController.text = this.url;
                      });

                      await controller.injectJavascriptFileFromAsset(
                          assetFilePath: "assets/inject.js");
                      print("injected javascript ");
                    },
                    onLoadError: (controller, url, code, message) {
                      pullToRefreshController.endRefreshing();
                    },
                    onProgressChanged: (controller, progress) {
                      if (progress == 100) {
                        pullToRefreshController.endRefreshing();
                      }
                      setState(() {
                        this.progress = progress / 100;
                        urlController.text = url;
                      });
                    },
                    onUpdateVisitedHistory: (controller, url, androidIsReload) {
                      setState(() {
                        this.url = url.toString();
                        urlController.text = this.url;
                      });
                    },
                    // whatever is returned in the console (result) gets logged in the app as OUTPUT
                    onConsoleMessage: (controller, consoleMessage) {
                      // Handle the custom event message
                      if (consoleMessage.message.contains('customEvent')) {
                        // Extract and parse the custom event data
                        var eventData = consoleMessage.message;
                        var jsonData = jsonDecode(eventData);
                        var signDoc = jsonData['detail']['signDoc'];
                        var signerAddress = jsonData['detail']['signerAddress'];

                        print(
                            "Received customEvent: signDoc=$signDoc, signerAddress=$signerAddress");
                      }
                      print(consoleMessage);
                    },
                  ),
                  progress < 1.0
                      ? LinearProgressIndicator(value: progress)
                      : Container(),
                ],
              ),
            ),
            ButtonBar(
              alignment: MainAxisAlignment.center,
              children: <Widget>[
                ElevatedButton(
                  child: const Icon(Icons.arrow_back),
                  onPressed: () {
                    webViewController?.goBack();
                  },
                ),
                ElevatedButton(
                  child: const Icon(Icons.arrow_forward),
                  onPressed: () {
                    webViewController?.goForward();
                  },
                ),
                ElevatedButton(
                  child: const Icon(Icons.refresh),
                  onPressed: () {
                    webViewController?.reload();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
