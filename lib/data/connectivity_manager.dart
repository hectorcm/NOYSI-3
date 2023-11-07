import 'dart:async';
import 'dart:io';

import 'package:code/_di/injector.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:rxdart/subjects.dart';
import 'package:code/utils/extensions.dart';

import '../enums.dart';

BehaviorSubject<ConnectivityResult> onConnectivityChangeController =
    BehaviorSubject();

BehaviorSubject<bool> hasInternetController = BehaviorSubject();

class ConnectivityManager {
  Connectivity? _connectivity;

  ConnectivityManager() {
    _connectivity ??= Connectivity();
  }

  Future<ConnectivityResult> checkConnectivity() async {
    return (await _connectivity?.checkConnectivity()) ?? ConnectivityResult.none;
  }

  ConnectivityManager.initConnectivityAndInternetCheckerWithListeners() {
    _connectivity ??= Connectivity();
    final host = Injector.instance.baseUrl.replaceFirst("https://", "");
    _connectivity!.onConnectivityChanged.listen((ConnectivityResult status) {
      if (status != (onConnectivityChangeController.valueOrNull ?? ConnectivityResult.none)) {
        onConnectivityChangeController
            .sinkAddSafe(status);
      }
    });

    onConnectivityChangeController.listen((ConnectivityResult value) async {
      var hasInternet = false;
      if (value != ConnectivityResult.none) {
        hasInternet = await _checkConnectionToHost(host);
      }
      hasInternetController.sinkAddSafe(hasInternet);
    });

    Timer.periodic(const Duration(seconds: 5), (timer) async {
      final hasInternet = await _checkConnectionToHost(host);
      hasInternetController.sinkAddSafe(hasInternet);
    });
  }

  Future<bool> _checkConnectionToHost(String host) async {
    try {
      final result = await InternetAddress.lookup(host);
      if(result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        return true;
      }
      return false;
    } on SocketException catch(ex) {
      if (kDebugMode) {
        print("SocketException Connection Check Routine: ${ex.toString()}");
      }
      return false;
    }
  }
}
