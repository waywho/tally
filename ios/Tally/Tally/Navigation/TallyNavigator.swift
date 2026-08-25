import HotwireNative
import UIKit

/// Wraps a Hotwire Navigator for a single tab. Each tab in the app gets its
/// own TallyNavigator so navigation stacks are independent.
final class TallyNavigator: NavigatorDelegate {
    let navigator: Navigator
    let rootURL: URL

    init(name: String, rootURL: URL) {
        self.rootURL = rootURL
        self.navigator = Navigator(configuration: .init(
            name: name,
            startLocation: rootURL
        ))
        navigator.delegate = self
        // Hide the native nav bar — web views have their own headers
        navigationController.setNavigationBarHidden(true, animated: false)
    }

    /// The UINavigationController managed by this navigator, suitable for
    /// embedding in a UITabBarController.
    var navigationController: UINavigationController {
        navigator.rootViewController
    }

    /// Loads the root URL into the navigator. Call once after setup.
    func start() {
        navigator.start()
    }

    /// Navigate to a specific URL within this tab's navigator.
    func visit(_ url: URL) {
        navigator.route(url)
    }

    /// Pop to the root view controller (used when the tab is re-tapped).
    func popToRoot() {
        navigationController.popToRootViewController(animated: true)
    }

    // MARK: - NavigatorDelegate

    func handle(proposal: VisitProposal, from navigator: Navigator) -> ProposalResult {
        // If the server redirected to /login, the session expired or user logged out
        if proposal.url.path == "/login" && SessionStore.loadCookies() != nil {
            NotificationCenter.default.post(name: .tallyDidLogout, object: nil)
            return .reject
        }
        return .accept
    }
}
