// Re-exports ArrayCoder from tuple_coder.dart.
//
// ArrayCoder and TupleCoder share the head/tail encoding algorithm and
// have a circular dependency through the coder factory, so they are
// co-located in tuple_coder.dart. This file provides a convenient
// import path for code that only needs ArrayCoder.
export 'tuple_coder.dart' show ArrayCoder;
