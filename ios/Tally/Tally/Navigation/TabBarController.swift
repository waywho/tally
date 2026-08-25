import UIKit

final class TabBarController: UITabBarController {

    private var navigators: [TallyNavigator] = []
    private var startedTabs: Set<Int> = []
    private let addButton = UIButton(type: .custom)

    // Index of the "+" tab (no navigator — it's an action, not a page)
    private let addTabIndex = 2

    // MARK: - Tab definitions

    private struct TabDefinition {
        let title: String
        let icon: String        // SF Symbol name
        let activeIcon: String  // SF Symbol name (filled)
        let path: String        // appended to Endpoints.baseURL
    }

    private let tabDefinitions: [TabDefinition] = [
        TabDefinition(title: "Today",    icon: "house",           activeIcon: "house.fill",      path: "/today"),
        TabDefinition(title: "My Foods",  icon: "leaf",            activeIcon: "leaf.fill",         path: "/foods"),
        TabDefinition(title: "Recipes",  icon: "book",            activeIcon: "book.fill",        path: "/recipes"),
        TabDefinition(title: "Settings", icon: "gearshape",       activeIcon: "gearshape.fill",   path: "/settings/edit"),
    ]

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        delegate = self
        setupTabs()
        setupAddButton()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        positionAddButton()
    }

    // MARK: - Tab setup

    private func setupTabs() {
        tabBar.tintColor = .tallyPrimary

        navigators = tabDefinitions.map { tab in
            let url = Endpoints.baseURL.appendingPathComponent(tab.path)
            let nav = TallyNavigator(name: tab.title.lowercased(), rootURL: url)

            nav.navigationController.tabBarItem = UITabBarItem(
                title: tab.title,
                image: UIImage(systemName: tab.icon),
                selectedImage: UIImage(systemName: tab.activeIcon)
            )

            return nav
        }

        // Build the view controllers array with a placeholder for the "+" tab in the center
        var vcs: [UIViewController] = []
        vcs.append(navigators[0].navigationController) // Today (index 0)
        vcs.append(navigators[1].navigationController) // Search (index 1)

        // "+" placeholder (index 2) — reserves space, real button overlays on top
        let addVC = UIViewController()
        addVC.tabBarItem = UITabBarItem(title: nil, image: nil, selectedImage: nil)
        addVC.tabBarItem.isEnabled = false

        vcs.append(addVC)
        vcs.append(navigators[2].navigationController) // Recipes (index 3)
        vcs.append(navigators[3].navigationController) // Settings (index 4)

        viewControllers = vcs

        // Only start the first tab now; others start lazily when selected
        navigators[0].start()
        startedTabs.insert(0)
    }

    // MARK: - Floating add button

    private func setupAddButton() {
        let size: CGFloat = 58
        let config = UIImage.SymbolConfiguration(pointSize: 22, weight: .semibold)
        addButton.setImage(UIImage(systemName: "plus", withConfiguration: config), for: .normal)
        addButton.tintColor = .white
        addButton.backgroundColor = .tallyPrimary
        addButton.layer.cornerRadius = size / 2
        addButton.clipsToBounds = true
        addButton.frame = CGRect(x: 0, y: 0, width: size, height: size)

        // Subtle shadow
        addButton.layer.masksToBounds = false
        addButton.layer.shadowColor = UIColor.black.cgColor
        addButton.layer.shadowOpacity = 0.15
        addButton.layer.shadowOffset = CGSize(width: 0, height: 2)
        addButton.layer.shadowRadius = 4

        addButton.addTarget(self, action: #selector(addButtonTapped), for: .touchUpInside)
        view.addSubview(addButton)
    }

    private func positionAddButton() {
        // Position so only ~15% sticks above the tab bar
        let stickOut: CGFloat = 58 * 0.15
        addButton.center = CGPoint(
            x: tabBar.center.x,
            y: tabBar.frame.origin.y + (58 / 2) - stickOut
        )
    }

    @objc private func addButtonTapped() {
        let meal = MealInferrer.current()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let today = dateFormatter.string(from: Date())

        let url = Endpoints.baseURL.appendingPathComponent("/foods")
            .appending(queryItems: [
                URLQueryItem(name: "meal", value: meal),
                URLQueryItem(name: "date", value: today),
            ])

        // Navigate within the Today tab — same as tapping "+ Add" in a meal bucket
        selectedIndex = 0
        if !startedTabs.contains(0) {
            navigators[0].start()
        }
        startedTabs.insert(0)
        navigators[0].visit(url)
    }

    // MARK: - Navigator index mapping

    /// Maps a tab bar index to the navigators array index.
    /// The "+" tab (index 2) has no navigator; tabs after it are offset by -1.
    private func navigatorIndex(for tabIndex: Int) -> Int? {
        if tabIndex == addTabIndex { return nil }
        return tabIndex < addTabIndex ? tabIndex : tabIndex - 1
    }
}

// MARK: - UITabBarControllerDelegate

extension TabBarController: UITabBarControllerDelegate {
    func tabBarController(_ tabBarController: UITabBarController, shouldSelect viewController: UIViewController) -> Bool {
        guard let tabIndex = viewControllers?.firstIndex(of: viewController) else { return true }

        // "+" tab tapped — handled by the overlay button, block selection
        if tabIndex == addTabIndex {
            addButtonTapped()
            return false
        }

        guard let navIndex = navigatorIndex(for: tabIndex) else { return true }

        if !startedTabs.contains(navIndex) {
            navigators[navIndex].start()
            startedTabs.insert(navIndex)
        } else if viewController == selectedViewController {
            navigators[navIndex].popToRoot()
        }
        return true
    }
}
