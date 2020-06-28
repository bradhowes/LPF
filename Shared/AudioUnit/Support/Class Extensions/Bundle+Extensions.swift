// Copyright © 2020 Apple. All rights reserved.

import Foundation

extension Bundle {

    /**
     Attempt to get a String value from the Bundle meta dictionary.

     - parameter key: what to fetch
     - returns: the value found or an empty string
     */
    private func string(forKey key: String) -> String { infoDictionary?[key] as? String ?? "" }

    /// Obtain the release version number associated with the bundle or "" if none found
    var releaseVersionNumber: String { string(forKey: "CFBundleShortVersionString") }

    /// Obtain the build version number associated with the bundle or "" if none found
    var buildVersionNumber: String { string(forKey: "CFBundleVersion") }

    /// Obtain the bundle identifier or "" if there is not one
    var bundleID: String { Bundle.main.bundleIdentifier?.lowercased() ?? "" }

    /// Obtain the build scheme that was used to generate the bundle. Returns " Dev" or " Staging" or ""
    var scheme: String {
        if bundleID.contains(".dev") { return " Dev" }
        if bundleID.contains(".staging") { return " Staging" }
        return ""
    }

    /// Obtain a version string with the following format: "Version V.B[ S]"
    /// where V is the releaseVersionNumber, B is the buildVersionNumber and S is the scheme.
    var versionString: String { "Version \(releaseVersionNumber).\(buildVersionNumber)\(scheme)" }
}
