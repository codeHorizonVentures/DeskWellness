//
//  PostureEngine.swift
//  DeskWellness
//
//  Created by Petro Kulakov on 1/11/26.
//

import AVFoundation
import Vision
import Combine
import UIKit

/// Detection mode for the posture engine
enum DetectionMode {
    case front  // Front-facing: detect shoulder tilt, head tilt
    case side   // Side profile: detect forward head posture
}

class PostureEngine: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {

    // MARK: - Published State for UI
    
    /// Current detection mode
    @Published var detectionMode: DetectionMode = .front
    
    // Front detection results
    @Published var shoulderTilt: Double = 0.0       // ° difference between shoulders (+ = right higher)
    @Published var headTilt: Double = 0.0           // ° head roll
    @Published var isFrontLocked: Bool = false      // Front pose successfully detected
    @Published var frontPoints: FrontPosePoints? = nil
    
    // Side detection results (CVA-based)
    @Published var cva: Double = 0.0               // Craniovertebral Angle (higher = better, normal ≥53°)
    @Published var forwardHeadAngle: Double = 0.0   // Legacy: ° forward head offset
    @Published var isSideLocked: Bool = false       // Side pose successfully detected
    @Published var sidePoints: SidePosePoints? = nil
    
    // General
    @Published var confidence: Double = 0.0
    
    // MARK: - Internal Math State (Smoothing & Stability)
    private var previousLeftShoulder: CGPoint?
    private var previousRightShoulder: CGPoint?
    private var previousNose: CGPoint?
    private var previousEar: CGPoint?
    private var previousNeck: CGPoint?
    
    // Missed frame counters for hysteresis
    private var frontMissedFrames: Int = 0
    private var sideMissedFrames: Int = 0
    
    // Lower alpha = more stable but slower. Higher = faster but jittery.
    private let smoothingAlpha: CGFloat = 0.3

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
    
    func switchToSideMode() {
        DispatchQueue.main.async {
            self.detectionMode = .side
            self.isSideLocked = false
            self.previousEar = nil
            self.previousNeck = nil
            self.sideMissedFrames = 0
        }
    }
    
    func switchToFrontMode() {
        DispatchQueue.main.async {
            self.detectionMode = .front
            self.isFrontLocked = false
            self.previousLeftShoulder = nil
            self.previousRightShoulder = nil
            self.previousNose = nil
            self.frontMissedFrames = 0
        }
    }
    
    func reset() {
        DispatchQueue.main.async {
            self.detectionMode = .front
            self.isFrontLocked = false
            self.isSideLocked = false
            self.shoulderTilt = 0
            self.headTilt = 0
            self.cva = 0
            self.forwardHeadAngle = 0
            self.frontPoints = nil
            self.sidePoints = nil
            self.frontMissedFrames = 0
            self.sideMissedFrames = 0
        }
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
                DispatchQueue.main.async {
                    self.isFrontLocked = false
                    self.isSideLocked = false
                }
                return
            }

            switch detectionMode {
            case .front:
                processFrontPose(observation)
            case .side:
                processSidePose(observation)
            }

        } catch {
            #if DEBUG
            print("Vision Error: \(error)")
            #endif
        }
    }
    
    // MARK: - Front Pose Detection
    
    private func processFrontPose(_ observation: VNHumanBodyPoseObservation) {
        // Get both shoulders and nose for front detection
        guard let leftShoulder = try? observation.recognizedPoint(.leftShoulder),
              let rightShoulder = try? observation.recognizedPoint(.rightShoulder),
              let nose = try? observation.recognizedPoint(.nose),
              leftShoulder.confidence > 0.5,
              rightShoulder.confidence > 0.5,
              nose.confidence > 0.5 else {
            
            // Frame Missed Logic
            frontMissedFrames += 1
            if frontMissedFrames > PostureConstants.missedFrameTolerance {
                DispatchQueue.main.async { self.isFrontLocked = false }
            }
            return
        }
        
        // Frame Hit Logic
        frontMissedFrames = 0
        
        // Convert to CGPoint (0..1) - flip Y
        let rawLeftShoulder = CGPoint(x: leftShoulder.location.x, y: 1 - leftShoulder.location.y)
        let rawRightShoulder = CGPoint(x: rightShoulder.location.x, y: 1 - rightShoulder.location.y)
        let rawNose = CGPoint(x: nose.location.x, y: 1 - nose.location.y)
        
        // Apply smoothing
        let smoothedLeftShoulder = smooth(new: rawLeftShoulder, old: previousLeftShoulder)
        let smoothedRightShoulder = smooth(new: rawRightShoulder, old: previousRightShoulder)
        let smoothedNose = smooth(new: rawNose, old: previousNose)
        
        previousLeftShoulder = smoothedLeftShoulder
        previousRightShoulder = smoothedRightShoulder
        previousNose = smoothedNose
        
        // Calculate shoulder tilt (difference in Y position)
        // Positive = right shoulder higher, Negative = left shoulder higher
        let shoulderDeltaY = smoothedRightShoulder.y - smoothedLeftShoulder.y
        let shoulderDistance = abs(smoothedRightShoulder.x - smoothedLeftShoulder.x)
        let shoulderTiltAngle = atan(shoulderDeltaY / max(shoulderDistance, 0.01)) * 180 / .pi
        
        // Calculate head tilt (nose offset from shoulder midpoint)
        let shoulderMidX = (smoothedLeftShoulder.x + smoothedRightShoulder.x) / 2
        let headOffset = smoothedNose.x - shoulderMidX
        let headTiltAngle = headOffset * 100 // Approximate degrees
        
        #if DEBUG
        print("Front: ShoulderTilt=\(shoulderTiltAngle)°, HeadTilt=\(headTiltAngle)°")
        #endif
        
        DispatchQueue.main.async {
            self.isFrontLocked = true
            self.shoulderTilt = shoulderTiltAngle
            self.headTilt = headTiltAngle
            self.confidence = Double((leftShoulder.confidence + rightShoulder.confidence + nose.confidence) / 3)
            self.frontPoints = FrontPosePoints(
                leftShoulder: smoothedLeftShoulder,
                rightShoulder: smoothedRightShoulder,
                nose: smoothedNose
            )
        }
    }
    
    // MARK: - Side Pose Detection (CVA-based)
    /// Calculates Craniovertebral Angle (CVA) = angle from ear(tragus) to neck(C7) measured from horizontal
    /// Higher CVA = more upright = better posture. Normal CVA ≥ 53°
    
    private func processSidePose(_ observation: VNHumanBodyPoseObservation) {
        // Get ear (tragus approximation) and compute neck point (C7 approximation)
        let leftEar = try? observation.recognizedPoint(.leftEar)
        let rightEar = try? observation.recognizedPoint(.rightEar)
        let leftShoulder = try? observation.recognizedPoint(.leftShoulder)
        let rightShoulder = try? observation.recognizedPoint(.rightShoulder)
        
        // Also try to get neck point if available
        let neck = try? observation.recognizedPoint(.neck)

        // Determine which side is visible (higher confidence)
        var ear: VNRecognizedPoint?
        var neckPoint: CGPoint?

        let leftConf = (leftEar?.confidence ?? 0) + (leftShoulder?.confidence ?? 0)
        let rightConf = (rightEar?.confidence ?? 0) + (rightShoulder?.confidence ?? 0)

        if leftConf > rightConf && leftConf > 1.0 {
            ear = leftEar
            // Use neck if available, otherwise estimate from shoulder
            if let neckPt = neck, neckPt.confidence > 0.3 {
                neckPoint = CGPoint(x: neckPt.location.x, y: 1 - neckPt.location.y)
            } else if let shoulder = leftShoulder {
                // C7 is approximately at shoulder level but more centered
                neckPoint = CGPoint(x: shoulder.location.x, y: 1 - shoulder.location.y)
            }
        } else if rightConf > 1.0 {
            ear = rightEar
            if let neckPt = neck, neckPt.confidence > 0.3 {
                neckPoint = CGPoint(x: neckPt.location.x, y: 1 - neckPt.location.y)
            } else if let shoulder = rightShoulder {
                neckPoint = CGPoint(x: shoulder.location.x, y: 1 - shoulder.location.y)
            }
        }

        guard let earPoint = ear, let rawNeck = neckPoint else {
            
            // Frame Missed Logic (Side)
            sideMissedFrames += 1
            if sideMissedFrames > PostureConstants.missedFrameTolerance {
                DispatchQueue.main.async { self.isSideLocked = false }
            }
            return
        }
        
        // Frame Hit Logic (Side)
        sideMissedFrames = 0

        let rawEar = CGPoint(x: earPoint.location.x, y: 1 - earPoint.location.y)

        let smoothedEar = smooth(new: rawEar, old: previousEar)
        let smoothedNeck = smooth(new: rawNeck, old: previousNeck)

        previousEar = smoothedEar
        previousNeck = smoothedNeck

        // CVA Calculation:
        // CVA = angle from horizontal line at neck to the ear
        // Higher angle = more upright = better posture
        let deltaX = smoothedEar.x - smoothedNeck.x  // Horizontal distance
        let deltaY = smoothedNeck.y - smoothedEar.y  // Vertical distance (ear is above neck)

        guard deltaY > 0 else { return }  // Ear must be above neck

        // CVA is angle from horizontal (atan2 gives angle from x-axis)
        // We want angle from horizontal at C7 to tragus
        let cvaRadians = atan2(deltaY, abs(deltaX))
        let cvaDegrees = cvaRadians * 180 / .pi
        
        // Legacy forward head angle (deviation from vertical)
        let forwardAngleRadians = atan(abs(deltaX) / deltaY)
        let forwardAngleDegrees = forwardAngleRadians * 180 / .pi

        #if DEBUG
        print("Side: CVA=\(cvaDegrees)° (\(PostureConstants.cvaClassification(for: cvaDegrees))), ForwardOffset=\(forwardAngleDegrees)°")
        #endif

        DispatchQueue.main.async {
            self.isSideLocked = true
            self.confidence = Double(earPoint.confidence)
            self.cva = cvaDegrees
            self.forwardHeadAngle = forwardAngleDegrees
            self.sidePoints = SidePosePoints(ear: smoothedEar, neck: smoothedNeck)
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

// MARK: - Front Pose Points

struct FrontPosePoints {
    let leftShoulder: CGPoint
    let rightShoulder: CGPoint
    let nose: CGPoint
}

// MARK: - Side Pose Points (CVA-based)

struct SidePosePoints {
    let ear: CGPoint       // Tragus approximation
    let neck: CGPoint      // C7 approximation
}
