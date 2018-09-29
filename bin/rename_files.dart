import 'dart:io';
import 'dart:convert';
import 'package:args/args.dart';
import 'package:path/path.dart' as path;

void main(List<String> arguments) {
  final parser = ArgParser();
  parser.addOption('dir',
      abbr: 'd',
      defaultsTo: '.',
      help: 'The root directory to be searched for matching files/dirs.');
  parser.addFlag('prompt',
      defaultsTo: true, help: 'Prompt the user to confirm before renaming.');

  final args = parser.parse(arguments);
  final dir = args['dir'] == '.' ? Directory.current : Directory(args['dir']);
  final prompt = args['prompt'];

  if (args.rest.length == 2) {
    final search = args.rest[0];
    final replace = args.rest[1];
    if (search == replace) {
      print('Error: <search> and <replace> are the same.');
      return;
    }
    final results = findFiles(dir, search);
    print(summarizeResults(results));
    if (results.isNotEmpty) {
      if (prompt) {
        final confirm =
            promptUser('Continue renaming "$search" to "$replace"? [Y/n]');
        if (confirm.isEmpty || confirm.toLowerCase() == 'y') {
          renameAll(results, search, replace);
        }
      } else {
        renameAll(results, search, replace);
      }
    }
  } else {
    stdout.write(usage(parser));
  }
}

String usage(ArgParser parser) => '''
Usage:
  dart rename_files.dart [ARGUMENTS] <search> <replace>

  ARGUMENTS

  ${parser.usage}
''';

String promptUser(String prompt, [bool singleByte = false]) {
  stdout.write('$prompt ');
  return singleByte
      ? utf8.decode([stdin.readByteSync()])
      : stdin.readLineSync(encoding: utf8);
}

List<FileSystemEntity> findFiles(Directory dir, String search) {
  final results = List<FileSystemEntity>();
  // Renaming the current dir causes issues.
  // if (path.basename(dir.path).contains(search)) results.add(dir);
  dir.listSync(recursive: true).forEach((fse) {
    if (!fse.path.contains('.git')) {
      if (path.basename(fse.path).contains(search)) results.add(fse);
    }
  });
  return results;
}

String summarizeResults(List<FileSystemEntity> results) {
  final sb = StringBuffer();
  results.forEach((fse) {
    sb.writeln(fse.path);
  });
  sb.writeln('${results.length} files or directories to rename.');
  return sb.toString();
}

void renameAll(List<FileSystemEntity> results, String oldName, String newName) {
  // Renaming files/dirs must be done in reverse order so that leaf nodes change
  // first.
  results.reversed.forEach((fse) {
    final name = path.basename(fse.path);
    try {
      fse.renameSync(
          path.join(path.dirname(fse.path), name.replaceAll(oldName, newName)));
    } catch (e) {
      stderr.writeln('Failed to rename ${fse.path}.');
      stderr.writeln('$e');
    }
  });
  print('Done. Use your Editor/IDE to safely search and replace within files.');
}
