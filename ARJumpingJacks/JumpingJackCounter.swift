import Foundation

/// State machine that turns a stream of pose frames into jumping-jack rep counts.
/// One rep = a full `.open` (arms overhead + legs apart) -> `.closed` (arms down + legs together)
/// transition. The opposite transition primes the next rep but doesn't count.
///
/// A pose must be sustained for `confirmFrames` consecutive frames before it's
/// committed, which absorbs single-frame jitter from Vision.
final class JumpingJackCounter {

    enum Pose { case closed, open, other }

    private(set) var totalReps: Int = 0
    private(set) var lastConfirmed: Pose = .other

    /// Most recent raw pose observed; useful for debug overlays.
    private(set) var currentRaw: Pose = .other

    private var pendingPose: Pose = .other
    private var pendingStreak: Int = 0

    /// How many consecutive matching frames are required before a transient
    /// pose is committed as `lastConfirmed`. With frameStride=2 and a 30fps
    /// camera (~15 Hz here), 2 frames ~= 130 ms — enough to ignore one bad
    /// detection but fast enough to feel responsive.
    var confirmFrames: Int = 2

    func reset() {
        totalReps = 0
        lastConfirmed = .other
        currentRaw = .other
        pendingPose = .other
        pendingStreak = 0
    }

    /// Feed a new pose. Returns true if this frame completed a rep.
    @discardableResult
    func ingest(_ pose: PoseData) -> Bool {
        let raw = classify(pose)
        currentRaw = raw

        if raw == pendingPose {
            pendingStreak += 1
        } else {
            pendingPose = raw
            pendingStreak = 1
        }

        guard pendingStreak >= confirmFrames, raw != .other, raw != lastConfirmed else {
            return false
        }

        // .open -> .closed completes a rep; the reverse only primes the next one.
        let completed = (lastConfirmed == .open && raw == .closed)
        lastConfirmed = raw
        if completed {
            totalReps += 1
        }
        return completed
    }

    private func classify(_ pose: PoseData) -> Pose {
        if pose.armsOverhead && pose.legsApart { return .open }
        if pose.armsBySides  && pose.legsTogether { return .closed }
        return .other
    }
}
