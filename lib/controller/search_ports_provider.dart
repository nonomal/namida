import 'dart:async';
import 'dart:isolate';

import 'package:namida/base/ports_provider.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';

class SearchPortsProvider with PortsProviderBase {
  static final SearchPortsProvider inst = SearchPortsProvider._internal();
  SearchPortsProvider._internal();

  final _ports = <MediaType, PortsComm?>{};

  void disposeAll() {
    final ports = _ports.values.whereType<PortsComm>().toList();
    _ports.clear();
    ports.loop(disposePort);
  }

  Future<void> closePorts(MediaType type) async {
    final port = _ports[type];
    if (port != null) {
      await disposePort(port);
      _ports[type] = null;
    }
  }

  Future<SendPort> preparePorts({
    required MediaType type,
    required void Function(dynamic result) onResult,
    required Future<void> Function(SendPort itemsSendPort) isolateFunction,
    bool force = false,
  }) async {
    return await preparePortBase(
      portN: _ports[type],
      onPortNull: () async {
        await closePorts(type);
        _ports[type] = (items: ReceivePort(), search: Completer<SendPort>());
        return _ports[type]!;
      },
      onResult: onResult,
      isolateFunction: isolateFunction,
    );
  }
}
