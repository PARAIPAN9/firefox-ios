// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import Foundation

final class StoryProvider: FeatureFlaggable, Sendable {
    private let numberOfPocketStories: Int
    private let pocketAPI: PocketStoriesProviding

    init(
        pocketAPI: PocketStoriesProviding,
        numberOfPocketStories: Int = 12
    ) {
        self.pocketAPI = pocketAPI
        self.numberOfPocketStories = numberOfPocketStories
    }

    func fetchPocketStories() async -> [PocketStory] {
        let isStoriesRedesignEnabled = featureFlags.isFeatureEnabled(.homepageStoriesRedesign, checking: .buildOnly)
        let numberOfPocketStoriesIfRedesignEnabled = 9
        let numberOfPocketStories = isStoriesRedesignEnabled ? numberOfPocketStoriesIfRedesignEnabled
                                                             : self.numberOfPocketStories
        let global = (try? await pocketAPI.fetchStories(items: numberOfPocketStories)) ?? []
        // Convert global feed to PocketStory
        return global.map(PocketStory.init)
    }
}
