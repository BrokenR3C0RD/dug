import 'dart:io';

import 'package:dug/dug.dart';
import 'package:dug/src/parse/nodes.dart';
import 'package:dug/src/parse/parser.dart';
import 'package:path/path.dart' as path;
import 'package:source_span/source_span.dart';

typedef LoaderFn = String Function(String);
typedef ResolveFn = String Function(String file, Uri? source);

class LoadException extends SourceSpanException {
  LoadException(dynamic error, FileSpan span) : super('Failed to load: $error', span);
}

class LoadPugException extends MultiSourceSpanException {
  LoadPugException._(super.message, super.span, super.primaryLabel, super.secondarySpans);

  factory LoadPugException(String message, FileSpan span, Iterable<FileSpan> loadStack) {
    final secondarySpans = Map.fromEntries(loadStack.map((entry) => MapEntry(entry, 'included here')));

    return LoadPugException._(message, span, 'error here', secondarySpans);
  }
}

class _IncludeLoader {
  final Node _root;

  final LoaderFn _loadFile;
  final ResolveFn _resolve;

  _IncludeLoader(Node node, {required LoaderFn loadFile, required ResolveFn resolve})
    : _root = node,
      _loadFile = loadFile,
      _resolve = resolve;

  static String defaultResolve(String file, Uri? source) {
    if (source == null) {
      if (path.isRelative(file)) {
        throw Exception('tried to load from relative path when origin path is unknown');
      }
      return path.normalize(file);
    }
    return path.canonicalize(path.absolute(path.dirname(source.toFilePath()), file));
  }

  static String defaultLoad(String file) {
    return File(file).readAsStringSync();
  }

  List<FileSpan> includeStack = [];

  bool _before(Node node, ReplaceFn replace, int _) {
    if (node is! Include && node is! Extends && node is! RawInclude) {
      return true;
    }

    final file = (node as LoadableNode).file;

    try {
      file.fullPath = _resolve(file.path, node.span.file.url);
      file.str ??= _loadFile(file.fullPath!);
    } catch (e) {
      throw LoadException(e, file.span);
    }

    if (node is Include || node is Extends) {
      includeStack.add(node.span);
      try {
        file.ast ??= Parser.fromLexer(Lexer.fromString(file.str!, path: file.fullPath!)).parse();
      } on SourceSpanException catch (e) {
        throw LoadPugException(e.message, e.span! as FileSpan, includeStack.reversed);
      } catch (e) {
        throw LoadException(e, node.span);
      } finally {
        includeStack.removeLast();
      }
    }

    return true;
  }

  bool _after(Node node, ReplaceFn replace, int _) {
    if (node is Include && node.file.ast != null) {
      replace(node.file.ast!.nodes);
    }
    return true;
  }

  Node execute() {
    return _root..walkAST(includeDependencies: true, before: _before, after: _after);
  }
}

extension IncludeLoaderExtension on Node {
  void loadDependencies({
    LoaderFn loadFile = _IncludeLoader.defaultLoad,
    ResolveFn resolvePath = _IncludeLoader.defaultResolve,
  }) => _IncludeLoader(this, loadFile: loadFile, resolve: resolvePath).execute();
}
