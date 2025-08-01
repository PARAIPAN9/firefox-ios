// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import MozillaAppServices
import Common
import SwiftDraw

protocol ASSearchEngineIconDataFetcherProtocol: Sendable {
    /// Accepts a list of Search Engines models and populates them with the correct
    /// icon data based on the Remote Settings `search-config-icon` records.
    /// - Parameters:
    ///   - engines: input engines that need icons.
    ///   - completion: a list of paired engines and their associated icons.
    func populateEngineIconData(_ engines: [SearchEngineDefinition],
                                completion: @escaping ([(SearchEngineDefinition, UIImage)]) -> Void)
}

/// Utility class for fetching search engine icon records from Remote Settings.
final class ASSearchEngineIconDataFetcher: ASSearchEngineIconDataFetcherProtocol {
    let service: RemoteSettingsService
    let client: RemoteSettingsClient?
    let logger: Logger
    private let fallbackEngineIcon: UIImage? = UIImage(named: StandardImageIdentifiers.Large.search)

    init?(logger: Logger = DefaultLogger.shared) {
        let profile: Profile = AppContainer.shared.resolve()
        guard let service = profile.remoteSettingsService else {
            logger.log("Remote Settings service unavailable.", level: .warning, category: .remoteSettings)
            return nil
        }
        self.service = service
        self.client = ASRemoteSettingsCollection.searchEngineIcons.makeClient()
        self.logger = logger
    }

    // MARK: - ASSearchEngineIconDataFetcherProtocol

    func populateEngineIconData(_ engines: [SearchEngineDefinition],
                                completion: @escaping ([(SearchEngineDefinition, UIImage)]) -> Void) {
        // Reminder: client creation must happen before sync() or the sync won't pull data for that client's collection
        guard let client, let records = client.getRecords() else {
            // If we can't fetch icons, return the input engines list with blank icons
            // This should never happen, but we need to make sure we handle it regardless
            logger.log("[SEC] Search engine icon fetch failed. Nil client or getRecords() was empty.",
                       level: .warning,
                       category: .remoteSettings)
            completion(engines.map { ($0, UIImage()) })
            return
        }

        logger.log("[SEC] Fetched \(records.count) search icon records", level: .info, category: .remoteSettings)
        let iconRecords = records.map { ASSearchEngineIconRecord(record: $0) }

        // This is an O(nm) loop but should generally be an extremely small collection
        // of search engines. For example for en-US we currently only get 7 records.
        let mapped = engines.map { engine in
            var maybeIconImage: UIImage?
            let engineIdentifier = engine.identifier

            for iconRecord in iconRecords {
                let iconIdentifiers = iconRecord.engineIdentifiers
                var matchFound = false

                for ident in iconIdentifiers {
                    if ident.hasSuffix("*") {
                        // If an individual entry is suffixed with a star, matching is applied on a "starts with" basis.
                        let iconIdent = ident.dropLast()
                        if engineIdentifier.hasPrefix(iconIdent) {
                            matchFound = true
                        }
                    } else if ident == engineIdentifier {
                        matchFound = true
                    }
                    if matchFound { break }
                }

                if matchFound, let iconImage = fetchIcon(for: iconRecord) {
                    maybeIconImage = iconImage
                    break
                }
            }

            let iconImage = {
                guard let maybeIconImage else {
                    logger.log("[SEC] No icon available for search engine '\(engineIdentifier)'.",
                               level: .warning,
                               category: .remoteSettings)
                    return UIImage()
                }
                return maybeIconImage
            }()

            return (engine, iconImage)
        }

        completion(mapped)
    }

    // MARK: - Private Utilities

    private func fetchIcon(for iconRecord: ASSearchEngineIconRecord) -> UIImage? {
        guard let client else { return fallbackEngineIcon }
        do {
            var fetchedIcon: UIImage?
            let data = try client.getAttachment(record: iconRecord.backingRecord)
            let mimeType = iconRecord.mimeType ?? ""
            if mimeType.hasPrefix("image/svg") {
                fetchedIcon = SVG(data: data)?.rasterize()
            } else if mimeType.hasPrefix("application/pdf") {
                fetchedIcon = UIImage.imageFromPDF(data: data, minimumSize: CGSize(width: 64.0, height: 64.0))
            } else {
                fetchedIcon = UIImage(data: data)
            }
            return fetchedIcon ?? fallbackEngineIcon
        } catch {
            logger.log("[SEC] Error fetching engine icon attachment (\(iconRecord.id)).", level: .warning, category: .remoteSettings)
            return fallbackEngineIcon
        }
    }
}
