import CoreGraphics
import Foundation

// Normalized pose data in [0,1] coordinates with bottom-left origin (Vision convention).
// The frames are mirrored to match the mirrored front-camera preview, so x maps directly.
nonisolated struct PoseData: Sendable {
    var leftWrist: CGPoint?
    var rightWrist: CGPoint?
    var leftElbow: CGPoint?
    var rightElbow: CGPoint?
    var leftShoulder: CGPoint?
    var rightShoulder: CGPoint?
    var leftHip: CGPoint?
    var rightHip: CGPoint?
    var leftKnee: CGPoint?
    var rightKnee: CGPoint?
    var leftAnkle: CGPoint?
    var rightAnkle: CGPoint?

    // ---- TUNING: arms-overhead / arms-by-sides thresholds ----
    // Vertical margin (normalized image coords, 0..1) the wrists must clear past
    // the shoulder line for the gesture to register. Two thresholds form a
    // hysteresis band so a wrist hovering near shoulder height won't flicker.
    static let armsOverheadYMargin: CGFloat = 0.05   // wrists above shoulders by this much
    static let armsBySidesYMargin:  CGFloat = 0.05   // wrists below shoulders by this much

    // ---- TUNING: legs-apart / legs-together thresholds ----
    // Ankle-separation normalized by shoulder width. ~1.0 = roughly shoulder-width
    // stance. Jumping out lands you near 1.5–2x; feet together lands near 0.1–0.3.
    static let legsApartRatio:    CGFloat = 1.4
    static let legsTogetherRatio: CGFloat = 0.55

    // ---- TUNING: wrist-together (kamehameha) detection ----
    static let wristsTogetherDist: CGFloat = 0.12

    /// True when both shoulders and both wrists are detected — needed for arm-pose signals.
    var hasUpperBody: Bool {
        leftWrist != nil && rightWrist != nil &&
        leftShoulder != nil && rightShoulder != nil
    }

    /// True when both hips, knees, and ankles are detected — i.e. the player's full
    /// lower body is visible in frame. Used to gate game start on AR detection.
    var hasFullLowerBody: Bool {
        leftHip != nil && rightHip != nil &&
        leftKnee != nil && rightKnee != nil &&
        leftAnkle != nil && rightAnkle != nil
    }

    /// Player fully in frame from shoulders to ankles. Gates game start.
    var hasFullBody: Bool { hasUpperBody && hasFullLowerBody }

    /// Both wrists clearly above the shoulder line (arms raised overhead).
    var armsOverhead: Bool {
        guard let lw = leftWrist, let rw = rightWrist,
              let ls = leftShoulder, let rs = rightShoulder else { return false }
        let shoulderTop = max(ls.y, rs.y)
        let wristLow = min(lw.y, rw.y)
        return wristLow > shoulderTop + Self.armsOverheadYMargin
    }

    /// Both wrists clearly below the shoulder line (arms down by sides).
    var armsBySides: Bool {
        guard let lw = leftWrist, let rw = rightWrist,
              let ls = leftShoulder, let rs = rightShoulder else { return false }
        let shoulderLow = min(ls.y, rs.y)
        let wristHigh = max(lw.y, rw.y)
        return wristHigh < shoulderLow - Self.armsBySidesYMargin
    }

    /// Ratio of ankle horizontal separation to shoulder width. nil if either pair
    /// missing or shoulder width is too small to be meaningful.
    var ankleToShoulderWidthRatio: CGFloat? {
        guard let la = leftAnkle, let ra = rightAnkle,
              let ls = leftShoulder, let rs = rightShoulder else { return nil }
        let shoulderWidth = abs(ls.x - rs.x)
        guard shoulderWidth > 0.01 else { return nil }
        return abs(la.x - ra.x) / shoulderWidth
    }

    /// Feet planted wider than shoulder-width (jumped-out pose).
    var legsApart: Bool {
        guard let r = ankleToShoulderWidthRatio else { return false }
        return r > Self.legsApartRatio
    }

    /// Feet together (closed pose).
    var legsTogether: Bool {
        guard let r = ankleToShoulderWidthRatio else { return false }
        return r < Self.legsTogetherRatio
    }

    /// True when both wrists are present and within the tuned distance.
    var wristsTogether: Bool {
        guard let l = leftWrist, let r = rightWrist else { return false }
        let dx = l.x - r.x, dy = l.y - r.y
        return sqrt(dx * dx + dy * dy) < Self.wristsTogetherDist
    }

    /// Midpoint between the two wrists in normalized coords, if both visible.
    var wristMidpoint: CGPoint? {
        guard let l = leftWrist, let r = rightWrist else { return nil }
        return CGPoint(x: (l.x + r.x) / 2, y: (l.y + r.y) / 2)
    }
}

// Coordinate conversion helper: Vision normalized (origin bottom-left) -> SwiftUI overlay (origin top-left).
// Frames are mirrored to match the preview, so x is used directly.
extension CGPoint {
    func visionToOverlay(in size: CGSize) -> CGPoint {
        CGPoint(x: x * size.width, y: (1 - y) * size.height)
    }
}
