import 'dart:io';
import 'dart:convert';
import 'package:args/args.dart';
import 'package:colorize/colorize.dart';

void main(List<String> args) async {
  final parser = ArgParser()
    ..addFlag('help',
        abbr: 'h',
        defaultsTo: false,
        negatable: false,
        help: 'Print this help message.')
    ..addFlag('prompt',
        defaultsTo: true,
        help: 'Prompt the user to confirm before making changes.')
    ..addFlag('get',
        abbr: 'g',
        defaultsTo: false,
        negatable: false,
        help:
            'Runs `pub get` or `flutter packages get` on the package before processing.')
    ..addFlag('upgrade',
        abbr: 'u',
        defaultsTo: false,
        negatable: false,
        help:
            'Runs `pub upgrade` or `flutter packages upgrade` on the package before processing.'
            ' This option overrides --get.')
    ..addFlag('force',
        abbr: 'f',
        defaultsTo: false,
        negatable: false,
        help: 'Equivalent to --upgrade --no-prompt');

  ArgResults argv;
  try {
    argv = parser.parse(args);
  } catch (e) {
    print(usage(parser));
    return;
  }
  if (argv['help'] || argv.rest.length > 1) {
    print(usage(parser));
    return;
  }

  final force = argv['force'];
  final prompt = !force && argv['prompt'];
  final upgrade = force || argv['upgrade'];
  final runGet = !upgrade && argv['get'];
  final path = argv.rest.length == 1 ? argv.rest.first : '.';

  final packagesFile = File('$path/.packages');
  final pubspecFile = File('$path/pubspec.yaml');

  if (packagesFile.existsSync() && pubspecFile.existsSync()) {
    String packagesString = packagesFile.readAsStringSync();

    if (upgrade || runGet) {
      String command;
      final commandArgs = <String>[];
      if (packagesString.contains(RegExp(r'\sflutter:', multiLine: true))) {
        command = 'flutter';
        commandArgs.add('packages');
      } else {
        command = 'pub';
      }
      commandArgs.add(upgrade ? 'upgrade' : 'get');
      print('Running command "$command ${commandArgs.join()}"');
      print('-----');
      final process =
          await Process.start(command, commandArgs, workingDirectory: path);
      process.stdout
          .transform(utf8.decoder)
          .listen((data) => stdout.write(data));
      process.stderr
          .transform(utf8.decoder)
          .listen((data) => stderr.write(data));
      final exitCode = await process.exitCode;
      print('-----');
      if (exitCode == 0) {
        packagesString = packagesFile.readAsStringSync();
      } else {
        print('Command failed, bailing on version upgrades.');
        return;
      }
    }

    final packages = parseVersions(packagesString);
    final pubspec = findChanges(pubspecFile, packages);
    if (pubspec.changed) {
      print('The following pubspec.yaml package versions will be changed:');
      if (pubspec.mainDepsChanges.isNotEmpty) {
        print('dependencies:');
        pubspec.mainDepsChanges.forEach((dep) => print('  $dep'));
      }
      if (pubspec.devDepsChanges.isNotEmpty) {
        print('dev_dependencies:');
        pubspec.devDepsChanges.forEach((dep) => print('  $dep'));
      }
      bool confirmed = true;
      if (prompt) {
        final reponse = promptUser('Continue with changes? [y/N]');
        confirmed = reponse.toLowerCase() == 'y';
      }
      if (confirmed) {
        pubspecFile.writeAsStringSync(pubspec.contents.join('\n'), flush: true);
      }
    } else {
      print('pubspec.yaml versions are already up to date!');
    }
  } else {
    print('"$path" is not a package directory.');
    print(usage(parser));
  }
}

/// Finds *versioned* packages in a `.packages` file's contents.
Map<String, String> parseVersions(String packagesString) {
  return Map.fromEntries(RegExp(r'/(\w+)-([0-9.+]+[-\w]*)/lib/')
      .allMatches(packagesString)
      .map((match) => MapEntry(match.group(1), match.group(2))));
}

/// Finds changes to the version string of *versioned* packages in a
/// `pubspec.yaml` file.
ChangedPubspec findChanges(File pubspecFile, Map<String, String> versions) {
  final matcher = RegExp(r'^  (\w+):\s*(.+)');
  final prefixMatcher = RegExp(r'([<>=^|]*)\d');
  final lines = pubspecFile.readAsLinesSync();
  final mainChanges = <String>[];
  final devChanges = <String>[];
  int index = 0;
  while (index < lines.length) {
    final isMainDepsHeader = lines[index].trimRight() == 'dependencies:';
    final isDevDepsHeader = lines[index].trimRight() == 'dev_dependencies:';
    if (isMainDepsHeader || isDevDepsHeader) {
      int subIndex = index + 1;
      while (subIndex < lines.length &&
          (lines[subIndex].isEmpty || lines[subIndex].startsWith('  '))) {
        final match = matcher.firstMatch(lines[subIndex]);
        if (match != null) {
          assert(versions.containsKey(match.group(1)));
          final pkg = match.group(1);
          final oldVersion = match.group(2);
          final prefix = prefixMatcher.firstMatch(oldVersion)?.group(1) ?? '';
          final newVersion = '${prefix}${versions[pkg]}';
          if (oldVersion != newVersion) {
            final change =
                '$pkg: ${Colorize(oldVersion)..red()} ${Colorize(newVersion)..green()}';
            if (isMainDepsHeader) {
              mainChanges.add(change);
            } else if (isDevDepsHeader) {
              devChanges.add(change);
            }
            lines[subIndex] =
                lines[subIndex].replaceFirst(oldVersion, newVersion);
          }
        }
        subIndex++;
      }
      index = subIndex;
    } else {
      index++;
    }
  }
  return ChangedPubspec(lines, mainChanges, devChanges);
}

class ChangedPubspec {
  const ChangedPubspec(
      this.contents, this.mainDepsChanges, this.devDepsChanges);
  final List<String> contents, mainDepsChanges, devDepsChanges;
  bool get changed => mainDepsChanges.isNotEmpty || devDepsChanges.isNotEmpty;
}

String promptUser(String prompt, [bool singleByte = false]) {
  stdout.write('$prompt ');
  return singleByte
      ? utf8.decode([stdin.readByteSync()])
      : stdin.readLineSync(encoding: utf8);
}

String usage(ArgParser parser) => '''
update-package.dart [arguments] [directory]

${parser.usage}
''';
