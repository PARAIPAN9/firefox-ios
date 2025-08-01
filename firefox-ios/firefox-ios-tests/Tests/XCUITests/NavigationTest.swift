// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import Common
import XCTest

let website_1 = [
    "url": "www.mozilla.org",
    "label": "Internet for people, not profit — Mozilla",
    "value": "mozilla.org"
]
let website_2 = [
    "url": "www.example.com",
    "label": "Example",
    "value": "example",
    "link": "More information...",
    "moreLinkLongPressUrl": "iana.org",
    "moreLinkLongPressInfo": "iana"
]
let popUpTestUrl = path(forTestPage: "test-popup-blocker.html")

class NavigationTest: FeatureFlaggedTestBase {
    // https://mozilla.testrail.io/index.php?/cases/view/2441488
    func testNavigation() {
        app.launch()
        let urlPlaceholder = "Search or enter address"
        let searchTextField = AccessibilityIdentifiers.Browser.AddressToolbar.searchTextField
        mozWaitForElementToExist(app.textFields[searchTextField])
        let defaultValuePlaceholder = app.textFields[searchTextField].placeholderValue!

        // Check the url placeholder text and that the back and forward buttons are disabled
        XCTAssert(urlPlaceholder == defaultValuePlaceholder)
        XCTAssertFalse(app.buttons[AccessibilityIdentifiers.Toolbar.backButton].isEnabled)
        XCTAssertFalse(app.buttons[AccessibilityIdentifiers.Toolbar.forwardButton].isEnabled)

        if iPad() {
            app.textFields[AccessibilityIdentifiers.Browser.AddressToolbar.searchTextField].waitAndTap()
            // Once an url has been open, the back button is enabled but not the forward button
            navigator.performAction(Action.CloseURLBarOpen)
            navigator.nowAt(NewTabScreen)
        }
        navigator.openURL(path(forTestPage: "test-example.html"))
        waitUntilPageLoad()
        let url = app.textFields[AccessibilityIdentifiers.Browser.AddressToolbar.searchTextField]
        mozWaitForValueContains(url, value: "localhost")
        XCTAssertTrue(app.buttons[AccessibilityIdentifiers.Toolbar.backButton].isEnabled)
        XCTAssertFalse(app.buttons[AccessibilityIdentifiers.Toolbar.forwardButton].isEnabled)

        // Once a second url is open, back button is enabled but not the forward one till we go back to url_1
        navigator.openURL(path(forTestPage: "test-mozilla-org.html"))
        waitUntilPageLoad()
        mozWaitForValueContains(url, value: "localhost")
        XCTAssertTrue(app.buttons[AccessibilityIdentifiers.Toolbar.backButton].isEnabled)
        XCTAssertFalse(app.buttons[AccessibilityIdentifiers.Toolbar.forwardButton].isEnabled)
        // Go back to previous visited web site
        app.buttons[AccessibilityIdentifiers.Toolbar.backButton].waitAndTap()

        waitUntilPageLoad()
        mozWaitForValueContains(url, value: "localhost")

        if iPad() {
            app.buttons[AccessibilityIdentifiers.Toolbar.forwardButton].waitAndTap()
        } else {
            // Go forward to next visited web site
            app.buttons[AccessibilityIdentifiers.Toolbar.forwardButton].waitAndTap()
        }
        waitUntilPageLoad()
        mozWaitForValueContains(url, value: "localhost")
    }

    // https://mozilla.testrail.io/index.php?/cases/view/2441489
    func testTapSignInShowsFxAFromTour() {
        app.launch()
        waitForTabsButton()
        navigator.nowAt(NewTabScreen)
        // Open FxAccount from tour option in settings menu and go throughout all the screens there
        navigator.goto(Intro_FxASignin)
        navigator.performAction(Action.OpenEmailToSignIn)
        mozWaitForElementToExist(app.webViews.firstMatch, timeout: TIMEOUT_LONG)
        if #available(iOS 17, *) {
            mozWaitForElementToExist(app.webViews.staticTexts["Continue to your ⁨Mozilla account⁩"])
        }
    }

    // https://mozilla.testrail.io/index.php?/cases/view/2441493
    func testTapSigninShowsFxAFromSettings() {
        app.launch()
        waitForTabsButton()
        navigator.nowAt(NewTabScreen)
        navigator.goto(SettingsScreen)
        // Open FxAccount from settings menu and check the Sign in to Firefox screen
        let signInToFirefoxStaticText = app.tables[AccessibilityIdentifiers.Settings.tableViewController]
            .staticTexts[AccessibilityIdentifiers.Settings.FirefoxAccount.fxaSettingsButton]
        signInToFirefoxStaticText.waitAndTap()
        checkFirefoxSyncScreenShownViaSettings()

        // After that it is possible to go back to Settings
        let closeButton = app.navigationBars["Client.FxAWebView"].buttons.element(boundBy: 0)
        closeButton.waitAndTap()

        let closeButtonFxView = app.navigationBars[AccessibilityIdentifiers.Settings.FirefoxAccount.fxaNavigationBar]
            .buttons["Settings"]
        closeButtonFxView.waitAndTap()
    }

    // Because the Settings menu does not stretch tot the top we need a different function to check
    // if the Firefox Sync screen is shown
    private func checkFirefoxSyncScreenShownViaSettings() {
        mozWaitForElementToExist(
            app.navigationBars[AccessibilityIdentifiers.Settings.FirefoxAccount.fxaNavigationBar],
            timeout: TIMEOUT_LONG
        )
        app.buttons["EmailSignIn.button"].waitAndTap()
        mozWaitForElementToExist(app.webViews.textFields.element(boundBy: 0), timeout: TIMEOUT_LONG)

        let email = app.webViews.textFields.element(boundBy: 0)
        // Verify the placeholdervalues here for the textFields
        let mailPlaceholder = "Enter your email"
        var defaultMailPlaceholder: String
        if #available(iOS 17, *) {
            defaultMailPlaceholder = email.label
            XCTAssertEqual(mailPlaceholder, defaultMailPlaceholder, "The mail placeholder does not show the correct value")
        } else if #available(iOS 16, *), ProcessInfo.processInfo.operatingSystemVersion.majorVersion == 16 {
            if let value = app.staticTexts["Enter your email"].value as? String {
                defaultMailPlaceholder = value
                XCTAssertEqual(mailPlaceholder,
                               defaultMailPlaceholder,
                               "The mail placeholder does not show the correct value")
            } else {
                XCTFail("The mail placeholder value is not a String")
            }
        } else {
            mozWaitForElementToExist(app.staticTexts[mailPlaceholder])
        }
    }

    // https://mozilla.testrail.io/index.php?/cases/view/2441494
    func testTapSignInShowsFxAFromRemoteTabPanel_tabTrayExperimentOff() {
        addLaunchArgument(jsonFileName: "defaultEnabledOff", featureName: "tab-tray-ui-experiments")
        app.launch()
        waitForTabsButton()
        navigator.nowAt(NewTabScreen)
        // Open FxAccount from remote tab panel and check the Sign in to Firefox screen
        navigator.goto(TabTray)
        navigator.performAction(Action.ToggleSyncMode)

        app.tables.buttons[AccessibilityIdentifiers.Settings.FirefoxAccount.fxaSettingsButton].waitAndTap()
        waitForElementsToExist(
            [
                app.navigationBars["Sync and Save Data"],
                app.buttons["Use Email Instead"]
            ]
        )
    }

    // https://mozilla.testrail.io/index.php?/cases/view/2441494
    func testTapSignInShowsFxAFromRemoteTabPanel_tabTrayExperimentOn() {
        addLaunchArgument(jsonFileName: "defaultEnabledOn", featureName: "tab-tray-ui-experiments")
        app.launch()
        waitForTabsButton()
        navigator.nowAt(NewTabScreen)
        // Open FxAccount from remote tab panel and check the Sign in to Firefox screen
        navigator.goto(TabTray)
        navigator.performAction(Action.ToggleExperimentSyncMode)

        app.tables.buttons[AccessibilityIdentifiers.Settings.FirefoxAccount.fxaSettingsButton].waitAndTap()
        waitForElementsToExist(
            [
                app.navigationBars["Sync and Save Data"],
                app.buttons["Use Email Instead"]
            ]
        )
    }

    // https://mozilla.testrail.io/index.php?/cases/view/2441495
    func testScrollsToTopWithMultipleTabs() {
        app.launch()
        navigator.goto(TabTray)
        navigator.openURL(website_1["url"]!)
        waitUntilPageLoad()
        let url = app.textFields[AccessibilityIdentifiers.Browser.AddressToolbar.searchTextField]
        mozWaitForValueContains(url, value: website_1["value"]!)
        let topElement = app.links["Mozilla"].firstMatch
        let bottomElement = app.webViews.links.staticTexts["Legal"]

        // Scroll to bottom
        scrollToElement(bottomElement)
        mozWaitForElementToExist(bottomElement)
        // Scroll to top
        scrollToElement(topElement, swipe: "down")
        mozWaitForElementToExist(topElement)
    }

    // https://mozilla.testrail.io/index.php?/cases/view/2306836
    // Smoketest
    func testLongPressLinkOptions() {
        app.launch()
        openContextMenuForArticleLink()
        waitForElementsToExist(
            [
                app.buttons["Open in New Tab"],
                app.buttons["Open in New Private Tab"],
                app.buttons["Copy Link"],
                app.buttons["Download Link"],
                app.buttons["Share Link"],
                app.buttons["Bookmark Link"]
            ]
        )
    }

    // https://mozilla.testrail.io/index.php?/cases/view/2441496
    func testCopyLink() {
        app.launch()
        longPressLinkOptions(optionSelected: "Copy Link")
        navigator.goto(NewTabScreen)
        app.textFields[AccessibilityIdentifiers.Browser.AddressToolbar.searchTextField].press(forDuration: 2)

        mozWaitForElementToExist(app.tables["Context Menu"])
        app.tables.buttons[AccessibilityIdentifiers.Photon.pasteAction].waitAndTap()
        app.buttons["Go"].waitAndTap()
        waitUntilPageLoad()
        let url = app.textFields[AccessibilityIdentifiers.Browser.AddressToolbar.searchTextField]
        mozWaitForValueContains(url, value: website_2["moreLinkLongPressInfo"]!)
    }

    // https://mozilla.testrail.io/index.php?/cases/view/2441497
    func testCopyLinkPrivateMode_tabTrayExperimentOff() {
        addLaunchArgument(jsonFileName: "defaultEnabledOff", featureName: "tab-tray-ui-experiments")
        app.launch()
        navigator.nowAt(NewTabScreen)
        navigator.toggleOn(userState.isPrivate, withAction: Action.TogglePrivateMode)
        longPressLinkOptions(optionSelected: "Copy Link")
        navigator.goto(NewTabScreen)
        mozWaitForElementToExist(app.textFields[AccessibilityIdentifiers.Browser.AddressToolbar.searchTextField])
        app.textFields[AccessibilityIdentifiers.Browser.AddressToolbar.searchTextField].press(forDuration: 2)

        app.tables.buttons[AccessibilityIdentifiers.Photon.pasteAction].waitAndTap()
        app.buttons["Go"].waitAndTap()
        waitUntilPageLoad()
        let url = app.textFields[AccessibilityIdentifiers.Browser.AddressToolbar.searchTextField]
        mozWaitForValueContains(url, value: website_2["moreLinkLongPressInfo"]!)
    }

    // https://mozilla.testrail.io/index.php?/cases/view/2441497
    func testCopyLinkPrivateMode_tabTrayExperimentOn() {
        addLaunchArgument(jsonFileName: "defaultEnabledOn", featureName: "tab-tray-ui-experiments")
        app.launch()
        navigator.nowAt(NewTabScreen)
        navigator.toggleOn(userState.isPrivate, withAction: Action.ToggleExperimentPrivateMode)
        longPressLinkOptions(optionSelected: "Copy Link")
        navigator.goto(NewTabScreen)
        mozWaitForElementToExist(app.textFields[AccessibilityIdentifiers.Browser.AddressToolbar.searchTextField])
        app.textFields[AccessibilityIdentifiers.Browser.AddressToolbar.searchTextField].press(forDuration: 2)

        app.tables.buttons[AccessibilityIdentifiers.Photon.pasteAction].waitAndTap()
        app.buttons["Go"].waitAndTap()
        waitUntilPageLoad()
        let url = app.textFields[AccessibilityIdentifiers.Browser.AddressToolbar.searchTextField]
        mozWaitForValueContains(url, value: website_2["moreLinkLongPressInfo"]!)
    }

    // https://mozilla.testrail.io/index.php?/cases/view/2441923
    func testLongPressOnAddressBar() throws {
        // Long press on the URL requires copy & paste permission
        throw XCTSkip("Test needs to be updated")
        /*
            app.launch()
            // This test is for populated clipboard only so we need to make sure there's something in Pasteboard
            urlBarAddress.typeText("www.google.com")
            // Tapping two times when the text is not selected will reveal the menu
            urlBarAddress.tap()
            mozWaitForElementToExist(urlBarAddress)
            urlBarAddress.tap()
            mozWaitForElementToExist(app.menuItems["Select All"])
            XCTAssertTrue(app.menuItems["Select All"].exists)
            XCTAssertTrue(app.menuItems["Select"].exists)

            // Tap on Select All option and make sure Copy, Cut, Paste, and Look Up are shown
            app.menuItems["Select All"].tap()
            mozWaitForElementToExist(app.menuItems["Copy"])
            if iPad() {
                XCTAssertTrue(app.menuItems["Copy"].exists)
                XCTAssertTrue(app.menuItems["Cut"].exists)
                XCTAssertTrue(app.menuItems["Paste"].exists)
                XCTAssertTrue(app.menuItems["Open Link"].exists)
                XCTAssertTrue(app.menuItems["Add to Reading List"].exists)
                XCTAssertTrue(app.menuItems["Share…"].exists)
                XCTAssertTrue(app.menuItems["Paste & Go"].exists)
            } else {
                XCTAssertTrue(app.menuItems["Copy"].exists)
                XCTAssertTrue(app.menuItems["Cut"].exists)
                XCTAssertTrue(app.menuItems["Paste"].exists)
                XCTAssertTrue(app.menuItems["Open Link"].exists)
            }

            urlBarAddress.typeText("\n")
            waitUntilPageLoad()
            mozWaitForElementToNotExist(app.staticTexts["XCUITests-Runner pasted from Fennec"])

            app.textFields[AccessibilityIdentifiers.Browser.AddressToolbar.searchTextField].press(forDuration: 3)
            app.tables.otherElements[StandardImageIdentifiers.Large.link].tap()

            sleep(2)
            app.textFields[AccessibilityIdentifiers.Browser.AddressToolbar.searchTextField].tap()
            // Since the textField value appears all selected first time is clicked
            // this workaround is necessary
            mozWaitForElementToNotExist(app.staticTexts["XCUITests-Runner pasted from Fennec"])
            urlBarAddress.waitAndTap()
            mozWaitForElementToExist(app.menuItems["Copy"])
            if iPad() {
                XCTAssertTrue(app.menuItems["Cut"].exists)
                XCTAssertTrue(app.menuItems["Copy"].exists)
                XCTAssertTrue(app.menuItems["Open Link"].exists)
                XCTAssertTrue(app.menuItems["Add to Reading List"].exists)
                XCTAssertTrue(app.menuItems["Paste"].exists)
            } else {
                XCTAssertTrue(app.menuItems["Copy"].exists)
                XCTAssertTrue(app.menuItems["Cut"].exists)
                XCTAssertTrue(app.menuItems["Open Link"].exists)
            }
        }
         */
    }

    private func longPressLinkOptions(optionSelected: String) {
        navigator.nowAt(NewTabScreen)
        if app.buttons["Done"].exists {
            app.buttons["Done"].waitAndTap()
        }
        navigator.goto(ClearPrivateDataSettings)
        app.cells.switches["Downloaded Files"].waitAndTap()
        navigator.performAction(Action.AcceptClearPrivateData)

        navigator.goto(HomePanelsScreen)
        navigator.openURL(path(forTestPage: "test-example.html"))
        waitUntilPageLoad()
        app.webViews.links[website_2["link"]!].press(forDuration: 2)
        app.buttons[optionSelected].waitAndTap()
    }

    // https://mozilla.testrail.io/index.php?/cases/view/2441498
    func testDownloadLink() {
        app.launch()
        longPressLinkOptions(optionSelected: "Download Link")
        mozWaitForElementToExist(app.tables["Context Menu"])
        app.tables["Context Menu"].buttons[StandardImageIdentifiers.Large.download].waitAndTap()
        navigator.goto(BrowserTabMenu)
        navigator.goto(LibraryPanel_Downloads)
        mozWaitForElementToExist(app.tables["DownloadsTable"])
        // There should be one item downloaded. It's name and size should be shown
        let downloadedList = app.tables["DownloadsTable"].cells.count
        XCTAssertEqual(downloadedList, 1, "The number of items in the downloads table is not correct")
        mozWaitForElementToExist(app.tables.cells.staticTexts["example-domains.html"])

        // Tap on the just downloaded link to check that the web page is loaded
        app.tables.cells.staticTexts["example-domains.html"].waitAndTap()
        waitUntilPageLoad()
        let url = app.textFields[AccessibilityIdentifiers.Browser.AddressToolbar.searchTextField]
        mozWaitForValueContains(url, value: "example-domains.html")
    }

    // https://mozilla.testrail.io/index.php?/cases/view/2441499
    func testShareLink() {
        app.launch()
        longPressLinkOptions(optionSelected: "Share Link")
        if #available(iOS 16, *) {
            mozWaitForElementToExist(app.cells["Copy"])
        } else {
            mozWaitForElementToExist(app.buttons["Copy"])
        }
        if #unavailable(iOS 18) {
            if !iPad() {
                mozWaitForElementToExist(app.scrollViews.staticTexts["Messages"])
            }
        }
        if #unavailable(iOS 17) {
            mozWaitForElementToExist(app.scrollViews.cells["XCElementSnapshotPrivilegedValuePlaceholder"])
        } else {
            mozWaitForElementToExist(app.scrollViews.staticTexts["Reminders"])
        }
    }

    // https://mozilla.testrail.io/index.php?/cases/view/2441500
    func testShareLinkPrivateMode_tabTrayExperimentOff() {
        addLaunchArgument(jsonFileName: "defaultEnabledOff", featureName: "tab-tray-ui-experiments")
        app.launch()
        navigator.nowAt(NewTabScreen)
        navigator.toggleOn(userState.isPrivate, withAction: Action.TogglePrivateMode)
        longPressLinkOptions(optionSelected: "Share Link")
        if #available(iOS 16, *) {
            mozWaitForElementToExist(app.cells["Copy"])
        } else {
            mozWaitForElementToExist(app.buttons["Copy"])
        }
        if #unavailable(iOS 18) {
            if !iPad() {
                mozWaitForElementToExist(app.scrollViews.staticTexts["Messages"])
            }
        }
        if #unavailable(iOS 17) {
            mozWaitForElementToExist(app.scrollViews.cells["XCElementSnapshotPrivilegedValuePlaceholder"])
        } else {
            mozWaitForElementToExist(app.scrollViews.staticTexts["Reminders"])
        }
    }

    // https://mozilla.testrail.io/index.php?/cases/view/2441776
    // Smoketest
    func testPopUpBlocker_tabTrayExperimentOff() throws {
        addLaunchArgument(jsonFileName: "defaultEnabledOff", featureName: "tab-tray-ui-experiments")
        app.launch()
        // Check that it is enabled by default
        navigator.nowAt(BrowserTab)
        mozWaitForElementToExist(app.buttons["TabToolbar.menuButton"], timeout: TIMEOUT)
        navigator.goto(BrowsingSettings)
        mozWaitForElementToExist(app.tables.otherElements[AccessibilityIdentifiers.Settings.Browsing.tabs])
        let switchBlockPopUps = app.tables.cells.switches[AccessibilityIdentifiers.Settings.Browsing.blockPopUps]
        let switchValue = switchBlockPopUps.value!
        XCTAssertEqual(switchValue as? String, "1")
        // Navigate back to the homepage
        navigator.goto(BrowserTab)
        navigator.nowAt(NewTabScreen)

        // Check that there are no pop ups
        navigator.openURL(popUpTestUrl)
        mozWaitForValueContains(app.textFields[AccessibilityIdentifiers.Browser.AddressToolbar.searchTextField],
                                value: "localhost")
        mozWaitForElementToExist(app.webViews.staticTexts["Blocked Element"])

        let numTabs = app.buttons[AccessibilityIdentifiers.Toolbar.tabsButton].value
        XCTAssertEqual("1", numTabs as? String, "There should be only on tab")

        // Now disable the Browsing -> Block PopUps option
        navigator.goto(BrowserTabMenu)
        navigator.goto(BrowsingSettings)
        mozWaitForElementToExist(app.tables.otherElements[AccessibilityIdentifiers.Settings.Browsing.tabs])

        switchBlockPopUps.waitAndTap()
        let switchValueAfter = switchBlockPopUps.value!
        XCTAssertEqual(switchValueAfter as? String, "0")
        // Navigate back to the homepage
        app.buttons[AccessibilityIdentifiers.Settings.title].waitAndTap()
        app.buttons[AccessibilityIdentifiers.Settings.navigationBarItem].waitAndTap()
        navigator.nowAt(NewTabScreen)

        // Check that now pop ups are shown, two sites loaded
        navigator.goto(URLBarOpen)
        app.buttons["Clear text"].waitAndTap()
        navigator.openURL(popUpTestUrl)
        waitUntilPageLoad()
        mozWaitForValueContains(app.textFields[AccessibilityIdentifiers.Browser.AddressToolbar.searchTextField],
                                value: "example.com")
        let numTabsAfter = app.buttons[AccessibilityIdentifiers.Toolbar.tabsButton].value
        XCTAssertNotEqual("1", numTabsAfter as? String, "Several tabs are open")
    }

    // https://mozilla.testrail.io/index.php?/cases/view/2441776
    // Smoketest
    func testPopUpBlocker_tabTrayExperimentOn() throws {
        addLaunchArgument(jsonFileName: "defaultEnabledOn", featureName: "tab-tray-ui-experiments")
        app.launch()
        // Check that it is enabled by default
        navigator.nowAt(BrowserTab)
        mozWaitForElementToExist(app.buttons["TabToolbar.menuButton"], timeout: TIMEOUT)
        navigator.goto(BrowsingSettings)
        mozWaitForElementToExist(app.tables.otherElements[AccessibilityIdentifiers.Settings.Browsing.links])
        let switchBlockPopUps = app.tables.cells.switches[AccessibilityIdentifiers.Settings.Browsing.blockPopUps]
        let switchValue = switchBlockPopUps.value!
        XCTAssertEqual(switchValue as? String, "1")
        // Navigate back to the homepage
        navigator.goto(BrowserTab)
        navigator.nowAt(NewTabScreen)

        // Check that there are no pop ups
        navigator.openURL(popUpTestUrl)
        mozWaitForValueContains(app.textFields[AccessibilityIdentifiers.Browser.AddressToolbar.searchTextField],
                                value: "localhost")
        mozWaitForElementToExist(app.webViews.staticTexts["Blocked Element"])

        let numTabs = app.buttons[AccessibilityIdentifiers.Toolbar.tabsButton].value
        XCTAssertEqual("1", numTabs as? String, "There should be only on tab")

        // Now disable the Browsing -> Block PopUps option
        navigator.goto(BrowserTabMenu)
        navigator.goto(BrowsingSettings)
        mozWaitForElementToExist(app.tables.otherElements[AccessibilityIdentifiers.Settings.Browsing.links])

        switchBlockPopUps.waitAndTap()
        let switchValueAfter = switchBlockPopUps.value!
        XCTAssertEqual(switchValueAfter as? String, "0")
        // Navigate back to the homepage
        app.buttons[AccessibilityIdentifiers.Settings.title].waitAndTap()
        app.buttons[AccessibilityIdentifiers.Settings.navigationBarItem].waitAndTap()
        navigator.nowAt(NewTabScreen)

        // Check that now pop ups are shown, two sites loaded
        navigator.goto(URLBarOpen)
        app.buttons["Clear text"].waitAndTap()
        navigator.openURL(popUpTestUrl)
        waitUntilPageLoad()
        mozWaitForValueContains(app.textFields[AccessibilityIdentifiers.Browser.AddressToolbar.searchTextField],
                                value: "example.com")
        let numTabsAfter = app.buttons[AccessibilityIdentifiers.Toolbar.tabsButton].value
        XCTAssertNotEqual("1", numTabsAfter as? String, "Several tabs are open")
    }

    // https://mozilla.testrail.io/index.php?/cases/view/2306858
    // Smoketest
    func testSSL() {
        app.launch()
        navigator.nowAt(NewTabScreen)
        navigator.openURL("https://expired.badssl.com/")
        mozWaitForElementToExist(app.webViews.otherElements["This Connection is Untrusted"])
        XCTAssertTrue(app.webViews.otherElements["This Connection is Untrusted"].exists)
        app.buttons["Go Back"].waitAndTap()
        navigator.nowAt(NewTabScreen)
        navigator.openURL("https://expired.badssl.com/")
        mozWaitForElementToExist(app.webViews.otherElements["This Connection is Untrusted"])
        XCTAssertTrue(app.webViews.otherElements["This Connection is Untrusted"].exists)
        app.buttons["Advanced"].waitAndTap()
        app.links["Visit site anyway"].waitAndTap()
        mozWaitForElementToExist(app.webViews.otherElements["expired.badssl.com"], timeout: TIMEOUT_LONG)
    }

    // https://mozilla.testrail.io/index.php?/cases/view/2307022
    // In this test, the parent window opens a child and in the child it creates a fake link 'link-created-by-parent'
    func testWriteToChildPopupTab() {
        app.launch()
        waitForTabsButton()
        navigator.nowAt(NewTabScreen)
        navigator.goto(BrowsingSettings)
        let switchBlockPopUps = app.tables.cells.switches[AccessibilityIdentifiers.Settings.Browsing.blockPopUps]
        switchBlockPopUps.waitAndTap()
        let switchValueAfter = switchBlockPopUps.value!
        XCTAssertEqual(switchValueAfter as? String, "0")
        navigator.goto(HomePanelsScreen)
        navigator.openURL(path(forTestPage: "test-mozilla-org.html"))
        waitUntilPageLoad()
        navigator.openURL(path(forTestPage: "test-window-opener.html"))
        mozWaitForElementToExist(app.links["link-created-by-parent"])
    }

    // https://mozilla.testrail.io/index.php?/cases/view/2307020
    // Smoketest
    func testVerifyBrowserTabMenu() {
        app.launch()
        mozWaitForElementToExist(app.buttons[AccessibilityIdentifiers.Toolbar.settingsMenuButton])
        navigator.nowAt(NewTabScreen)
        navigator.goto(BrowserTabMenu)
        waitForElementsToExist(
            [
                app.tables.cells.buttons[AccessibilityIdentifiers.MainMenu.bookmarks],
                app.tables.cells.buttons[AccessibilityIdentifiers.MainMenu.history],
                app.tables.cells.buttons[AccessibilityIdentifiers.MainMenu.downloads],
                app.tables.cells.buttons[AccessibilityIdentifiers.MainMenu.passwords],
                app.tables.cells[AccessibilityIdentifiers.MainMenu.settings]
            ]
        )
    }

    // https://mozilla.testrail.io/index.php?/cases/view/2441775
    // Smoketest
    func testURLBar() {
        app.launch()
        let urlBar = app.textFields[AccessibilityIdentifiers.Browser.AddressToolbar.searchTextField]
        urlBar.waitAndTap()

        XCTAssertTrue(urlBarAddress.value(forKey: "hasKeyboardFocus") as? Bool ?? false)

        // These instances are false positives of the swiftlint configuration
        // swiftlint:disable empty_count
        XCTAssert(app.keyboards.count > 0, "The keyboard is not shown")
        app.typeText("example.com\n")

        mozWaitForValueContains(urlBar, value: "example.com")
        XCTAssertFalse(app.keyboards.count > 0, "The keyboard is shown")
        // swiftlint:enable empty_count
    }

    // https://mozilla.testrail.io/index.php?/cases/view/2441772
    func testOpenInNewTab_tabTrayExperimentOff() {
        addLaunchArgument(jsonFileName: "defaultEnabledOff", featureName: "tab-tray-ui-experiments")
        app.launch()
        // Long-tap on an article link. Choose "Open in New Tab".
        openContextMenuForArticleLink()
        app.buttons["Open in New Tab"].waitAndTap()
        // A new tab loading the article page should open
        navigator.goto(TabTray)
        mozWaitForElementToExist(app.otherElements[tabsTray].cells.staticTexts["Example Domain"])
        let numTabs = app.otherElements[tabsTray].cells.count
        XCTAssertEqual(numTabs, 2, "Total number of opened tabs should be 2")
        mozWaitForElementToExist(app.otherElements[tabsTray].cells.elementContainingText("Example Domain."))
    }

    // https://mozilla.testrail.io/index.php?/cases/view/2441772
    func testOpenInNewTab_tabTrayExperimentOn() {
        addLaunchArgument(jsonFileName: "defaultEnabledOn", featureName: "tab-tray-ui-experiments")
        app.launch()
        // Long-tap on an article link. Choose "Open in New Tab".
        openContextMenuForArticleLink()
        app.buttons["Open in New Tab"].waitAndTap()
        // A new tab loading the article page should open
        navigator.goto(TabTray)
        mozWaitForElementToExist(app.cells.elementContainingText("Example Domain"))
        let numTabs = app.otherElements[tabsTray].cells.count
        XCTAssertEqual(numTabs, 2, "Total number of opened tabs should be 2")
        mozWaitForElementToExist(app.otherElements[tabsTray].cells.elementContainingText("Example Domain."))
    }

    // https://mozilla.testrail.io/index.php?/cases/view/2441773
    func testOpenInNewPrivateTab_tabTrayExperimentOff() {
        addLaunchArgument(jsonFileName: "defaultEnabledOff", featureName: "tab-tray-ui-experiments")
        app.launch()
        // Long-tap on an article link. Choose "Open in New Private Tab".
        openContextMenuForArticleLink()
        app.buttons["Open in New Private Tab"].waitAndTap()
        // The article is loaded in a new private tab
        navigator.goto(TabTray)
        var numTabs = app.otherElements[tabsTray].cells.count
        XCTAssertEqual(numTabs, 1, "Total number of regulat opened tabs should be 1")
        mozWaitForElementToExist(app.otherElements[tabsTray].cells.elementContainingText("Example Domain."))
        if iPad() {
            app.buttons["Private"].waitAndTap()
        } else {
            // Workaround for https://github.com/mozilla-mobile/firefox-ios/issues/25093
            // Waiting is needed before switching to private tab in order to display the expected domain
            sleep(3)
            // workaround end
            app.buttons[StandardImageIdentifiers.Large.privateMode].waitAndTap()
        }
        numTabs = app.otherElements[tabsTray].cells.count
        XCTAssertEqual(numTabs, 1, "Total number of private opened tabs should be 1")
        mozWaitForElementToExist(app.otherElements[tabsTray].cells.element(boundBy: 0).staticTexts["Example Domains"])
    }

    // https://mozilla.testrail.io/index.php?/cases/view/2441774
    func testBookmarkLink() {
        app.launch()
        // Long-tap on an article link. Choose "Bookmark Link".
        openContextMenuForArticleLink()
        app.buttons["Bookmark Link"].waitAndTap()
        // The link has been added to the Bookmarks panel in Library
        navigator.goto(LibraryPanel_Bookmarks)
        waitForElementsToExist(
            [
                app.tables["Bookmarks List"],
                app.tables["Bookmarks List"].staticTexts[website_2["link"]!]
            ]
        )
    }

    // https://mozilla.testrail.io/index.php?/cases/view/2695828
    func testBackArrowNavigation() {
        app.launch()
        mozWaitForElementToExist(app.buttons[AccessibilityIdentifiers.Toolbar.settingsMenuButton])
        navigator.nowAt(NewTabScreen)
        closeFromAppSwitcherAndRelaunch()
        navigator.openURL(path(forTestPage: "test-example.html"))
        waitUntilPageLoad()
        app.links[website_2["link"]!].waitAndTap()
        waitUntilPageLoad()
        let backButton = app.buttons[AccessibilityIdentifiers.Toolbar.backButton]
        mozWaitForElementToExist(backButton)
        mozWaitElementHittable(element: backButton, timeout: TIMEOUT)
        XCTAssertTrue(backButton.isEnabled, "Back button is disabled")
        backButton.waitAndTap()
        waitUntilPageLoad()
        if #available(iOS 16, *) {
            let url = app.textFields[AccessibilityIdentifiers.Browser.AddressToolbar.searchTextField]
            mozWaitForValueContains(url, value: "localhost")
            XCTAssertTrue(backButton.isHittable, "Back button is not hittable")
            XCTAssertTrue(backButton.isEnabled, "Back button is disabled")
            backButton.waitAndTap()
            waitUntilPageLoad()
            mozWaitForElementToExist(app.links[AccessibilityIdentifiers.FirefoxHomepage.TopSites.itemCell])
        }
    }

    // https://mozilla.testrail.io/index.php?/cases/view/2721282
    func testOpenExternalLink_tabTrayExperimentOff() {
        addLaunchArgument(jsonFileName: "defaultEnabledOff", featureName: "tab-tray-ui-experiments")
        app.launch()
        // Go to Settings -> Browsing and disable "Block external links" toggle
        navigator.nowAt(NewTabScreen)
        navigator.goto(BrowsingSettings)
        mozWaitForElementToExist(app.tables.otherElements[AccessibilityIdentifiers.Settings.Browsing.tabs])
        let switchBlockLinks = app.tables.cells.switches[AccessibilityIdentifiers.Settings.BlockExternal.title]
        scrollToElement(switchBlockLinks)
        if let switchValue = switchBlockLinks.value as? String, switchValue == "1" {
            switchBlockLinks.waitAndTap()
        }
        // Open website and tap on one of the external article links
        navigator.nowAt(BrowsingSettings)
        navigator.goto(NewTabScreen)
        validateExternalLink()
        navigator.nowAt(NewTabScreen)
        navigator.toggleOn(userState.isPrivate, withAction: Action.TogglePrivateMode)
        validateExternalLink(isPrivate: true)
    }

    private func validateExternalLink(isPrivate: Bool = false) {
        navigator.openURL("ultimateqa.com/dummy-automation-websites")
        waitUntilPageLoad()

        // If there are multiple matches for "SauceDemo.com", then both the normal tab and the private tab views may be
        // in the view hierarchy simultaneously. This should not change unintentionally! Check the Debug View Hierarchy.
        // Note: Additional matches may also appear if the external website updates.
        XCTAssertEqual(app.links.matching(identifier: "SauceDemo.com").count, 1, "Too many matches")

        if #available(iOS 18, *) {
            scrollToElement(app.links["SauceDemo.com"].firstMatch)
        } else {
            app.swipeUp()
        }
        app.links["SauceDemo.com"].firstMatch.tap(force: true)
        waitUntilPageLoad()
        // Sometimes first tap is not working on iPad
        if iPad() {
            if let urlTextField =  app.textFields[AccessibilityIdentifiers.Browser.AddressToolbar.searchTextField].value
                as? String,
               urlTextField == "ultimateqa.com" {
                app.links["SauceDemo.com"].firstMatch.tap(force: true)
            }
        }
        let tabsButton = app.buttons[AccessibilityIdentifiers.Toolbar.tabsButton]
        mozWaitForElementToExist(tabsButton)
        XCTAssertEqual(tabsButton.value as? String, "2")
    }

    private func openContextMenuForArticleLink() {
        navigator.openURL(path(forTestPage: "test-example.html"))
        mozWaitForElementToExist(app.webViews.links[website_2["link"]!], timeout: TIMEOUT_LONG)
        app.webViews.links[website_2["link"]!].press(forDuration: 2)
        mozWaitForElementToExist(app.otherElements.collectionViews.element(boundBy: 0))
    }
 }
