import SwiftUI
import AVFoundation

struct ContentView: View {
    @State private var detectedState: VBDState = .noFaces
    @State private var longBlinkTimer: Timer?
    @State private var toggleState = false
    var body: some View {
        VStack {
            EmptyView()
            VisionBlinkDetector(detectedState: $detectedState)
                .frame(width: 500, height: 500)
                .mask(RoundedRectangle(cornerRadius: 20))
                .edgesIgnoringSafeArea(.all)
            Text(detectedState.rawValue)
            Toggle("Eye Switch", isOn: $toggleState)
                .onChange(of: detectedState) { newValue in
                    if newValue == .eyesClosed {
                        longBlinkTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false, block: { _ in
                            // create a sound ID, in this case its the tweet sound.
                            let systemSoundID: SystemSoundID = 1016

                            // to play sound
                            AudioServicesPlaySystemSound(systemSoundID)
                        })
                    }else if newValue == .eyesOpen{
                        longBlinkTimer?.invalidate()
                        toggleState.toggle()
                    }else {
                        longBlinkTimer?.invalidate()
                    }
                }
        }
    }
}
