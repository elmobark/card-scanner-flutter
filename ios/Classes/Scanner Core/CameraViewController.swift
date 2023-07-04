//
//  CameraViewController.swift
//  Card Promise Showcase
//
//  Created by Mohammed Sadiq on 26/07/20.
//  Copyright © 2020 MZaink. All rights reserved.
//

import UIKit
import AVFoundation
import MLKitTextRecognition
import MLKitVision

protocol CameraDelegate {
    func camera(_ camera: CameraViewController, didScan scanResult: Text)
    func cameraDidStopScanning(_ camera: CameraViewController)
}


class CameraViewController: UIViewController {
    var scansDroppedSinceLastReset: Int = 0
    
    let textRecognizer = TextRecognizer.textRecognizer()
    
    var cameraDelegate: CameraDelegate?
    var captureSession: AVCaptureSession!
    var device: AVCaptureDevice!
    var input: AVCaptureDeviceInput!
    var prompt: String = ""
    var torchOn: Bool = false
    
    var cameraOrientation: CameraOrientation = .portrait
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        gainCameraPermission()
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        DispatchQueue.main.async {
            let tapCapturingView = UIControl(
                frame: CGRect(
                    x: 0.0,
                    y: 80.0,
                    width: self.view.frame.width,
                    height: self.view.frame.height - 230
                )
            )
            
            tapCapturingView.addTarget(
                self,
                action: #selector(self.captureTap(_:)),
                for: .touchDown
            )
            
            self.view.addSubview(tapCapturingView)
        }
    }
    
    @objc func captureTap(_ sender: UIEvent) {
        refocus()
    }
    
    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        addAnimatingScanLine()
    }
    
    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if isBeingDismissed {
            stopScanning()
        }
    }
    
    func setupCaptureSession() {
        captureSession = AVCaptureSession()
        captureSession.sessionPreset = .high
        
        guard let safeCaptureDevice = AVCaptureDevice.default(for: .video), let safeCaptureDeviceInput = try? AVCaptureDeviceInput(device: safeCaptureDevice) else {
            return
        }
        
        device = safeCaptureDevice
        input = safeCaptureDeviceInput
        
        refocus()
        
        addInputDeviceToSession()
        
        createAndAddPreviewLayer()
        
        addOutputToInputDevice()
        
        addScanControlsAndIndicators()
        
        startScanning()
    }
    
    func gainCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupCaptureSession()
            
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted {
                    self.setupCaptureSession()
                }
            }
            
        case .denied, .restricted:
            // The user has previously denied access; or
            // The user can't grant access due to restrictions.
            fallthrough
            
        @unknown default:
            NSLog("Camera Permissions Error")
            dismiss(animated: true, completion: nil)
        }
    }
    
    func addInputDeviceToSession() {
        captureSession.addInput(input)
    }
    
    func createAndAddPreviewLayer() {
        DispatchQueue.main.async {
            let previewLayer = AVCaptureVideoPreviewLayer(session: self.captureSession)
            previewLayer.frame = UIScreen.main.bounds
            previewLayer.videoGravity = .resizeAspectFill
            previewLayer.isOpaque = true
            self.view.layer.isOpaque = true
            self.view.layer.addSublayer(previewLayer)
        }
    }
    
    func addOutputToInputDevice() {
        let dataOutput = AVCaptureVideoDataOutput()
        dataOutput.alwaysDiscardsLateVideoFrames = true
        dataOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "Video Queue"))
        captureSession.addOutput(dataOutput)
    }
    
    func refocus() {
        do {
            try device.lockForConfiguration()
            device.focusMode = .autoFocus
        } catch {
            print(error)
        }
    }
    
    func addScanControlsAndIndicators() {
        addCornerClips()
        addScanYourCardToProceedLabel()
        addNavigationBar()
    }
    
    func addCornerClips() {
        DispatchQueue.main.async {
            let cornerClipsView = CornerClipsView()
            cornerClipsView.backgroundColor = .clear
            cornerClipsView.frame = self.view.frame
            self.view.addSubview(cornerClipsView)
        }
    }
    
    
    func addScanYourCardToProceedLabel() {
        DispatchQueue.main.async {
            let center = self.view.center
            let scanYourCardToProceedLabel = UILabel(
                frame: CGRect(
                    origin: CGPoint(
                        x: center.x - 160,
                        y: center.y - 160
                    ),
                    size: CGSize(
                        width: 320,
                        height: 40
                    )
                )
            )
            
            scanYourCardToProceedLabel.textAlignment = NSTextAlignment.center
            scanYourCardToProceedLabel.text = self.prompt
            scanYourCardToProceedLabel.numberOfLines = 0
            scanYourCardToProceedLabel.font = UIFont.systemFont(ofSize: 16.0, weight: UIFont.Weight.semibold)
            scanYourCardToProceedLabel.textColor = .white
            self.view.addSubview(scanYourCardToProceedLabel)
        }
    }
    
    
    func addNavigationBar() {
        DispatchQueue.main.async {
            self.view.addSubview(self.cancelButton)
            self.view.addSubview(self.backButton)
            self.view.addSubview(self.flashButton)
            
        }
    }
    
    lazy var flashButton: UIButton = {
        let device = AVCaptureDevice.default(for: AVMediaType.video)!
        let flashBtn = UIButton(
            frame: CGRect(
                x: self.view.frame.width - (49+16),
                y: 55,
                width: 49,
                height: 49
            )
        )
        
        flashBtn.setImage(
            UIImage(
                named: device.isTorchOn ? "flashOn" : "flashOff"
            ),
            for: .normal
        )
        
        flashBtn.addTarget(
            self,
            action: #selector(selectorFlashLightButton),
            for: .touchUpInside
        )
        
        flashBtn.contentEdgeInsets = UIEdgeInsets(
            top: 0.0,
            left: 0.0,
            bottom: 0.0,
            right: 0.0
        )
        
        return flashBtn
    }()
    
    lazy var backButton: UIButton = {
        let backBtn = UIButton(
            frame: CGRect(
                x: 0,
                y: 55,
                width: 48,
                height: 48
            )
        )
        
        backBtn.setImage(
            UIImage(
                named: "backButton"
            )?.withRenderingMode(.alwaysTemplate),
            for: .normal
        )
        backBtn.tintColor = UIColor.white
        
        backBtn.addTarget(
            self,
            action: #selector(selectorBackButton),
            for: .touchUpInside
        )
        
        backBtn.contentEdgeInsets = UIEdgeInsets(
            top: 0.0,
            left: 0.0,
            bottom: 0.0,
            right: 0.0
        )
        
        return backBtn
    }()
    
    lazy var cancelButton: UIButton = {
        let cancelBtn = UIButton(
            frame: CGRect(
                x: self.view.center.x - (16 + 26),
                y: self.view.frame.height - (61+14+32),
                width: 52+16+16,
                height: 14+16
            )
        )
        
        cancelBtn.backgroundColor = UIColor(hex: "e5f1ff")
        cancelBtn.setTitle("اغلاق", for: .normal)
        cancelBtn.setTitleColor(UIColor(hex: "0075ff"), for: .normal)
        cancelBtn.titleLabel?.font = .systemFont(ofSize: 14)
        
        cancelBtn.layer.cornerRadius = 8
        cancelBtn.layer.masksToBounds = true
        
        
        cancelBtn.addTarget(
            self,
            action: #selector(selectorBackButton),
            for: .touchUpInside
        )
        

        
        return cancelBtn
    }()
    //        cancelBtn.backgroundColor = .orange
            
    //        cancelBtn.contentEdgeInsets = UIEdgeInsets(
    //            top: 16.0,
    //            left: 16.0,
    //            bottom: 16.0,
    //            right: 16.0
    //        )
    
    @objc func selectorFlashLightButton() {
        guard let device = AVCaptureDevice.default(for: AVMediaType.video) else {
            return
        }
        
        DispatchQueue.main.async {
            device.toggleTorch()
            self.flashButton.setImage(
                UIImage(named: device.isTorchOn ? "flashOn" : "flashOff"),
                for: .normal
            )
        }
    }
    
    @objc func selectorBackButton() {
        print("button clicked!")
        DispatchQueue.main.async {
            self.dismiss(animated: true, completion: nil)
        }
    }
    
    @objc func selectorCancelButton() {
//        print("button clicked!")
        DispatchQueue.main.async {
            self.dismiss(animated: true, completion: nil)
        }
    }
    
    func addAnimatingScanLine() {
        
        guard let image = UIImage(named: "blueScanLine", in: Bundle(for: SwiftCardScannerPlugin.self), compatibleWith: nil) else {
            return
        }
        
        let blueScanLineImage = UIImageView(image: image)
        
        var center = view.center
        
        for view in view.subviews {
            if let cornerClips = view as? CornerClipsView {
                center = cornerClips.center
            }
        }
        
        blueScanLineImage.frame = CGRect(origin: CGPoint(x: center.x - 160.0, y: center.y - 95.0), size: CGSize(width: 320.0, height: 30.0))
        
        
        
        DispatchQueue.main.async {
            UIView.animate(withDuration: 2.0, delay: 0, options: [.repeat, .autoreverse], animations: {
                blueScanLineImage.frame = CGRect(origin: CGPoint(x: center.x - 160, y:  center.y + 95.0 - 30.0), size: CGSize(width: 320.0, height: 30.0))
            }, completion: nil)
            self.view.addSubview(blueScanLineImage)
        }
    }
    
    public func startScanning() {
        captureSession.startRunning()
    }
    
    public func stopScanning() {
        DispatchQueue.main.async {
            self.device.unlockForConfiguration()
            self.captureSession.stopRunning()
            self.dismiss(animated: true, completion: nil)
        }
    }
}

extension UIColor {
    convenience init(hex: String) {
        var hexFormatted: String = hex.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).uppercased()

        if hexFormatted.hasPrefix("#") {
            hexFormatted = String(hexFormatted.dropFirst())
        }

        assert(hexFormatted.count == 6, "Invalid hex code used.")

        var rgbValue: UInt64 = 0
        Scanner(string: hexFormatted).scanHexInt64(&rgbValue)

        self.init(
            red: CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0,
            green: CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0,
            blue: CGFloat(rgbValue & 0x0000FF) / 255.0,
            alpha: 1.0
        )
    }
}

extension CameraViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let visionImage = VisionImage(buffer: sampleBuffer)
        
        // .right = portrait mode
        // .up = landscapeRight
        visionImage.orientation = orientationForScanning
        
        guard let result = try? textRecognizer.results(in: visionImage) else {
            #if DEBUG
            NSLog("Text Recognizer", "Something went wrong while setting up TextRecognizer")
            #endif
            return
        }
        
        cameraDelegate?.camera(self, didScan: result)
    }
}

// MARK: - Auxilliary methods
extension CameraViewController {
    func vibrateToIndicateTouch() {
        let impactFeedbackgenerator = UIImpactFeedbackGenerator(style: .medium)
        impactFeedbackgenerator.prepare()
        impactFeedbackgenerator.impactOccurred()
    }

    var orientationForScanning: UIImage.Orientation {
        if (cameraOrientation == .landscape) {
            // landscape mode
            return .up
        } else {
            // portrait mode
            return .right
        }
    }
    
    func imageOrientation(
        deviceOrientation: UIDeviceOrientation,
        cameraPosition: AVCaptureDevice.Position
    ) -> UIImage.Orientation {
        switch deviceOrientation {
        case .portrait:
            return cameraPosition == .front ? .leftMirrored : .right
        case .landscapeLeft:
            return cameraPosition == .front ? .downMirrored : .up
        case .portraitUpsideDown:
            return cameraPosition == .front ? .rightMirrored : .left
        case .landscapeRight:
            return cameraPosition == .front ? .upMirrored : .down
        case .faceDown, .faceUp, .unknown:
            return .up
        @unknown default:
            return .up
        }
    }
}

class CornerClipsView: UIView {
    override func draw(_ rect: CGRect) {
        super.draw(rect)
        
        let halfWidth: CGFloat = 160.0
        let halfHeight: CGFloat = 95.0
        let startPoint: CGPoint = CGPoint(x: center.x - halfWidth, y: center.y - halfHeight)
        let endPoint: CGPoint = CGPoint(x: center.x + halfWidth, y: center.y + halfHeight)
        let corner = 6.75/2
        
        
        let leftTopCorner: CGPoint = startPoint
        let rightTopCorner: CGPoint = CGPoint(x: endPoint.x, y: startPoint.y)
        let leftBottomCorner: CGPoint = CGPoint(x: startPoint.x, y: endPoint.y)
        let rightBottomCorner: CGPoint = endPoint
        
        guard let ctx  = UIGraphicsGetCurrentContext() else {
            return
        }
        //카드 이외에 구역 어둡게하는 코드
        let backgroundColor = UIColor.black.withAlphaComponent(0.6)
        let card = CGRect(x: leftTopCorner.x, y: leftTopCorner.y, width: 320.0, height: 190.0)
    
        backgroundColor.setFill()
        UIRectFill(rect)

        let path = UIBezierPath(roundedRect: card, cornerRadius: 0)

        let holeRectIntersection = rect.intersection(card)

        UIRectFill(holeRectIntersection)

        UIColor.clear.setFill()
        UIGraphicsGetCurrentContext()?.setBlendMode(CGBlendMode.copy)
        path.fill()
        //여기까지가 어둡게하는 코드
        
        var blue = UIColor(red: 0.0/255.0, green: 119.0/255.0, blue: 255.0/255.0, alpha: 1.0)
        
        ctx.setLineWidth(6.75)
        ctx.setStrokeColor(blue.cgColor)
        
        ctx.move(to: CGPoint(x: leftTopCorner.x - corner, y: leftTopCorner.y))
        ctx.addLine(to: CGPoint(x: leftTopCorner.x + 30, y: leftTopCorner.y))
        ctx.move(to: CGPoint(x: leftTopCorner.x, y: leftTopCorner.y - corner))
        ctx.addLine(to: CGPoint(x: leftTopCorner.x, y: leftTopCorner.y + 30))
        
        ctx.move(to: CGPoint(x: leftBottomCorner.x - corner, y: leftBottomCorner.y))
        ctx.addLine(to: CGPoint(x: leftBottomCorner.x + 30, y: leftBottomCorner.y))
        ctx.move(to: CGPoint(x: leftBottomCorner.x, y: leftBottomCorner.y + corner))
        ctx.addLine(to: CGPoint(x: leftBottomCorner.x, y: leftBottomCorner.y - 30))
        
        ctx.move(to: CGPoint(x: rightTopCorner.x + corner, y: rightTopCorner.y))
        ctx.addLine(to: CGPoint(x: rightTopCorner.x - 30, y: rightTopCorner.y))
        ctx.move(to: CGPoint(x: rightTopCorner.x, y: rightTopCorner.y - corner))
        ctx.addLine(to: CGPoint(x: rightTopCorner.x, y: rightTopCorner.y + 30))
        
        ctx.move(to: CGPoint(x: rightBottomCorner.x + corner, y: rightBottomCorner.y))
        ctx.addLine(to: CGPoint(x: rightBottomCorner.x - 30, y: rightBottomCorner.y))
        ctx.move(to: CGPoint(x: rightBottomCorner.x, y: rightBottomCorner.y + corner))
        ctx.addLine(to: CGPoint(x: rightBottomCorner.x, y: rightBottomCorner.y - 30))
        
        ctx.strokePath()
    }
}

extension AVCaptureDevice {
    var isLocked: Bool {
        do {
            try lockForConfiguration()
            return true
        } catch {
            print(error)
            return false
        }
    }
    
    func toggleTorch() {
        guard hasTorch && isLocked else { return }
        
        defer { unlockForConfiguration() }
        
        if torchMode == .off {
            torchMode = .on
        }  else {
            torchMode = .off
        }
    }
    
    var isTorchOn: Bool {
        return torchMode == .on
    }
}

