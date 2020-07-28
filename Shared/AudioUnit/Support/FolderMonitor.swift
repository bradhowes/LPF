import Foundation

/**
 Utility class that monitors a specific folder on the file system for changes and emits the contens of the folder to
 a configured closure.
 */
public final class FolderMonitor {
    public typealias ClosureType = ([URL]) -> Void

    private let closure: ClosureType
    private let queue =  DispatchQueue(label: "FolderMonitor", attributes: .concurrent)
    private var monitor: DispatchSource?
    private let url: URL

    /**
     Create a new monitor.

     - parameter url: the location of the folder to monitor
     - parameter closure: the closure to invoke when the contents of the folder changes
     */
    public init(url: URL, _ closure: @escaping ClosureType) {
        self.url = url
        self.closure = closure
    }
}

extension FolderMonitor {

    /**
     Begin monitoring the folder for changes.
     */
    public func start() {
        guard monitor == nil else { return }
        let fileDescriptor = url.withUnsafeFileSystemRepresentation { (path) -> Int32 in
            guard let path = path else { return -1 }
            return open(path, O_EVTONLY)
        }

        guard fileDescriptor != -1 else { return }
        guard let monitor = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fileDescriptor,
                                                                      eventMask: DispatchSource.FileSystemEvent.write,
                                                                      queue: queue) as? DispatchSource else { return }
        self.monitor = monitor

        monitor.setEventHandler {
            if let contents = self.contents() {
                self.closure(contents)
            }
        }

        monitor.setCancelHandler {
            close(fileDescriptor)
            self.monitor = nil
        }

        monitor.resume()
    }

    /**
     Stop monitoring the folder for changes.
     */
    public func stop() {
        guard let monitor = self.monitor else { return }
        monitor.cancel()
    }
}

extension FolderMonitor {

    private func contents() -> [URL]? {
        let found = try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [])
        return found
    }
}
