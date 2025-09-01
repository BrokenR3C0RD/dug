// Implemented by AI
// Reimplementation of character-parser (JavaScript).

import 'package:string_scanner/string_scanner.dart';

enum TokenType {
  lineComment,
  blockComment,
  singleQuote,
  doubleQuote,
  templateQuote,
  regexp,
  roundBracket,
  curlyBracket,
  squareBracket;

  static TokenType _getBracketType(String bracket) => switch (bracket) {
    '(' => roundBracket,
    '{' => curlyBracket,
    '[' => squareBracket,
    _ => throw UnsupportedError('invalid bracket'),
  };

  bool _isMatchingBracket(String closeBracket) => switch (this) {
    roundBracket => closeBracket == ')',
    curlyBracket => closeBracket == '}',
    squareBracket => closeBracket == ']',
    _ => false,
  };
}

class State {
  final stack = <TokenType>[];
  bool regexpStart = false;
  bool escaped = false;
  bool hasDollar = false;

  var src = '';
  var history = '';
  var lastChar = '';

  TokenType? get current => stack.lastOrNull;

  bool get isString => switch (current) {
    TokenType.singleQuote || TokenType.doubleQuote || TokenType.templateQuote => true,
    _ => false,
  };

  bool get isComment => switch (current) {
    TokenType.lineComment || TokenType.blockComment => true,
    _ => false,
  };

  bool isNesting({bool ignoreLineComment = false}) {
    if (ignoreLineComment && stack.length == 1 && stack.first == TokenType.lineComment) {
      return false;
    }

    return stack.isNotEmpty;
  }
}

class CharacterParserException implements Exception {
  final String code;
  final String message;
  final int index; // scanner.position at throw-time

  CharacterParserException(this.code, this.message, this.index);

  @override
  String toString() => '$code at $index: $message';
}

State defaultState() => State();

/// Parse the remaining input on [scanner] (or until [endPosition]),
/// updating/returning [state] (defaulting to a fresh one).
State parseScanner(
  SpanScanner scanner, {
  State? state,
  int? endPosition,
}) {
  final s = state ?? defaultState();
  final end = endPosition ?? scanner.string.length;
  while (scanner.position < end) {
    final cp = scanner.readChar();
    final ch = String.fromCharCode(cp);

    try {
      parseChar(ch, s, scanner.position);
    } on CharacterParserException {
      rethrow;
    } catch (e) {
      // Normalize unexpected exceptions with index context
      throw CharacterParserException(
        'CHARACTER_PARSER:UNKNOWN',
        e.toString(),
        scanner.position,
      );
    }
  }
  return s;
}

/// Result of [parseUntilScanner].
class ParseSlice {
  final int start;
  final int end;
  final String src;
  ParseSlice({required this.start, required this.end, required this.src});
}

/// Parse forward until [delimiter] matches at the current cursor.
/// Respects nesting unless [ignoreNesting] is true.
/// If [ignoreLineComment] is true, a sole line comment on the stack is ignored for nesting.
ParseSlice parseUntilScanner(
  SpanScanner scanner,
  Pattern delimiter, {
  bool ignoreLineComment = false,
  bool ignoreNesting = false,
  int? endPosition,
}) {
  final start = scanner.position;
  final state = defaultState();
  final end = endPosition ?? scanner.string.length;

  while (scanner.position < end) {
    if ((ignoreNesting || !state.isNesting(ignoreLineComment: ignoreLineComment)) &&
        _matchesAt(scanner, delimiter)) {
      final stop = scanner.position;
      return ParseSlice(
        start: start,
        end: stop,
        src: scanner.string.substring(start, stop),
      );
    }

    final cp = scanner.readChar();
    final ch = String.fromCharCode(cp);
    try {
      parseChar(ch, state, scanner.position - 1);
    } on CharacterParserException catch (ex) {
      // Add current index context (like upstream)
      throw CharacterParserException(ex.code, ex.message, scanner.position - 1);
    }
  }

  throw CharacterParserException(
    'CHARACTER_PARSER:END_OF_STRING_REACHED',
    'The end of the string was reached with no closing bracket found.',
    scanner.position,
  );
}

/// Core state machine for a single character.
State parseChar(String character, State state, int index) {
  if (character.length != 1) {
    throw CharacterParserException(
      'CHARACTER_PARSER:CHAR_LENGTH_NOT_ONE',
      'Character must be a string of length 1',
      index,
    );
  }

  state.src += character;
  final wasComment = state.isComment;
  final lastHistoryChar = state.history.isNotEmpty ? state.history[0] : '';

  // If we *just* assumed a regexp, but the next char shows it's actually // or /*,
  // drop the REGEXP token so comment logic can take over (parity with upstream).
  if (state.regexpStart) {
    if (character == '/' || character == '*') {
      state.stack.removeLast();
    }
    state.regexpStart = false;
  }

  switch (state.current) {
    case TokenType.lineComment:
      if (character == '\n') {
        state.stack.removeLast();
      }
      break;

    case TokenType.blockComment:
      if (state.lastChar == '*' && character == '/') {
        state.stack.removeLast();
      }
      break;

    case TokenType.singleQuote:
      if (character == "'" && !state.escaped) {
        state.stack.removeLast();
      } else if (character == r'\' && !state.escaped) {
        state.escaped = true;
      } else {
        state.escaped = false;
      }
      break;

    case TokenType.doubleQuote:
      if (character == '"' && !state.escaped) {
        state.stack.removeLast();
      } else if (character == r'\' && !state.escaped) {
        state.escaped = true;
      } else {
        state.escaped = false;
      }
      break;

    case TokenType.templateQuote:
      if (character == '`' && !state.escaped) {
        state.stack.removeLast();
        state.hasDollar = false;
      } else if (character == r'\' && !state.escaped) {
        state.escaped = true;
        state.hasDollar = false;
      } else if (character == r'$' && !state.escaped) {
        state.hasDollar = true;
      } else if (character == '{' && state.hasDollar) {
        state.stack.add(TokenType.curlyBracket);
      } else {
        state.escaped = false;
        state.hasDollar = false;
      }
      break;

    case TokenType.regexp:
      if (character == '/' && !state.escaped) {
        state.stack.removeLast();
      } else if (character == r'\' && !state.escaped) {
        state.escaped = true;
      } else {
        state.escaped = false;
      }
      break;

    default:
      // Brackets
      if (_isOpenBracket(character)) {
        state.stack.add(TokenType._getBracketType(character));
      } else if (_isCloseBracket(character)) {
        final top = state.current;
        if (top == null || !top._isMatchingBracket(character)) {
          throw CharacterParserException(
            'CHARACTER_PARSER:MISMATCHED_BRACKET',
            'Mismatched bracket: $character',
            index,
          );
        }
        state.stack.removeLast();
      }
      // Comments
      else if (lastHistoryChar == '/' && character == '/') {
        // remove the '/' from history (so it doesn't affect regex heuristics)
        state.history = state.history.substring(1);
        state.stack.add(TokenType.lineComment);
      } else if (lastHistoryChar == '/' && character == '*') {
        state.history = state.history.substring(1);
        state.stack.add(TokenType.blockComment);
      }
      // RegExp literal (vs divide) heuristic
      else if (character == '/' && _isRegexp(state.history)) {
        state.stack.add(TokenType.regexp);
        // If the *next* char is '/' or '*', this wasn't a regexp; see regexpStart handling above.
        state.regexpStart = true;
      }
      // Strings / template
      else if (character == "'") {
        state.stack.add(TokenType.singleQuote);
      } else if (character == '"') {
        state.stack.add(TokenType.doubleQuote);
      } else if (character == '`') {
        state.stack.add(TokenType.templateQuote);
      }
      break;
  }

  // Update history unless we are in (or just were in) a comment.
  if (!state.isComment && !wasComment) {
    state.history = character + state.history;
  }
  // Keep lastChar (used for */ detection)
  state.lastChar = character;

  return state;
}

// ---------- helpers ----------

bool _matchesAt(SpanScanner scanner, Pattern matcher) {
  final pos = scanner.position;
  if (matcher is String) {
    return scanner.string.startsWith(matcher, pos);
  } else if (matcher is RegExp) {
    return matcher.matchAsPrefix(scanner.string, pos) != null;
  } else {
    // Fallback via String.matchAsPrefix for generic Pattern (rare)
    final m = matcher.matchAsPrefix(scanner.string, pos);
    return m != null;
  }
}

bool _isOpenBracket(String ch) => ch == '(' || ch == '{' || ch == '[';
bool _isCloseBracket(String ch) => ch == ')' || ch == '}' || ch == ']';

bool isPunctuator(String? c) {
  if (c == null || c.isEmpty) return true; // start of string = punctuator
  final code = c.codeUnitAt(0);
  switch (code) {
    case 46: // .
    case 40: // (
    case 41: // )
    case 59: // ;
    case 44: // ,
    case 123: // {
    case 125: // }
    case 91: // [
    case 93: // ]
    case 58: // :
    case 63: // ?
    case 126: // ~
    case 37: // %
    case 38: // &
    case 42: // *
    case 43: // +
    case 45: // -
    case 47: // /
    case 60: // <
    case 62: // >
    case 94: // ^
    case 124: // |
    case 33: // !
    case 61: // =
      return true;
    default:
      return false;
  }
}

bool _isKeyword(String id) {
  return id == 'if' ||
      id == 'in' ||
      id == 'do' ||
      id == 'var' ||
      id == 'for' ||
      id == 'new' ||
      id == 'try' ||
      id == 'let' ||
      id == 'this' ||
      id == 'else' ||
      id == 'case' ||
      id == 'void' ||
      id == 'with' ||
      id == 'enum' ||
      id == 'while' ||
      id == 'break' ||
      id == 'catch' ||
      id == 'throw' ||
      id == 'const' ||
      id == 'yield' ||
      id == 'class' ||
      id == 'super' ||
      id == 'return' ||
      id == 'typeof' ||
      id == 'delete' ||
      id == 'switch' ||
      id == 'export' ||
      id == 'import' ||
      id == 'default' ||
      id == 'finally' ||
      id == 'extends' ||
      id == 'function' ||
      id == 'continue' ||
      id == 'debugger' ||
      id == 'package' ||
      id == 'private' ||
      id == 'interface' ||
      id == 'instanceof' ||
      id == 'implements' ||
      id == 'protected' ||
      id == 'public' ||
      id == 'static';
}

/// Heuristic to decide if a '/' at this point starts a RegExp literal (vs divide).
bool _isRegexp(String history) {
  var h = history;
  // Remove leading whitespace in the (reversed) history
  h = h.replaceFirst(RegExp(r'^\s*'), '');

  if (h.isEmpty) return true; // start of string => OK for regexp
  final first = h[0];

  // Unless it's an `if (...) /` / `while` / `for` / `with` tail, ')' means divide -> not regexp
  if (first == ')') return false;
  // After a block, assume regexp (e.g. `} /.../`)
  if (first == '}') return true;
  // Any punctuator means regexp
  if (isPunctuator(first)) return true;

  // If the last token (remember: history is newest-first) is a keyword, it's a regexp
  final m = RegExp(r'^\w+\b').firstMatch(h);
  if (m != null) {
    final reversedWord = m.group(0)!;
    final forward = reversedWord.split('').reversed.join();
    if (_isKeyword(forward)) return true;
  }
  return false;
}

// ---------- optional convenience over String ----------

State parseString(
  String src, {
  State? state,
  int start = 0,
  int? end,
}) {
  final scanner = SpanScanner(src)..position = start;
  return parseScanner(scanner, state: state, endPosition: end);
}

ParseSlice parseUntilString(
  String src,
  Pattern delimiter, {
  int start = 0,
  bool ignoreLineComment = false,
  bool ignoreNesting = false,
  int? end,
}) {
  final scanner = SpanScanner(src)..position = start;
  return parseUntilScanner(
    scanner,
    delimiter,
    ignoreLineComment: ignoreLineComment,
    ignoreNesting: ignoreNesting,
    endPosition: end,
  );
}
