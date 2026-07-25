import Foundation

/// The running version, read once from the bundle.
///
/// Read from the bundle rather than baked in at compile time so a build cut
/// from a tag reports that tag. A bundle missing the key is a packaging
/// mistake: the sentinel sorts below every real release, so the updater offers
/// an update rather than quietly deciding there is nothing newer.
enum AppVersion {
    /// Stands in for a key the bundle does not carry.
    static let unknown = "0.0.0"

    /// `CFBundleShortVersionString`, the marketing version the tag sets.
    static let current = value(forKey: "CFBundleShortVersionString")

    /// `CFBundleVersion`. Equal marketing versions are broken by this.
    static let build = value(forKey: "CFBundleVersion")

    /// Orders dotted numeric versions by component, because a string comparison
    /// puts 1.10.0 below 1.9.0. A leading `v` is tolerated so release tag names
    /// compare against bundle versions without being trimmed first.
    ///
    /// Missing and non-numeric components count as zero: a version that cannot
    /// be parsed should lose to one that can, not crash the update check. A
    /// pre-release suffix sorts below the release it precedes, so `1.2.0`
    /// reaches someone running `1.2.0-beta.1`.
    static func compare(_ lhs: String, _ rhs: String) -> ComparisonResult {
        let left = parse(lhs)
        let right = parse(rhs)

        for index in 0 ..< max(left.numbers.count, right.numbers.count) {
            let leftNumber = index < left.numbers.count ? left.numbers[index] : 0
            let rightNumber = index < right.numbers.count ? right.numbers[index] : 0

            if leftNumber != rightNumber {
                return leftNumber < rightNumber ? .orderedAscending : .orderedDescending
            }
        }

        guard left.preRelease == right.preRelease else {
            return orderPreRelease(left.preRelease, right.preRelease)
        }

        return .orderedSame
    }

    /// An absent suffix wins; two present ones fall back to a plain string
    /// order, which is enough to separate `beta.1` from `beta.2`.
    private static func orderPreRelease(_ lhs: String, _ rhs: String) -> ComparisonResult {
        if lhs.isEmpty || rhs.isEmpty {
            return lhs.isEmpty ? .orderedDescending : .orderedAscending
        }

        return lhs < rhs ? .orderedAscending : .orderedDescending
    }

    private static func parse(_ version: String) -> (numbers: [Int], preRelease: String) {
        let trimmed = version.trimmingCharacters(in: .whitespaces).drop { $0 == "v" || $0 == "V" }
        let parts = trimmed.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: false)
        let numbers = parts[0]
            .split(separator: ".")
            .map { component in Int(component.prefix { $0.isNumber }) ?? 0 }

        return (numbers, parts.count > 1 ? String(parts[1]) : "")
    }

    private static func value(forKey key: String) -> String {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String, !value.isEmpty else {
            assertionFailure("\(key) is missing from the bundle")

            return unknown
        }

        return value
    }
}
