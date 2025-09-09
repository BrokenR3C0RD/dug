import 'package:collection/collection.dart';

extension IterableWindowExtension<T> on Iterable<T> {
  Iterable<List<T>> windows(int size) sync* {
    if (size > length) {
      throw ArgumentError.value(size, 'size', 'window size > $length');
    }

    final iterator = this.iterator;
    final window = QueueList.from(
      List.generate(size, (_) {
        iterator.moveNext();
        return iterator.current;
      }),
    );

    while (true) {
      yield window;
      if (!iterator.moveNext()) break;

      window.removeFirst();
      window.addLast(iterator.current);
    }
  }
}
