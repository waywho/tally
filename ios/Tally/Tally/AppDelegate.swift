import HotwireNative
import UIKit
import WebKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // Share a single process pool so all tabs share cookies (login session)
        let processPool = WKProcessPool()
        Hotwire.config.makeCustomWebView = { config in
            config.processPool = processPool
            return WKWebView(frame: .zero, configuration: config)
        }

        // Load path configuration before any Navigator is created
        var sources: [PathConfiguration.Source] = [
            .server(Endpoints.pathConfigurationURL)
        ]
        if let localURL = Bundle.main.url(forResource: "path-configuration", withExtension: "json") {
            sources.insert(.file(localURL), at: 0)
        }
        Hotwire.loadPathConfiguration(from: sources)

        // Custom error screen for offline / server errors
        Hotwire.config.makeCustomErrorView = { error, retryHandler in
            ErrorView(retryHandler: retryHandler)
        }

        // Register bridge components
        Hotwire.registerBridgeComponents([
            BarcodeScannerComponent.self
        ])

        return true
    }

    // MARK: UISceneSession Lifecycle

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let config = UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
        config.delegateClass = SceneDelegate.self
        return config
    }
}
