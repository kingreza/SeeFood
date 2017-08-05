//
//  FrameExtractor.swift
//  Created by Bobo on 29/12/2016.
//

import UIKit
import AVFoundation

protocol FrameExtractorDelegate: class {
  func captured(image: UIImage)
}

class FrameExtractor: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
  
  private var position = AVCaptureDevice.Position.back
  private let quality = AVCaptureSession.Preset.medium
  
  private var permissionGranted = false
  private let sessionQueue = DispatchQueue(label: "session queue")
  private let captureSession = AVCaptureSession()
  private let context = CIContext()
  
  weak var delegate: FrameExtractorDelegate?
  
  override init() {
    super.init()
    checkPermission()
    sessionQueue.async { [unowned self] in
      self.configureSession()
      self.captureSession.startRunning()
    }
  }
  
  public func flipCamera() {
    sessionQueue.async { [unowned self] in
      self.captureSession.beginConfiguration()
      guard let currentCaptureInput = self.captureSession.inputs.first else { return }
      self.captureSession.removeInput(currentCaptureInput)
      guard let currentCaptureOutput = self.captureSession.outputs.first else { return }
      self.captureSession.removeOutput(currentCaptureOutput)
      self.position = self.position == .front ? .back : .front
      self.configureSession()
      self.captureSession.commitConfiguration()
    }
  }
  
  // MARK: AVSession configuration
  private func checkPermission() {
    switch AVCaptureDevice.authorizationStatus(for: AVMediaType.video) {
    case .authorized:
      permissionGranted = true
    case .notDetermined:
      requestPermission()
    default:
      permissionGranted = false
    }
  }
  
  private func requestPermission() {
    sessionQueue.suspend()
    AVCaptureDevice.requestAccess(for: AVMediaType.video) { [unowned self] granted in
      self.permissionGranted = granted
      self.sessionQueue.resume()
    }
  }
  
  private func configureSession() {
    guard permissionGranted else { return }
    captureSession.sessionPreset = quality
    guard let captureDevice = selectCaptureDevice() else { return }
    guard let captureDeviceInput = try? AVCaptureDeviceInput(device: captureDevice) else { return }
    guard captureSession.canAddInput(captureDeviceInput) else { return }
    captureSession.addInput(captureDeviceInput)
    let videoOutput = AVCaptureVideoDataOutput()
    videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "sample buffer"))
    guard captureSession.canAddOutput(videoOutput) else { return }
    captureSession.addOutput(videoOutput)
    guard let connection = videoOutput.connection(with: AVFoundation.AVMediaType.video) else { return }
    guard connection.isVideoOrientationSupported else { return }
    guard connection.isVideoMirroringSupported else { return }
    connection.videoOrientation = .portrait
    connection.isVideoMirrored = position == .front
  }
  
  private func selectCaptureDevice() -> AVCaptureDevice? {
    return AVCaptureDevice.default(for: .video)
  }
  
  // MARK: Sample buffer to UIImage conversion
  private func imageFromSampleBuffer(sampleBuffer: CMSampleBuffer) -> UIImage? {
    guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }
    let ciImage = CIImage(cvPixelBuffer: imageBuffer)
    guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return nil }
    return UIImage(cgImage: cgImage)
  }
  
  // MARK: AVCaptureVideoDataOutputSampleBufferDelegate
  func captureOutput(_ captureOutput: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
    guard let uiImage = imageFromSampleBuffer(sampleBuffer: sampleBuffer) else { return }
    DispatchQueue.main.async { [unowned self] in
      self.delegate?.captured(image: uiImage)
    }
  }
}

