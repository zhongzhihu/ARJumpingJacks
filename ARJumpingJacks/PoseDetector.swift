import CoreMedia
import Foundation
import Vision

// Runs a single VNDetectHumanBodyPoseRequest per frame and produces a PoseData.
// nonisolated because it's invoked from the camera background queue.
nonisolated final class PoseDetector {

    private let bodyRequest = VNDetectHumanBodyPoseRequest()

    // Confidence floor. Below this we treat a landmark as missing.
    // TUNE: raise (e.g. 0.4) if landmarks jitter, lower (e.g. 0.15) if they drop out.
    private let confidenceThreshold: Float = 0.25

    func detect(in sampleBuffer: CMSampleBuffer) -> PoseData? {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }

        // The CameraManager already rotates frames to portrait, so .up is correct here.
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        do {
            try handler.perform([bodyRequest])
        } catch {
            return nil
        }

        guard let observation = bodyRequest.results?.first else { return nil }

        var pose = PoseData()
        pose.leftWrist     = point(observation, .leftWrist)
        pose.rightWrist    = point(observation, .rightWrist)
        pose.leftElbow     = point(observation, .leftElbow)
        pose.rightElbow    = point(observation, .rightElbow)
        pose.leftShoulder  = point(observation, .leftShoulder)
        pose.rightShoulder = point(observation, .rightShoulder)
        pose.leftHip       = point(observation, .leftHip)
        pose.rightHip      = point(observation, .rightHip)
        pose.leftKnee      = point(observation, .leftKnee)
        pose.rightKnee     = point(observation, .rightKnee)
        pose.leftAnkle     = point(observation, .leftAnkle)
        pose.rightAnkle    = point(observation, .rightAnkle)
        return pose
    }

    private func point(_ obs: VNHumanBodyPoseObservation,
                       _ jointName: VNHumanBodyPoseObservation.JointName) -> CGPoint? {
        guard let p = try? obs.recognizedPoint(jointName), p.confidence >= confidenceThreshold else {
            return nil
        }
        // VNRecognizedPoint is already normalized [0,1] with bottom-left origin.
        return CGPoint(x: p.location.x, y: p.location.y)
    }
}
