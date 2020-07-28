// Copyright © 2020 Brad Howes. All rights reserved.

import XCTest
import LowPassFilterFramework

class FolderMonitorTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testMonitoring() throws {
        let path = URL(fileURLWithPath: NSTemporaryDirectory())
        let temporaryDirectoryURL = try! FileManager.default.url(for: .itemReplacementDirectory, in: .userDomainMask,
                                                                 appropriateFor: path, create: true)
        var expectations = [XCTestExpectation]()
        expectations.forEach { $0.assertForOverFulfill = false }

        let monitor = FolderMonitor(url: temporaryDirectoryURL) { (contents: [URL]) in
            guard contents.count > 0 else { return }
            expectations[contents.count - 1].fulfill()
        }

        monitor.start()

        for (index, file) in ["file1", "file2", "file3", "file4"].enumerated() {
            expectations.append(expectation(description: file))
            expectations.last!.assertForOverFulfill = false
            let data = file.data(using: .utf8)!
            try data.write(to: temporaryDirectoryURL.appendingPathComponent(file), options: .atomic)
            wait(for: [expectations[index]], timeout: 5.0)
        }

        monitor.stop()
    }

    func testStop() throws {
        let path = URL(fileURLWithPath: NSTemporaryDirectory())
        let temporaryDirectoryURL = try! FileManager.default.url(for: .itemReplacementDirectory, in: .userDomainMask,
                                                                 appropriateFor: path, create: true)
        var expectations = [XCTestExpectation]()
        expectations.forEach { $0.assertForOverFulfill = false }

        let monitor = FolderMonitor(url: temporaryDirectoryURL) { (contents: [URL]) in
            guard contents.count > 0 else { return }
            expectations[contents.count - 1].fulfill()
        }

        monitor.start()

        for (index, file) in ["file1", "file2", "file3", "file4"].enumerated() {
            expectations.append(expectation(description: file))
            expectations.last!.assertForOverFulfill = false
            let data = file.data(using: .utf8)!
            try data.write(to: temporaryDirectoryURL.appendingPathComponent(file), options: .atomic)
            wait(for: [expectations[index]], timeout: 5.0)
        }

        monitor.stop()

        for file in ["file5", "file6", "file7", "file8"] {
            expectations.append(expectation(description: file))
            expectations.last!.isInverted = true
            let data = file.data(using: .utf8)!
            try data.write(to: temporaryDirectoryURL.appendingPathComponent(file), options: .atomic)
        }

        wait(for: Array(expectations[4..<8]), timeout: 5.0)
    }
}
