//
//  ViewController.swift
//  MetalCamera
//
//  Created by 新谷　よしみ on 2017/02/12.
//
//

import UIKit
import AVFoundation

class ViewController: UIViewController {

    
    @IBOutlet weak var snapshotButton: UIButton!
    
    let session = AVCaptureSession()
    var videoConnection: AVCaptureConnection?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let device = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeVideo)
        let input = try? AVCaptureDeviceInput(device: device)
        if session.canAddInput(input) {
            session.addInput(input)
        }
        
        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as AnyHashable : kCVPixelFormatType_32BGRA]
        output.setSampleBufferDelegate(self, queue: DispatchQueue(label: "cameraQueue"))
        if session.canAddOutput(output) {
            session.addOutput(output)
        }
        
        if session.canSetSessionPreset(AVCaptureSessionPresetPhoto) {
            session.canSetSessionPreset(AVCaptureSessionPresetPhoto)
        }
        
        session.beginConfiguration()
        
        for (_, connection) in output.connections.enumerated() {
            for (_, port) in (connection as! AVCaptureConnection).inputPorts.enumerated() {
                if (port as! AVCaptureInputPort).mediaType == AVMediaTypeVideo {
                    videoConnection = connection as? AVCaptureConnection
                    break
                }
            }
            if videoConnection != nil {
                break;
            }
        }
        
        if (videoConnection?.isVideoOrientationSupported)! {
            videoConnection?.videoOrientation = .portrait
        }
        
        session.commitConfiguration()
        
        session.startRunning()
        
        snapshotButton.layer.cornerRadius = snapshotButton.frame.width * 0.5
        snapshotButton.layer.borderColor = UIColor.white.cgColor
        snapshotButton.layer.borderWidth = 3
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        switch UIApplication.shared.statusBarOrientation {
        case .portrait:
            videoConnection?.videoOrientation = .portrait
            break
        case .portraitUpsideDown:
            videoConnection?.videoOrientation = .portraitUpsideDown
            break
        case .landscapeLeft:
            videoConnection?.videoOrientation = .landscapeLeft
            break
        case .landscapeRight:
            videoConnection?.videoOrientation = .landscapeRight
            break
        default:
            break
        }
    }

    @IBAction func snapshot(_ sender: Any) {
        let metalView =  view as! MetalView
        UIImageWriteToSavedPhotosAlbum(metalView.snapshot(), nil, nil, nil);
    }
}

extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, from connection: AVCaptureConnection!) {
        let metalView =  view as! MetalView
        metalView.setPixelBuffer(CMSampleBufferGetImageBuffer(sampleBuffer)!)
    }
}

