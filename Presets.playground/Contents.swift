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
