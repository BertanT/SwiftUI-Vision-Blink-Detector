enum VBDError: Error {
    case camPermissionDenied, noCaptureDevices, noInputs, invalidInputs, cannotGetImageBuffer
}
