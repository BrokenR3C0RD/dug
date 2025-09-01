// Small pieces implemented by AI
// Reimplementation of pug-lexer

import 'dart:io';
import 'dart:math';

import 'package:dug/src/lex/char.dart';
import 'package:dug/src/lex/tokens.dart';
import 'package:jsparser/jsparser.dart';
import 'package:source_span/source_span.dart';
import 'package:string_scanner/string_scanner.dart';

typedef _TokenCons<T extends Token> = T Function(FileSpan);

extension on FileSpan {
  FileSpan trim() {
    final matches = RegExp(r'^(\s*)(.+?)(\s*)$', dotAll: true, multiLine: true).firstMatch(text);
    if(matches == null) return this;
    final trimStart = matches.group(1)?.length ?? 0;
    final trimEnd = matches.group(3)?.length ?? 0;

    return subspan(trimStart, length - trimEnd);
  }
}

class LexException implements Exception {
  final SourceSpan span;
  final String message;

  LexException(this.span, this.message);

  @override
  String toString() {
    return 'LexException: ${span.message(message)}';
  }
}

class Lexer {
  final SpanScanner _scanner;
  final bool _interpolated;
  final SourceFile file;

  final _tokens = <Token>[];
  final _whitespaceRe = RegExp(r'[ \n\t]');
  final _quoteRe = RegExp('[\'"]');

  RegExp? _indentRe;

  List<Token> get tokens => List.unmodifiable(_tokens);

  final _indentStack = <int>[0];
  var _ended = false;
  var _interpolationAllowed = true;

  Lexer(this._scanner, {bool interpolated = false}) : _interpolated = interpolated, file = _scanner.emptySpan.file;

  Lexer.fromString(String source, {bool interpolated = false}) : this(SpanScanner(source), interpolated: interpolated);
  Lexer.fromFile(File file) : this(SpanScanner(file.readAsStringSync(), sourceUrl: file.uri));

  T? _scan<T extends Token>(Pattern pattern, _TokenCons<T> type) {
    if (_scanner.scan(pattern)) {
      return type(_scanner.lastSpan!.trim());
    }
    return null;
  }

  T? _scanEndOfLine<T extends Token>(Pattern pattern, _TokenCons<T> cons) {
    final before = _scanner.state;
    if (!_scanner.scan(pattern)) return null;

    final matchedSpan = _scanner.lastSpan!;

    final nextChar = _scanner.peekCodePoint();
    if (nextChar == ':'.codeUnitAt(0)) {
      return cons(matchedSpan);
    }

    _scanner.scan(RegExp(r'[ \t]*'));

    final ended = _scanner.isDone;
    final atNewline = _scanner.peekCodePoint() == '\n'.codeUnitAt(0);

    if (ended || atNewline) {
      return cons(matchedSpan);
    }

    _scanner.state = before;
    return null;
  }

  bool _colon() {
    final tok = _scan(RegExp(': +'), ColonToken.new);
    if (tok != null) {
      _tokens.add(tok);
      return true;
    }
    return false;
  }

  bool _blank() => _scanner.scan(RegExp(r'\n[ \t]*(?=\n|$)'));

  bool _eos() {
    if (!_scanner.isDone) return false;
    if (_interpolated) _scanner.error('End of line was reached with no closing bracket for interpolation');

    final span = _scanner.emptySpan;
    while (_indentStack.isNotEmpty && _indentStack.first > 0) {
      _tokens.add(OutdentToken(_scanner.emptySpan));
      _indentStack.removeAt(0);
    }

    _tokens.add(EndOfSourceToken(span));
    _ended = true;

    return true;
  }

  bool _endInterpolation() {
    if (_interpolated && _scanner.scan(']')) {
      _ended = true;
      return true;
    }
    return false;
  }

  bool _yield() {
    final tok = _scanEndOfLine('yield', YieldToken.new);

    if (tok != null) {
      _tokens.add(tok);
      return true;
    }

    return false;
  }

  bool _doctype() {
    final tok = _scanEndOfLine(RegExp('doctype *([^\n]*)'), DoctypeToken.new);

    if (tok != null) {
      _tokens.add(tok);
      return true;
    }
    return false;
  }

  void _bracketExpression([int offset = -1]) {
    _scanner.position += offset;
    _scanner.expect(RegExp(r'[\(\{\[]'), name: '`[`, `(`, or `{`');
    final start = _scanner.lastSpan!.text;

    final end = switch (start) {
      '(' => ')',
      '{' => '}',
      '[' => ']',
      _ => throw StateError('unreachable'),
    };

    try {
      parseUntilScanner(_scanner, end);

      if (!_scanner.scan(end)) {
        _scanner.error('Expected closing bracket $end');
      }
    } on CharacterParserException catch (ex) {
      final idx = ex.index;

      if (ex.code == 'CHARACTER_PARSER:END_OF_STRING_REACHED') {
        _scanner.error('The end of the string reached with no closing bracket $end found.', position: idx);
      } else if (ex.code == 'CHARACTER_PARSER:MISMATCHED_BRACKET') {
        _scanner.error(ex.message, position: idx);
      } else {
        _scanner.error(ex.message, position: idx);
      }
    }
  }

  bool _assertExpression(FileSpan expr, {bool noThrow = false}) {
    try {
      final _ = parsejs(expr.text, parseAsExpression: true);
      return true;
    } on ParseError catch (e) {
      if (noThrow) return false;

      final startOffset = (e.startOffset ?? e.endOffset);
      final endOffset = e.endOffset;
      print(tokens.join('\n'));
      throw SourceSpanException('Invalid expression: ${e.message}', expr.subspan(startOffset, endOffset));
    }
  }

  bool _assertExpressionArray(FileSpan expr) {
    try {
      final _ = parsejs('[${expr.text}]', parseAsExpression: true);
      return true;
    } on ParseError catch (e) {
      final startOffset = (e.startOffset ?? e.endOffset) - 2;
      final endOffset = e.endOffset - 2;
      throw SourceSpanException('Invalid expression: ${e.message}', expr.subspan(startOffset, endOffset));
    }
  }

  Match? _scanIndentation() {
    final start = _scanner.state;
    if (_indentRe != null) {
      _scanner.scan(_indentRe!);
    } else {
      final tabRe = RegExp('\n(\t*) *');
      final spaceRe = RegExp('\n( *)');
      if (_scanner.scan(tabRe) && _scanner.lastMatch!.group(1)!.isNotEmpty) {
        _indentRe = tabRe;
      } else {
        _scanner.state = start;
        if (_scanner.scan(spaceRe) && _scanner.lastMatch!.group(1)!.isNotEmpty) {
          _indentRe = spaceRe;
        }
      }
    }

    final match = _scanner.lastMatch;
    _scanner.state = start;
    return match;
  }

  bool _pipelessText() {
    // skip empty lines
    while (_blank()) {}

    final match = _scanIndentation();
    final indents = match?.group(1)?.length ?? 0;
    if (indents <= _indentStack.first) return false;

    final lineRegex = RegExp(r'\n.*(?=\n|$)');
    final entryState = _scanner.state;

    final parts = <dynamic>[];
    parts.add(StartPipelessTextToken(_scanner.emptySpan));

    final minIndent = _indentStack.first + 1;
    int? minIndentInBlock;

    while (!_scanner.isDone) {
      final previousState = _scanner.state;

      _scanner.scan(lineRegex);

      final span = _scanner.lastSpan!;
      if (span.text.trim().isNotEmpty) {
        final indent = _indentRe!.matchAsPrefix(span.text)?.group(1)?.length;
        if (indent == null || indent < minIndent) {
          _scanner.state = previousState;
          break;
        }

        minIndentInBlock ??= indent;
        minIndentInBlock = min(minIndentInBlock, indent);
        parts.add(span);
      }

      if (!_scanner.isDone) {
        parts.add(EndOfLineToken(_scanner.spanFromPosition(_scanner.position, _scanner.position + 1)));
      }
    }

    if (minIndentInBlock == null) {
      _scanner.state = entryState;
      return false;
    }

    final last = parts.lastIndexWhere((part) => part is FileSpan);

    for (final part in parts.take(last + 1)) {
      switch (part) {
        case final FileSpan line:
          _addText(TextToken.new, SpanScanner.within(line.length == 0 ? line : line.subspan(minIndentInBlock + 1)));

        case final Token tok:
          _tokens.add(tok);
      }
    }

    _tokens.add(EndPipelessTextToken(_scanner.emptySpan));
    return true;
  }

  bool _interpolation() {
    if (_scanner.scan(RegExp(r'\#\{'))) {
      final start = _scanner.lastSpan!;
      _bracketExpression(-1);
      final end = _scanner.lastSpan!;

      final tok = InterpolationToken(end.expand(start));
      _assertExpression(tok.span.subspan(2, tok.span.length - 1));
      _tokens.add(tok);

      return true;
    }
    return false;
  }

  bool _case() {
    final tok = _scanEndOfLine(RegExp('case +([^\n]+)'), CaseToken.new);
    if (tok != null) {
      _assertExpression(tok.span.subspan(5));
      _tokens.add(tok);
      return true;
    }

    if (_scanner.scan(RegExp(r'case\b'))) {
      _scanner.error('missing expression for case');
    }

    return false;
  }

  bool _when() {
    final tok = _scanEndOfLine(RegExp('when +([^:\n]+)'), WhenToken.new);
    if (tok != null) {
      final start = tok.span.start;
      final exprStart = start.offset + 5;

      var parser = parseString(_scanner.substring(exprStart));

      while (parser.isNesting() || parser.isString) {
        if (!_scanner.scan(RegExp(':([^:\n]+)'))) break;
        parser = parseString(_scanner.substring(exprStart));
      }

      final newTok = WhenToken(tok.span.expand(_scanner.emptySpan));
      _assertExpression(newTok.span.subspan(5));
      _tokens.add(newTok);
      return true;
    }

    if (_scanner.scan(RegExp(r'when\b'))) {
      _scanner.error('Missing expression for when');
    }

    return false;
  }

  bool _default() {
    final tok = _scanEndOfLine("default", DefaultToken.new);
    if (tok != null) {
      _tokens.add(tok);
      return true;
    }
    if (_scanner.scan(RegExp(r'default\b'))) {
      _scanner.error('default should not have an expression');
    }

    return false;
  }

  bool _path() {
    final tok = _scanEndOfLine(RegExp(' ([^\n]+)'), PathToken.new);
    if (tok != null && tok.path.isNotEmpty) {
      _tokens.add(tok);
      return true;
    }
    return false;
  }

  bool _extends() {
    final tok = _scan(RegExp(r'extends?(?= |\n|$)'), ExtendsToken.new);
    if (tok != null) {
      _tokens.add(tok);
      if (!_path()) {
        _scanner.error('missing path for extends');
      }
      return true;
    }

    if (_scanner.scan(RegExp(r'extends\b'))) {
      _scanner.error('malformed extends');
    }
    return false;
  }

  bool _append() {
    final saved = _scanner.state;

    if (!_scanner.scan(RegExp(r'(?:block +)?append +'))) {
      return false;
    }

    final keyword = _scanner.lastSpan!;

    if (!_scanner.scan(RegExp(r'[^\n]+(?=\n|//|$)'))) {
      _scanner.state = saved;
      return false;
    }

    final nameSpan = _scanner.lastSpan!.trim();

    if (nameSpan.text.isEmpty) {
      _scanner.state = saved;
      return false;
    }

    _tokens.add(BlockToken.append(keyword.expand(nameSpan), nameSpan));

    _scanner.scan(RegExp(r'[ \t]*'));
    _scanner.scan(RegExp(r'//[^\n]*'));

    return true;
  }

  bool _prepend() {
    final saved = _scanner.state;

    if (!_scanner.scan(RegExp(r'(?:block +)?prepend +'))) {
      return false;
    }

    final keyword = _scanner.lastSpan!;

    if (!_scanner.scan(RegExp(r'[^\n]+(?=\n|//|$)'))) {
      _scanner.state = saved;
      return false;
    }

    final nameSpan = _scanner.lastSpan!.trim();

    if (nameSpan.text.isEmpty) {
      _scanner.state = saved;
      return false;
    }

    _tokens.add(BlockToken.prepend(keyword.expand(nameSpan), nameSpan));

    _scanner.scan(RegExp(r'[ \t]*'));
    _scanner.scan(RegExp(r'//[^\n]*'));

    return true;
  }

  bool _block() {
    final saved = _scanner.state;

    if (!_scanner.scan(RegExp(r'block +'))) {
      return false;
    }

    final keyword = _scanner.lastSpan!;

    if (!_scanner.scan(RegExp(r'[^\n]+(?=\n|//|$)'))) {
      _scanner.state = saved;
      return false;
    }

    final nameSpan = _scanner.lastSpan!.trim();

    if (nameSpan.text.isEmpty) {
      _scanner.state = saved;
      return false;
    }

    _tokens.add(BlockToken.replace(keyword.expand(nameSpan), nameSpan));

    _scanner.scan(RegExp(r'[ \t]*'));
    _scanner.scan(RegExp(r'//[^\n]*'));

    return true;
  }

  bool _mixinBlock() {
    final tok = _scanEndOfLine('block', MixinBlockToken.new);
    if (tok != null) {
      _tokens.add(tok);
      return true;
    }
    return false;
  }

  void _skipWhitespace(SpanScanner scanner) {
    while (scanner.scan(_whitespaceRe)) {}
  }

  (FileSpan value, bool mustEscape)? _attributeValue(SpanScanner attrScanner) {
    _skipWhitespace(attrScanner);
    if (attrScanner.isDone) return null;

    var mustEscape = !attrScanner.scan('!');

    if (!attrScanner.scan('=')) {
      if (!mustEscape) attrScanner.expect('=');
      return null;
    }

    _skipWhitespace(attrScanner);

    var done = false;
    var state = defaultState();
    final dot = '.'.codeUnitAt(0);
    final comma = ','.codeUnitAt(0);
    final startState = attrScanner.state;

    while (!attrScanner.isDone) {
      if (!(state.isNesting() || state.isString)) {
        if (attrScanner.scan(_whitespaceRe)) {
          done = false;

          final last = attrScanner.state;
          _skipWhitespace(attrScanner);

          final peek = attrScanner.peekChar();
          if (peek == null) break;

          final ch = String.fromCharCode(peek);

          final isNotPunctuator = !isPunctuator(ch);
          final isQuote = _quoteRe.matchAsPrefix(ch) != null;
          final isColon = ch == ':';
          final isSpreadOperator = peek == dot && attrScanner.peekChar(1) == dot && attrScanner.peekChar(2) == dot;

          if ((isNotPunctuator || isQuote || isColon || isSpreadOperator) &&
              _assertExpression(attrScanner.spanFrom(startState, last), noThrow: true)) {
            done = true;
          }
          if (done || attrScanner.isDone) break;
        }

        if (attrScanner.peekChar() == comma && _assertExpression(attrScanner.spanFrom(startState), noThrow: true)) {
          break;
        }
      }

      state = parseChar(String.fromCharCode(attrScanner.readChar()), state, attrScanner.position);
    }

    final val = attrScanner.spanFrom(startState);
    _assertExpression(val);

    return (val.trim(), mustEscape);
  }

  void _attribute(SpanScanner attrScanner) {
    _skipWhitespace(attrScanner);

    if (attrScanner.isDone) return;
    attrScanner.scan(_quoteRe);

    final start = attrScanner.state;
    final quote = attrScanner.lastSpan?.text;

    final scan = quote != null ? attrScanner.scan(RegExp('[^$quote]*')) : attrScanner.scan(RegExp(r'[^\=\!\, \t]*'));
    if (scan == false) throw Exception();
    if (quote != null) attrScanner.expect(quote);

    final key = attrScanner.spanFrom(start);
    final resp = _attributeValue(attrScanner);
    final Object value;
    final bool mustEscape;

    if (resp == null) {
      value = true;
      mustEscape = true;
    } else {
      (value, mustEscape) = resp;
    }

    final tok = AttributeToken(attrScanner.spanFrom(start), key, value, mustEscape: mustEscape);
    _tokens.add(tok);

    _skipWhitespace(attrScanner);
    attrScanner.scan(',');
  }

  void _assertNestingCorrect(FileSpan exp) {
    final r = parseString(exp.text);
    if (r.isNesting()) {
      throw SourceSpanException('Nesting must match', exp);
    }
  }

  bool _attrs() {
    final start = _scanner.emptySpan;

    if (!_scanner.scan(RegExp(r'\('))) return false;
    _bracketExpression(-1);

    final str = start.expand(_scanner.emptySpan);
    _assertNestingCorrect(str);
    _tokens.add(StartAttributesToken(str.subspan(0, 1)));

    final attrScanner = SpanScanner.within(str.subspan(1, str.length - 1));
    while (!attrScanner.isDone) {
      _attribute(attrScanner);
    }

    _tokens.add(EndAttributesToken(str.subspan(str.length - 1)));
    return true;
  }

  bool _filter({bool inInclude = false}) {
    final tok = _scan(RegExp(r':([\w\-]+)'), FilterToken.new);
    if (tok == null) return false;

    _tokens.add(tok);
    _attrs();

    if (!inInclude) {
      _interpolationAllowed = false;
      _pipelessText();
    }

    return true;
  }

  bool _include() {
    final tok = _scan(RegExp(r'include(?=:| |$|\n)'), IncludeToken.new);
    if (tok != null) {
      _tokens.add(tok);

      while (_filter(inInclude: true)) {}
      if (!_path()) {
        if (_scanner.scan(RegExp(r'[^ \n]+'))) {
          _scanner.error('unknown');
        } else {
          _scanner.error('missing path for include');
        }
      }
      return true;
    }

    if (_scanner.scan(RegExp(r'include\b'))) {
      _scanner.error('malformed include');
    }

    return false;
  }

  bool _mixin() {
    final tok = _scan(RegExp(r'mixin +([-\w]+)(?: *\((.*)\))? '), MixinToken.new);
    if (tok == null) {
      return false;
    }

    _tokens.add(tok);

    return true;
  }

  bool _call() {
    final start = _scanner.state;
    final bool isInterpolated;
    FileSpan? args;

    if (_scanner.scan(RegExp(r'\+(\s*)(([-\w]+)|(#\{))'))) {
      final match = _scanner.lastMatch!;

      if (match.group(3)?.isNotEmpty == true) {
        isInterpolated = false;
      } else {
        _bracketExpression(-1);
        isInterpolated = true;
      }

      final srcEnd = _scanner.state;

      if (_scanner.scan(RegExp(r' *\('))) {
        final argStart = _scanner.state;
        _bracketExpression(-1);
        final range = _scanner.spanFrom(argStart);
        final rangeInner = range.subspan(0, range.length - 1);
        if (RegExp(r'\s*[-\w]+ *=').matchAsPrefix(rangeInner.text) == null) {
          _assertExpressionArray(rangeInner);
          args = rangeInner;
        }
      }

      _tokens.add(
        CallToken(
          _scanner.spanFrom(start),
          _scanner.spanFrom(start, srcEnd).subspan(1),
          args?.trim(),
          isInterpolated: isInterpolated,
        ),
      );
      return true;
    }

    return false;
  }

  bool _conditional() {
    final start = _scanner.state;
    if (_scanner.scan(RegExp(r'(if|unless|else +if|else)\b(?=[^\n]*)'))) {
      final type = _scanner.lastMatch!.group(1)!.replaceAll(RegExp(' +'), ' ');
      _scanner.scan(RegExp(r'[^\n]+'));

      final expr = _scanner.lastSpan?.trim();

      if (type == 'else') {
        if (expr != null) {
          _scanner.error(
            '`else` cannot have a condition, perhaps you meant `else if`',
            position: expr.start.offset,
            length: expr.length,
          );
        }

        _tokens.add(ElseToken(_scanner.spanFrom(start)));
        return true;
      }

      if (expr == null) {
        _scanner.error('`$type` is missing a condition');
      }

      _assertExpression(expr);
      final span = _scanner.spanFrom(start);

      _tokens.add(switch (type) {
        'if' => IfToken(span, expr),
        'unless' => UnlessToken(span, expr),
        'else if' => ElseIfToken(span, expr),
        _ => throw Error(),
      });

      return true;
    }

    return false;
  }

  bool _eachOf() {
    final start = _scanner.state;
    if (_scanner.scan(RegExp(r'(?:each|for) +(?=.*? of *[^\n]+)'))) {
      _scanner.expect(RegExp(r'.*?(?= of)'));
      final lval = _scanner.lastSpan!.trim();
      _scanner.expect(" of ");
      _scanner.expect(RegExp(r"[^\n]+"));
      final expr = _scanner.lastSpan!.trim();

      _assertExpression(expr);

      final re1 = RegExp(r'^[a-zA-Z_$][\w$]*$');
      final re2 = RegExp(r'\[ *[a-zA-Z_$][\w$]* *\, *[a-zA-Z_$][\w$]* *\]$');

      if ((re1.matchAsPrefix(lval.text) ?? re2.matchAsPrefix(lval.text)) == null) {
        _scanner.error(
          'The value variable for each must either be a valid identifier (e.g. `item`) or a pair of identifiers in square brackets (e.g. `[key, value]`).',
          position: lval.start.offset,
          length: lval.length,
        );
      }

      _tokens.add(EachOfToken(_scanner.spanFrom(start), lval, expr));
      return true;
    }

    if (_scanner.scan(RegExp(r'- *(?:each|for) +([a-zA-Z_$][\w$]*)(?: *, *([a-zA-Z_$][\w$]*))? +of +([^\n]+)'))) {
      _scanner.error(
        'Pug each and for should not be prefixed with a dash ("-"). They are pug keywords and not part of JavaScript.',
      );
    }
    return false;
  }

  bool _each() {
    final start = _scanner.state;

    if (_scanner.scan(RegExp(r'(?:each|for) +(?=([a-zA-Z_$][\w$]*)(?: *, *([a-zA-Z_$][\w$]*))? * in *([^\n]+))'))) {
      _scanner.expect(RegExp(r'([a-zA-Z_$][\w$]*)(?: *, *([a-zA-Z_$][\w$]*))? *(?= in)'));
      final lvals = _scanner.lastSpan!.trim();
      _scanner.expect(' in ');
      _scanner.expect(RegExp(r' *([^\n]+)'));
      final expr = _scanner.lastSpan!.trim();

      _assertExpression(expr);

      _tokens.add(EachToken(_scanner.spanFrom(start), lvals, expr));
      return true;
    }

    if (_scanner.scan(RegExp(r'(each|for)\b'))) {
      final keyword = _scanner.lastMatch!.group(1)!;
      _scanner.error(
        'This `$keyword` statement has a syntax error. '
        '`$keyword` statements should be of the form: '
        '`$keyword VARIABLE_NAME (of|in) EXPRESSION',
      );
    }

    if (_scanner.scan(RegExp(r'- *(?:each|for) +([a-zA-Z_$][\w$]*)(?: *, *([a-zA-Z_$][\w$]*))? +in +([^\n]+)'))) {
      _scanner.error(
        'Pug each and for should not be prefixed with a dash ("-"). '
        'They are pug keywords and not part of JavaScript.',
      );
    }

    return false;
  }

  bool _while() {
    final start = _scanner.state;
    if (_scanner.scan(RegExp(r'while +(?=[^\n]+)'))) {
      _scanner.expect(RegExp(r'[^\n]+'));
      final expr = _scanner.lastSpan!.trim();
      _assertExpression(expr);
      _tokens.add(WhileToken(_scanner.spanFrom(start), expr));
      return true;
    }

    if (_scanner.scan(RegExp(r'while\b'))) {
      _scanner.error('missing expression for `while`');
    }

    return false;
  }

  bool _tag() {
    final tok = _scan(RegExp(r'(\w(?:[-:\w]*\w)?)'), TagToken.new);
    if (tok == null) {
      return false;
    }

    _tokens.add(tok);
    return true;
  }

  bool _blockCode() {
    final tok = _scanEndOfLine('-', BlockCodeToken.new);
    if (tok != null) {
      _tokens.add(tok);
      _pipelessText();
      return true;
    }
    return false;
  }

  bool _code() {
    final start = _scanner.state;
    if (_scanner.scan(RegExp(r'(!?=|-)[ \t]*(?=[^\n]+)'))) {
      final flags = _scanner.lastMatch!.group(1)!;
      final FileSpan code;
      if (_interpolated) {
        final ParseSlice results;
        try {
          results = parseUntilScanner(_scanner, ']');
        } on CharacterParserException catch (e) {
          if (e.code == 'CHARACTER_PARSER:END_OF_STRING_REACHED') {
            _scanner.error('End of line was reached with no closing bracket for interpolation.', position: e.index);
          } else if (e.code == 'CHARACTER_PARSER:MISMATCHED_BRACKET') {
            _scanner.error(e.message, position: e.index);
          } else {
            rethrow;
          }
        }
        code = _scanner.spanFromPosition(results.start, results.end);
      } else {
        _scanner.expect(RegExp(r'[^\n]+'));
        code = _scanner.lastSpan!;
      }

      final mustEscape = flags[0] == '=';
      final buffer = flags.contains('=');
      if (buffer) _assertExpression(code);
      _tokens.add(CodeToken(_scanner.spanFrom(start), code, buffer: buffer, mustEscape: mustEscape));
      return true;
    }
    return false;
  }

  bool _id() {
    final tok = _scan(RegExp(r'#([\w-]+)'), IdToken.new);
    if (tok != null) {
      _tokens.add(tok);
      return true;
    }

    if (_scanner.scan('#')) {
      _scanner.scan(RegExp(r'[^ \t\(\#\.\:]*'));
      _scanner.error('not a valid ID');
    }
    return false;
  }

  bool _dot() {
    final tok = _scanEndOfLine('.', DotToken.new);
    if (tok == null) return false;

    _tokens.add(tok);
    _pipelessText();
    return true;
  }

  bool _className() {
    final tok = _scan(RegExp(r'\.([_a-z0-9\-]*[_a-z][_a-z0-9\-]*)'), ClassToken.new);
    if (tok != null) {
      _tokens.add(tok);
      return true;
    }

    if (_scanner.scan('.')) {
      if (_scanner.scan(RegExp(r'[_a-z0-9\-]+'))) {
        _scanner.error('Class names must contain at least one letter or underscore.');
      } else {
        _scanner.scan(RegExp(r'[^ \t\(\#\.\:]*'));
        _scanner.error(
          'not a valid class name. '
          'Class names can only contain "_", "-", a-z and 0-9, '
          'and must contain at least one of "_", or a-z',
        );
      }
    }

    return false;
  }

  bool _attributesBlock() {
    final start = _scanner.state;
    if (_scanner.scan('&attributes')) {
      final valueStart = _scanner.state;
      _bracketExpression(0);
      _tokens.add(AttributesBlockToken(_scanner.spanFrom(start), _scanner.spanFrom(valueStart)));
      return true;
    }
    return false;
  }

  bool _indent() {
    final match = _scanIndentation();
    if (match == null) return false;

    final indents = match.group(1)!.length;
    _scanner.position += indents + 1;

    if (_scanner.scan(RegExp(r'[ \t]'))) {
      _scanner.error('Invalid indentation; you can use tabs or spaces but not both');
    }

    if (_scanner.scan('\n')) {
      _interpolationAllowed = true;
      _tokens.add(EndOfLineToken(_scanner.lastSpan!));
      return true;
    }

    if (indents < _indentStack.first) {
      int outdentCount = 0;
      while (_indentStack.first > indents) {
        if (_indentStack[1] < indents) {
          _scanner.error(
            'Inconsistent indentation. '
            'Expecting either ${_indentStack[1]} or ${_indentStack[0]} spaces/tabs',
          );
        }
        outdentCount++;
        _indentStack.removeAt(0);
      }

      while (outdentCount-- > 0) {
        _tokens.add(OutdentToken(_scanner.emptySpan));
      }
    } else if (indents > 0 && indents != _indentStack.first) {
      _tokens.add(IndentToken(_scanner.emptySpan));
      _indentStack.insert(0, indents);
    } else {
      _tokens.add(EndOfLineToken(_scanner.emptySpan));
    }

    _interpolationAllowed = true;
    return true;
  }

  int _addText<T extends Token>(_TokenCons<T> type, SpanScanner scanner, [String prefix = '', int escaped = 0]) {
    final start = scanner.state;
    var startOfPlaintext = scanner.state;

    while (!scanner.isDone) {
      final current = scanner.state;

      void commit() {
        final span = scanner.spanFrom(startOfPlaintext, current);
        if (span.text.isNotEmpty) _tokens.add(type(span));
      }

      if (scanner.scan('\\#[') || scanner.scan('\\#{')) {
        continue;
      } else if (_interpolationAllowed && scanner.scan('#[')) {
        commit();

        _tokens.add(StartInterpolationToken(scanner.lastSpan!));
        final child = Lexer(scanner, interpolated: true);
        final interpolated = child.getTokens();
        _tokens.addAll(interpolated);
        _tokens.add(EndInterpolationToken(scanner.lastSpan!));

        startOfPlaintext = scanner.state;
      } else if (_interpolationAllowed && scanner.scan(RegExp(r'([#!])\{'))) {
        commit();
        final mustEscape = scanner.lastMatch!.group(1)! == '#';

        final ParseSlice results;
        try {
          results = parseUntilScanner(scanner, '}');
        } on CharacterParserException catch (e) {
          if (e.code == 'CHARACTER_PARSER:END_OF_STRING_REACHED') {
            scanner.error('End of line was reached with no closing bracket for interpolation.', position: e.index);
          } else if (e.code == 'CHARACTER_PARSER:MISMATCHED_BRACKET') {
            scanner.error(e.message, position: e.index);
          } else {
            rethrow;
          }
        }
        scanner.expect('}');

        final code = scanner.spanFromPosition(results.start, results.end);
        _assertExpression(code);

        _tokens.add(InterpolatedCodeToken(scanner.spanFrom(current), code, mustEscape: mustEscape));

        startOfPlaintext = scanner.state;
      } else if (_interpolated && String.fromCharCode(scanner.peekChar()!) == ']') {
        break;
      } else {
        scanner.readChar();
      }
    }

    final span = scanner.spanFrom(startOfPlaintext);
    if (span.text.isNotEmpty) {
      _tokens.add(type(span));
    }

    return scanner.spanFrom(start).length;
  }

  bool _text() {
    final tok =
        _scanner.scan(RegExp(r'(?:\| ?| )([^\n]+)')) ||
        _scanner.scan(RegExp(r'( )')) ||
        _scanner.scan(RegExp(r'\|( ?)'));

    if (!tok) return false;

    var span = _scanner.lastSpan!;
    if (span.text.startsWith('|')) {
      span = span.subspan(1);
    }

    final count = _addText(TextToken.new, SpanScanner.within(span));
    if (count < span.length) {
      _scanner.position -= (span.length - count);
    }
    return true;
  }

  bool _textHtml() {
    if (!_scanner.scan(RegExp(r'(<[^\n]*)'))) return false;

    _addText(TextHtmlToken.new, SpanScanner.within(_scanner.lastSpan!));
    return true;
  }
  
  bool _comment() {
    final start = _scanner.state;
    if (_scanner.scan(RegExp(r'\/\/(-?)'))) {
      final buffer = _scanner.lastMatch!.group(1)! != '-';
      _scanner.scan(RegExp(r'[^\n]*'));
      final content = _scanner.lastSpan ?? _scanner.emptySpan;
      _tokens.add(CommentToken(_scanner.spanFrom(start), content, buffer: buffer));
      _pipelessText();
      return true;
    }
    return false;
  }

  bool _slash() {
    final tok = _scan('/', SlashToken.new);
    if (tok == null) return false;

    _tokens.add(tok);
    return true;
  }

  bool advance() {
    return _blank() ||
        _eos() ||
        _endInterpolation() ||
        _yield() ||
        _doctype() ||
        _interpolation() ||
        _case() ||
        _when() ||
        _default() ||
        _extends() ||
        _append() ||
        _prepend() ||
        _block() ||
        _mixinBlock() ||
        _include() ||
        _mixin() ||
        _call() ||
        _conditional() ||
        _eachOf() ||
        _each() ||
        _while() ||
        _tag() ||
        _filter() ||
        _blockCode() ||
        _code() ||
        _id() ||
        _dot() ||
        _className() ||
        _attrs() ||
        _attributesBlock() ||
        _indent() ||
        _text() ||
        _textHtml() ||
        _comment() ||
        _slash() ||
        _colon() ||
        _fail();
  }

  Never _fail() {
    _scanner.error('unexpected text');
  }

  List<Token> getTokens() {
    while (!_ended) {
      advance();
    }

    return tokens;
  }
}
