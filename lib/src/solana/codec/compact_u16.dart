// ignore_for_file: public_member_api_docs

import 'dart:typed_data';

List<int> compactU16Encode(int value) {
  RangeError.checkValueInInterval(value, 0, 0xffff, 'value');
  final bytes = <int>[];
  var remaining = value;
  while (true) {
    var current = remaining & 0x7f;
    remaining >>= 7;
    if (remaining != 0) {
      current |= 0x80;
    }
    bytes.add(current);
    if (remaining == 0) {
      return bytes;
    }
  }
}

(int, int) compactU16Decode(Uint8List data, int offset) {
  if (offset < 0 || offset >= data.length) {
    throw RangeError.range(offset, 0, data.length - 1, 'offset');
  }
  var value = 0;
  var consumed = 0;
  while (true) {
    if (offset + consumed >= data.length) {
      throw RangeError('compact-u16 truncated at offset $offset');
    }
    final byte = data[offset + consumed];
    value |= (byte & 0x7f) << (consumed * 7);
    consumed++;
    if ((byte & 0x80) == 0) {
      return (value, consumed);
    }
    if (consumed > 3) {
      throw ArgumentError('compact-u16 exceeds 3 bytes');
    }
  }
}
