import HotwireNative
import UIKit
import AVFoundation

final class BarcodeScannerComponent: BridgeComponent {
    override nonisolated class var name: String { "barcode-scanner" }

    private var lastScannedBarcode: String?

    override func onReceive(message: Message) {
        guard message.event == "scan" else { return }
        presentScanner()
    }

    private var viewController: UIViewController? {
        delegate?.destination as? UIViewController
    }

    private func presentScanner() {
        guard let viewController else { return }

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            showScanner(from: viewController)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.showScanner(from: viewController)
                    } else {
                        self?.showPermissionDenied(from: viewController)
                    }
                }
            }
        default:
            showPermissionDenied(from: viewController)
        }
    }

    private func showScanner(from presenter: UIViewController) {
        let scanner = BarcodeScannerViewController()
        scanner.scannerDelegate = self
        scanner.modalPresentationStyle = .fullScreen
        presenter.present(scanner, animated: true)
    }

    private func showPermissionDenied(from presenter: UIViewController) {
        let alert = UIAlertController(
            title: "Camera Access Required",
            message: "Please allow camera access in Settings to scan barcodes.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Settings", style: .default) { _ in
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        })
        presenter.present(alert, animated: true)
    }
}

// MARK: - BarcodeScannerDelegate

extension BarcodeScannerComponent: BarcodeScannerDelegate {
    func barcodeScannerDidScan(_ barcode: String) {
        lastScannedBarcode = barcode
        // Reply triggers the JS callback; the JS reads the barcode via a
        // custom event we dispatch on the document
        reply(to: "scan", with: ScanResult(barcode: barcode))
    }

    func barcodeScannerDidCancel() {
        // No reply — JS callback never fires, nothing happens
    }
}

// MARK: - Data

private extension BarcodeScannerComponent {
    struct ScanResult: Encodable {
        let barcode: String
    }
}
