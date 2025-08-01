// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import Common
import Foundation
import Redux

struct MainMenuAction: Action {
    let windowUUID: WindowUUID
    let actionType: ActionType
    var tabID: TabUUID?
    var navigationDestination: MenuNavigationDestination?
    var currentTabInfo: MainMenuTabInfo?
    var accountData: AccountData?
    var accountIcon: UIImage?
    var siteProtectionsData: SiteProtectionsData?
    var telemetryInfo: TelemetryInfo?
    var isExpanded: Bool?
    var isBrowserDefault: Bool
    var isPhoneLandscape: Bool
    var moreCellTapped: Bool

    init(
        windowUUID: WindowUUID,
        actionType: any ActionType,
        navigationDestination: MenuNavigationDestination? = nil,
        currentTabInfo: MainMenuTabInfo? = nil,
        tabID: TabUUID? = nil,
        accountData: AccountData? = nil,
        accountIcon: UIImage? = nil,
        siteProtectionsData: SiteProtectionsData? = nil,
        telemetryInfo: TelemetryInfo? = nil,
        isExpanded: Bool? = nil,
        isBrowserDefault: Bool = false,
        isPhoneLandscape: Bool = false,
        moreCellTapped: Bool = false
    ) {
        self.windowUUID = windowUUID
        self.actionType = actionType
        self.navigationDestination = navigationDestination
        self.currentTabInfo = currentTabInfo
        self.tabID = tabID
        self.accountData = accountData
        self.accountIcon = accountIcon
        self.siteProtectionsData = siteProtectionsData
        self.telemetryInfo = telemetryInfo
        self.isExpanded = isExpanded
        self.isBrowserDefault = isBrowserDefault
        self.isPhoneLandscape = isPhoneLandscape
        self.moreCellTapped = moreCellTapped
    }
}

enum MainMenuActionType: ActionType {
    case tapNavigateToDestination
    case tapCloseMenu
    case tapToggleUserAgent
    case updateCurrentTabInfo
    case tapMoreOptions
    case didInstantiateView
    case viewDidLoad
    case menuDismissed
    case tapAddToBookmarks
    case tapEditBookmark
    case tapZoom
    case tapToggleNightMode
    case tapAddToShortcuts
    case tapRemoveFromShortcuts
    case updateSiteProtectionsHeader
    case updateMenuAppearance
}

enum MainMenuMiddlewareActionType: ActionType {
    case requestTabInfo
    case requestTabInfoForSiteProtectionsHeader
    case updateAccountHeader
    case updateBannerVisibility
    case updateMenuAppearance
    case updateMenuCells
}
