// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import Foundation
import Common
import MozillaAppServices

protocol BookmarksCoordinatorDelegate: AnyObject, LibraryPanelCoordinatorDelegate {
    func start(from folder: FxBookmarkNode)

    /// Shows the bookmark detail to modify a bookmark folder
    func showBookmarkDetail(for node: FxBookmarkNode, folder: FxBookmarkNode)

    /// Shows the bookmark detail to create a new bookmark or folder in the parent folder
    func showBookmarkDetail(
        bookmarkType: BookmarkNodeType,
        parentBookmarkFolder: FxBookmarkNode,
        parentFolderSelector: ParentFolderSelector?
    )

    func showSignIn()

    /// Calls the parent coordinator dismiss and remove the bookmarks coordinator
    func didFinish()
}

extension BookmarksCoordinatorDelegate {
    func showBookmarkDetail(
        bookmarkType: BookmarkNodeType,
        parentBookmarkFolder: FxBookmarkNode,
        parentFolderSelector: ParentFolderSelector? = nil
    ) {
        showBookmarkDetail(
            bookmarkType: bookmarkType,
            parentBookmarkFolder: parentBookmarkFolder,
            parentFolderSelector: parentFolderSelector
        )
    }
}

class BookmarksCoordinator: BaseCoordinator,
                            BookmarksCoordinatorDelegate,
                            QRCodeNavigationHandler,
                            ParentCoordinatorDelegate {
    // MARK: - Properties

    private let profile: Profile
    private weak var libraryCoordinator: LibraryCoordinatorDelegate?
    private weak var libraryNavigationHandler: LibraryNavigationHandler?
    private var fxAccountViewController: FirefoxAccountSignInViewController?
    private let windowUUID: WindowUUID

    // MARK: - Initializers

    init(
        router: Router,
        profile: Profile,
        windowUUID: WindowUUID,
        libraryCoordinator: LibraryCoordinatorDelegate?,
        libraryNavigationHandler: LibraryNavigationHandler?
    ) {
        self.profile = profile
        self.windowUUID = windowUUID
        self.libraryCoordinator = libraryCoordinator
        self.libraryNavigationHandler = libraryNavigationHandler
        super.init(router: router)
    }

    // MARK: - BookmarksCoordinatorDelegate

    func start(from folder: FxBookmarkNode) {
        let viewModel = BookmarksPanelViewModel(profile: profile,
                                                bookmarksHandler: profile.places,
                                                bookmarkFolderGUID: folder.guid)
        let controller = BookmarksViewController(viewModel: viewModel, windowUUID: windowUUID)
        controller.bookmarkCoordinatorDelegate = self
        controller.libraryPanelDelegate = libraryCoordinator
        router.push(controller)
    }

    func start(parentFolder: FxBookmarkNode, bookmark: FxBookmarkNode) {
        let viewModel = EditBookmarkViewModel(parentFolder: parentFolder,
                                              node: bookmark,
                                              profile: profile)
        viewModel.bookmarkCoordinatorDelegate = self
        let controller = EditBookmarkViewController(viewModel: viewModel,
                                                    windowUUID: windowUUID)
        router.setRootViewController(controller)
    }

    func showBookmarkDetail(for node: FxBookmarkNode, folder: FxBookmarkNode) {
        let bookmarksTelemetry = BookmarksTelemetry()
        bookmarksTelemetry.editBookmark(eventLabel: .bookmarksPanel)
        router.push(makeDetailController(for: node, folder: folder))
    }

    func showBookmarkDetail(
        bookmarkType: BookmarkNodeType,
        parentBookmarkFolder: FxBookmarkNode,
        parentFolderSelector: ParentFolderSelector? = nil
    ) {
        let detailController = makeDetailController(for: bookmarkType,
                                                    parentFolder: parentBookmarkFolder,
                                                    parentFolderSelector: parentFolderSelector)
        router.push(detailController)
    }

    func showSignIn() {
        let controller = makeSignInController()
        router.present(controller)
    }

    func didFinish() {
        libraryCoordinator?.didFinishLibrary(from: self)
    }

    func shareLibraryItem(url: URL, sourceView: UIView) {
        libraryNavigationHandler?.shareLibraryItem(url: url, sourceView: sourceView)
    }

    // MARK: - QRCodeNavigationHandler

    func showQRCode(delegate: QRCodeViewControllerDelegate, rootNavigationController: UINavigationController?) {
        var coordinator: QRCodeCoordinator
        if let qrCodeCoordinator = childCoordinators.first(where: { $0 is QRCodeCoordinator }) as? QRCodeCoordinator {
            coordinator = qrCodeCoordinator
        } else {
            if rootNavigationController != nil {
                coordinator = QRCodeCoordinator(
                    parentCoordinator: self,
                    router: DefaultRouter(navigationController: rootNavigationController!)
                )
            } else {
                coordinator = QRCodeCoordinator(
                    parentCoordinator: self,
                    router: router
                )
            }
            add(child: coordinator)
        }
        coordinator.showQRCode(delegate: delegate)
    }

    // MARK: - ParentCoordinatorDelegate

    func didFinish(from childCoordinator: Coordinator) {
        remove(child: childCoordinator)
    }

    // MARK: - Factory

    private func makeDetailController(for type: BookmarkNodeType,
                                      parentFolder: FxBookmarkNode,
                                      parentFolderSelector: ParentFolderSelector?) -> UIViewController {
        if type == .bookmark {
            return makeEditBookmarkController(for: nil, folder: parentFolder)
        }
        if type == .folder {
            return makeEditFolderController(for: nil, folder: parentFolder, parentFolderSelector: parentFolderSelector)
        }
        return UIViewController()
    }

    private func makeDetailController(for node: FxBookmarkNode, folder: FxBookmarkNode) -> UIViewController {
        if node.type == .bookmark {
            return makeEditBookmarkController(for: node, folder: folder)
        }
        if node.type == .folder {
            return makeEditFolderController(for: node, folder: folder, parentFolderSelector: nil)
        }
        return UIViewController()
    }

    private func makeEditBookmarkController(for node: FxBookmarkNode?, folder: FxBookmarkNode) -> UIViewController {
        let viewModel = EditBookmarkViewModel(parentFolder: folder, node: node, profile: profile)
        viewModel.onBookmarkSaved = { [weak self] in
            self?.reloadLastBookmarksController()
        }
        viewModel.bookmarkCoordinatorDelegate = self
        setBackBarButtonItemTitle(viewModel.getBackNavigationButtonTitle)
        let controller = EditBookmarkViewController(viewModel: viewModel,
                                                    windowUUID: windowUUID)
        controller.onViewWillAppear = { [weak self] in
            self?.libraryNavigationHandler?.setNavigationBarHidden(true)
        }
        controller.onViewWillDisappear = { [weak self] in
            if !(controller.transitionCoordinator?.isInteractive ?? false) {
                self?.libraryNavigationHandler?.setNavigationBarHidden(false)
            }
        }
        return controller
    }

    private func makeEditFolderController(for node: FxBookmarkNode?,
                                          folder: FxBookmarkNode,
                                          parentFolderSelector: ParentFolderSelector?) -> UIViewController {
        let viewModel = EditFolderViewModel(profile: profile,
                                            parentFolder: folder,
                                            folder: node)
        viewModel.onBookmarkSaved = { [weak self] in
            self?.reloadLastBookmarksController()
        }
        viewModel.parentFolderSelector = parentFolderSelector
        setBackBarButtonItemTitle("")
        let controller = EditFolderViewController(viewModel: viewModel,
                                                  windowUUID: windowUUID)
        controller.onViewWillAppear = { [weak self] in
            self?.libraryNavigationHandler?.setNavigationBarHidden(true)
        }
        controller.onViewWillDisappear = { [weak self] in
            if !(controller.transitionCoordinator?.isInteractive ?? false) {
                self?.libraryNavigationHandler?.setNavigationBarHidden(false)
            }
        }
        return controller
    }

    private func makeSignInController() -> UIViewController {
        let fxaParams = FxALaunchParams(entrypoint: .libraryPanel, query: [:])
        let viewController = FirefoxAccountSignInViewController(profile: profile,
                                                                parentType: .library,
                                                                deepLinkParams: fxaParams,
                                                                windowUUID: windowUUID)
        viewController.qrCodeNavigationHandler = self
        let buttonItem = UIBarButtonItem(
            title: .CloseButtonTitle,
            style: .plain,
            target: self,
            action: #selector(dismissFxAViewController)
        )
        viewController.navigationItem.leftBarButtonItem = buttonItem
        let navController = ThemedNavigationController(rootViewController: viewController, windowUUID: windowUUID)
        fxAccountViewController = viewController
        return navController
    }

    private func reloadLastBookmarksController() {
        guard let rootBookmarkController = router.navigationController.viewControllers.last
                as? BookmarksViewController
        else { return }
        rootBookmarkController.reloadData()
    }

    /// Sets the back button title for the controller
    ///
    /// It has to be done here and not in the detail controller directly, otherwise the modification won't take place.
    private func setBackBarButtonItemTitle(_ title: String) {
        let backBarButton = UIBarButtonItem(title: title)
        router.navigationController.viewControllers.last?.navigationItem.backBarButtonItem = backBarButton
    }

    @objc
    private func dismissFxAViewController() {
        fxAccountViewController?.dismissVC()
        fxAccountViewController = nil
    }
}
