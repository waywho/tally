import AVFoundation
import UIKit

protocol BarcodeScannerDelegate: AnyObject {
    func barcodeScannerDidScan(_ barcode: String)
    func barcodeScannerDidCancel()
}

final class BarcodeScannerViewController: UIViewController {

    weak var scannerDelegate: BarcodeScannerDelegate?

    private let captureSession = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        if AVCaptureDevice.default(for: .video) != nil {
            setupCamera()
        } else {
            showManualEntry()
        }

        setupOverlay()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if !captureSession.isRunning {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.captureSession.startRunning()
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if captureSession.isRunning {
            captureSession.stopRunning()
        }
    }

    // MARK: - Camera Setup

    private func setupCamera() {
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device) else {
            showManualEntry()
            return
        }

        captureSession.addInput(input)

        let output = AVCaptureMetadataOutput()
        captureSession.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.ean8, .ean13, .upce]

        let preview = AVCaptureVideoPreviewLayer(session: captureSession)
        preview.videoGravity = .resizeAspectFill
        preview.frame = view.bounds
        view.layer.addSublayer(preview)
        previewLayer = preview
    }

    // MARK: - Overlay

    private func setupOverlay() {
        let cancelButton = UIButton(type: .system)
        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.setTitleColor(.white, for: .normal)
        cancelButton.titleLabel?.font = .systemFont(ofSize: 17)
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        view.addSubview(cancelButton)

        let guideView = UIView()
        guideView.layer.borderColor = UIColor.white.cgColor
        guideView.layer.borderWidth = 2
        guideView.layer.cornerRadius = 12
        guideView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(guideView)

        let label = UILabel()
        label.text = "Point camera at a barcode"
        label.textColor = .white
        label.font = .systemFont(ofSize: 15)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)

        let torchButton = UIButton(type: .system)
        let torchConfig = UIImage.SymbolConfiguration(pointSize: 20)
        torchButton.setImage(UIImage(systemName: "flashlight.off.fill", withConfiguration: torchConfig), for: .normal)
        torchButton.tintColor = .white
        torchButton.translatesAutoresizingMaskIntoConstraints = false
        torchButton.addTarget(self, action: #selector(torchTapped(_:)), for: .touchUpInside)
        view.addSubview(torchButton)

        NSLayoutConstraint.activate([
            cancelButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            cancelButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),

            torchButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            torchButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            guideView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            guideView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -40),
            guideView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.75),
            guideView.heightAnchor.constraint(equalToConstant: 150),

            label.topAnchor.constraint(equalTo: guideView.bottomAnchor, constant: 24),
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        ])
    }

    // MARK: - Actions

    @objc private func cancelTapped() {
        scannerDelegate?.barcodeScannerDidCancel()
        dismiss(animated: true)
    }

    @objc private func torchTapped(_ sender: UIButton) {
        guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else { return }
        try? device.lockForConfiguration()
        device.torchMode = device.torchMode == .on ? .off : .on
        device.unlockForConfiguration()

        let iconName = device.torchMode == .on ? "flashlight.on.fill" : "flashlight.off.fill"
        let config = UIImage.SymbolConfiguration(pointSize: 20)
        sender.setImage(UIImage(systemName: iconName, withConfiguration: config), for: .normal)
    }

    // MARK: - Simulator Fallback

    private func showManualEntry() {
        let alert = UIAlertController(title: "Enter Barcode", message: "Camera unavailable (simulator)", preferredStyle: .alert)
        alert.addTextField { field in
            field.placeholder = "Barcode number"
            field.keyboardType = .numberPad
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { [weak self] _ in
            self?.scannerDelegate?.barcodeScannerDidCancel()
            self?.dismiss(animated: true)
        })
        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            if let barcode = alert.textFields?.first?.text, !barcode.isEmpty {
                self?.scannerDelegate?.barcodeScannerDidScan(barcode)
            } else {
                self?.scannerDelegate?.barcodeScannerDidCancel()
            }
            self?.dismiss(animated: true)
        })
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.present(alert, animated: true)
        }
    }
}

// MARK: - AVCaptureMetadataOutputObjectsDelegate

extension BarcodeScannerViewController: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let barcode = object.stringValue else { return }

        captureSession.stopRunning()

        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        scannerDelegate?.barcodeScannerDidScan(barcode)
        dismiss(animated: true)
    }
}
