import SwiftUI
import AVFoundation
import Vision

struct PoseCameraRepCounterView: UIViewControllerRepresentable {
    let exerciseType: String
    @Binding var isRunning: Bool
    @Binding var reps: Int
    @Binding var currentPose: VNHumanBodyPoseObservation?
    var onPlankFeedbackUpdate: ((PlankFormFeedback) -> Void)? = nil

    func makeUIViewController(context: Context) -> PoseCameraRepCounterController {
        let vc = PoseCameraRepCounterController()
        vc.onRepCount = { count in
            DispatchQueue.main.async { self.reps = count }
        }
        vc.onPoseUpdate = { observation in
            DispatchQueue.main.async { self.currentPose = observation }
        }
        vc.onPlankFeedback = { feedback in
            DispatchQueue.main.async { self.onPlankFeedbackUpdate?(feedback) }
        }
        vc.exerciseType = exerciseType
        return vc
    }

    func updateUIViewController(_ uiViewController: PoseCameraRepCounterController, context: Context) {
        if uiViewController.exerciseType != exerciseType {
            uiViewController.exerciseType = exerciseType
            uiViewController.repCounter.reset()
        }
        uiViewController.shouldProcess = isRunning
    }
}

final class PoseCameraRepCounterController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {

    var onRepCount: ((Int) -> Void)?
    var onPoseUpdate: ((VNHumanBodyPoseObservation?) -> Void)?
    var onPlankFeedback: ((PlankFormFeedback) -> Void)?
    var exerciseType: String = "Pushups"
    var shouldProcess: Bool = false

    let session = AVCaptureSession()
    private let output = AVCaptureVideoDataOutput()
    private let queue = DispatchQueue(label: "pose.camera.queue", qos: .userInitiated)
    private var previewLayer: AVCaptureVideoPreviewLayer?
    let repCounter = PoseRepCounter()
    private let request = VNDetectHumanBodyPoseRequest()
    var cachedIsLandscape: Bool = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        configureSession()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
        let isLandscape = view.bounds.width > view.bounds.height
        if isLandscape != cachedIsLandscape {
            cachedIsLandscape = isLandscape
            updatePreviewRotation()
        }
    }

    /// Only rotates the preview layer for display.
    /// Output connection stays fixed at 90° so Vision always gets a
    /// consistently portrait-oriented pixel buffer regardless of device orientation.
    func updatePreviewRotation() {
        previewLayer?.connection?.videoRotationAngle = cachedIsLandscape ? 180 : 90
    }

    func updateVideoRotation() { updatePreviewRotation() }

    deinit {
        session.stopRunning()
        print("🛑 Camera session stopped")
    }

    private func configureSession() {
        session.beginConfiguration()
        session.sessionPreset = .high

        guard
            let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
            let input = try? AVCaptureDeviceInput(device: device),
            session.canAddInput(input)
        else {
            print("❌ Failed to configure camera")
            session.commitConfiguration()
            return
        }

        session.addInput(input)
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        output.setSampleBufferDelegate(self, queue: queue)
        output.alwaysDiscardsLateVideoFrames = true

        guard session.canAddOutput(output) else {
            print("❌ Failed to add output")
            session.commitConfiguration()
            return
        }
        session.addOutput(output)

        // Fix output at 90° always — Vision receives portrait pixel buffer consistently
        if let conn = output.connection(with: .video) {
            conn.videoRotationAngle = 90
        }

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        preview.frame = view.bounds
        view.layer.addSublayer(preview)
        previewLayer = preview

        session.commitConfiguration()
        print("✅ Camera session configured")
        
        DispatchQueue.global(qos: .userInitiated).async {
            self.session.startRunning()
        }
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard shouldProcess else { return }
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        // Always .up — output connection is fixed at 90° so pixel buffer is always portrait
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        do {
            try handler.perform([request])
            guard let obs = request.results?.first as? VNHumanBodyPoseObservation else { return }
            onPoseUpdate?(obs)
            let count = repCounter.process(observation: obs, exerciseType: exerciseType)
            let isPlank = exerciseType.lowercased() == "plank"
            if isPlank || count != repCounter.lastPublished {
                repCounter.lastPublished = count
                onRepCount?(count)
            }
            onPlankFeedback?(repCounter.plankFeedback)
        } catch {
            // ignore frame errors
        }
    }
}
