import 'package:dug/src/parse/nodes.dart';
import 'package:jsparser/jsparser.dart' hide Node;
import 'package:source_span/source_span.dart';

extension ParseJs on Node {
  void parseJs() {
    walkAST(
      before: (node, replace, _) {
        if (node is Code) {
          try {
            node.statement = parsejs(node.val, parseAsExpression: node.buffer);
          } on ParseError catch (e) {
            final span = node.span.subspan(e.startOffset ?? e.endOffset, e.endOffset);
            throw SourceSpanException(e.message, span);
          }
        }
        return true;
      },
    );
  }
}
