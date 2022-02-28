import SwiftUI

struct ContentView: View {
    @State private var faceDetected = false
    @State private var multipleFaces = false
    @State private var eyesClosed = false
    var body: some View {
        VStack {
            EmptyView()
            VisionView(faceDetected: $faceDetected, multipleFaces: $multipleFaces, eyesClosed: $eyesClosed)
                .frame(width: 500, height: 500)
                .mask(RoundedRectangle(cornerRadius: 20))
                .edgesIgnoringSafeArea(.all)
            Text(eyesClosed ? "Eyes Closed!" : "Eyes open!")
                .font(.largeTitle)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        Text("Hello, world!")
    }
}
