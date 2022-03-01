import SwiftUI

struct ContentView: View {
    @State private var detectedState: VBDState = .noFaces
    var body: some View {
        VStack {
            EmptyView()
            VisionBlinkDetector(detectedState: $detectedState)
                .frame(width: 500, height: 500)
                .mask(RoundedRectangle(cornerRadius: 20))
                .edgesIgnoringSafeArea(.all)
            Text(detectedState.rawValue)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        Text("Hello, world!")
    }
}
