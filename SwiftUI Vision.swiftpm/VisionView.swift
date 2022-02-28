//
//  File.swift
//  SwiftUI Vision
//
//  Created by Bertan on 27.02.2022.
//

import UIKit
import SwiftUI
import AVFoundation
import Vision

// TODO: ADD Concurrency support!

protocol VisionViewControllerDelegate: AnyObject {
    var faceDetected: Bool { get set }
    var multipleFaces: Bool { get set }
    var eyesClosed: Bool { get set }
}

final class VisionViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    private let captureSession = AVCaptureSession()
    private let closedEyesThreshold = 0.2
    weak var delegate: VisionViewControllerDelegate?
    private lazy var previewLayer = AVCaptureVideoPreviewLayer(session: self.captureSession)
    private let videoDataOutput = AVCaptureVideoDataOutput()
    private var drawingLayers: [CAShapeLayer] = []
    private var lastFaceRectanglePoint: CGPoint?
    //var faceDetected = false
    //var multipleFaces = false
    //var eyesClosed: Bool = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        captureSessionSetup()
        captureSession.startRunning()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateOrientation()
        self.previewLayer.frame = self.view.frame
    }
    
    private func updateOrientation() {
        if let connection = previewLayer.connection {
            // Deprecated, but only way to know the orientation in Playgrounds!
            let orientation = self.interfaceOrientation
            let previewLayerConnection: AVCaptureConnection = connection
            
            if previewLayerConnection.isVideoOrientationSupported {
                previewLayerConnection.videoOrientation = AVCaptureVideoOrientation(rawValue: orientation.rawValue) ?? .portrait
            }
            self.previewLayer.frame = self.view.frame
        }
    }
    
    private func captureSessionSetup() {
        guard let captureDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
            print("Camera not found!")
            return
        }
        guard let deviceInput = try? AVCaptureDeviceInput(device: captureDevice) else {
            print("Cannot get device input!")
            return
        }
        if captureSession.canAddInput(deviceInput) {
            captureSession.addInput(deviceInput)
            //            Set up the preview layer
            previewLayerSetup()
        }else {
            print("Cannot add device input into AVCaptureSession!")
        }
    }
    
    private func previewLayerSetup() {
        self.previewLayer.videoGravity = .resizeAspectFill
        self.view.layer.addSublayer(self.previewLayer)
        self.previewLayer.frame = self.view.frame
        
        self.videoDataOutput.videoSettings = [(kCVPixelBufferPixelFormatTypeKey as NSString): NSNumber(value: kCVPixelFormatType_32BGRA)] as [String: Any]
        
        self.videoDataOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "Cam buffer queue"))
        self.captureSession.addOutput(self.videoDataOutput)
        
        let videoConnection = self.videoDataOutput.connection(with: .video)
        videoConnection?.videoOrientation = .portrait
    }
}

extension VisionViewController {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        let landmarksRequest = VNDetectFaceLandmarksRequest(completionHandler: { (request: VNRequest, error: Error?) in
            DispatchQueue.main.async {
                if let observations = request.results as? [VNFaceObservation] {
                    self.handleFaceDetectionObservations(observations: observations)
                }
            }
        })
        
        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: imageBuffer, orientation: .leftMirrored, options: [:])
        
        do {
            try imageRequestHandler.perform([landmarksRequest])
        }catch {
            print(error.localizedDescription)
        }
    }
    
    // Calculate the Euclidean distance of two points based on the Pythagorean theorem
    private func euclideanDistance(from p1: CGPoint, to p2: CGPoint) -> Double {
        let dx = p2.x - p1.x
        let dy = p2.y - p1.y
        
        let dxSquared = pow(dx, 2)
        let dySquared = pow(dy, 2)
        
        let d = sqrt(dxSquared + dySquared)
        
        return d
    }
    
    // Calculate eye aspect ratio
    private func calculateEAR(eyePoints: [CGPoint], faceBoundingBox: CGRect) -> Double {
        // Adjust for different device orientations!
        // Again, no other way to get the orientation than to use the deprecated propperty :(
        let xDivisor = self.interfaceOrientation.isPortrait ? faceBoundingBox.width : faceBoundingBox.height
        let yDivisor = self.interfaceOrientation.isPortrait ? faceBoundingBox.height : faceBoundingBox.width
        
        let p = eyePoints.map { CGPoint(x: $0.x / xDivisor, y: $0.y / yDivisor) }
        
        let d1 = euclideanDistance(from: p[1], to: p[5])
        let d2 = euclideanDistance(from: p[2], to: p[4])
        let d3 = euclideanDistance(from: p[0], to: p[3])
        
        let EAR = (d1 + d2) / (2.0 * d3)
        return EAR
    }
    
    private func clearFaceRectangle() {
        self.drawingLayers.forEach { drawing in drawing.removeFromSuperlayer() }
    }
    
    func scaledUpRect(rect: CGRect, scale: Double) -> CGRect {
        let adjustedWidth = rect.width * scale / 2
        let adjustmentHeight = rect.height * scale / 2
        return rect.insetBy(dx: -adjustedWidth, dy: -adjustmentHeight)
    }
    
    private func drawFaceRectangle(boundingBox: CGRect) {
        let scaledRect = scaledUpRect(rect: boundingBox, scale: 0.5)
        let drawingPath = UIBezierPath(roundedRect: scaledRect, byRoundingCorners: .allCorners, cornerRadii: CGSize(width: 15, height: 15)).cgPath
        
        let drawingLayer = CAShapeLayer()
        drawingLayer.path = drawingPath
        drawingLayer.lineWidth = 6
        drawingLayer.fillColor = UIColor.clear.cgColor
        drawingLayer.strokeColor = UIColor.systemTeal.cgColor
        
        clearFaceRectangle()
        self.drawingLayers.append(drawingLayer)
        self.view.layer.addSublayer(drawingLayer)
        
        self.lastFaceRectanglePoint = boundingBox.origin
    }
    
    private func handleFaceDetectionObservations(observations: [VNFaceObservation]) {
        switch observations.count {
        case 0:
            clearFaceRectangle()
            delegate?.faceDetected = false
            delegate?.multipleFaces = false
            return
        case 1:
            delegate?.faceDetected = true
            delegate?.multipleFaces = false
        default:
            clearFaceRectangle()
            delegate?.faceDetected = true
            delegate?.multipleFaces = true
            return
        }
        
        let observation = observations[0]
        
        let drawingRect = self.previewLayer.layerRectConverted(fromMetadataOutputRect: observation.boundingBox)
        
        if let lastFaceRectanglePoint = lastFaceRectanglePoint {
            let displacement = euclideanDistance(from: lastFaceRectanglePoint, to: drawingRect.origin)
            if displacement > 20 {
                drawFaceRectangle(boundingBox: drawingRect)
            }
        }else {
            drawFaceRectangle(boundingBox: drawingRect)
        }
        
        
        // Check if both eyes are closed
        if let landmarks = observation.landmarks {
            if let leftEye = landmarks.leftEye, let rightEye = landmarks.rightEye {
                let boundingBox = observation.boundingBox
                let leftEAR = calculateEAR(eyePoints: leftEye.normalizedPoints, faceBoundingBox: boundingBox)
                let rightEAR = calculateEAR(eyePoints: rightEye.normalizedPoints, faceBoundingBox: boundingBox)
                
                delegate?.eyesClosed = leftEAR < closedEyesThreshold || rightEAR < closedEyesThreshold
                print("\(leftEAR) \(rightEAR)")
                print(delegate?.eyesClosed)
            }
        }
    }
}

struct VisionView: UIViewControllerRepresentable {
    typealias UIViewControllerType = VisionViewController
    @Binding var faceDetected: Bool
    @Binding var multipleFaces: Bool
    @Binding var eyesClosed: Bool
    
    class Coordinator: NSObject, VisionViewControllerDelegate {
        var faceDetected = false {
            willSet {
                self.parent.faceDetected = newValue
            }
        }
        
        var multipleFaces = false {
            willSet {
                self.parent.multipleFaces = newValue
            }
        }
        
        var eyesClosed = false {
            willSet {
                self.parent.eyesClosed = newValue
            }
        }
        
        var parent: VisionView
        
        init(_ parent: VisionView) {
            self.parent = parent
        }
        
    }
    
    func makeUIViewController(context: Context) -> VisionViewController {
        let visionVC = VisionViewController()
        visionVC.delegate = context.coordinator
        return visionVC
    }
    
    func updateUIViewController(_ uiViewController: VisionViewController, context: Context) {
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
}
