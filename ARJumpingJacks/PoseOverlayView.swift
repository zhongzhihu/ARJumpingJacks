import SwiftUI

/// Draws detected joints and bones over the camera preview so the user can see
/// what the pose detector is tracking — the standard "AR skeleton" look.
struct PoseOverlayView: View {
    let pose: PoseData

    private static let bones: [(WritableKeyPath<PoseData, CGPoint?>, WritableKeyPath<PoseData, CGPoint?>)] = [
        (\.leftShoulder, \.rightShoulder),
        (\.leftHip,      \.rightHip),
        (\.leftShoulder, \.leftHip),
        (\.rightShoulder,\.rightHip),
        (\.leftShoulder, \.leftElbow),
        (\.leftElbow,    \.leftWrist),
        (\.rightShoulder,\.rightElbow),
        (\.rightElbow,   \.rightWrist),
        (\.leftHip,      \.leftKnee),
        (\.leftKnee,     \.leftAnkle),
        (\.rightHip,     \.rightKnee),
        (\.rightKnee,    \.rightAnkle),
    ]

    private static let joints: [WritableKeyPath<PoseData, CGPoint?>] = [
        \.leftShoulder, \.rightShoulder,
        \.leftElbow,    \.rightElbow,
        \.leftWrist,    \.rightWrist,
        \.leftHip,      \.rightHip,
        \.leftKnee,     \.rightKnee,
        \.leftAnkle,    \.rightAnkle,
    ]

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack {
                ForEach(Array(Self.bones.enumerated()), id: \.offset) { _, bone in
                    if let a = pose[keyPath: bone.0]?.visionToOverlay(in: size),
                       let b = pose[keyPath: bone.1]?.visionToOverlay(in: size) {
                        Path { p in
                            p.move(to: a)
                            p.addLine(to: b)
                        }
                        .stroke(Color.green.opacity(0.9), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .shadow(color: .green.opacity(0.7), radius: 6)
                    }
                }

                ForEach(Array(Self.joints.enumerated()), id: \.offset) { _, joint in
                    if let p = pose[keyPath: joint]?.visionToOverlay(in: size) {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 10, height: 10)
                            .overlay(Circle().stroke(Color.green, lineWidth: 2))
                            .shadow(color: .green.opacity(0.8), radius: 4)
                            .position(p)
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }
}
