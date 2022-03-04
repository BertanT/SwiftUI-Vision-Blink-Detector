import SwiftUI

struct GuidedVisionBlinkDtector: View {
    @Binding var detectedState: VBDState
    let onError: (VBDError) -> Void
    
    @State private var alertText: String?
    
    var body: some View {
        VisionBlinkDetector(detectedState: $detectedState, onError: handleError)
            .overlay { 
                if let alertText = alertText {
                    ZStack {
                        Rectangle()
                            .foregroundColor(.black)
                        VStack {
                            Spacer()
                            Image(systemName: "exclamationmark.triangle.fill")
                                .symbolRenderingMode(.multicolor)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 50)
                            Text(alertText)
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                            Spacer()
                            Spacer()
                            Spacer()
                        }
                    }
                }
            }
    }
    
    private func handleError(error: VBDError) {
        onError(error)
        switch error {
        case .camPermissionDenied:
            alertText = "Camera access is denied!\nTo use this playground, please allow camera access in settings."
        case .noCaptureDevices:
            alertText = "There are no compatible cameras in your device."
        case .cannotGetImageBuffer:
            // TODO: Add warning message to UI
            break
        default:
            alertText = "An unexpected error occured while processing image data"
        }
    }
}
