/// Returns the index in the [sortedList] where the first record value of that
/// element is equal to [value], if it exists.
///
/// Returns `-1` if the `value` is not in the list. Requires the list items
/// to implement [Comparable] and the `sortedList` to already be ordered.
//TODO: is this needed?
int recordBinarySearch(
  List<(int, int)> sortedList,
  int value, {
  required int Function((int, int)) transformer,
}) {
  int min = 0;
  int max = sortedList.length;
  while (min < max) {
    final int mid = min + ((max - min) >> 1);
    final int element = transformer(sortedList[mid]);
    final int comp = element.compareTo(value);
    if (comp == 0) {
      return mid;
    }
    if (comp < 0) {
      min = mid + 1;
    } else {
      max = mid;
    }
  }
  return -1;
}

/// Finds the greatest element in [sortedList] less than or equal to [value].
int binarySearchLEQ<S extends Object, T extends Comparable<Object>>(
  List<S> sortedList,
  T value, {
  T Function(S other)? transformer,
}) {
  int left = 0;
  int right = sortedList.length - 1;

  while (left <= right) {
    int mid = (left + right) ~/ 2;

    final element =
        transformer?.call(sortedList[mid]) ?? sortedList[mid] as Comparable;
    final int comp = element.compareTo(value);
    if (comp <= 0) {
      left = mid + 1;
    } else {
      right = mid - 1;
    }
  }

  return right;
}

enum Direction { forward, reverse }
