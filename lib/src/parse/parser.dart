import 'dart:collection';

import 'package:dug/dug.dart';
import 'package:dug/src/lex/tokens.dart';
import 'package:dug/src/parse/nodes.dart';
import 'package:source_span/source_span.dart';

const _inlineTags = [
  'a',
  'abbr',
  'acronym',
  'b',
  'br',
  'code',
  'em',
  'font',
  'i',
  'img',
  'ins',
  'kbd',
  'map',
  'samp',
  'small',
  'span',
  'strong',
  'sub',
  'sup',
];

class ParserException implements Exception {
  final String? expected;
  final Token token;
  final String message;

  ParserException(this.message, {required this.token, this.expected});

  @override
  String toString({Object? color}) => token.span.message(
    'ParserException: ${expected != null ? 'expected $expected, ' : ''}'
    '$message',
  );
}

class TokenStream {
  final ListQueue<Token> tokens;

  TokenStream(List<Token> tokens) : tokens = ListQueue.of(tokens);

  Token lookahead(int offset) => tokens.elementAt(offset);
  Token peek() => tokens.first;
  Token advance() => tokens.removeFirst();
  void defer(Token token) => tokens.addFirst(token);

  T expect<T extends Token>(String type) {
    if (peek() is! T) {
      throw ParserException('got ${peek().type}', token: peek(), expected: type);
    } else {
      return advance() as T;
    }
  }

  T? accept<T extends Token>() {
    if (peek() is T) {
      return advance() as T;
    }
    return null;
  }
}

class Parser {
  final TokenStream tokens;
  final SourceFile file;
  FileSpan last;

  Parser(List<Token> tokens, this.file) : tokens = TokenStream(tokens), last = file.location(0).pointSpan();
  factory Parser.fromLexer(Lexer lexer) => Parser(lexer.getTokens(), lexer.file);

  Block parse() {
    final block = _emptyBlock(last.start);

    while (_peek() is! EndOfSourceToken) {
      final peek = _peek();
      if (peek is EndOfLineToken) {
        _advance();
      } else if (peek is TextHtmlToken) {
        block.nodes.addAll(_parseTextHtml());
      } else {
        block.extend(_parseExpr());
      }
    }

    return block;
  }

  Block _emptyBlock(FileLocation start) => _initBlock(start, []);

  Block _initBlock(FileLocation start, List<Node> nodes) => Block(start.pointSpan(), nodes);

  Token _peek() {
    final tok = tokens.peek();
    last = tok.span;
    return tok;
  }

  Token _advance() {
    final tok = tokens.advance();
    last = tok.span;
    return tok;
  }

  Node _parseExpr([void _]) => switch (_peek()) {
    TagToken() => _parseTag(),
    MixinToken() => _parseMixin(),
    BlockToken() => _parseBlock(),
    MixinBlockToken() => _parseMixinBlock(),
    CaseToken() => _parseCase(),
    ExtendsToken() => _parseExtends(),
    IncludeToken() => _parseInclude(),
    DoctypeToken() => _parseDoctype(),
    FilterToken() => _parseFilter(),
    CommentToken() => _parseComment(),
    TextToken() || InterpolatedCodeToken() || StartInterpolationToken() => _parseText(block: true),
    TextHtmlToken() => _initBlock(_peek().span.start, _parseTextHtml()),
    DotToken() => _parseDot(),
    EachToken() => _parseEach(),
    EachOfToken() => _parseEachOf(),
    CodeToken() => _parseCode(),
    BlockCodeToken() => _parseBlockCode(),
    IfToken() || UnlessToken() => _parseConditional(),
    WhileToken() => _parseWhile(),
    CallToken() => _parseCall(),
    InterpolationToken() => _parseInterpolation(),
    YieldToken() => _parseYield(),
    IdToken() || ClassToken() => _parseExpr(tokens.defer(TagToken(_peek().span, 'div'))),
    _ => _invalidToken(),
  };

  Node _parseTag() {
    final tok = tokens.expect<TagToken>('tag');
    final tag = Tag(
      tok.span,
      tok.tag,
      selfClosing: false,
      isInline: _inlineTags.contains(tok.tag),
      block: _emptyBlock(tok.span.start),
    );

    return _tag(tag, selfClosingAllowed: true);
  }

  Node _tag(Tag tag, {bool selfClosingAllowed = false}) {
    var seenAttrs = false;
    final attributeNames = <String>[];

    out:
    while (true) {
      switch (_peek()) {
        case IdToken():
          final tok = _advance() as IdToken;
          if (attributeNames.contains('id')) {
            throw ParserException('Duplicate attribute "id" is not allowed', token: tok);
          }
          attributeNames.add('id');
          tag.attrs.add(Attr(tok.span, 'id', "'${tok.span.text.substring(1)}'", mustEscape: false));
          continue;

        case ClassToken():
          final tok = _advance() as ClassToken;
          tag.attrs.add(Attr(tok.span, 'class', "'${tok.span.text.substring(1)}'", mustEscape: false));
          continue;

        case StartAttributesToken():
          if (seenAttrs) {
            print('warning (${_peek().span.start.toolString}): Should not have multiple attributes');
          }
          seenAttrs = true;
          tag.attrs.addAll(_attrs(attributeNames));
          continue;

        case AttributesBlockToken():
          final tok = _advance() as AttributesBlockToken;
          tag.attrBlocks.add(AttributeBlock(tok.span, tok.value.text));
          continue;

        default:
          break out;
      }
    }

    if (_peek() is DotToken) {
      tag.textOnly = true;
      _advance();
    }

    switch (_peek()) {
      case TextToken():
      case InterpolatedCodeToken():
        tag.block!.extend(_parseText());
      case CodeToken():
        tag.block!.nodes.add(_parseCode(todo: true));
      case ColonToken():
        _advance();
        tag.block = Block.fromNode(_parseExpr());

      case EndOfLineToken():
      case IndentToken():
      case OutdentToken():
      case EndOfSourceToken():
      case StartPipelessTextToken():
      case EndInterpolationToken():
        break;

      case SlashToken() when selfClosingAllowed:
        _advance();
        tag.selfClosing = true;

      default:
        throw ParserException(
          'Got ${_peek().type}',
          expected:
              'text, interpolated code, code, :'
              '${selfClosingAllowed ? ', /' : ''}, '
              'newline, or end of source.',
          token: _peek(),
        );
    }

    while (_peek() is EndOfLineToken) {
      _advance();
    }

    if (tag.textOnly) {
      tag.block = _parseTextBlock() ?? _emptyBlock(tag.location!.start);
    } else if (_peek() is IndentToken) {
      tag.block!.extend(_block());
    }

    return tag;
  }

  Block? _parseTextBlock() {
    final tok = tokens.accept<StartPipelessTextToken>();
    if (tok == null) return null;

    final block = _emptyBlock(tok.span.start);

    while (_peek() is! EndPipelessTextToken) {
      final tok = _advance();
      switch (tok) {
        case TextToken():
          block.nodes.add(Text(tok.span, tok.text));

        case EndOfLineToken():
          block.nodes.add(Text(tok.span, '\n'));

        case StartInterpolationToken():
          block.nodes.add(_parseExpr());
          tokens.expect<EndInterpolationToken>('end-interpolation');

        case InterpolatedCodeToken():
          block.nodes.add(
            Code(tok.span, tok.code.text, buffer: tok.buffer, mustEscape: tok.mustEscape, isInline: true),
          );

        default:
          throw ParserException('Unexpected token "${tok.type}"', token: tok);
      }
    }

    _advance();
    return block;
  }

  List<Attr> _attrs([List<String>? attributeNames]) {
    tokens.expect<StartAttributesToken>('start-attributes');

    final attrs = <Attr>[];
    Token tok = _advance();
    while (tok is AttributeToken) {
      final name = tok.key.text;
      final value = tok.value;
      final mustEscape = tok.mustEscape;

      if (attributeNames != null) {
        if (attributeNames.contains(name)) {
          throw ParserException('Duplicate attribute "$name" is not allowed', token: tok);
        }
        attributeNames.add(name);
      }

      attrs.add(Attr(tok.span, name, value, mustEscape: mustEscape));
      tok = _advance();
    }

    tokens.defer(tok);
    tokens.expect<EndAttributesToken>('end-attributes');
    return attrs;
  }

  Node _parseMixin() {
    throw UnimplementedError();
  }

  Node _parseBlock() {
    throw UnimplementedError();
  }

  Node _parseMixinBlock() {
    throw UnimplementedError();
  }

  Node _parseCase() {
    throw UnimplementedError();
  }

  Node _parseExtends() {
    throw UnimplementedError();
  }

  Block _block() {
    final tok = tokens.expect<IndentToken>('indent');
    final block = _emptyBlock(tok.span.start);

    while (tokens.peek() is! OutdentToken) {
      final peek = tokens.peek();
      if (peek is EndOfLineToken) {
        tokens.advance();
      } else if (peek is TextHtmlToken) {
        block.nodes.addAll(_parseTextHtml());
      } else {
        block.extend(_parseExpr());
      }
    }

    tokens.expect<OutdentToken>('outdent');
    return block;
  }

  Node _parseInclude() {
    final tok = tokens.expect<IncludeToken>('include');
    final filters = <IncludeFilter>[];

    while (_peek() is FilterToken) {
      filters.add(_parseIncludeFilter());
    }

    final path = tokens.expect<PathToken>('path');
    final file = FileReference(path.span, path.path);

    if (file.filename.endsWith('.pug') && filters.isEmpty) {
      final block = _peek() is IndentToken ? _block() : _emptyBlock(tok.span.start);
      return Include(tok.span, file, block);
    } else {
      return RawInclude(tok.span, file, filters);
    }
  }

  IncludeFilter _parseIncludeFilter() {
    throw UnimplementedError();
  }

  Node _parseDoctype() {
    final tok = tokens.expect<DoctypeToken>('doctype');
    return Doctype(tok.span, tok.doctype);
  }

  Node _parseFilter() {
    throw UnimplementedError();
  }

  Node _parseComment() {
    final tok = tokens.expect<CommentToken>('comment');

    if (_parseTextBlock() case final Block block) {
      return BlockComment(tok.span, tok.content.text, block, buffer: tok.buffer);
    } else {
      return Comment(tok.span, tok.content.text, buffer: tok.buffer);
    }
  }

  Node _parseText({bool block = false}) {
    final tags = <Node>[];
    final start = _peek().span.start;

    var tok = _peek();

    loop:
    while (true) {
      switch (tok) {
        case TextToken():
          _advance();
          tags.add(Text(tok.span, tok.text));
        case InterpolatedCodeToken():
          _advance();
          tags.add(Code(tok.span, tok.code.text, buffer: tok.buffer, mustEscape: tok.mustEscape, isInline: true));
        case EndOfLineToken():
          if (!block) break loop;
          _advance();
          if (_peek() is TextToken || _peek() is InterpolatedCodeToken) {
            tags.add(Text(tok.span, '\n'));
          }
        case StartInterpolationToken():
          _advance();
          tags.add(_parseExpr());
          tokens.expect<EndInterpolationToken>('end-interpolation');
        default:
          break loop;
      }
      tok = _peek();
    }
    return tags.singleOrNull ?? _initBlock(start, tags);
  }

  List<Node> _parseTextHtml() {
    throw UnimplementedError();
  }

  Node _parseDot() {
    throw UnimplementedError();
  }

  Node _parseEach() {
    throw UnimplementedError();
  }

  Node _parseEachOf() {
    throw UnimplementedError();
  }

  Node _parseCode({bool todo = false}) {
    throw UnimplementedError();
  }

  Node _parseBlockCode() {
    throw UnimplementedError();
  }

  Node _parseConditional() {
    throw UnimplementedError();
  }

  Node _parseWhile() {
    throw UnimplementedError();
  }

  Node _parseCall() {
    final tok = tokens.expect<CallToken>('call');
    final name = tok.src;
    final args = tok.args;

    final mixin = Mixin(tok.span, name.text, args?.text, call: true, block: _emptyBlock(tok.span.start));
    _tag(mixin);

    if (mixin.code != null) {
      mixin.block!.nodes.add(mixin.code!);
      mixin.code = null;
    }

    if (mixin.block!.nodes.isEmpty) mixin.block = null;
    return mixin;
  }

  Node _parseInterpolation() {
    throw UnimplementedError();
  }

  Node _parseYield() {
    throw UnimplementedError();
  }

  Never _invalidToken() {
    throw ParserException('unexpected token `${_peek().type}`', token: _peek());
  }
}
