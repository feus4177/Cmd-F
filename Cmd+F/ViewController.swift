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
import TesseractOCR


class ViewController: UIViewController, AVCapturePhotoCaptureDelegate {
    override func viewDidLoad() {
        super.viewDidLoad()

        self.checkCameraAuthorization { authorized in
            if authorized {
                print("Cool")
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

    func performImageRecognition(_ image: UIImage) {
        if let tesseract = G8Tesseract(language: "eng") {
            tesseract.engineMode = .tesseractCubeCombined
            tesseract.pageSegmentationMode = .auto
            tesseract.image = image.g8_blackAndWhite()
            tesseract.recognize()
            textView.text = tesseract.recognizedText
        }

        activityIndicator.stopAnimating()
    }

    @IBAction func getPhoto(_ sender: Any) {
        presentImagePicker()
    }

    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var previewView: PreviewView!
    @IBOutlet weak var textView: UITextView!
    @IBOutlet weak var getPhotoButton: UIButton!
}

extension ViewController: UINavigationControllerDelegate {
}

extension ViewController: UIImagePickerControllerDelegate {
    func presentImagePicker() {
        let imagePickerActionSheet = UIAlertController(title: "Get Image",
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

        let libraryButton = UIAlertAction(title: "Use Existing",
                                          style: .default) { (alert) -> Void in
                                            let imagePicker = UIImagePickerController()
                                            imagePicker.delegate = self
                                            imagePicker.sourceType = .photoLibrary
                                            self.present(imagePicker, animated: true)
        }
        imagePickerActionSheet.addAction(libraryButton)

        let cancelButton = UIAlertAction(title: "Cancel", style: .cancel)
        imagePickerActionSheet.addAction(cancelButton)

        present(imagePickerActionSheet, animated: true)
    }

    func imagePickerController(_ picker: UIImagePickerController,
                               didFinishPickingMediaWithInfo info: [String : Any]) {
        if let selectedPhoto = info[UIImagePickerControllerOriginalImage] as? UIImage {
            activityIndicator.startAnimating()
            dismiss(animated: true, completion: {
                self.performImageRecognition(selectedPhoto)
            })
        }
    }
}

