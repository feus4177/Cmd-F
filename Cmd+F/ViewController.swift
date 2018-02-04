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


class ViewController: UIViewController {
    var selectedImage: UIImage?
    var currentSearch = ""
    var tesseract: G8Tesseract?
    var recognizedSelectedImage = false

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

    func performImageRecognition() {
        if let image = selectedImage, let newTesseract = G8Tesseract(language: "eng", engineMode: .tesseractCubeCombined) {
            progressbar.setProgress(0.2, animated: false)
            progressbar.isHidden = false

            tesseract = newTesseract
            tesseract!.delegate = self
            tesseract!.pageSegmentationMode = .auto
            tesseract!.image = image.g8_blackAndWhite()
            DispatchQueue.global().async {
                if self.tesseract!.recognize() {
                    print("SUCCEEDED")
                    self.recognizedSelectedImage = true
                } else {
                    print("FAILED")
                }

                DispatchQueue.main.async {
                    self.progressbar.isHidden = true
                    self.drawBlocks()
                }
            }
        }
    }

    func drawBlocks() {
        if recognizedSelectedImage, let image = selectedImage {
            UIGraphicsBeginImageContext(image.size)
            if let context = UIGraphicsGetCurrentContext() {
                image.draw(at: CGPoint.zero)

                context.setLineWidth(1.0)
                context.setStrokeColor(UIColor.blue.cgColor)
                let blocks = tesseract?.recognizedBlocks(by: .symbol) as! [G8RecognizedBlock]
                for block: G8RecognizedBlock in blocks {
                    context.stroke(block.boundingBox(atImageOf: image.size))
                }

                imageView.image = UIGraphicsGetImageFromCurrentImageContext()
            }
            UIGraphicsEndImageContext()
        }
    }

    @IBAction func getPhoto(_ sender: Any) {
        presentImagePicker()
    }

    @IBAction func tap(_ sender: Any) {
        searchBar.endEditing(true)
    }

    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var progressbar: UIProgressView!
}

extension ViewController: G8TesseractDelegate {
    func progressImageRecognition(for tesseract: G8Tesseract!) {
        DispatchQueue.main.async {
            self.progressbar.setProgress(Float(tesseract.progress) / 100.0, animated: true)
        }
    }

    func shouldCancelImageRecognition(for tesseract: G8Tesseract!) -> Bool {
        return false
    }
}

extension ViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        self.currentSearch = searchText
        self.drawBlocks()
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.endEditing(true)
    }

    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
        searchBar.endEditing(true)
    }
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
        if let selectedImage = info[UIImagePickerControllerOriginalImage] as? UIImage {
            self.recognizedSelectedImage = false
            self.selectedImage = selectedImage
            self.imageView.image = selectedImage

            dismiss(animated: true) {
                self.performImageRecognition()
            }
        }
    }
}



