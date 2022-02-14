import AudioUnit
import Foundation

struct Foo {
  let name: String
  let number: Int
}

let existing = [
  Foo(name: "One", number: -1),
  Foo(name: "Three", number: -3),
  Foo(name: "Ten", number: -10),
  Foo(name: "Two", number: -2),
  Foo(name: "Five", number: -5),
  Foo(name: "Six", number: -6)
]

let ordered = existing.sorted { $0.number > $1.number }
ordered

var number = ordered.first?.number ?? -1
for entry in ordered {
  print(entry, number)
  if entry.number != number {
    break
  }
  number -= 1
}

print(number)

powf(2, 0.5)
powf(2, 0.333333)

extension ClosedRange where Bound: BinaryFloatingPoint, Bound.Stride == Bound {
  func stride(by value: Bound) -> StrideThrough<Bound> {
    Swift.stride(from: lowerBound, through: upperBound, by: value)
  }
}

log10f(1.0)
log10f(10.0)

let log10 = (0.0...1.0).stride(by: 0.01).map { log10f($0 + 1) / log10f(2) }
Array(log10).last
let log1010 = (0.0...1.0).stride(by: 0.01).map { log10f(10 * $0 + 1) / log10f(11) }
Array(log1010).last
let log10100 = (0.0...1.0).stride(by: 0.01).map { log10f(100 * $0 + 1) / log10f(101) }
Array(log10100).last
let pow10 = (0.0...1.0).stride(by: 0.01).map { (powf(10, $0) - 1) / 9.0 }
Array(pow10).last
let pow100 = (0.0...1.0).stride(by: 0.01).map { (powf(100, $0) - 1) / 99.0 }
Array(pow100).last
let exp = (0.0...1.0).stride(by: 0.01).map { (expf($0) - 1) / (expf(1.0) - 1) }
Array(exp).last
let exp2 = (0.0...1.0).stride(by: 0.01).map { (expf(2 * $0) - 1) / (expf(2.0) - 1) }
Array(exp2).last
let exp4 = (0.0...1.0).stride(by: 0.01).map { (expf(10 * $0) - 1) / (expf(10.0) - 1) }
Array(exp4).last
let squareRoot = (0.0...1.0).stride(by: 0.01).map { sqrt($0) }
Array(squareRoot).last
let cubeRoot = (0.0...1.0).stride(by: 0.01).map { cbrt($0) }
Array(cubeRoot).last
let squared = (0.0...1.0).stride(by: 0.01).map { powf($0, 2.0) }
Array(squared).last
let cubed = (0.0...1.0).stride(by: 0.01).map { powf($0, 3.0) }
Array(cubed).last

let frequencyRange = Float(12.0)...20_000.0
let frequencyScale = log2f(frequencyRange.upperBound / frequencyRange.lowerBound)
let other = (0.0...1.0).stride(by: 0.01).map { frequencyRange.lowerBound * pow(2, Float($0) * frequencyScale) }

log2f(12.0)
(0.0...1.0).stride(by: 0.01).map { pow(2, log2f(12.0) + $0 * 10.70275) }
