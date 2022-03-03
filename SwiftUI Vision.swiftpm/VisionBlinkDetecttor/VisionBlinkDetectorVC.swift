import UIKit
import AVFoundation
import Vision

final class VisionBlinkDetectorVC: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    weak var delegate: VisionBlinkDetectorVCDelegate?
    
    private let captureSession = AVCaptureSession()
    private let videoDataOutput = AVCaptureVideoDataOutput()
    private let closedEyesThreshold = 0.2
    private lazy var previewLayer = AVCaptureVideoPreviewLayer(session: self.captureSession)
    
    private var drawingLayers: [CAShapeLayer] = []
    private var lastFaceRectangleOrigin: CGPoint?
    
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
    
    private func checkCamPermission() -> Bool {
        let permission = AVCaptureDevice.authorizationStatus(for: .video)
        
        switch permission {
        case .authorized:
            return true
        case .notDetermined:
            var permission = false
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted {
                    permission = true
                }
            }
            return permission
        default:
            return false
        }
    }
    
    // Handle errors here!
    private func captureSessionSetup() {
        if !checkCamPermission() {
            delegate?.onError(VBDError.camPermissionDenied)
            return
        }
        guard let captureDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
            delegate?.onError(VBDError.noCaptureDevices)
            return
        }
        guard let deviceInput = try? AVCaptureDeviceInput(device: captureDevice) else {
            delegate?.onError(VBDError.noInputs)
            return
        }
        if captureSession.canAddInput(deviceInput) {
            captureSession.addInput(deviceInput)
            previewLayerSetup()
        }else {
            delegate?.onError(VBDError.invalidInputs)
        }
    }
}

extension VisionBlinkDetectorVC {
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
        
        self.lastFaceRectangleOrigin = boundingBox.origin
    }
    
    private func clearFaceRectangle() {
        self.drawingLayers.forEach { drawing in drawing.removeFromSuperlayer() }
    }
    
    private func handleFaceDetectionObservations(observations: [VNFaceObservation]) {
        switch observations.count {
        case 0:
            clearFaceRectangle()
            delegate?.detectedState = .noFaces
            return
        case 1:
            break
        default:
            clearFaceRectangle()
            delegate?.detectedState = .multipleFaces
            return
        }
        
        let observation = observations[0]
        
        let drawingRect = self.previewLayer.layerRectConverted(fromMetadataOutputRect: observation.boundingBox)
        
        if let lastFaceRectangleOrigin = lastFaceRectangleOrigin {
            let displacement = euclideanDistance(from: lastFaceRectangleOrigin, to: drawingRect.origin)
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
                
                if leftEAR < closedEyesThreshold || rightEAR < closedEyesThreshold {
                    delegate?.detectedState = .eyesClosed
                }else {
                    delegate?.detectedState = .eyesOpen
                }
                print("\(leftEAR) \(rightEAR)")
                print(delegate?.detectedState)
            }
        }
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            delegate?.onError(VBDError.cannotGetImageBuffer)
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
}

