import UIKit
import WebKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = (scene as? UIWindowScene) else { return }

        window = UIWindow(windowScene: windowScene)

        // Observe logout from web Settings page
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleLogout),
            name: .tallyDidLogout,
            object: nil
        )

        if let cookies = SessionStore.loadCookies() {
            injectCookiesAndShowApp(cookies: cookies)
        } else {
            showLogin()
        }
    }

    // MARK: - Transitions

    private func showLogin() {
        let loginVC = LoginViewController { [weak self] in
            self?.transitionToApp()
        }
        window?.rootViewController = loginVC
        window?.makeKeyAndVisible()
    }

    private func transitionToApp() {
        let tabBar = TabBarController()
        window?.rootViewController = tabBar
    }

    @objc private func handleLogout() {
        SessionStore.clear()
        // Clear all website data so stale cookies don't linger in webviews
        WKWebsiteDataStore.default().removeData(
            ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
            modifiedSince: .distantPast
        ) { [weak self] in
            self?.showLogin()
        }
    }

    // MARK: - Cookie Injection

    private func injectCookiesAndShowApp(cookies: [HTTPCookie]) {
        let store = WKWebsiteDataStore.default().httpCookieStore
        let group = DispatchGroup()
        for cookie in cookies {
            group.enter()
            store.setCookie(cookie) { group.leave() }
        }
        group.notify(queue: .main) { [weak self] in
            self?.transitionToApp()
            self?.window?.makeKeyAndVisible()
        }
    }
}

// MARK: - Notification Name

extension Notification.Name {
    static let tallyDidLogout = Notification.Name("tallyDidLogout")
}
