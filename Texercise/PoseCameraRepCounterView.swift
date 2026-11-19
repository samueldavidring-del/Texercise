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

        guard let obs = detectPose(in: pixelBuffer) else { return }

        onPoseUpdate?(obs)
        let count = repCounter.process(observation: obs, exerciseType: exerciseType)
        let isPlank = exerciseType.lowercased() == "plank"
        if isPlank || count != repCounter.lastPublished {
            repCounter.lastPublished = count
            onRepCount?(count)
        }
        onPlankFeedback?(repCounter.plankFeedback)
    }

    // MARK: - Pose detection

    private var isSitups: Bool {
        let t = exerciseType.lowercased()
        return t.contains("sit-up") || t.contains("situp")
    }

    /// Which way up to hand the frame to Vision for sit-ups. Remembered
    /// between frames so the second attempt is rarely needed.
    private var situpOrientation: CGImagePropertyOrientation = .up
    private var lastOrientationLog: Date = .distantPast

    /// The output connection is fixed at 90°, so Vision always gets a
    /// portrait buffer (.up). For sit-ups the phone is in landscape, so you
    /// appear rotated in that buffer — and depending on which way your head
    /// points and which way the phone is turned, you can appear UPSIDE DOWN.
    /// Vision's body pose model barely finds joints on upside-down people,
    /// which is what the debug log showed (repeated "no chain" lines). So for
    /// sit-ups, if the current orientation can't find a shoulder-hip-knee
    /// chain, try the frame rotated 180° and keep whichever works.
    private func detectPose(in pixelBuffer: CVPixelBuffer) -> VNHumanBodyPoseObservation? {
        guard isSitups else {
            return performPose(pixelBuffer, orientation: .up)
        }

        let primary = situpOrientation
        let alternate: CGImagePropertyOrientation = (primary == .up) ? .down : .up

        let first = performPose(pixelBuffer, orientation: primary)
        if let first, SitupDetector.measure(observation: first) != nil {
            return first
        }

        let second = performPose(pixelBuffer, orientation: alternate)
        if let second, SitupDetector.measure(observation: second) != nil {
            situpOrientation = alternate
            if Date().timeIntervalSince(lastOrientationLog) > 5 {
                lastOrientationLog = Date()
                repCounter.logSitup("SITUP switched Vision orientation to \(alternate == .up ? "up" : "down (180°)")")
            }
            return second
        }

        // Neither found a chain — return whatever was seen so the overlay
        // and the "no chain" logging still work.
        return first ?? second
    }

    private func performPose(_ pixelBuffer: CVPixelBuffer,
                             orientation: CGImagePropertyOrientation) -> VNHumanBodyPoseObservation? {
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation, options: [:])
        do {
            try handler.perform([request])
            return request.results?.first as? VNHumanBodyPoseObservation
        } catch {
            return nil
        }
    }
}
