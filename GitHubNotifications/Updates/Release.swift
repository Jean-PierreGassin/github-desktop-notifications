import Foundation

/// A published release the app could move to.
///
/// Only the fields an update needs: what version it is, where to read about it,
/// and the zip to fetch. The DMG published beside it is for people.
struct Release: Sendable, Equatable {
    let version: String
    let pageURL: URL
    let downloadURL: URL
    let publishedAt: Date
}

/// GitHub's release payload, kept private to the decoding step.
private struct ReleasePayload: Decodable {
    struct Asset: Decodable {
        let name: String
        let browserDownloadURL: URL

        enum CodingKeys: String, CodingKey {
            case name
            case browserDownloadURL = "browser_download_url"
        }
    }

    let tagName: String
    let htmlURL: URL
    let publishedAt: Date?
    let isDraft: Bool
    let isPreRelease: Bool
    let assets: [Asset]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlURL = "html_url"
        case publishedAt = "published_at"
        case isDraft = "draft"
        case isPreRelease = "prerelease"
        case assets
    }
}

extension Release {
    /// The asset the updater consumes. `ditto -x -k` round-trips a bundle
    /// faithfully, which is why the zip is the contract rather than the DMG.
    static let assetPrefix = "GitHubNotifications-"
    static let assetSuffix = ".zip"

    /// Returns nothing rather than throwing for a release this app cannot use:
    /// a draft, a pre-release, or one published without the zip. None of those
    /// is an error worth showing anyone.
    static func decode(from data: Data) -> Release? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        guard let payload = try? decoder.decode(ReleasePayload.self, from: data),
              !payload.isDraft,
              !payload.isPreRelease,
              let asset = payload.assets.first(where: isUpdateAsset)
        else {
            return nil
        }

        return Release(
            version: String(payload.tagName.drop { $0 == "v" || $0 == "V" }),
            pageURL: payload.htmlURL,
            downloadURL: asset.browserDownloadURL,
            publishedAt: payload.publishedAt ?? Date(),
        )
    }

    private static func isUpdateAsset(_ asset: ReleasePayload.Asset) -> Bool {
        asset.name.hasPrefix(assetPrefix) && asset.name.hasSuffix(assetSuffix)
    }
}
