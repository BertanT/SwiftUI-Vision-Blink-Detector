import SwiftUI
import AVFoundation

struct ContentView: View {
    @State private var detectedState: VBDState = .noFaces
    @State private var longBlinkTimer: Timer?
    @State private var userLongBlinked = false
    @State private var toggleState = false
    var body: some View {
        VStack {
            EmptyView()
            VisionBlinkDetector(detectedState: $detectedState) { error in 
                fatalError(error.localizedDescription)
            }
                .frame(width: 500, height: 500)
                .mask(RoundedRectangle(cornerRadius: 20))
                .edgesIgnoringSafeArea(.all)
            Text(detectedState.rawValue)
            Toggle("Eye Switch", isOn: $toggleState)
                .onChange(of: detectedState) { newValue in
                    if newValue == .eyesClosed {
                        longBlinkTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false, block: { _ in
                            let systemSoundID: SystemSoundID = 1335
                            AudioServicesPlaySystemSound(systemSoundID)
                            userLongBlinked = true
                        })
                    }else if newValue == .eyesOpen{
                        if userLongBlinked {
                            userLongBlinked = false
                        }else {
                            longBlinkTimer?.invalidate()
                            toggleState.toggle()
                        }
                    }else {
                        longBlinkTimer?.invalidate()
                    }
                }
        }
    }
}
