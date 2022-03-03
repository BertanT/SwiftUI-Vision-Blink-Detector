import SwiftUI

struct VisionBlinkDetector: UIViewControllerRepresentable {
    typealias UIViewControllerType = VisionBlinkDetectorVC
    @Binding var detectedState: VBDState
    let onError: (Error) -> Void
    
    class Coordinator: NSObject, VisionBlinkDetectorVCDelegate {
        var parent: VisionBlinkDetector
        
        var detectedState: VBDState = .noFaces {
            willSet {
                self.parent.detectedState = newValue
            }
        }
        
        var onError: (VBDError) -> Void
        
        init(_ parent: VisionBlinkDetector) {
            self.parent = parent
            self.onError = parent.onError
        }
        
    }
    
    func makeUIViewController(context: Context) -> VisionBlinkDetectorVC {
        let visionVC = VisionBlinkDetectorVC()
        visionVC.delegate = context.coordinator
        return visionVC
    }
    
    func updateUIViewController(_ uiViewController: VisionBlinkDetectorVC, context: Context) {
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
}
