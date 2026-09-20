import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Resolves the on-disk path for the Drift database file.
///
/// Native Android Caller ID reads this file directly for fast lookups while
/// the Flutter isolate may not be running.
Future<String> resolveDriftDatabasePath({String name = 'tajeerai'}) async {
  if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
    final Directory directory = await getApplicationDocumentsDirectory();

    return p.join(directory.path, '$name.sqlite');
  }

  throw UnsupportedError(
    'Drift database path resolution is not supported on ${Platform.operatingSystem}.',
  );
}
