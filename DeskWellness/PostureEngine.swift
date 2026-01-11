//
//  PostureEngine.swift
//  DeskWellness
//
//  Created by P Dev on 1/11/26.
//

import AVFoundation
import Vision
import Combine
import UIKit

class PostureEngine: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {

    // MARK: - Published State for UI
    @Published var headAngle: Double = 0.0
    @Published var confidence: Double = 0.0
    @Published var isLocked: Bool = false
    @Published var normalizedPoints: (ear: CGPoint, shoulder: CGPoint)? = nil

    // MARK: - Internal Math State (Smoothing)
    private var previousEar: CGPoint?
    private var previousShoulder: CGPoint?
    private let smoothingAlpha: CGFloat = 0.6 // Tweak this: 1.0 = fast/jittery, 0.1 = slow/laggy

    // MARK: - Vision Request
    private let videoOutput = AVCaptureVideoDataOutput()
    public let captureSession = AVCaptureSession()
    private let sequenceHandler = VNSequenceRequestHandler()

    override init() {
        super.init()
        setupCamera()
    }

    func start() {
        DispatchQueue.global(qos: .userInitiated).async {
            self.captureSession.startRunning()
        }
    }

    func stop() {
        captureSession.stopRunning()
    }

    private func setupCamera() {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let input = try? AVCaptureDeviceInput(device: device) else { return }

        if captureSession.canAddInput(input) { captureSession.addInput(input) }

        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        if captureSession.canAddOutput(videoOutput) { captureSession.addOutput(videoOutput) }
    }

    // MARK: - The "Magic" Loop (Runs every frame)
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {

        let request = VNDetectHumanBodyPoseRequest()

        do {
            try sequenceHandler.perform([request], on: sampleBuffer, orientation: .leftMirrored)

            guard let observation = request.results?.first else {
                DispatchQueue.main.async { self.isLocked = false }
                return
            }

            // 1. Extract Points (Safety Check)
            // Instead of forcing .leftEar, find the BEST side
            let leftEar = try? observation.recognizedPoint(.leftEar)
            let leftShoulder = try? observation.recognizedPoint(.leftShoulder)

            let rightEar = try? observation.recognizedPoint(.rightEar)
            let rightShoulder = try? observation.recognizedPoint(.rightShoulder)

            // Determine which side is visible (Higher Confidence)
            var ear: VNRecognizedPoint?
            var shoulder: VNRecognizedPoint?

            let leftConf = (leftEar?.confidence ?? 0) + (leftShoulder?.confidence ?? 0)
            let rightConf = (rightEar?.confidence ?? 0) + (rightShoulder?.confidence ?? 0)

            if leftConf > rightConf && leftConf > 1.0 { // Threshold 0.5 * 2
                ear = leftEar
                shoulder = leftShoulder
            } else if rightConf > 1.0 {
                ear = rightEar
                shoulder = rightShoulder
            }

            // If neither side is good, FAIL
            guard let earPoint = ear, let shoulderPoint = shoulder else {
                DispatchQueue.main.async { self.isLocked = false }
                return
            }

            // 2. Convert to CGPoint (0..1)
            let rawEar = CGPoint(x: earPoint.location.x, y: 1 - earPoint.location.y)
            let rawShoulder = CGPoint(x: shoulderPoint.location.x, y: 1 - shoulderPoint.location.y)

            // 3. APPLY SMOOTHING (The Wow Factor)
            // This prevents the "jittery line" effect
            let smoothedEar = smooth(new: rawEar, old: previousEar)
            let smoothedShoulder = smooth(new: rawShoulder, old: previousShoulder)

            previousEar = smoothedEar
            previousShoulder = smoothedShoulder

            // 4. Calculate Angle (Geometry)
            // 0° = Perfect Vertical alignment. +ve = Head Forward.
            // Ear Y < Shoulder Y (Ear is above).

            // Calculate raw difference
            let deltaX = smoothedEar.x - smoothedShoulder.x
            let deltaY = smoothedShoulder.y - smoothedEar.y // Positive if Ear is above Shoulder

            // Safety: If head is somehow below shoulder (upside down), ignore.
            guard deltaY > 0 else { return }

            // Calculate Angle from Vertical (Y-axis)
            // atan(deltaX / deltaY) gives angle from vertical.
            // We use abs(deltaX) so it works if you face Left OR Right.
            let angleRadians = atan(abs(deltaX) / deltaY)
            let angleDegrees = angleRadians * 180 / .pi

            // DEBUG PRINT: Check the raw values in Console
            print("Ear: \(smoothedEar), Shoulder: \(smoothedShoulder), Angle: \(angleDegrees)")

            // 5. Update UI (Main Thread)
            DispatchQueue.main.async {
                self.isLocked = true
                self.confidence = Double(earPoint.confidence)
                self.headAngle = angleDegrees
                self.normalizedPoints = (smoothedEar, smoothedShoulder)
            }

        } catch {
            print("Vision Error: \(error)")
        }
    }

    private func smooth(new: CGPoint, old: CGPoint?) -> CGPoint {
        guard let old = old else { return new }
        return CGPoint(
            x: (new.x * smoothingAlpha) + (old.x * (1 - smoothingAlpha)),
            y: (new.y * smoothingAlpha) + (old.y * (1 - smoothingAlpha))
        )
    }
}

