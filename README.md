# MetalCamera
 Camera app using MetalKit

1. Go to the storyboard and select the View under the View Controller as set its class to a MetalView type under Identity Inspector as seen in the image below.

<img src="https://github.com/yoshimin/MetalCamera/blob/master/screenshot.png" width=600>

2. Create CVPixelBuffer with CMSampleBuffer return from method AVCaptureVideoDataOutputSampleBufferDelegate.
3. Set the CVPixelBuffer into MetalView.
```
func captureOutput(_ captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, from connection: AVCaptureConnection!) {
    let metalView =  view as! MetalView
    metalView.setPixelBuffer(CMSampleBufferGetImageBuffer(sampleBuffer)!)
}
```

4. Call `snapshot()` to take a photo.
```
@IBAction func snapshot(_ sender: Any) {
    let metalView =  view as! MetalView
    UIImageWriteToSavedPhotosAlbum(metalView.snapshot(), nil, nil, nil);
}
```
