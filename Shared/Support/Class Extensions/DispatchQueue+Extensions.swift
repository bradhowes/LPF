// Copyright © 2020 Brad Howes. All rights reserved.

extension DispatchQueue {
  public static func performOnMain(_ operation: @escaping () -> Void) {
    if Thread.isMainThread {
      operation()
    }
    else {
      DispatchQueue.main.async { operation() }
    }
  }
}
