import HaishinKit
import AVFoundation
import VideoToolbox
import SwiftUI
import PhotosUI
import Combine
import Logboard

final class ExampleRecorderDelegate: DefaultAVRecorderDelegate {
    static let `default` = ExampleRecorderDelegate()
    
    override func didFinishWriting(_ recorder: AVRecorder) {
        guard let writer: AVAssetWriter = recorder.writer else {
            return
        }
        PHPhotoLibrary.shared().performChanges({() -> Void in
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: writer.outputURL)
        }, completionHandler: { _, error -> Void in
            do {
                try FileManager.default.removeItem(at: writer.outputURL)
            } catch {
                print(error)
            }
        })
    }
}

final class ViewModel: ObservableObject {
    let maxRetryCount: Int = 5
    
    private var rtmpConnection = RTMPConnection()
    @Published var rtmpStream: RTMPStream!
    private var sharedObject: RTMPSharedObject!
    private var currentEffect: VideoEffect?
    @Published var currentPosition: AVCaptureDevice.Position = .back
    private var retryCount: Int = 0
    @Published var published: Bool = false
    @Published var zoomLevel: CGFloat = 1.0
    @Published var videoRate: CGFloat = 160.0
    @Published var audioRate: CGFloat = 32.0
    @Published var fps: String = "FPS"
    private var nc = NotificationCenter.default
    
    var subscriptions = Set<AnyCancellable>()
    
    var frameRate: String = "30.0" {
        willSet {
            rtmpStream.captureSettings[.fps] = Float(newValue)
            objectWillChange.send()
        }
    }
    
    var videoEffect: String = "None" {
        willSet {
            if let currentEffect: VideoEffect = currentEffect {
                _ = rtmpStream.unregisterVideoEffect(currentEffect)
            }
            
            switch newValue {
            case "Monochrome":
                currentEffect = MonochromeEffect()
                _ = rtmpStream.registerVideoEffect(currentEffect!)
                
            case "Pronoma":
                print("case Pronoma")
                currentEffect = PronamaEffect()
                _ = rtmpStream.registerVideoEffect(currentEffect!)
                
            default: break
            }
            
            objectWillChange.send()
        }
    }
    
    var videoEffectData = ["None", "Monochrome", "Pronoma"]

    var frameRateData = ["15.0", "30.0", "60.0"]

    func config() {
        rtmpStream = RTMPStream(connection: rtmpConnection)
        if let orientation = DeviceUtil.videoOrientation(by: UIDevice.current.orientation) {
            rtmpStream.orientation = orientation
        }
        rtmpStream.captureSettings = [
            .sessionPreset: AVCaptureSession.Preset.hd1280x720,
            .continuousAutofocus: true,
            .continuousExposure: true
            // .preferredVideoStabilizationMode: AVCaptureVideoStabilizationMode.auto
        ]
        rtmpStream.videoSettings = [
            .width: 720,
            .height: 1280
        ]
        rtmpStream.mixer.recorder.delegate = ExampleRecorderDelegate.shared
        
        nc.publisher(for: UIDevice.orientationDidChangeNotification, object: nil)
            .sink { [weak self] _ in
                guard let orientation = DeviceUtil.videoOrientation(by: UIDevice.current.orientation), let self = self else {
                    return
                }
                self.rtmpStream.orientation = orientation
            }
            .store(in: &subscriptions)
        
        checkDeviceAuthorization()
    }
    
    func checkDeviceAuthorization() {
        let requiredAccessLevel: PHAccessLevel = .readWrite
        PHPhotoLibrary.requestAuthorization(for: requiredAccessLevel) { authorizationStatus in
            switch authorizationStatus {
            case .limited:
                logger.info("limited authorization granted")
            case .authorized:
                logger.info("authorization granted")
            default:
                //FIXME: Implement handling for all authorizationStatus
                logger.info("Unimplemented")
            }
        }
    }
    
    func registerForPublishEvent() {
        rtmpStream.attachAudio(AVCaptureDevice.default(for: .audio)) { error in
            logger.error(error.description)
        }
        
        rtmpStream.attachCamera(DeviceUtil.device(withPosition: currentPosition)) { error in
            logger.error(error.description)
        }
                
        rtmpStream.publisher(for: \.currentFPS)
            .sink { [weak self] currentFPS in
                guard let self = self else { return }
                logger.info(">>> currentFPS", currentFPS)
                DispatchQueue.main.async {
                    self.fps = self.published == true ? "\(currentFPS)" : "FPS"
                }
            }
            .store(in: &subscriptions)
        
        nc.publisher(for: AVAudioSession.interruptionNotification, object: nil)
            .sink { notification in
                logger.info(notification)
            }
            .store(in: &subscriptions)
        
        nc.publisher(for: AVAudioSession.routeChangeNotification, object: nil)
            .sink { notification in
                logger.info(notification)
            }
            .store(in: &subscriptions)
    }
    
    func unregisterForPublishEvent() {
        rtmpStream.close()
    }
    
    func startPublish() {
        UIApplication.shared.isIdleTimerDisabled = true
        logger.info(Preference.defaultInstance.uri!)
        
        rtmpConnection.addEventListener(.rtmpStatus, selector: #selector(rtmpStatusHandler), observer: self)
        rtmpConnection.addEventListener(.ioError, selector: #selector(rtmpErrorHandler), observer: self)
        rtmpConnection.connect(Preference.defaultInstance.uri!)
    }
    
    func stopPublish() {
        UIApplication.shared.isIdleTimerDisabled = false
        rtmpConnection.close()
        rtmpConnection.removeEventListener(.rtmpStatus, selector: #selector(rtmpStatusHandler), observer: self)
        rtmpConnection.removeEventListener(.ioError, selector: #selector(rtmpErrorHandler), observer: self)
    }
    
    func toggleTorch() {
        rtmpStream.torch.toggle()
    }
    
    func pausePublish() {
        rtmpStream.paused.toggle()
    }
    
    func tapScreen(touchPoint: CGPoint) {
        let pointOfInterest = CGPoint(x: touchPoint.x / UIScreen.main.bounds.size.width, y: touchPoint.y / UIScreen.main.bounds.size.height)
        logger.info("pointOfInterest: \(pointOfInterest)")
        rtmpStream.setPointOfInterest(pointOfInterest, exposure: pointOfInterest)
    }
    
    func rotateCamera() {
        let position: AVCaptureDevice.Position = currentPosition == .back ? .front : .back
        rtmpStream.captureSettings[.isVideoMirrored] = position == .front
        rtmpStream.attachCamera(DeviceUtil.device(withPosition: position)) { error in
            logger.error(error.description)
        }
        currentPosition = position
    }
    
    func changeZoomLevel(level: CGFloat) {
        rtmpStream.setZoomFactor(level, ramping: true, withRate: 5.0)
    }
    
    func changeVideoRate(level: CGFloat) {
        rtmpStream.videoSettings[.bitrate] = level * 1000
    }
    
    func changeAudioRate(level: CGFloat) {
        rtmpStream.audioSettings[.bitrate] = level * 1000
    }
    
    @objc
    private func rtmpStatusHandler(_ notification: Notification) {
        let e = Event.from(notification)
        guard let data: ASObject = e.data as? ASObject, let code: String = data["code"] as? String else {
            return
        }
       print(code)
        switch code {
        case RTMPConnection.Code.connectSuccess.rawValue:
            retryCount = 0
            rtmpStream.publish(Preference.defaultInstance.streamName!)
            // sharedObject!.connect(rtmpConnection)
        case RTMPConnection.Code.connectFailed.rawValue, RTMPConnection.Code.connectClosed.rawValue:
            guard retryCount <= maxRetryCount else {
                return
            }
            Thread.sleep(forTimeInterval: pow(2.0, Double(retryCount)))
            rtmpConnection.connect(Preference.defaultInstance.uri!)
            retryCount += 1
        default:
            break
        }
    }
    
    @objc
    private func rtmpErrorHandler(_ notification: Notification) {
        logger.error(notification)
        rtmpConnection.connect(Preference.defaultInstance.uri!)
    }
}
