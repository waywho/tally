import UIKit
import WebKit

/// Native login screen. POSTs credentials to Rodauth's /login endpoint.
/// On success, captures session cookies, stores in Keychain, and calls onLogin.
final class LoginViewController: UIViewController {

    private let onLogin: () -> Void

    private let logoImageView = UIImageView(image: UIImage(named: "Logo"))
    private let logoLabel = UILabel()
    private let emailField = UITextField()
    private let passwordField = UITextField()
    private let loginButton = UIButton(type: .system)
    private let errorLabel = UILabel()
    private let createAccountButton = UIButton(type: .system)
    private let forgotPasswordButton = UIButton(type: .system)
    private let stackView = UIStackView()

    init(onLogin: @escaping () -> Void) {
        self.onLogin = onLogin
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .tallyPageBackground
        setupUI()
    }

    // MARK: - UI Setup

    private func setupUI() {
        logoImageView.contentMode = .scaleAspectFit
        logoImageView.heightAnchor.constraint(equalToConstant: 72).isActive = true

        logoLabel.text = "Tally"
        logoLabel.font = .systemFont(ofSize: 32, weight: .bold)
        logoLabel.textColor = .tallyPrimary
        logoLabel.textAlignment = .center

        emailField.placeholder = "Email"
        emailField.borderStyle = .roundedRect
        emailField.keyboardType = .emailAddress
        emailField.autocapitalizationType = .none
        emailField.autocorrectionType = .no
        emailField.returnKeyType = .next
        emailField.delegate = self

        passwordField.placeholder = "Password"
        passwordField.borderStyle = .roundedRect
        passwordField.isSecureTextEntry = true
        passwordField.returnKeyType = .go
        passwordField.delegate = self

        loginButton.setTitle("Log in", for: .normal)
        loginButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        loginButton.setTitleColor(.white, for: .normal)
        loginButton.backgroundColor = .tallyPrimary
        loginButton.layer.cornerRadius = 10
        loginButton.heightAnchor.constraint(equalToConstant: 50).isActive = true
        loginButton.addTarget(self, action: #selector(loginTapped), for: .touchUpInside)

        errorLabel.text = "Invalid email or password"
        errorLabel.textColor = .systemRed
        errorLabel.font = .systemFont(ofSize: 14)
        errorLabel.textAlignment = .center
        errorLabel.isHidden = true

        createAccountButton.setTitle("Don't have an account? Create one", for: .normal)
        createAccountButton.titleLabel?.font = .systemFont(ofSize: 14)
        createAccountButton.setTitleColor(.tallyPrimary, for: .normal)
        createAccountButton.addTarget(self, action: #selector(createAccountTapped), for: .touchUpInside)

        forgotPasswordButton.setTitle("Forgot password?", for: .normal)
        forgotPasswordButton.titleLabel?.font = .systemFont(ofSize: 14)
        forgotPasswordButton.setTitleColor(.tallyPrimary, for: .normal)
        forgotPasswordButton.addTarget(self, action: #selector(forgotPasswordTapped), for: .touchUpInside)

        stackView.axis = .vertical
        stackView.spacing = 16
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(logoImageView)
        stackView.addArrangedSubview(logoLabel)
        stackView.addArrangedSubview(UIView())
        stackView.addArrangedSubview(emailField)
        stackView.addArrangedSubview(passwordField)
        stackView.addArrangedSubview(errorLabel)
        stackView.addArrangedSubview(loginButton)
        stackView.addArrangedSubview(createAccountButton)
        stackView.addArrangedSubview(forgotPasswordButton)

        stackView.setCustomSpacing(12, after: logoImageView)
        stackView.setCustomSpacing(32, after: logoLabel)
        stackView.setCustomSpacing(8, after: errorLabel)
        stackView.setCustomSpacing(8, after: createAccountButton)

        view.addSubview(stackView)

        // Cap the width so the form stays a readable column on iPad instead of
        // stretching the full screen; the 32pt insets still win on iPhone.
        let width = stackView.widthAnchor.constraint(equalToConstant: 380)
        width.priority = .defaultHigh

        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -40),
            width,
            stackView.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 32),
            stackView.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -32),
        ])
    }

    // MARK: - Actions

    @objc private func loginTapped() {
        guard let email = emailField.text, !email.isEmpty,
              let password = passwordField.text, !password.isEmpty else {
            showError()
            return
        }

        errorLabel.isHidden = true
        loginButton.isEnabled = false
        loginButton.alpha = 0.6

        performLogin(email: email, password: password)
    }

    @objc private func createAccountTapped() {
        let url = Endpoints.baseURL.appendingPathComponent("/create-account")
        presentWebPage(url: url)
    }

    @objc private func forgotPasswordTapped() {
        let url = Endpoints.baseURL.appendingPathComponent("/reset-password-request")
        presentWebPage(url: url)
    }

    // MARK: - Login

    private func performLogin(email: String, password: String) {
        let url = Endpoints.baseURL.appendingPathComponent("/login")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("Tally/1.0 Turbo Native iOS", forHTTPHeaderField: "User-Agent")

        let body = "email=\(urlEncode(email))&password=\(urlEncode(password))"
        request.httpBody = body.data(using: .utf8)

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.handleLoginResponse(data: data, response: response, error: error)
            }
        }.resume()
    }

    private func handleLoginResponse(data: Data?, response: URLResponse?, error: Error?) {
        loginButton.isEnabled = true
        loginButton.alpha = 1.0

        guard let httpResponse = response as? HTTPURLResponse,
              let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type"),
              contentType.contains("application/json") else {
            showError()
            return
        }

        // Extract cookies from the shared cookie storage
        let url = Endpoints.baseURL
        if let cookies = HTTPCookieStorage.shared.cookies(for: url), !cookies.isEmpty {
            SessionStore.save(cookies: cookies)
            injectCookiesIntoWebView(cookies: cookies) { [weak self] in
                self?.onLogin()
            }
        } else {
            showError()
        }
    }

    private func injectCookiesIntoWebView(cookies: [HTTPCookie], completion: @escaping () -> Void) {
        let store = WKWebsiteDataStore.default().httpCookieStore
        let group = DispatchGroup()
        for cookie in cookies {
            group.enter()
            store.setCookie(cookie) { group.leave() }
        }
        group.notify(queue: .main) { completion() }
    }

    private func showError() {
        errorLabel.isHidden = false
        loginButton.isEnabled = true
        loginButton.alpha = 1.0
    }

    private func urlEncode(_ string: String) -> String {
        string.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? string
    }

    // MARK: - Web Fallback

    private func presentWebPage(url: URL) {
        let webVC = WebFallbackViewController(url: url) { [weak self] in
            self?.adoptWebSession()
        }
        let nav = UINavigationController(rootViewController: webVC)
        present(nav, animated: true)
    }

    /// Signing up happens in a modal webview, so the session it establishes is
    /// invisible to the shell. Once that webview reaches a signed-in page, take
    /// its cookies, close the modal and enter the app.
    private func adoptWebSession() {
        WKWebsiteDataStore.default().httpCookieStore.getAllCookies { [weak self] cookies in
            guard let self, !cookies.isEmpty else { return }

            SessionStore.save(cookies: cookies)
            self.dismiss(animated: true) { self.onLogin() }
        }
    }
}

// MARK: - UITextFieldDelegate

extension LoginViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == emailField {
            passwordField.becomeFirstResponder()
        } else if textField == passwordField {
            loginTapped()
        }
        return true
    }
}

// MARK: - WebFallbackViewController

/// Minimal webview for "Create account" and "Forgot password" flows.
final class WebFallbackViewController: UIViewController, WKNavigationDelegate {
    /// Paths that only a signed-in account can reach, so landing on one means
    /// the account was created and is now logged in.
    private static let signedInPaths = ["/today", "/onboarding"]

    private let url: URL
    private let onSignedIn: () -> Void

    init(url: URL, onSignedIn: @escaping () -> Void) {
        self.url = url
        self.onSignedIn = onSignedIn
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done, target: self, action: #selector(dismissSelf)
        )

        let webView = WKWebView(frame: view.bounds)
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        webView.navigationDelegate = self
        view.addSubview(webView)
        webView.load(URLRequest(url: url))
    }

    @objc private func dismissSelf() {
        dismiss(animated: true)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard let path = webView.url?.path,
              Self.signedInPaths.contains(where: { path == $0 || path.hasPrefix("\($0)/") })
        else { return }

        onSignedIn()
    }
}
