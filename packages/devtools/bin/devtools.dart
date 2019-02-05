// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:args/args.dart';
import 'package:http_server/http_server.dart' show VirtualDirectory;
import 'package:meta/meta.dart';
import 'package:path/path.dart' as path;

const argHelp = 'help';
const argMachine = 'machine';
const argPort = 'port';

final argParser = new ArgParser()
  ..addFlag(
    argHelp,
    negatable: false,
    abbr: 'h',
  )
  ..addFlag(
    argMachine,
    negatable: false,
    abbr: 'm',
    help: 'Sets output format to JSON for consumption in tools.',
  )
  ..addOption(
    argPort,
    abbr: 'p',
    help: 'Port to serve DevTools on. '
        'Pass 0 to automatically assign an available port.',
    defaultsTo: '9100',
  );

void main(List<String> arguments) async {
  final args = argParser.parse(arguments);
  if (args[argHelp]) {
    print(argParser.usage);
    return;
  }

  final bool machineMode = args[argMachine];
  final Uri resourceUri = await Isolate.resolvePackageUri(
      Uri(scheme: 'package', path: 'devtools/devtools.dart'));
  final packageDir = path.dirname(path.dirname(resourceUri.toFilePath()));
  final String buildDir = path.join(packageDir, 'build');
  final virDir = new VirtualDirectory(buildDir);

  // Set up a directory handler to serve index.html files.
  virDir.allowDirectoryListing = true;
  virDir.directoryHandler = (dir, request) {
    final indexUri = new Uri.file(dir.path).resolve('index.html');
    virDir.serveFile(new File(indexUri.toFilePath()), request);
  };

  final port = args[argPort] != null ? int.tryParse(args[argPort]) ?? 0 : 0;
  final server = await HttpServer.bind('127.0.0.1', port);

  virDir.serve(server);
  printOutput(
    'Serving DevTools at http://${server.address.host}:${server.port}',
    {
      'method': 'server.started',
      'params': {'host': server.address.host, 'port': server.port}
    },
    machineMode: machineMode,
  );
}

void printOutput(
  String message,
  Object json, {
  @required bool machineMode,
}) {
  print(machineMode ? jsonEncode(json) : message);
}