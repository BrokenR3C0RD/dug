import 'package:dug/src/parse/nodes.dart';

extension StripComments on Node {
  void stripComments({bool stripUnbuffered = true, bool stripBuffered = false, bool includeDependencies = true}) {
    walkAST(
      before: (node, replace, _) {
        if (node is Comment) {
          if (node.buffer && stripBuffered || !node.buffer && stripUnbuffered) {
            replace(<Node>[]);
            return false;
          }
        }
        return true;
      },
    );
  }
}
