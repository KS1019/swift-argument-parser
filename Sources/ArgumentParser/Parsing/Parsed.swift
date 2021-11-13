//===----------------------------------------------------------*- swift -*-===//
//
// This source file is part of the Swift Argument Parser open source project
//
// Copyright (c) 2020 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
//
//===----------------------------------------------------------------------===//

import Foundation

enum Parsed<Value> {
  /// The definition of how this value is to be parsed from command-line arguments.
  ///
  /// Internally, this wraps an `ArgumentSet`, but that’s not `public` since it’s
  /// an implementation detail.
  case value(Value)
  case definition((InputKey) -> ArgumentSet)
  
  internal init(_ makeSet: @escaping (InputKey) -> ArgumentSet) {
    self = .definition(makeSet)
  }
}

/// A type that wraps a `Parsed` instance to act as a property wrapper.
///
/// This protocol simplifies the implementations of property wrappers that
/// wrap the `Parsed` type.
internal protocol ParsedWrapper: Decodable, ArgumentSetProvider {
  associatedtype Value
  var _parsedValue: Parsed<Value> { get }
  var isInteractable: Bool { get }
  init(_parsedValue: Parsed<Value>)
}

/// A `Parsed`-wrapper whose value type knows how to decode itself. Types that
/// conform to this protocol can initialize their values directly from a
/// `Decoder`.
internal protocol DecodableParsedWrapper: ParsedWrapper
  where Value: Decodable
{
  init(_parsedValue: Parsed<Value>)
}

extension ParsedWrapper {
  init(_decoder: Decoder) throws {
    guard let d = _decoder as? SingleValueDecoder else {
      throw ParserError.invalidState
    }
      
    // TODO: KS1019 - Do something around here to prompt interactive argument
    // Kinda got this to work but I cannot access to isInteractable
    guard let value = d.parsedElement?.value as? Value else {
      if !String(describing: d.parsedElement).contains("generateCompletionScript") {
        print("Enter \((d.parsedElement?.key ?? d.key).rawValue): ", terminator: "")
        var input = readLine()
        let parsed: Parsed = .value(input as! Self.Value)
        self.init(_parsedValue: parsed)
        return
      }
      throw ParserError.noValue(forKey: d.parsedElement?.key ?? d.key)
    }
    
    self.init(_parsedValue: .value(value))
  }
  
  func argumentSet(for key: InputKey) -> ArgumentSet {
    switch _parsedValue {
    case .value:
      fatalError("Trying to get the argument set from a resolved/parsed property.")
    case .definition(let a):
      return a(key)
    }
  }
}

extension ParsedWrapper where Value: Decodable {
  init(_decoder: Decoder) throws {
    var value: Value
    
    do {
      value = try Value.init(from: _decoder)
    } catch {
      if let d = _decoder as? SingleValueDecoder,
        let v = d.parsedElement?.value as? Value {
        value = v
      } else {
        throw error
      }
    }
    
    self.init(_parsedValue: .value(value))
  }
}
