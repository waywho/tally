import UIKit

/// Branded error screen with a retry button. Used by Hotwire Native when
/// a page fails to load (offline, server error, timeout).
final class ErrorView: UIView {

    private let retryHandler: () -> Void

    init(retryHandler: @escaping () -> Void) {
        self.retryHandler = retryHandler
        super.init(frame: .zero)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        backgroundColor = UIColor(red: 247/255, green: 247/255, blue: 245/255, alpha: 1)

        let logoLabel = UILabel()
        logoLabel.text = "Tally"
        logoLabel.font = .systemFont(ofSize: 28, weight: .bold)
        logoLabel.textColor = UIColor(red: 34/255, green: 197/255, blue: 94/255, alpha: 1)
        logoLabel.textAlignment = .center

        let messageLabel = UILabel()
        messageLabel.text = "Something went wrong"
        messageLabel.font = .systemFont(ofSize: 17)
        messageLabel.textColor = .secondaryLabel
        messageLabel.textAlignment = .center

        let retryButton = UIButton(type: .system)
        retryButton.setTitle("Try Again", for: .normal)
        retryButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        retryButton.setTitleColor(.white, for: .normal)
        retryButton.backgroundColor = UIColor(red: 34/255, green: 197/255, blue: 94/255, alpha: 1)
        retryButton.layer.cornerRadius = 10
        retryButton.addTarget(self, action: #selector(retryTapped), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [logoLabel, messageLabel, retryButton])
        stack.axis = .vertical
        stack.spacing = 16
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -40),
            retryButton.widthAnchor.constraint(equalToConstant: 200),
            retryButton.heightAnchor.constraint(equalToConstant: 50),
        ])
    }

    @objc private func retryTapped() {
        retryHandler()
    }
}
