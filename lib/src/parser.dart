import 'package:dug/src/lex/tokens.dart';

class TokenStream {
  final List<Token> tokens;
  var cursor = 0;

  TokenStream(this.tokens);

  Token peek() => tokens[cursor];
  Token advance() => tokens[cursor++];
  Token lookahead(int offset) => tokens[cursor + offset];
}

class Parser {}
