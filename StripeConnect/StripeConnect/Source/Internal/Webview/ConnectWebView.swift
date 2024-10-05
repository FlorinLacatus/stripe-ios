//
//  ConnectWebView.swift
//  StripeConnect
//
//  Created by Mel Ludowise on 5/3/24.
//

import QuickLook
import SafariServices
@_spi(STP) import StripeCore
import WebKit

enum ConnectWebViewError: Int, Error {
    case popupNotSet = 0
}

/**
 Custom implementation of a web view that handles:
 - Camera access
 - Popup windows
 - Opening email links
 - Downloads 
 */
@available(iOS 15, *)
class ConnectWebView: WKWebView {

    /// File URL for a downloaded file
    var downloadedFile: URL?

    private var optionalPresentPopup: ((UIViewController) -> Void)?

    /// Closure to present a popup web view controller.
    /// This is required for any components that can open a popup, otherwise an assertionFailure will occur.
    var presentPopup: (UIViewController) -> Void {
        get {
            assert(optionalPresentPopup != nil, "Cannot present popup")
            analyticsClient.logError(ConnectWebViewError.popupNotSet)
            return optionalPresentPopup ?? { _ in }
        }
        set {
            optionalPresentPopup = newValue
        }
    }

    /// Closure that executes when `window.close()` is called in JS
    var didClose: ((ConnectWebView) -> Void)?

    /// The instance that will handle opening external urls
    let urlOpener: ApplicationURLOpener

    /// The file manager responsible for creating temporary file directories to store downloads
    let fileManager: FileManager

    /// The analytics client used to log load errors
    let analyticsClient: ComponentAnalyticsClient

    /// The current version for the SDK
    let sdkVersion: String?

    init(frame: CGRect,
         configuration: WKWebViewConfiguration,
         analyticsClient: ComponentAnalyticsClient,
         // Only override for tests
         urlOpener: ApplicationURLOpener = UIApplication.shared,
         fileManager: FileManager = .default,
         sdkVersion: String? = StripeAPIConfiguration.STPSDKVersion) {
        self.analyticsClient = analyticsClient
        self.urlOpener = urlOpener
        self.fileManager = fileManager
        self.sdkVersion = sdkVersion
        configuration.applicationNameForUserAgent = "- stripe-ios/\(sdkVersion ?? "")"
        super.init(frame: frame, configuration: configuration)

        // Allow the web view to be inspected for debug builds on 16.4+
        #if DEBUG
        if #available(iOS 16.4, *) {
            isInspectable = true
        }
        #endif

        uiDelegate = self
        navigationDelegate = self
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func showAlertAndLog(error: Error) {
        analyticsClient.logError(error)
        let alert = UIAlertController(
            title: nil,
            message: NSError.stp_unexpectedErrorMessage(),
            preferredStyle: .alert)
        presentPopup(alert)
    }
}

// MARK: - Private

@available(iOS 15, *)
private extension ConnectWebView {
    // Opens the given navigation in a PopupWebViewController
    func openInPopup(configuration: WKWebViewConfiguration,
                     navigationAction: WKNavigationAction) -> WKWebView? {
        let popupVC = PopupWebViewController(configuration: configuration,
                                             navigationAction: navigationAction,
                                             analyticsClient: analyticsClient,
                                             urlOpener: urlOpener,
                                             sdkVersion: sdkVersion)
        let navController = UINavigationController(rootViewController: popupVC)
        popupVC.navigationItem.rightBarButtonItem = .init(systemItem: .done, primaryAction: .init(handler: { [weak popupVC] _ in
            popupVC?.dismiss(animated: true)
        }))

        presentPopup(navController)
        return popupVC.webView
    }

    // Opens the given URL in an SFSafariViewController
    func openInAppSafari(url: URL) {
        let safariVC = SFSafariViewController(url: url)
        safariVC.dismissButtonStyle = .done
        safariVC.modalPresentationStyle = .popover
        presentPopup(safariVC)
    }

    // Opens with UIApplication.open, if supported
    func openOnSystem(url: URL) {
        do {
            try urlOpener.openIfPossible(url)
        } catch {
            analyticsClient.logError(error)
        }
    }
}

// MARK: - WKUIDelegate

@available(iOS 15, *)
extension ConnectWebView: WKUIDelegate {
    func webView(_ webView: WKWebView,
                 createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction,
                 windowFeatures: WKWindowFeatures) -> WKWebView? {
        // If targetFrame is nil, this is a popup
        guard navigationAction.targetFrame == nil else { return nil }

        if let url = navigationAction.request.url {
            // Only `http` or `https` URL schemes can be opened in WKWebView or
            // SFSafariViewController. Opening other schemes, like `mailto`, will
            // cause a fatal error.
            guard Set(["http", "https"]).contains(url.scheme) else {
                openOnSystem(url: url)
                return nil
            }

            // Only open popups to known hosts inside PopupWebViewController,
            // otherwise use an SFSafariViewController
            guard let host = url.host,
                    StripeConnectConstants.allowedHosts.contains(host) else {
                openInAppSafari(url: url)
                return nil
            }
        }

        return openInPopup(configuration: configuration, navigationAction: navigationAction)
    }

    func webView(_ webView: WKWebView,
                 decideMediaCapturePermissionsFor origin: WKSecurityOrigin,
                 initiatedBy frame: WKFrameInfo,
                 type: WKMediaCaptureType) async -> WKPermissionDecision {
        // Don't prompt the user for camera permissions from a Connect host
        // https://developer.apple.com/videos/play/wwdc2021/10032/?time=754
        StripeConnectConstants.allowedHosts.contains(origin.host) ? .grant : .deny
    }

    func webViewDidClose(_ webView: WKWebView) {
        // Call our custom handler when `window.close()` is called from JS
        self.didClose?(self)
    }
}

// MARK: - WKNavigationDelegate

@available(iOS 15, *)
extension ConnectWebView: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // To be overridden by subclass
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: any Error) {
        // Log error
        analyticsClient.log(event: PageLoadErrorEvent(metadata: .init(
            error: error,
            url: webView.url
        )))
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: any Error) {
        // Log error
        analyticsClient.log(event: PageLoadErrorEvent(metadata: .init(
            error: error,
            url: webView.url
        )))
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction
    ) async -> WKNavigationActionPolicy {
        /*
         `shouldPerformDownload` will be true if the request has MIME types
         or a `Content-Type` header indicating it's a download or it originated
         as a JS download.

         NOTE: We sometimes can't know if a request should be a download until
         after its response is received. Those cases are handled by
         `decidePolicyFor navigationResponse` below.
         */
        navigationAction.shouldPerformDownload ? .download : .allow
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationResponse: WKNavigationResponse
    ) async -> WKNavigationResponsePolicy {
        // Log erroneous status code if applicable
        if let httpResponse = navigationResponse.response as? HTTPURLResponse,
           httpResponse.statusCode != 200 {
            analyticsClient.log(event: PageLoadErrorEvent(metadata: .init(
                status: httpResponse.statusCode,
                url: httpResponse.url
            )))
        }

        // Downloads will typically originate from a non-allow-listed host (e.g. S3)
        // so first check if the response is a download before evaluating the host

        // The response should be a download if its Content-Disposition is
        // shaped like `attachment; filename=payouts.csv`
        if navigationResponse.canShowMIMEType,
           let response = navigationResponse.response as? HTTPURLResponse,
           let contentDisposition = response.value(forHTTPHeaderField: "Content-Disposition"),
           contentDisposition
            .split(separator: ";")
            .map({ $0.trimmingCharacters(in: .whitespaces) })
            .caseInsensitiveContains("attachment") {
            return .download
        }

        return .allow
    }

    func webView(_ webView: WKWebView,
                 navigationAction: WKNavigationAction,
                 didBecome download: WKDownload) {
        download.delegate = self
    }

    func webView(_ webView: WKWebView,
                 navigationResponse: WKNavigationResponse,
                 didBecome download: WKDownload) {
        download.delegate = self
    }
}

// MARK: - WKDownloadDelegate implementation

@available(iOS 15, *)
extension ConnectWebView {
    // This extension is an abstraction layer to implement `WKDownloadDelegate`
    // functionality and make it testable. There's no way to instantiate
    // `WKDownload` in tests without causing an EXC_BAD_ACCESS error.

    func download(decideDestinationUsing response: URLResponse,
                  suggestedFilename: String) async -> URL? {
        // The temporary filename must be unique or the download will fail.
        // To ensure uniqueness, append a UUID to the directory path in case a
        // file with the same name was already downloaded from this app.
        let tempDir = fileManager
            .temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        do {
            try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        } catch {
            showAlertAndLog(error: error)
            return nil
        }

        downloadedFile = tempDir.appendingPathComponent(suggestedFilename)
        return downloadedFile
    }

    func download(didFailWithError error: any Error,
                  resumeData: Data?) {
        showAlertAndLog(error: error)
    }

    func downloadDidFinish() {

        // Display a preview of the file to the user
        let previewController = QLPreviewController()
        previewController.dataSource = self
        previewController.modalPresentationStyle = .pageSheet
        presentPopup(previewController)
    }
}

// MARK: - WKDownloadDelegate

@available(iOS 15, *)
extension ConnectWebView: WKDownloadDelegate {
    func download(_ download: WKDownload,
                  decideDestinationUsing response: URLResponse,
                  suggestedFilename: String) async -> URL? {
        await self.download(decideDestinationUsing: response,
                            suggestedFilename: suggestedFilename)
    }

    func download(_ download: WKDownload,
                  didFailWithError error: any Error,
                  resumeData: Data?) {
        self.download(didFailWithError: error, resumeData: resumeData)
    }

    func downloadDidFinish(_ download: WKDownload) {
        self.downloadDidFinish()
    }
}

// MARK: - QLPreviewControllerDataSource

@available(iOS 15, *)
extension ConnectWebView: QLPreviewControllerDataSource {
    func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
        downloadedFile == nil ? 0 : 1
    }

    func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> any QLPreviewItem {
        // Okay to force-unwrap since numberOfPreviewItems returns 0 when downloadFile is nil
        downloadedFile! as QLPreviewItem
    }
}
