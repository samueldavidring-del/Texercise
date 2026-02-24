import SwiftUI
import AVFoundation
import Vision

struct PoseCameraRepCounterView: UIViewControllerRepresentable {
    let exerciseType: String
    @Binding var isRunning: Bool
    @Binding var reps: Int
    @Binding var currentPose: VNHumanBodyPoseObservation?

    func makeUIViewController(context: Context) -> PoseCameraRepCounterController {
        let vc = PoseCameraRepCounterController()
        vc.onRepCount = { count in
            DispatchQueue.main.async {
                self.reps = count
            }
        }
        vc.onPoseUpdate = { observation in
            DispatchQueue.main.async {
                self.currentPose = observation
            }
        }
        vc.exerciseType = exerciseType
        
        // Start the session on a background thread
        DispatchQueue.global(qos: .userInitiated).async {
            vc.session.startRunning()
        }
        
        return vc
    }

    func updateUIViewController(_ uiViewController: PoseCameraRepCounterController, context: Context) {
        // Update exercise type if it changed
        if uiViewController.exerciseType != exerciseType {
            print("🔄 Exercise type changed from \(uiViewController.exerciseType) to \(exerciseType)")
            uiViewController.exerciseType = exerciseType
            uiViewController.repCounter.reset()
        }
        
        // Update processing state
        uiViewController.shouldProcess = isRunning
        print("🎬 Processing updated: \(isRunning)")
    }
}

final class PoseCameraRepCounterController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {

    var onRepCount: ((Int) -> Void)?
    var onPoseUpdate: ((VNHumanBodyPoseObservation?) -> Void)?
    var exerciseType: String = "Pushups"
    var shouldProcess: Bool = false

    let session = AVCaptureSession()
    private let output = AVCaptureVideoDataOutput()
    private let queue = DispatchQueue(label: "pose.camera.queue", qos: .userInitiated)

    private var previewLayer: AVCaptureVideoPreviewLayer?
    let repCounter = PoseRepCounter()

    private let request = VNDetectHumanBodyPoseRequest()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        configureSession()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
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

        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        output.setSampleBufferDelegate(self, queue: queue)
        output.alwaysDiscardsLateVideoFrames = true

        guard session.canAddOutput(output) else {
            print("❌ Failed to add output")
            session.commitConfiguration()
            return
        }
        session.addOutput(output)

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
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard shouldProcess else { return }
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        do {
            try handler.perform([request])
            guard let obs = request.results?.first as? VNHumanBodyPoseObservation else { return }

            // Publish observation for overlay
            onPoseUpdate?(obs)

            let count = repCounter.process(observation: obs, exerciseType: exerciseType)
            if count != repCounter.lastPublished {
                repCounter.lastPublished = count
                onRepCount?(count)
            }
        } catch {
            // ignore frame errors
        }
    }
    
    deinit {
        session.stopRunning()
        print("🛑 Camera session stopped")
    }
}
