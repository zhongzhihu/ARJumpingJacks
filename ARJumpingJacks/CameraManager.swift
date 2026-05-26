import AVFoundation
import CoreMedia
import Foundation

// Front-camera capture. Marked nonisolated because AVFoundation delegate methods are
// called on background queues. The project default actor isolation is MainActor.
nonisolated final class CameraManager: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {

    let session = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let videoQueue = DispatchQueue(label: "camera.video.queue")

    // Process every Nth frame to keep Vision work cheap. Tune 1..3 as needed.
    private let frameStride = 2
    private var frameCounter = 0

    /// Called on the camera background queue with each (sampled) frame.
    var onFrame: (@Sendable (CMSampleBuffer) -> Void)?

    private var configured = false

    func requestPermissionAndConfigure(completion: @escaping @Sendable (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureAsync(completion: completion)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                guard granted else {
                    completion(false)
                    return
                }
                self?.configureAsync(completion: completion)
            }
        default:
            completion(false)
        }
    }

    func start() {
        guard configured else { return }
        if !session.isRunning {
            videoQueue.async { [weak self] in
                self?.session.startRunning()
            }
        }
    }

    func stop() {
        if session.isRunning {
            videoQueue.async { [weak self] in
                self?.session.stopRunning()
            }
        }
    }

    private func configureAsync(completion: @escaping @Sendable (Bool) -> Void) {
        videoQueue.async { [weak self] in
            guard let self else {
                completion(false)
                return
            }
            self.configureIfNeeded()
            completion(self.configured)
        }
    }

    private func configureIfNeeded() {
        guard !configured else { return }
        configured = true

        session.beginConfiguration()
        session.sessionPreset = .high

        // Pick the front camera.
        guard
            let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
            let input = try? AVCaptureDeviceInput(device: device)
        else {
            session.commitConfiguration()
            return
        }
        if session.canAddInput(input) {
            session.addInput(input)
        }

        // Video data output for Vision.
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
        ]
        videoOutput.setSampleBufferDelegate(self, queue: videoQueue)
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
        }

        // Force portrait + mirrored so what Vision sees matches what the user sees.
        if let conn = videoOutput.connection(with: .video) {
            if conn.isVideoRotationAngleSupported(90) {
                conn.videoRotationAngle = 90  // portrait
            }
            if conn.isVideoMirroringSupported {
                conn.automaticallyAdjustsVideoMirroring = false
                conn.isVideoMirrored = true
            }
        }

        session.commitConfiguration()
    }

    // MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        frameCounter &+= 1
        if frameCounter % frameStride != 0 { return }
        onFrame?(sampleBuffer)
    }
}
