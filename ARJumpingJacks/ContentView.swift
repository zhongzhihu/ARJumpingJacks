//
//  ContentView.swift
//  ARJumpingJacks
//

import AVFoundation
import Combine
import SwiftUI

/// Milestone 1: camera preview + live jumping-jack rep counter with a debug overlay
/// showing each underlying pose signal so thresholds can be tuned against the user's
/// body. The game UI (charge meter, monsters, fireballs) will layer on top in later
/// milestones.
struct ContentView: View {
    @StateObject private var model = JumpingJackDebugModel()
    @State private var cameraManager = CameraManager()
    private let poseDetector = PoseDetector()

    @State private var permissionState: PermissionState = .unknown

    enum PermissionState { case unknown, granted, denied }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            switch permissionState {
            case .unknown:
                ProgressView("Requesting camera…")
                    .foregroundStyle(.white)
            case .denied:
                permissionDeniedView
            case .granted:
                ZStack {
                    CameraPreviewView(session: cameraManager.session)
                        .ignoresSafeArea()
                    PoseOverlayView(pose: model.pose)
                        .ignoresSafeArea()
                    debugOverlay
                }
            }
        }
        .onAppear { setup() }
        .onDisappear { cameraManager.stop() }
    }

    private var debugOverlay: some View {
        VStack {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Reps")
                        .font(.caption).foregroundStyle(.white.opacity(0.7))
                    Text("\(model.reps)")
                        .font(.system(size: 72, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(radius: 4)
                    Text("Pose: \(model.rawPose.label)")
                        .font(.headline).foregroundStyle(.white)
                    Text("Confirmed: \(model.confirmedPose.label)")
                        .font(.subheadline).foregroundStyle(.white.opacity(0.8))
                }
                .padding(12)
                .background(.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 12))

                Spacer()

                Button("Reset") { model.resetReps() }
                    .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 16)
            .padding(.top, 60)

            Spacer()

            VStack(spacing: 8) {
                signalRow("armsOverhead", on: model.pose.armsOverhead)
                signalRow("armsBySides",  on: model.pose.armsBySides)
                signalRow("legsApart",    on: model.pose.legsApart)
                signalRow("legsTogether", on: model.pose.legsTogether)
                if let r = model.pose.ankleToShoulderWidthRatio {
                    Text(String(format: "ankle/shoulder ratio: %.2f", r))
                        .font(.caption).foregroundStyle(.white)
                }
                if !model.pose.hasFullBody {
                    Text("Step back — need full body in frame")
                        .font(.caption).foregroundStyle(.yellow)
                }
            }
            .padding(12)
            .background(.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 16)
            .padding(.bottom, 40)
        }
    }

    private func signalRow(_ name: String, on: Bool) -> some View {
        HStack {
            Circle()
                .fill(on ? .green : .red)
                .frame(width: 14, height: 14)
            Text(name)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.white)
            Spacer()
        }
    }

    private var permissionDeniedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.fill")
                .font(.system(size: 50))
                .foregroundStyle(.white)
            Text("Camera access required")
                .font(.title3).foregroundStyle(.white)
            Text("Open Settings to enable the camera for this game.")
                .font(.body).foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private func setup() {
        cameraManager.onFrame = { [poseDetector] sampleBuffer in
            if let pose = poseDetector.detect(in: sampleBuffer) {
                Task { @MainActor in
                    model.ingest(pose)
                }
            }
        }

        cameraManager.requestPermissionAndConfigure { granted in
            Task { @MainActor in
                if granted {
                    permissionState = .granted
                    cameraManager.start()
                } else {
                    permissionState = .denied
                }
            }
        }
    }
}

@MainActor
final class JumpingJackDebugModel: ObservableObject {
    @Published private(set) var reps: Int = 0
    @Published private(set) var rawPose: JumpingJackCounter.Pose = .other
    @Published private(set) var confirmedPose: JumpingJackCounter.Pose = .other
    @Published private(set) var pose: PoseData = PoseData()

    private let counter = JumpingJackCounter()

    func ingest(_ p: PoseData) {
        pose = p
        counter.ingest(p)
        reps = counter.totalReps
        rawPose = counter.currentRaw
        confirmedPose = counter.lastConfirmed
    }

    func resetReps() {
        counter.reset()
        reps = 0
        rawPose = .other
        confirmedPose = .other
    }
}

extension JumpingJackCounter.Pose {
    var label: String {
        switch self {
        case .closed: return "closed"
        case .open:   return "open"
        case .other:  return "—"
        }
    }
}

#Preview {
    ContentView()
}
