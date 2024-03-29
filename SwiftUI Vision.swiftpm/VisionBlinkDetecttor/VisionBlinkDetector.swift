import SwiftUI

struct VisionBlinkDetector: UIViewControllerRepresentable {
    typealias UIViewControllerType = VisionBlinkDetectorVC
    @Binding var detectedState: VBDState
    let onError: (VBDError) -> Void
    
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
            func onErrorAsync(_ error: VBDError) {
                DispatchQueue.main.async {
                    parent.onError(error)
                }
            }
            self.onError = onErrorAsync(_:)
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
