// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import Foundation
import Redux
import Common

enum TabTrayLayoutType: Equatable {
    case regular // iPad
    case compact // iPhone
}

struct TabTrayState: ScreenState, Equatable {
    var isPrivateMode: Bool
    var selectedPanel: TabTrayPanelType
    var normalTabsCount: String
    var hasSyncableAccount: Bool
    var shouldDismiss: Bool
    var toastType: ToastType?
    var windowUUID: WindowUUID
    var showCloseConfirmation: Bool

    var navigationTitle: String {
        return selectedPanel.navTitle
    }

    var isSyncTabsPanel: Bool {
        return selectedPanel == .syncedTabs
    }

    var isNormalTabsPanel: Bool {
        return selectedPanel == .tabs
    }

    init(appState: AppState, uuid: WindowUUID) {
        guard let panelState = store.state.screenState(TabTrayState.self,
                                                       for: .tabsTray,
                                                       window: uuid) else {
            self.init(windowUUID: uuid, panelType: .tabs)
            return
        }

        self.init(windowUUID: panelState.windowUUID,
                  isPrivateMode: panelState.isPrivateMode,
                  selectedPanel: panelState.selectedPanel,
                  normalTabsCount: panelState.normalTabsCount,
                  hasSyncableAccount: panelState.hasSyncableAccount,
                  shouldDismiss: panelState.shouldDismiss,
                  toastType: panelState.toastType,
                  showCloseConfirmation: panelState.showCloseConfirmation)
    }

    init(windowUUID: WindowUUID) {
        self.init(windowUUID: windowUUID,
                  isPrivateMode: false,
                  selectedPanel: .tabs,
                  normalTabsCount: "0",
                  hasSyncableAccount: false,
                  toastType: nil)
    }

    init(windowUUID: WindowUUID, panelType: TabTrayPanelType) {
        self.init(windowUUID: windowUUID,
                  isPrivateMode: panelType == .privateTabs,
                  selectedPanel: panelType,
                  normalTabsCount: "0",
                  hasSyncableAccount: false)
    }

    init(windowUUID: WindowUUID,
         isPrivateMode: Bool,
         selectedPanel: TabTrayPanelType,
         normalTabsCount: String,
         hasSyncableAccount: Bool,
         shouldDismiss: Bool = false,
         toastType: ToastType? = nil,
         showCloseConfirmation: Bool = false) {
        self.windowUUID = windowUUID
        self.isPrivateMode = isPrivateMode
        self.selectedPanel = selectedPanel
        self.normalTabsCount = normalTabsCount
        self.hasSyncableAccount = hasSyncableAccount
        self.shouldDismiss = shouldDismiss
        self.toastType = toastType
        self.showCloseConfirmation = showCloseConfirmation
    }

    static let reducer: Reducer<Self> = { state, action in
        // Only process actions for the current window
        guard action.windowUUID == .unavailable || action.windowUUID == state.windowUUID
        else {
            return defaultState(from: state)
        }

        if let action  = action as? TabTrayAction {
            return reduceTabTrayAction(action: action, state: state)
        } else if let action = action as? TabPanelMiddlewareAction {
            return reduceTabPanelMiddlewareAction(action: action, state: state)
        } else if let action = action as? TabPanelViewAction {
            return reduceTabPanelViewAction(action: action, state: state)
        }

        return defaultState(from: state)
    }

    static func reduceTabTrayAction(action: TabTrayAction, state: TabTrayState) -> TabTrayState {
        switch action.actionType {
        case TabTrayActionType.didLoadTabTray:
            guard let tabTrayModel = action.tabTrayModel else { return defaultState(from: state) }
            return TabTrayState(windowUUID: state.windowUUID,
                                isPrivateMode: tabTrayModel.isPrivateMode,
                                selectedPanel: tabTrayModel.selectedPanel,
                                normalTabsCount: tabTrayModel.normalTabsCount,
                                hasSyncableAccount: tabTrayModel.hasSyncableAccount)

        case TabTrayActionType.changePanel:
            guard let panelType = action.panelType else { return defaultState(from: state) }
            return TabTrayState(windowUUID: state.windowUUID,
                                isPrivateMode: panelType == .privateTabs,
                                selectedPanel: panelType,
                                normalTabsCount: state.normalTabsCount,
                                hasSyncableAccount: state.hasSyncableAccount)

        case TabTrayActionType.dismissTabTray:
            return TabTrayState(windowUUID: state.windowUUID,
                                isPrivateMode: state.isPrivateMode,
                                selectedPanel: state.selectedPanel,
                                normalTabsCount: state.normalTabsCount,
                                hasSyncableAccount: state.hasSyncableAccount,
                                shouldDismiss: true)

        case TabTrayActionType.firefoxAccountChanged:
            guard let isSyncAccountEnabled = action.hasSyncableAccount else { return defaultState(from: state) }
            // Account updates may occur in a global manner, independent of specific windows.
            let uuid = state.windowUUID
            return TabTrayState(windowUUID: uuid,
                                isPrivateMode: state.isPrivateMode,
                                selectedPanel: state.selectedPanel,
                                normalTabsCount: state.normalTabsCount,
                                hasSyncableAccount: isSyncAccountEnabled)

        default:
            return defaultState(from: state)
        }
    }

    static func reduceTabPanelMiddlewareAction(action: TabPanelMiddlewareAction, state: TabTrayState) -> TabTrayState {
        switch action.actionType {
        case TabPanelMiddlewareActionType.didChangeTabPanel:
            guard let tabDisplayModel = action.tabDisplayModel else { return defaultState(from: state) }
            let panelType = tabDisplayModel.isPrivateMode ? TabTrayPanelType.privateTabs : TabTrayPanelType.tabs
            return TabTrayState(windowUUID: state.windowUUID,
                                isPrivateMode: tabDisplayModel.isPrivateMode,
                                selectedPanel: panelType,
                                normalTabsCount: tabDisplayModel.normalTabsCount,
                                hasSyncableAccount: state.hasSyncableAccount)

        case TabPanelMiddlewareActionType.refreshTabs:
            // Only update the normal tab count if the tabs being refreshed are not private
            guard let tabDisplayModel = action.tabDisplayModel else { return defaultState(from: state) }
            let isPrivate = tabDisplayModel.tabs.first?.isPrivate ?? false
            let tabCount = isPrivate ? state.normalTabsCount : tabDisplayModel.normalTabsCount
            return TabTrayState(windowUUID: state.windowUUID,
                                isPrivateMode: state.isPrivateMode,
                                selectedPanel: state.selectedPanel,
                                normalTabsCount: tabCount,
                                hasSyncableAccount: state.hasSyncableAccount)

        case TabPanelMiddlewareActionType.showToast:
            guard let type = action.toastType else { return defaultState(from: state) }

            return TabTrayState(windowUUID: state.windowUUID,
                                isPrivateMode: state.isPrivateMode,
                                selectedPanel: state.selectedPanel,
                                normalTabsCount: state.normalTabsCount,
                                hasSyncableAccount: state.hasSyncableAccount,
                                toastType: type)

        default:
            return defaultState(from: state)
        }
    }

    static func reduceTabPanelViewAction(action: TabPanelViewAction, state: TabTrayState) -> TabTrayState {
        switch action.actionType {
        case TabPanelViewActionType.closeAllTabs:
            return TabTrayState(windowUUID: state.windowUUID,
                                isPrivateMode: state.isPrivateMode,
                                selectedPanel: state.selectedPanel,
                                normalTabsCount: state.normalTabsCount,
                                hasSyncableAccount: state.hasSyncableAccount,
                                showCloseConfirmation: true)

        default:
            return defaultState(from: state)
        }
    }

    static func defaultState(from state: TabTrayState) -> TabTrayState {
        return TabTrayState(windowUUID: state.windowUUID,
                            isPrivateMode: state.isPrivateMode,
                            selectedPanel: state.selectedPanel,
                            normalTabsCount: state.normalTabsCount,
                            hasSyncableAccount: state.hasSyncableAccount)
    }
}
