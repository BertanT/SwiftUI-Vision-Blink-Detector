protocol VisionBlinkDetectorVCDelegate: AnyObject {
    var detectedState: VBDState { get set }
    var onError: (VBDError) -> Void { get set }
}
