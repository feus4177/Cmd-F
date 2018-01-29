//
//  ViewController.swift
//  Cmd+F
//
//  Created by John Feusi on 12/28/17.
//  Copyright © 2017 Feusi's Appworks. All rights reserved.
//

import UIKit
import AVFoundation
import Photos


class ViewController: UIViewController, AVCapturePhotoCaptureDelegate {
    private var captureSession: AVCaptureSession!
    private var capturePhotoOutput: AVCapturePhotoOutput!
    private var photoSampleBuffer: CMSampleBuffer!
    private var isCaptureSessionConfigured = false
    private let sessionQueue = DispatchQueue(label: "session queue")

    override func viewDidLoad() {
        super.viewDidLoad()

        previewView.session = captureSession

        self.checkCameraAuthorization { authorized in
            if authorized {
                self.captureSession = AVCaptureSession()
            } else {
                print("Permission to use camera denied.")
            }
        }

        self.checkPhotoLibraryAuthorization { authorized in
            if authorized {
                print("Cool")
            } else {
                print("Permissio to use library denied.")
            }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if self.isCaptureSessionConfigured {
            if !self.captureSession.isRunning {
                self.captureSession.startRunning()
            }
        } else {
            // First time: request camera access, configure capture session and start it.
            self.checkCameraAuthorization({ authorized in
                guard authorized else {
                    print("Permission to use camera denied.")
                    return
                }
                self.sessionQueue.async {
                    self.configureCaptureSession({ success in
                        guard success else { return }
                        self.isCaptureSessionConfigured = true
                        self.captureSession.startRunning()
                        DispatchQueue.main.async {
                            self.previewView.updateVideoOrientationForDeviceOrientation()
                        }
                    })
                }
            })
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        if captureSession.isRunning {
            captureSession.stopRunning()
        }
    }

    func checkCameraAuthorization(_ completionHandler: @escaping ((_ authorized: Bool) -> Void)) {
        switch AVCaptureDevice.authorizationStatus(forMediaType: AVMediaTypeVideo) {
        case .authorized:
            //The user has previously granted access to the camera.
            completionHandler(true)

        case .notDetermined:
            // The user has not yet been presented with the option to grant video access so request access.
            AVCaptureDevice.requestAccess(forMediaType: AVMediaTypeVideo, completionHandler: { success in
                completionHandler(success)
            })

        case .denied:
            // The user has previously denied access.
            completionHandler(false)

        case .restricted:
            // The user doesn't have the authority to request access e.g. parental restriction.
            completionHandler(false)
        }
    }

    func checkPhotoLibraryAuthorization(_ completionHandler: @escaping ((_ authorized: Bool) -> Void)) {
        switch PHPhotoLibrary.authorizationStatus() {
        case .authorized:
            // The user has previously granted access to the photo library.
            completionHandler(true)

        case .notDetermined:
            // The user has not yet been presented with the option to grant photo library access so request access.
            PHPhotoLibrary.requestAuthorization({ status in
                completionHandler((status == .authorized))
            })

        case .denied:
            // The user has previously denied access.
            completionHandler(false)

        case .restricted:
            // The user doesn't have the authority to request access e.g. parental restriction.
            completionHandler(false)
        }
    }


    func defaultDevice() -> AVCaptureDevice {
        if let device = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeVideo) {
            return device
        } else {
            fatalError("All supported devices are expected to have at least one of the queried capture devices.")
        }
    }

    func configureCaptureSession(_ completionHandler: ((_ success: Bool) -> Void)) {
        var success = false
        defer { completionHandler(success) } // Ensure all exit paths call completion handler.

        // Get video input for the default camera.
        let videoCaptureDevice = defaultDevice()
        guard let videoInput = try? AVCaptureDeviceInput(device: videoCaptureDevice) else {
            print("Unable to obtain video input for default camera.")
            return
        }

        // Create and configure the photo output.
        let capturePhotoOutput = AVCapturePhotoOutput()
        capturePhotoOutput.isHighResolutionCaptureEnabled = true
        capturePhotoOutput.isLivePhotoCaptureEnabled = false

        // Make sure inputs and output can be added to session.
        guard self.captureSession.canAddInput(videoInput) else { return }
        guard self.captureSession.canAddOutput(capturePhotoOutput) else { return }

        // Configure the session.
        self.captureSession.beginConfiguration()
        self.captureSession.sessionPreset = AVCaptureSessionPresetPhoto
        self.captureSession.addInput(videoInput)
        self.captureSession.addOutput(capturePhotoOutput)
        self.captureSession.commitConfiguration()

        self.capturePhotoOutput = capturePhotoOutput

        success = true
    }

    func snapPhoto() {
        guard let capturePhotoOutput = self.capturePhotoOutput else { return }
        let videoPreviewLayerOrientation = previewView.videoPreviewLayer.connection.videoOrientation
        self.sessionQueue.async {
            // Update the photo output's connection to match the video orientation of the video preview layer.
            if let photoOutputConnection = capturePhotoOutput.connection(withMediaType: AVMediaTypeVideo) {
                photoOutputConnection.videoOrientation = videoPreviewLayerOrientation
            }

            var photoSettings = AVCapturePhotoSettings()
            if !self.capturePhotoOutput.availablePhotoPixelFormatTypes.isEmpty {
                var pixelFormatType = NSNumber(value: kCVPixelFormatType_48RGB)
                if !self.capturePhotoOutput.availablePhotoPixelFormatTypes.contains(pixelFormatType) {
                    pixelFormatType = self.capturePhotoOutput.availablePhotoPixelFormatTypes.first!
                }
                photoSettings = AVCapturePhotoSettings(
                    format: [kCVPixelBufferPixelFormatTypeKey as String: pixelFormatType]
                )
            }
            photoSettings.isAutoStillImageStabilizationEnabled = true
            photoSettings.isHighResolutionPhotoEnabled = true
            photoSettings.flashMode = .auto

            capturePhotoOutput.capturePhoto(with: photoSettings, delegate: self)
        }
    }

    func capture(_ captureOutput: AVCapturePhotoOutput,
                 didFinishProcessingPhotoSampleBuffer photoSampleBuffer: CMSampleBuffer?,
                 previewPhotoSampleBuffer: CMSampleBuffer?,
                 resolvedSettings: AVCaptureResolvedPhotoSettings,
                 bracketSettings: AVCaptureBracketedStillImageSettings?,
                 error: Error?) {
        guard error == nil, let photoSampleBuffer = photoSampleBuffer else {
            print("Error capturing photo: \(String(describing: error))")
            return
        }

        self.photoSampleBuffer = photoSampleBuffer
    }

    func capture(_ captureOutput: AVCapturePhotoOutput,
                 didFinishCaptureForResolvedSettings resolvedSettings: AVCaptureResolvedPhotoSettings,
                 error: Error?) {
        guard error == nil else {
            print("Error in capture process: \(String(describing: error))")
            return
        }
        guard let cvPixelBuffer = CMSampleBufferGetImageBuffer(self.photoSampleBuffer) else {
            print("photoSampleBuffer does not contain a CVPixelBuffer.")
            return
        }

        // Create a Core Image image from the pixel buffer and apply a filter.
        let orientationMap: [AVCaptureVideoOrientation : CGImagePropertyOrientation] = [
            .portrait           : .right,
            .portraitUpsideDown : .left,
            .landscapeLeft      : .down,
            .landscapeRight     : .up,
            ]
        let imageOrientation = Int32(orientationMap[previewView.videoPreviewLayer.connection.videoOrientation]!.rawValue)
        let ciImage = CIImage(cvPixelBuffer: cvPixelBuffer).applyingOrientation(imageOrientation)
        let uiImage = UIImage(ciImage: ciImage)

    }

    @IBOutlet weak var previewView: PreviewView!
}

extension ViewController: UINavigationControllerDelegate {
}

extension ViewController: UIImagePickerControllerDelegate {
    func presentImagePicker() {
        let imagePickerActionSheet = UIAlertController(title: "Choose Image",
                                                       message: nil,
                                                       preferredStyle: .actionSheet)

        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            let cameraButton = UIAlertAction(title: "Take Photo",
                                             style: .default) { (alert) -> Void in
                                                let imagePicker = UIImagePickerController()
                                                imagePicker.delegate = self
                                                imagePicker.sourceType = .camera
                                                self.present(imagePicker, animated: true)
            }
            imagePickerActionSheet.addAction(cameraButton)
        }

        let libraryButton = UIAlertAction(title: "Choose Existing",
                                          style: .default) { (alert) -> Void in
                                            let imagePicker = UIImagePickerController()
                                            imagePicker.delegate = self
                                            imagePicker.sourceType = .photoLibrary
                                            self.present(imagePicker, animated: true)
        }
        imagePickerActionSheet.addAction(libraryButton)
        // 2
        let cancelButton = UIAlertAction(title: "Cancel", style: .cancel)
        imagePickerActionSheet.addAction(cancelButton)
        // 3
        present(imagePickerActionSheet, animated: true)
    }
}

