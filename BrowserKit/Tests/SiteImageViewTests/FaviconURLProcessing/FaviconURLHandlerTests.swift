// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import XCTest
@testable import SiteImageView

class FaviconURLHandlerTests: XCTestCase {
    let siteURL = URL(string: "https://www.firefox.com")!
    let faviconURL = URL(string: "https://www.firefox.com/image")!

    var mockFetcher: MockFaviconURLFetcher!
    var mockCache: FaviconURLCacheMock!

    override func setUp() {
        super.setUp()
        mockFetcher = MockFaviconURLFetcher()
        mockCache = FaviconURLCacheMock()
    }

    func testGetFaviconURL_inCache() async throws {
        await mockCache.setTestResult(url: faviconURL)
        let model = createSiteImageModel(siteURL: siteURL)
        let subject = DefaultFaviconURLHandler(urlFetcher: mockFetcher,
                                               urlCache: mockCache)

        let url = try await subject.getFaviconURL(model: model)

        XCTAssertEqual(url, faviconURL)
        let getURLCount = await mockCache.getURLFromCacheCalledCount
        let cacheURLCount = await mockCache.cacheURLCalledCount
        XCTAssertEqual(getURLCount, 1, "get url should have been called on the cache")
        XCTAssertEqual(cacheURLCount, 0, "cache url should not have been called")
        XCTAssertEqual(mockFetcher.fetchFaviconURLCalledCount, 0, "fetch favicon url should not have been called")
    }

    func testGetFaviconURL_notInCache() async throws {
        await mockCache.setTestResult(error: .noURLInCache)
        mockFetcher.url = faviconURL
        let model = createSiteImageModel(siteURL: siteURL)
        let subject = DefaultFaviconURLHandler(urlFetcher: mockFetcher,
                                               urlCache: mockCache)

        let url = try await subject.getFaviconURL(model: model)

        XCTAssertEqual(url, faviconURL)
        let getURLCount = await mockCache.getURLFromCacheCalledCount
        let cacheURLCount = await mockCache.cacheURLCalledCount
        XCTAssertEqual(getURLCount, 1, "get url should have been called on the cache")
        XCTAssertEqual(cacheURLCount, 1, "cache url should have been called")
        XCTAssertEqual(mockFetcher.fetchFaviconURLCalledCount, 1, "fetch favicon url should have been called")
    }

    func testGetFaviconURL_forInternalURL() async {
        let internalSiteURL = URL(string: "internal://local/about/home#panel=0")!

        await mockCache.setTestResult(error: .noURLInCache)
        mockFetcher.url = faviconURL
        let model = createSiteImageModel(siteURL: internalSiteURL)
        let subject = DefaultFaviconURLHandler(urlFetcher: mockFetcher,
                                               urlCache: mockCache)
        do {
            _ = try await subject.getFaviconURL(model: model)
            XCTFail("Should throw an error")
        } catch {
            XCTAssertEqual(error as? SiteImageError, SiteImageError.noFaviconFound)
        }
    }

    func testGetFaviconURL_errorNoFaviconFound() async {
        await mockCache.setTestResult(error: .noURLInCache)
        mockFetcher.error = SiteImageError.noFaviconFound
        let model = createSiteImageModel(siteURL: siteURL)
        let subject = DefaultFaviconURLHandler(urlFetcher: mockFetcher,
                                               urlCache: mockCache)
        do {
            _ = try await subject.getFaviconURL(model: model)
            XCTFail("Request should have thrown an error")
        } catch {
            XCTAssertTrue(error is SiteImageError)
            XCTAssertEqual(error as? SiteImageError, SiteImageError.noFaviconURLFound)
        }
    }

    func testCacheFaviconURL() async {
        let subject = DefaultFaviconURLHandler(urlFetcher: mockFetcher,
                                               urlCache: mockCache)
        subject.cacheFaviconURL(cacheKey: "key", faviconURL: URL(string: "myUrl")!)

        try? await Task.sleep(nanoseconds: 100_000_000)
        let count = await mockCache.cacheURLCalledCount
        let key = await mockCache.cacheKey
        let url = await mockCache.faviconURL?.absoluteString

        XCTAssertEqual(count, 1)
        XCTAssertEqual(key, "key")
        XCTAssertEqual(url, "myUrl")
    }

    func testGetFaviconURL_whenClientError() async throws {
        await mockCache.setTestResult(error: .noURLInCache)
        mockFetcher.error = URLError(.notConnectedToInternet)
        let model = createSiteImageModel(siteURL: siteURL)
        let subject = DefaultFaviconURLHandler(urlFetcher: mockFetcher, urlCache: mockCache)

        do {
            _ = try await subject.getFaviconURL(model: model)
            XCTFail("Request should have thrown a client error")
        } catch {
            let responseError = try XCTUnwrap(error as? SiteImageError)
            XCTAssertEqual(responseError, SiteImageError.noFaviconURLFound)
            let cacheURLCalledCount = await mockCache.cacheURLCalledCount
            XCTAssertEqual(cacheURLCalledCount, 0)
        }
    }

    func testGetFaviconURL_whenServerError() async throws {
        await mockCache.setTestResult(error: .noURLInCache)
        mockFetcher.error = URLError(.badServerResponse)
        let model = createSiteImageModel(siteURL: siteURL)
        let subject = DefaultFaviconURLHandler(urlFetcher: mockFetcher, urlCache: mockCache)

        do {
            _ = try await subject.getFaviconURL(model: model)
            XCTFail("Request should have thrown a server error")
        } catch {
            let responseError = try XCTUnwrap(error as? SiteImageError)
            XCTAssertEqual(responseError, SiteImageError.noFaviconURLFound)
            let cacheURLCalledCount = await mockCache.cacheURLCalledCount
            XCTAssertEqual(cacheURLCalledCount, 1)
        }
    }

    func testClearCache() async {
        let subject = DefaultFaviconURLHandler(urlFetcher: mockFetcher,
                                               urlCache: mockCache)
        subject.clearCache()

        try? await Task.sleep(nanoseconds: 100_000_000)
        let count = await mockCache.clearCacheCalledCount

        XCTAssertEqual(count, 1)
    }

    private func createSiteImageModel(siteURL: URL) -> SiteImageModel {
        return SiteImageModel(id: UUID(),
                              imageType: .favicon,
                              siteURL: siteURL,
                              siteResource: nil)
    }
}
