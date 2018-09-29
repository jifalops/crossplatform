import 'dart:io';
import 'dart:async';
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

  // pubspec.yaml must exist.
  if (pubspecFile.existsSync()) {
    final pubspecLines = pubspecFile.readAsLinesSync();
    Command command;

    // Try to create .packages if it doesn't exist.
    if (!packagesFile.existsSync()) {
      print('`.packages` not found. Creating...');
      command = Command.fromPubspec(pubspecLines, upgrade);
      await command.run(path);
      if (!packagesFile.existsSync()) {
        print('Failed to create `.packages`. Exiting.');
        return;
      }
    }

    // Run get/upgrade if requested and it hasn't been run.
    if ((upgrade || runGet) && command == null) {
      command = Command.fromPubspec(pubspecLines, upgrade);
      int exitCode = await command.run(path);
      if (exitCode != 0) {
        print('Command failed, cannot update versions.');
        return;
      }
    }

    final packages = parsePackageVersions(packagesFile);
    final pubspec = findChanges(pubspecLines, packages);

    if (pubspec.changed) {
      print('The following pubspec.yaml package versions will be changed:');
      if (pubspec.mainChanges.isNotEmpty) {
        print('dependencies:');
        pubspec.mainChanges.forEach((dep) => print('  $dep'));
      }
      if (pubspec.devChanges.isNotEmpty) {
        print('dev_dependencies:');
        pubspec.devChanges.forEach((dep) => print('  $dep'));
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
    print('"$path" is not a package directory.\n');
    print(usage(parser));
  }
}

class Command {
  const Command(this.command, this.args);
  final String command;
  final List<String> args;

  @override
  toString() => '$command ${args.join(' ')}';

  Future<int> run(String path) async {
    print('Running command "$this".');
    print('-----');
    final process = await Process.start(command, args, workingDirectory: path);
    process.stdout.transform(utf8.decoder).listen((data) => stdout.write(data));
    process.stderr.transform(utf8.decoder).listen((data) => stderr.write(data));
    final exitCode = await process.exitCode;
    print('-----');
    return exitCode;
  }

  static Command fromPubspec(List<String> pubspecLines, bool upgrade) {
    String command = 'pub';
    final args = <String>[];
    for (final line in pubspecLines) {
      if (line.trim() == 'flutter:') {
        command = 'flutter';
        args.add('packages');
        break;
      }
    }
    return Command(command, args..add(upgrade ? 'upgrade' : 'get'));
  }
}

/// Finds *versioned* packages in a `.packages` file's contents.
Map<String, String> parsePackageVersions(File packagesFile) {
  return Map.fromEntries(RegExp(r'/(\w+)-([0-9.+]+[-\w]*)/lib/')
      .allMatches(packagesFile.readAsStringSync())
      .map((match) => MapEntry(match.group(1), match.group(2))));
}

/// Finds changes to the version string of *versioned* packages in a
/// `pubspec.yaml` file.
ChangedPubspec findChanges(List<String> lines, Map<String, String> versions) {
  final matcher = RegExp(r'^  (\w+):\s*(.+)');
  final prefixMatcher = RegExp(r'([<>=^|]*)\d');
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
  const ChangedPubspec(this.contents, this.mainChanges, this.devChanges);
  final List<String> contents, mainChanges, devChanges;
  bool get changed => mainChanges.isNotEmpty || devChanges.isNotEmpty;
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
