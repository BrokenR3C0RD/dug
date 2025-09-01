import 'package:source_span/source_span.dart';

extension on FileSpan {
  FileSpan trim() {
    final matches = RegExp(r'^(\s*)(.+?)(\s*)$', dotAll: true, multiLine: true).firstMatch(text)!;
    final trimStart = matches.group(1)?.length ?? 0;
    final trimEnd = matches.group(3)?.length ?? 0;

    return subspan(trimStart, length - trimEnd);
  }
}

abstract class Token {
  String get type;
  final FileSpan span;

  String? get repr => '`${RegExp.escape(span.text)}`';

  Token(this.span);

  @override
  String toString() => '<$type @ ${span.start.line}:${span.start.column}${repr != null ? ': $repr' : ''}>';
}

class NumberToken extends Token {
  @override
  final type = 'number';

  final num value;

  NumberToken._(super.span, this.value);

  factory NumberToken.base2(FileSpan span) =>
      NumberToken._(span, int.parse(span.text.substring(2).replaceAll('_', ''), radix: 2));
  factory NumberToken.base10(FileSpan span) => NumberToken._(span, num.parse(span.text.replaceAll('_', '')));
  factory NumberToken.base16(FileSpan span) =>
      NumberToken._(span, int.parse(span.text.substring(2).replaceAll('_', ''), radix: 16));

  @override
  String get repr => '$value';
}

class StringToken extends Token {
  @override
  final type = 'string';
  final String value;

  StringToken(super.span) : value = span.text.substring(1, span.length - 1);

  @override
  String get repr => '"${RegExp.escape(value)}"';
}

abstract class CharToken extends Token {
  final String char;

  CharToken(super.span) : char = span.text.trim();

  @override
  String get repr => "'$char'";
}

class ColonToken extends CharToken {
  @override
  final type = 'colon';

  ColonToken(super.span);
}

abstract class KeywordToken extends Token {
  KeywordToken(super.span);

  String get keyword => span.text.split(' ').first;

  @override
  String get repr => keyword;
}

class TextToken extends Token {
  @override
  final type = 'text';

  TextToken(super.span);

  String get text => span.text;
}

class TextHtmlToken extends Token {
  @override
  final type = 'text-html';

  TextHtmlToken(super.span);

  String get text => span.text;
}

class EndOfLineToken extends Token {
  @override
  final type = 'eol';

  EndOfLineToken(super.span);

  @override
  String get repr => RegExp.escape(span.text);
}

class EndOfSourceToken extends Token {
  @override
  final type = 'eos';

  EndOfSourceToken(super.span);
}

class WhitespaceToken extends Token {
  @override
  final type = 'whitespace';

  WhitespaceToken(super.span);
}

class TagToken extends Token {
  @override
  final type = 'tag';

  TagToken(super.span);
}

class IndentToken extends Token {
  @override
  final type = 'indent';

  IndentToken(super.span);
}

class OutdentToken extends Token {
  @override
  final type = 'outdent';

  OutdentToken(super.span);
}

class DoctypeToken extends KeywordToken {
  @override
  final type = 'doctype';

  DoctypeToken(super.span);
}

class YieldToken extends KeywordToken {
  @override
  final type = 'yield';

  YieldToken(super.span);
}

class CaseToken extends KeywordToken {
  @override
  final type = 'case';

  CaseToken(super.span);

  String get expression => super.span.text.substring(5);

  @override
  String toString() => '${super.toString()} = $expression';
}

class WhenToken extends KeywordToken {
  @override
  final type = 'when';

  WhenToken(super.span);

  String get expression => super.span.text.substring(5);

  @override
  String toString() => '${super.toString()} = $expression';
}

class InterpolationToken extends Token {
  @override
  final type = 'interpolation';

  InterpolationToken(super.span);

  String get expression => span.text.substring(2, span.length - 1);

  @override
  String toString() => '${super.toString()} = $expression';
}

class DefaultToken extends KeywordToken {
  @override
  final type = 'default';

  DefaultToken(super.span);
}

class PathToken extends Token {
  @override
  final type = 'path';

  PathToken(super.span);

  String get path => super.span.text.trim();
}

class ExtendsToken extends KeywordToken {
  @override
  final type = 'extends';

  ExtendsToken(super.span);
}

class BlockToken extends Token {
  @override
  final type = 'block';

  final String mode;
  final FileSpan name;

  BlockToken._(super.span, this.name, this.mode);

  factory BlockToken.append(FileSpan span, FileSpan name) => BlockToken._(span, name, 'append');
  factory BlockToken.prepend(FileSpan span, FileSpan name) => BlockToken._(span, name, 'prepend');
  factory BlockToken.replace(FileSpan span, FileSpan name) => BlockToken._(span, name, 'replace');

  @override
  String toString() => '${super.toString()} = ${name.text} ($mode)';
}

class MixinBlockToken extends KeywordToken {
  @override
  final type = 'mixinBlock';

  MixinBlockToken(super.span);
}

class StartAttributesToken extends CharToken {
  @override
  final type = 'start-attributes';

  StartAttributesToken(super.span);
}

class EndAttributesToken extends CharToken {
  @override
  final type = 'end-attributes';

  EndAttributesToken(super.span);
}

class AttributeToken extends Token {
  @override
  final type = 'attribute';

  final FileSpan key;
  final Object value;
  final bool mustEscape;

  AttributeToken(super.span, this.key, this.value, {required this.mustEscape});

  @override
  String get repr =>
      '${key.text} ${mustEscape ? '' : '!'}= ${value is FileSpan ? (value as FileSpan).trim().text : value.toString()}';
}

class FilterToken extends Token {
  @override
  final type = 'filter';

  FilterToken(super.span);
}

class IncludeToken extends Token {
  @override
  final type = 'include';

  IncludeToken(super.span);
}

class MixinToken extends KeywordToken {
  @override
  final type = 'mixin';

  MixinToken(super.span);
}

class CallToken extends Token {
  @override
  final type = 'call';

  final FileSpan src;
  final FileSpan? args;
  final bool isInterpolated;

  CallToken(super.span, this.src, this.args, {required this.isInterpolated});

  @override
  String? get repr => '${src.text} ${args != null ? '(${args!.text})' : ''}';
}

class IfToken extends Token {
  @override
  final type = 'if';

  final FileSpan expr;

  IfToken(super.span, this.expr);
}

class UnlessToken extends Token {
  @override
  final type = 'if';

  final FileSpan expr;

  UnlessToken(super.span, this.expr);
}

class ElseIfToken extends Token {
  @override
  final type = 'else-if';

  final FileSpan expr;

  ElseIfToken(super.span, this.expr);
}

class ElseToken extends Token {
  @override
  final type = 'else';

  ElseToken(super.span);
}

class EachOfToken extends Token {
  @override
  final type = 'eachOf';

  final FileSpan lval;
  final FileSpan expr;

  EachOfToken(super.span, this.lval, this.expr);
}

class EachToken extends Token {
  @override
  final type = 'each';

  final FileSpan lval;
  final FileSpan expr;

  EachToken(super.span, this.lval, this.expr);
}

class WhileToken extends Token {
  @override
  final type = 'each';

  final FileSpan expr;

  WhileToken(super.span, this.expr);
}

class StartPipelessTextToken extends Token {
  @override
  final type = 'start-pipeless-text';

  StartPipelessTextToken(super.span);
}

class EndPipelessTextToken extends Token {
  @override
  final type = 'end-pipeless-text';

  EndPipelessTextToken(super.span);
}

class BlockCodeToken extends Token {
  @override
  final type = 'blockcode';

  BlockCodeToken(super.span);
}

class CodeToken extends Token {
  @override
  String get type => 'code';

  final FileSpan code;
  final bool buffer;
  final bool mustEscape;

  CodeToken(super.span, this.code, {required this.buffer, required this.mustEscape});
}

class InterpolatedCodeToken extends CodeToken {
  @override
  final type = 'interpolated-code';

  InterpolatedCodeToken(super.span, super.code, {required super.mustEscape}) : super(buffer: false);
}

class IdToken extends Token {
  @override
  final type = 'id';

  IdToken(super.span);
}

class DotToken extends Token {
  @override
  final type = 'dot';

  DotToken(super.span);
}

class ClassToken extends Token {
  @override
  final type = 'class';

  ClassToken(super.span);
}

class AttributesBlockToken extends Token {
  @override
  final type = '&attributes';

  final FileSpan value;

  AttributesBlockToken(super.span, this.value);
}

class StartInterpolationToken extends Token {
  @override
  final type = 'start-interpolation';

  StartInterpolationToken(super.span);
}

class EndInterpolationToken extends Token {
  @override
  final type = 'end-interpolation';

  EndInterpolationToken(super.span);
}

class CommentToken extends Token {
  @override
  final type = 'comment';

  final FileSpan content;
  final bool buffer;

  CommentToken(super.span, this.content, {required this.buffer});
}


class SlashToken extends CharToken {
  @override
  String get type => 'slash';

  SlashToken(super.span);

}
