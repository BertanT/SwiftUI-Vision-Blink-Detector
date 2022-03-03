enum VBDError: Error {
    case camPermissionDenied, noCaptureDevices, invalidInputs, noInputs, other, cannotGetImageBuffer
}
