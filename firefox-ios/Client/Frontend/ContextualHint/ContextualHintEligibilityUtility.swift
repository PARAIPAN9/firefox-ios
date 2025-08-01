// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import Foundation
import Shared

/// Public interface for contextual hint consumers
protocol ContextualHintEligibilityUtilityProtocol {
    func canPresent(_ hint: ContextualHintType) -> Bool
}

struct ContextualHintEligibilityUtility: ContextualHintEligibilityUtilityProtocol,
                                         ContextualHintPrefsKeysProvider,
                                         SearchBarLocationProvider {
    var profile: Profile
    // For contextual hints shown in Homepage that can overlap with keyboard being raised by user interaction
    private var overlayState: OverlayStateProtocol?
    var isToolbarUpdateCFRFeatureEnabled: Bool

    init(with profile: Profile,
         overlayState: OverlayStateProtocol?,
         isToolbarUpdateCFRFeatureEnabled: Bool = false) {
        self.profile = profile
        self.overlayState = overlayState
        self.isToolbarUpdateCFRFeatureEnabled = isToolbarUpdateCFRFeatureEnabled
    }

    /// Determine if this hint is eligible to present, outside of Nimbus flag settings.
    func canPresent(_ hintType: ContextualHintType) -> Bool {
        guard !isInOverlayMode else { return false }

        var hintTypeShouldBePresented = false

        switch hintType {
        case .dataClearance:
            hintTypeShouldBePresented = true
        case .jumpBackIn:
            hintTypeShouldBePresented = canJumpBackInBePresented
        case .jumpBackInSyncedTab:
            hintTypeShouldBePresented = canPresentJumpBackInSyncedTab
        case .mainMenu:
            hintTypeShouldBePresented = canMenuRedesignCFRBePresented
        case .inactiveTabs:
            hintTypeShouldBePresented = true
        case .navigation:
            hintTypeShouldBePresented = true
        case .toolbarUpdate:
            hintTypeShouldBePresented = canToolbarUpdateCFRBePresented
        }

        return hintTypeShouldBePresented && !hasAlreadyBeenPresented(hintType)
    }

    // MARK: - Private helpers

    private var isInOverlayMode: Bool {
        guard overlayState != nil else { return false }

        return overlayState?.inOverlayMode ?? false
    }

    /// Determine if the CFR for Menu Redesign is presentable.
    ///
    /// It's presentable on these conditions:
    /// - menu-redesign-hint flag is enabled
    private var canMenuRedesignCFRBePresented: Bool {
        return featureFlags.isFeatureEnabled(.menuRedesignHint, checking: .buildOnly) ? true : false
    }

    /// Determine if the CFR for Toolbar Update is presentable.
    ///
    /// It's presentable on these conditions:
    /// - toolbar-update-hint flag is enabled
    private var canToolbarUpdateCFRBePresented: Bool {
        return isToolbarUpdateCFRFeatureEnabled
    }

    /// We present JumpBackIn and SyncTab CFRs only after Toolbar CFR has been
    /// presented if the feature is enabled. If the Toolbar CFR flag is disabled we bypass it.
    private var shouldCheckToolbarHasShown: Bool {
        guard isToolbarUpdateCFRFeatureEnabled else { return true }

        return profile.prefs.boolForKey(CFRPrefsKeys.toolbarUpdateKey.rawValue) ?? false
    }

    /// Determine if the CFR for Jump Back In is presentable.
    ///
    /// It's presentable on these conditions:
    /// - the Toolbar Update CFR has already been presented or the toolbar update flag CFR is disabled
    /// - the JumpBackInSyncedTab CFR has NOT been presented already
    /// - the JumpBackIn CFR has NOT been presented yet
    private var canJumpBackInBePresented: Bool {
        guard shouldCheckToolbarHasShown,
              !hasHintBeenConfigured(.jumpBackInSyncedTab),
              !hasAlreadyBeenPresented(.jumpBackInSyncedTab)
        else { return false }

        return true
    }

    /// Determine if the CFR for SyncedTab in JumpBackIn is presentable.
    ///
    /// The context hint is presentable when certain conditions are met:
    /// - the Toolbar Update CFR has already been presented or the toolbar update flag CFR is disabled
    private var canPresentJumpBackInSyncedTab: Bool {
        return shouldCheckToolbarHasShown
    }

    private func hasAlreadyBeenPresented(_ hintType: ContextualHintType) -> Bool {
        guard let contextualHintData = profile.prefs.boolForKey(prefsKey(for: hintType)) else { return false }

        return contextualHintData
    }

    /// In cases where hints need to be made aware of each other, this will inform of configured ones.
    ///
    /// Hints are configured when the anchor point is visible on screen. Sometimes, multiple hints can become
    /// configured and be eligible to present together. One hint can affect whether or not another should be
    /// presented, but currently hints are unaware of each other.
    ///
    /// With this method, if `hintA` needs to be aware of `hintB`, `hintA` can query for whether `hintB`
    /// has been configured. Then, `hintA` can react accordingly.
    ///
    /// This is a workaround for hints becoming aware of each other until we have a proper CFR system in place.
    private func hasHintBeenConfigured(_ hintType: ContextualHintType) -> Bool {
        var hintConfigured = false

        switch hintType {
        case .jumpBackIn:
            guard let jumpBackInConfigured = profile.prefs.boolForKey(
                CFRPrefsKeys.jumpBackInConfiguredKey.rawValue
            ) else { return false }

            hintConfigured = jumpBackInConfigured
        case .jumpBackInSyncedTab:
            guard let syncedTabConfigured = profile.prefs.boolForKey(
                CFRPrefsKeys.jumpBackInSyncedTabConfiguredKey.rawValue
            ) else { return false }

            hintConfigured = syncedTabConfigured
        default: break
        }

        return hintConfigured
    }
}
