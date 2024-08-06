/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Contains the main app implementation using Vision.
*/

import Photos
import UIKit
import Vision
import AVFoundation
import ARKit
import CoreBluetooth
import SwiftUI
import Charts


enum SessionState {
    case camera
    case ar
    case displayImage
}

enum ARObjects { // what we're displaying in the view
    case numbers
    case tempMap
    case blobNodes
    case tempGraph
    case humGraph
    case proxGraph
}

//// SwiftUI view that represents the chart
struct TemperatureChartView: View {
    var data: [Float]

    var body: some View {
        Text ("Temperature")
            .foregroundColor(.black)
        Chart {
            ForEach(Array(data.enumerated()), id: \.offset) { index, value in
                LineMark(
                    x: .value("Time", index),
                    y: .value("Temperature", value-5)
                )
                .foregroundStyle(Color.red)
                .lineStyle(StrokeStyle(lineWidth: 8))
            }
        }
        .chartYScale(domain: 0 ... 40)
        .frame(width: 500, height: 500)
        .chartXAxis {
            AxisMarks(preset: .aligned) {
                AxisGridLine().foregroundStyle(.black)
                AxisTick().foregroundStyle(.black)
                AxisValueLabel().foregroundStyle(.black).font(.system(size: 12, weight: .bold))
            }
        }
        .chartYAxis {
            AxisMarks(preset: .aligned) {
                AxisGridLine().foregroundStyle(.black)
                AxisTick().foregroundStyle(.black)
                AxisValueLabel().foregroundStyle(.black).font(.system(size: 12, weight: .bold))
            }
        }
    }
}

struct HumidityChartView: View {
    var data: [Float]

    var body: some View {
        Text ("Humidity")
            .foregroundColor(.black)
        Chart {
            ForEach(Array(data.enumerated()), id: \.offset) { index, value in
                LineMark(
                    x: .value("Time", index),
                    y: .value("Humidity", value)
                )
                .foregroundStyle(Color.red)
                .lineStyle(StrokeStyle(lineWidth: 8))
            }
        }
        .chartYScale(domain: 0 ... 60)
        .frame(width: 500, height: 500)
        .chartXAxis {
            AxisMarks(preset: .aligned) {
                AxisGridLine().foregroundStyle(.black)
                AxisTick().foregroundStyle(.black)
                AxisValueLabel().foregroundStyle(.black).font(.system(size: 12, weight: .bold))
            }
        }
        .chartYAxis {
            AxisMarks(preset: .aligned) {
                AxisGridLine().foregroundStyle(.black)
                AxisTick().foregroundStyle(.black)
                AxisValueLabel().foregroundStyle(.black).font(.system(size: 12, weight: .bold))
            }
        }
    }
}

struct ProximityChartView: View {
    var data: [Float]

    var body: some View {
        
        Text ("Proximity")
            .foregroundColor(.black)
        Chart {
            ForEach(Array(data.enumerated()), id: \.offset) { index, value in
                LineMark(
                    x: .value("Time", index),
                    y: .value("Proximity", value)
                )
                .foregroundStyle(Color.red)
                .lineStyle(StrokeStyle(lineWidth: 8))
            }
        }
        .chartYScale(domain: 0 ... 255)
        .frame(width: 300, height: 300)
        .chartXAxis {
            AxisMarks(preset: .aligned) {
                AxisGridLine().foregroundStyle(.black)
                AxisTick().foregroundStyle(.black)
                AxisValueLabel().foregroundStyle(.black).font(.system(size: 12, weight: .bold))
            }
        }
        .chartYAxis {
            AxisMarks(preset: .aligned) {
                AxisGridLine().foregroundStyle(.black)
                AxisTick().foregroundStyle(.black)
                AxisValueLabel().foregroundStyle(.black).font(.system(size: 12, weight: .bold))
            }
        }
    }
}

struct MatchedColor {
    var color: UIColor
    var order: Int
}

class CustomSCNNode: SCNNode {
    var order: Int = 0
    
    init(geometry: SCNGeometry? = nil, order: Int) {
        self.order = order
        super.init()
        if let geom = geometry {
            self.geometry = geom
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
}


class ViewController: UIViewController, UINavigationControllerDelegate, AVCaptureVideoDataOutputSampleBufferDelegate, ARSessionDelegate, ARSCNViewDelegate, AVCapturePhotoCaptureDelegate, CBCentralManagerDelegate, CBPeripheralDelegate {

    
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var captureOrResetButton: UIButton!
    @IBOutlet weak var recordColorButton: UIButton!
    @IBOutlet weak var selectNodeButton: UIButton!
    @IBOutlet weak var viewToggleButton: UIButton!
    @IBOutlet weak var nodeID: UITextField!
    @IBOutlet weak var rgbValue: UITextField!
    
    var alert: UIAlertController?
    var captureSession: AVCaptureSession!
    var photoOutput: AVCapturePhotoOutput!
    var previewLayer: AVCaptureVideoPreviewLayer!
    var arSession: ARSession!
    var arView: ARSCNView!
    var ar: SCNScene!
    var arConfiguration: ARWorldTrackingConfiguration!
    var sessionState: SessionState = .camera
    var arObjects: ARObjects = .numbers
    var targetPoint3d: SCNVector3?
    
    var capturedImageView: UIImageView!
    var centerPoints: [CGPoint] = []
    var colors: [(color: UIColor, order: Int)] =     [(UIColor(red: 1, green: 0, blue: 0, alpha: 1), 1),
                                                      (UIColor(red: 1, green: 42/255, blue: 0, alpha: 1), 3)]
//    [(UIColor(red: 1, green: 0, blue: 0, alpha: 1), 23),
//                                                  (UIColor(red: 1, green: 0.67, blue: 0, alpha: 1), 22),
//                                                  (UIColor(red: 0.67, green: 1, blue: 0, alpha: 1), 21),
//                                                  (UIColor(red: 0, green: 1, blue: 0, alpha: 1), 20),
//                                                  (UIColor(red: 0, green: 1, blue: 0.67, alpha: 1), 28),
//                                                  (UIColor(red: 0, green: 0.67, blue: 1, alpha: 1), 27),
//                                                  (UIColor(red: 0, green: 0, blue: 1, alpha: 1), 26),
//                                                  (UIColor(red: 0.67, green: 0, blue: 1, alpha: 1), 25),
//                                                  (UIColor(red: 1, green: 0, blue: 0.67, alpha: 1), 24)]
    var colorOrderIndex: Int = 0
    
    var priorityNode = 1
    
    var textNodes: [CustomSCNNode] = []
    var latestDataForNodes: [Int: [String: Float]] = [:]
    var selectedOptions: [String] = [] // what info to display
    
    var temps: [Int: Float] = [:]
    var tempMapNodes: [Int: SCNNode] = [:]
    
    var showingBlob: [Int: Bool] = [20: false, 21: false, 22: false, 23: false, 24: false, 25: false, 26: false, 27: false]
    var pastThresholdInLastStep: [Int: Bool] = [20: false, 21: false, 22: false, 23: false, 24: false, 25: false, 26: false, 27: false]
    var tempBlobNodes: [Int: SCNNode] = [:]
    var humBlobNodes: [Int: SCNNode] = [:]
    
    
    var tempGraphNodes: [Int: SCNNode] = [:]
    var humGraphNodes: [Int: SCNNode] = [:]
    var proxGraphNodes: [Int: SCNNode] = [:]
    var tempData: [Int: [Float]] = [:]
    var proxData: [Int: [Float]] = [:]
    var humData: [Int: [Float]] = [:]
    var ticksSinceUpdate: [Int: Int] = [:]
    let maxDataPoints = 50
    let graphWidth: CGFloat = 2.0
    let graphHeight: CGFloat = 1.0
    var minMaxValues: (min: Float, max: Float) = (0,0)
    
    var nodePositions: [[(position: SCNVector3, deviceID: Int)]] = Array(repeating: Array(repeating: (position: SCNVector3(), deviceID: -1), count: 3), count: 3)
    var nodeIndices = [(Int, Int)]() // To keep track of indices in a list
    
    var updateTimer: Timer?
    
    //for bluetooth
    // Central manager and peripheral variables
    var centralManager: CBCentralManager!
    var bluefruitPeripheral: CBPeripheral?
    

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Initialize the central manager
        centralManager = CBCentralManager(delegate: self, queue: nil)

        
        // Check if Bluetooth is available
        if centralManager.state == .poweredOn {
            centralManager.scanForPeripherals(withServices: nil, options: nil)
        } else {
            print("Bluetooth is not available.")
        }
        
        // App functionality setup
        requestCameraAccess()
        setupARSession()
        setupCameraSession()
        setupCapturedImageView()
        switchToARFeed()
        captureOrResetButton.addTarget(self, action: #selector(captureOrResetAction), for: .touchUpInside)
        recordColorButton.addTarget(self, action: #selector(recordColor), for: .touchUpInside)
        viewToggleButton.addTarget(self, action: #selector(toggleView), for: .touchUpInside)
        viewToggleButton.isHidden = true
        selectNodeButton.addTarget(self, action: #selector(selectNode), for: .touchUpInside)
        rgbValue.keyboardType = .numbersAndPunctuation
        
        if #available(iOS 17.0, *) {
            let menuItems = [
                UIAction(title: "Temperature", handler: { _ in self.toggleOption("Temperature") }),
                UIAction(title: "Pressure", handler: { _ in self.toggleOption("Pressure") }),
                UIAction(title: "Humidity", handler: { _ in self.toggleOption("Humidity") }),
                UIAction(title: "Proximity", handler: { _ in self.toggleOption("Proximity") }),
                UIAction(title: "Ambient light", handler: { _ in self.toggleOption("Ambient light") }),
                UIAction(title: "RGB light", handler: { _ in self.toggleOption("RGB light") }),
                UIAction(title: "Quaternion", handler: { _ in self.toggleOption("Quaternion") }),
                UIAction(title: "Acceleration", handler: { _ in self.toggleOption("Acceleration") }),
                UIAction(title: "Magnet", handler: { _ in self.toggleOption("Magnet") })
            ]

            let menu = UIMenu(title: "Options", children: menuItems)
            let menuButton = UIBarButtonItem(title: "Menu", menu: menu)
            navigationItem.rightBarButtonItem = menuButton
        } else {
            alert = UIAlertController(title: "Select Options", message: nil, preferredStyle: .actionSheet)
            let menuItems = [
                UIAlertAction(title: "Temperature", style: .default, handler: { _ in self.toggleOption("Temperature") }),
                UIAlertAction(title: "Pressure", style: .default, handler: { _ in self.toggleOption("Pressure") }),
                UIAlertAction(title: "Humidity", style: .default, handler: { _ in self.toggleOption("Humidity") }),
                UIAlertAction(title: "Proximity", style: .default, handler: { _ in self.toggleOption("Proximity") }),
                UIAlertAction(title: "Ambient light", style: .default, handler: { _ in self.toggleOption("Ambient light") }),
                UIAlertAction(title: "RGB light", style: .default, handler: { _ in self.toggleOption("RGB light") }),
                UIAlertAction(title: "Quaternion", style: .default, handler: { _ in self.toggleOption("Quaternion") }),
                UIAlertAction(title: "Acceleration", style: .default, handler: { _ in self.toggleOption("Acceleration") }),
                UIAlertAction(title: "Magnet", style: .default, handler: { _ in self.toggleOption("Magnet") })
            ]
            menuItems.forEach { alert!.addAction($0) }
            alert!.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
            
            let menuButton = UIBarButtonItem(title: "Menu", style: .plain, target: self, action: #selector(showAlertMenu(_:)))
            navigationItem.rightBarButtonItem = menuButton
        }
        
        
    }

    @objc func showAlertMenu(_ sender: UIBarButtonItem) {
        if let alert = alert {
            present(alert, animated: true, completion: nil)
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let imageFrame = imageView.frame
        previewLayer.frame = imageFrame
        arView.frame = imageFrame
        capturedImageView.frame = imageFrame
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        updateTimer?.invalidate()
    }
    
    func toggleOption(_ option: String) {
        
        if let index = selectedOptions.firstIndex(of: option) {
            selectedOptions.remove(at: index)
            
            //
        } else {
            selectedOptions.append(option)
            
        }
//        print("toggled \(option) now displaying \(selectedOptions)")
        DispatchQueue.main.async {
            self.updateViewableParameters()
        }

    }

    func showCameraAccessDeniedAlert() {
        let alert = UIAlertController(title: "Camera Access Denied",
                                      message: "Please enable camera access in Settings to use this feature.",
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        alert.addAction(UIAlertAction(title: "Settings", style: .default) { _ in
            if let appSettings = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(appSettings, options: [:], completionHandler: nil)
            }
        })
        present(alert, animated: true, completion: nil)
    }
    
    func requestCameraAccess() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupCameraSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted {
                    DispatchQueue.main.async {
                        self.setupCameraSession()
                    }
                } else {
                    self.showCameraAccessDeniedAlert()
                }
            }
        case .denied, .restricted:
            showCameraAccessDeniedAlert()
        @unknown default:
            fatalError("Unhandled case in camera authorization status")
        }
    }
    
    func setupARSession() {
        let imageFrame = imageView.frame
        arView = ARSCNView(frame: imageFrame)
        arSession = ARSession()
        arSession.delegate = self
        arView.session = arSession
        arView.session.delegate = self
        view.addSubview(arView)
        arView.isHidden = true
        arConfiguration = ARWorldTrackingConfiguration()
        arConfiguration.planeDetection = [.horizontal, .vertical]
    }
    
    func setupCameraSession() {
        print("setting up camera session")
        captureSession = AVCaptureSession()
        captureSession.beginConfiguration()
        
        var videoDevice: AVCaptureDevice?
        
        do {
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
                throw NSError(domain: "AVFoundationErrorDomain", code: -1, userInfo: [NSLocalizedDescriptionKey: "No video device available."])
            }
            
            videoDevice = device
            
            let videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice!)
            if captureSession.canAddInput(videoDeviceInput) {
                captureSession.addInput(videoDeviceInput)
            } else {
                throw NSError(domain: "AVFoundationErrorDomain", code: -1, userInfo: [NSLocalizedDescriptionKey: "Cannot add video device input."])
            }
            
            let videoDataOutput = AVCaptureVideoDataOutput()
            videoDataOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
            videoDataOutput.alwaysDiscardsLateVideoFrames = true
            
            if captureSession.canAddOutput(videoDataOutput) {
                captureSession.addOutput(videoDataOutput)
            } else {
                throw NSError(domain: "AVFoundationErrorDomain", code: -1, userInfo: [NSLocalizedDescriptionKey: "Cannot add video data output."])
            }
            
            photoOutput = AVCapturePhotoOutput()
            if captureSession.canAddOutput(photoOutput) {
                captureSession.addOutput(photoOutput)
            } else {
                throw NSError(domain: "AVFoundationErrorDomain", code: -1, userInfo: [NSLocalizedDescriptionKey: "Cannot add photo output."])
            }
            
            previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
            previewLayer.frame = imageView.frame
            previewLayer.videoGravity = .resizeAspectFill
            imageView.layer.addSublayer(previewLayer)
            
            captureSession.commitConfiguration()
        } catch let error {
            print("Error setting up camera session: \(error.localizedDescription)")
            presentAlert("Camera Session Error", error: error as NSError)
        }
        setExposureForCameraSession()
    }
    
    func setupCapturedImageView() {
        capturedImageView = UIImageView(frame: imageView.frame)
        capturedImageView.contentMode = .scaleAspectFit
        capturedImageView.isHidden = true
        view.addSubview(capturedImageView)
    }
    
    func setExposureForCameraSession() {
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            print("No video device available.")
            return
        }
        
        do {
            try videoDevice.lockForConfiguration()
            
            videoDevice.exposureMode = .continuousAutoExposure
            
            videoDevice.setExposureTargetBias(-6.0, completionHandler: nil)
            
            videoDevice.unlockForConfiguration()
        } catch {
            print("Error adjusting exposure for camera session: \(error)")
        }
    }
    
    func setExposureForARSession() {
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            print("No video device available.")
            return
        }
        
        do {
            try videoDevice.lockForConfiguration()
            
            // Set the exposure mode to continuous auto exposure for AR session
            videoDevice.exposureMode = .continuousAutoExposure
            videoDevice.setExposureTargetBias(0, completionHandler: nil)
            
            videoDevice.unlockForConfiguration()
        } catch {
            print("Error adjusting exposure for AR session: \(error)")
        }
    }

    @objc func switchToCameraFeed() {
        print("Switching to Camera Feed")
        arView.isHidden = true
        previewLayer.isHidden = false
        capturedImageView.isHidden = true
        viewToggleButton.isHidden = true
        arSession.pause()
        // Run startRunning() on a background thread
        DispatchQueue.global(qos: .userInitiated).async {
            self.captureSession.startRunning()
        }
        
        sessionState = .camera
        
        // Set exposure settings for camera session
        setExposureForCameraSession()
        
        DispatchQueue.main.async {
            self.captureOrResetButton.setTitle("Capture", for: .normal)
        }
    }
    
    @objc func switchToARFeed() {
        print("Switching to AR Feed")
        previewLayer.isHidden = true
        capturedImageView.isHidden = true
        arView.isHidden = false
        viewToggleButton.isHidden = false
        captureSession.stopRunning()
        let arConfiguration = ARWorldTrackingConfiguration()
        arConfiguration.planeDetection = [.horizontal, .vertical]
        arSession.run(arConfiguration)
        sessionState = .ar
        arObjects = .numbers
        
        // Set exposure settings for AR session
        setExposureForARSession()
        
        DispatchQueue.main.async {
            self.captureOrResetButton.setTitle("Reset", for: .normal)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.performHitTestForCenters()
        }
        
    }
    
    @objc func captureOrResetAction() {
        print("calling capture or reset action")
        if sessionState == .camera {
            capturePhoto()
        } else {
            resetARSession()
        }
    }
    
    @objc func selectNode() {
        guard let selectedNode = nodeID.text else {
            return
        }
        
        let selectedNodeID = Int(selectedNode)
         
        if arObjects == .tempGraph {
            for node in tempGraphNodes {
                if node.0 == selectedNodeID {
                    node.1.isHidden = false
                } else {
                    node.1.isHidden = true
                }
            }
        } else if arObjects == .humGraph {
            for node in humGraphNodes {
                if node.0 == selectedNodeID {
                    node.1.isHidden = false
                } else {
                    node.1.isHidden = true
                }
            }
        } else if arObjects == .proxGraph {
            for node in proxGraphNodes {
                if node.0 == selectedNodeID {
                    node.1.isHidden = false
                } else {
                    node.1.isHidden = true
                }
            }
        }
        
        priorityNode = selectedNodeID!
        
        nodeID.text = ""

        view.endEditing(true)
        
        
        
        
    }
    
    @objc func recordColor() {
        guard let rgbText = rgbValue.text else {
            // Handle empty input
            return
        }

        let components = rgbText.split(separator: ",")
        guard components.count == 4,
              let red = Int(components[0].trimmingCharacters(in: .whitespaces)),
              let green = Int(components[1].trimmingCharacters(in: .whitespaces)),
              let blue = Int(components[2].trimmingCharacters(in: .whitespaces)),
              let deviceID = Int(components[3].trimmingCharacters(in: .whitespaces)),
              (0...255).contains(red), (0...255).contains(green), (0...255).contains(blue) else {
            // Handle invalid input (e.g., show an alert)
            print("Invalid RGB input. Please enter values in the format 'R,G,B' where R, G, and B are integers between 0 and 255.")
            return
        }

        // Create a UIColor from the RGB values
        let color = UIColor(red: CGFloat(red) / 255.0, green: CGFloat(green) / 255.0, blue: CGFloat(blue) / 255.0, alpha: 1.0)

        // Append the color and its order to the list
        colors.append((color: color, order: deviceID))
        colorOrderIndex += 1

        // Clear the text field
        rgbValue.text = ""

        // Dismiss the keyboard
        view.endEditing(true)

        print("Recorded color: \(color)")
    }

    @objc func toggleView() {
        print("toggling view")
        if arObjects == .blobNodes {
            
            print("switching to show temp map")
            
            DispatchQueue.main.async {
                self.viewToggleButton.setTitle("show num", for: .normal)
            }
            
            arObjects = .tempMap
            
            // Show text nodes and hide sphere nodes
            for textNode in textNodes {
                textNode.isHidden = true
            }
            for tempGraph in tempGraphNodes {
                tempGraph.1.isHidden = true
            }
            for humGraph in humGraphNodes {
                humGraph.1.isHidden = true
            }
            
            for proxGraph in proxGraphNodes {
                proxGraph.1.isHidden = true
            }
            
            for blobNode in tempBlobNodes {
                blobNode.1.isHidden = true
            }
            
            for blobNode in humBlobNodes {
                blobNode.1.isHidden = true
            }
            
        } else if arObjects == .tempMap {
            
            print("switching to show numbers")
            
            DispatchQueue.main.async {
                self.viewToggleButton.setTitle("show tempGraph", for: .normal)
            }
            
            arObjects = .numbers
            
            // Show text nodes and hide sphere nodes
            for textNode in textNodes {
                textNode.isHidden = false
            }
            for tempGraph in tempGraphNodes {
                tempGraph.1.isHidden = true
            }
            for humGraph in humGraphNodes {
                humGraph.1.isHidden = true
            }
            
            for proxGraph in proxGraphNodes {
                proxGraph.1.isHidden = true
            }
            
        } else if arObjects == .numbers {
            
            print("switching to show tempGraph")
            DispatchQueue.main.async {
                self.viewToggleButton.setTitle("show humGraph", for: .normal)
            }
            arObjects = .tempGraph
            
            // Hide text nodes and show sphere nodes
            for textNode in textNodes {
                textNode.isHidden = true
            }
            for tempGraph in tempGraphNodes {
                if tempGraph.0 == priorityNode{
                    tempGraph.1.isHidden = false
                } else {
                    tempGraph.1.isHidden = true
                }
                
            }
            for humGraph in humGraphNodes {
                humGraph.1.isHidden = true
            }
            
            for proxGraph in proxGraphNodes {
                proxGraph.1.isHidden = true
            }
            
                
        } else if arObjects == .tempGraph {
            print("switching to show humGraph")
            DispatchQueue.main.async {
                self.viewToggleButton.setTitle("show proxGraph", for: .normal)
            }
            arObjects = .humGraph
            
            for textNode in textNodes {
                textNode.isHidden = true
            }
            for tempGraph in tempGraphNodes {
                tempGraph.1.isHidden = true
            }
            for humGraph in humGraphNodes {
                if humGraph.0 == priorityNode{
                    humGraph.1.isHidden = false
                } else {
                    humGraph.1.isHidden = true
                }
                
            }
            
            for proxGraph in proxGraphNodes {
                proxGraph.1.isHidden = true
            }
            
            
        } else if arObjects == .humGraph {
            print("switching to show proxGraph")
            DispatchQueue.main.async {
                self.viewToggleButton.setTitle("show tempBlobs", for: .normal)
            }
            arObjects = .proxGraph
            
            for textNode in textNodes {
                textNode.isHidden = true
            }
            for tempGraph in tempGraphNodes {
                tempGraph.1.isHidden = true
            }
            for humGraph in humGraphNodes {
                humGraph.1.isHidden = true
            }
            
            for proxGraph in proxGraphNodes {
                if proxGraph.0 == priorityNode {
                    proxGraph.1.isHidden = false
                } else {
                    proxGraph.1.isHidden = true
                }
                
            }
            
            
        } else if arObjects == .proxGraph {
            print("switching to show tempBlobs")
            DispatchQueue.main.async {
                self.viewToggleButton.setTitle("show tempGraph", for: .normal)
            }
            arObjects = .blobNodes
            
//            for (num, triggered) in showingBlob {
//                triggered = false
//            }
            
            for textNode in textNodes {
                textNode.isHidden = true
            }
            for tempGraph in tempGraphNodes {
                tempGraph.1.isHidden = true
            }
            for humGraph in humGraphNodes {
                humGraph.1.isHidden = true
            }
            
            for proxGraph in proxGraphNodes {
                proxGraph.1.isHidden = true
            }
            
            for blobNode in tempBlobNodes {
                blobNode.1.isHidden = true
            }
            
            for blobNode in humBlobNodes {
                blobNode.1.isHidden = true
            }
            
            
        }
    }

    // COLOR STUFF and IMAGE STUFF
    
    func rgbToUIColor(red: Int, green: Int, blue: Int) -> UIColor {
        return UIColor(red: CGFloat(red) / 255.0, green: CGFloat(green) / 255.0, blue: CGFloat(blue) / 255.0, alpha: 1.0)
    }
    
    func capturePhoto() {
        let photoSettings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: photoSettings, delegate: self)
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil else {
            print("Error capturing photo: \(error!.localizedDescription)")
            return
        }
        
        guard let imageData = photo.fileDataRepresentation() else {
            print("Error converting photo to data")
            return
        }
        
        guard let image = UIImage(data: imageData) else {
            print("Error creating UIImage from data")
            return
        }
        
        let fixedImage = fixImageOrientation(image: image)
        processCapturedImage(image: fixedImage)
    }
    
    func processCapturedImage(image: UIImage) {
        print("Processing captured image")
        let (processedImage, centerPoints, colorsFromImage, areas) = drawContours(image: image)
        
        if let centers = centerPoints, let detectedColors = colorsFromImage, let areas = areas {
            // tuples of (center, color, area, identifier)
            var contoursData = zip(centers.enumerated(), zip(detectedColors, areas)).map { (indexCenter, colorArea) in
                (index: indexCenter.offset, center: indexCenter.element, color: colorArea.0, area: colorArea.1)
            } // combines all the information into organized tuples
            
            // sort contoursData by area in descending order
            contoursData.sort { $0.area.floatValue > $1.area.floatValue }
            
            // filter out the smallest areas until the number of detected colors equals the number of inputted colors
            while contoursData.count > colors.count {
                contoursData.removeLast()
            } // works up to this point I am certain
            
            // extract the filtered data
            let filteredCenters = contoursData.map { $0.center }
            let filteredColors = contoursData.map { $0.color }
            let filteredAreas = contoursData.map { $0.area } // to be honest I don't need this anymore
            let filteredIdentifiers = contoursData.map { $0.index }
            
            
            // RGB values to UIColor
            let uiColors = filteredColors.map { rgbValues -> UIColor in
                let red = CGFloat(rgbValues[0].floatValue) / 255.0
                let green = CGFloat(rgbValues[1].floatValue) / 255.0
                let blue = CGFloat(rgbValues[2].floatValue) / 255.0
                return UIColor(red: red, green: green, blue: blue, alpha: 1.0)
            }
            
            for (index, center) in filteredCenters.enumerated() {
                let rgbValues = filteredColors[index]
                let color = uiColors[index]
                let area = filteredAreas[index]
                let identifier = filteredIdentifiers[index]
//                print("Stage 1")
//                print("Center: \(center), RGB Values: \(rgbValues), UIColor: \(color), Area: \(area), Identifier: \(identifier)")
            }
            
            // Transform image coordinates to view coordinates
            let transformedCentersWithColorsAndIdentifiers = zip(filteredCenters, zip(uiColors, filteredIdentifiers)).map { (center, colorIdentifier) in
                (transformImagePointToViewPoint(imagePoint: center, imageSize: image.size, viewSize: imageView.frame.size), colorIdentifier.0, colorIdentifier.1)
            }

            // Match detected colors to input colors using brute force search
            let matchedColorsWithOrder = matchToClosestColorsHSL(detectedColors: uiColors, inputColors: colors)
//            print("matchedColorsWithOrder is \(matchedColorsWithOrder)")

            
            // combine the matched colors with their corresponding screen coordinates, identifier, and order
            let transformedCentersWithMatchedColors = zip(transformedCentersWithColorsAndIdentifiers, matchedColorsWithOrder).map { (centerColorIdentifier, matchedColorWithOrder) in
                (centerColorIdentifier.0, matchedColorWithOrder.color, matchedColorWithOrder.order, centerColorIdentifier.2)
            }
            
            // debug
//            for (center, matchedColor, order, identifier) in transformedCentersWithMatchedColors {
//                print("Center: \(center), Matched Color: \(matchedColor), Order: \(order), Identifier: \(identifier)")
//            }

            DispatchQueue.main.async {
                self.capturedImageView.image = processedImage
                self.capturedImageView.isHidden = false
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.switchToARFeed()
                let filteredTransformedCentersWithMatchedColors = transformedCentersWithMatchedColors.map { (center, matchedColor, order, _) in
                    (center, matchedColor, order)
                }
                self.placeObjects(at: filteredTransformedCentersWithMatchedColors)  // Place objects in AR after switching to AR mode
            }

        }
    }

    func matchToClosestColorsHSL(detectedColors: [UIColor], inputColors: [(color: UIColor, order: Int)]) -> [(color: UIColor, order: Int)] {
        guard detectedColors.count <= inputColors.count else {
            print("Error: Not enough input colors for detected colors")
            return [UIColor](repeating: UIColor.clear, count: detectedColors.count).map { (color: $0, order: 0) }
        }

        let detectedHSLColors = detectedColors.map { $0.toHSL() }
        let inputHSLColors = inputColors.map { ($0.color.toHSL(), $0.order) }

        var bestMatch = [(color: UIColor, order: Int)](repeating: (UIColor.clear, 0), count: detectedColors.count)
        var minError = CGFloat.greatestFiniteMagnitude

        func permutation(_ elements: inout [(color: (h: CGFloat, s: CGFloat, l: CGFloat), order: Int)], _ k: Int) {
            if k == 0 {
                let error = detectedHSLColors.enumerated().reduce(0) { (result, tuple) -> CGFloat in
                    let (index, detectedHSLColor) = tuple
                    return result + hslDistance(color1: detectedHSLColor, color2: elements[index].color)
                }
                if error < minError {
                    minError = error
                    bestMatch = elements.prefix(detectedHSLColors.count).map { (color: UIColor(hue: $0.color.h, saturation: $0.color.s, brightness: $0.color.l, alpha: 1.0), order: $0.order) }
                }
                return
            }
            permutation(&elements, k - 1)
            for i in 0..<k {
                elements.swapAt(i, k)
                permutation(&elements, k - 1)
                elements.swapAt(i, k)
            }
        }

        var elements: [(color: (h: CGFloat, s: CGFloat, l: CGFloat), order: Int)] = inputHSLColors
        permutation(&elements, inputHSLColors.count - 1)
        
        for (index, detectedColor) in detectedColors.enumerated() {
            let bestMatchColor = bestMatch[index]
            print("Detected Color: \(detectedColor), Matched Color: \(bestMatchColor.color), Order: \(bestMatchColor.order)")
        }

        return bestMatch
    }

//    func generatePermutations<T>(_ array: [T]) -> [[T]] {
//        if array.count == 1 { return [array] }
//        var result: [[T]] = []
//        for (index, element) in array.enumerated() {
//            var remainingElements = array
//            remainingElements.remove(at: index)
//            let subPermutations = generatePermutations(remainingElements)
//            for subPermutation in subPermutations {
//                result.append([element] + subPermutation)
//            }
//        }
////        print("permutation is", result)
//        return result
//    }
    
    func hslDistance(color1: (h: CGFloat, s: CGFloat, l: CGFloat), color2: (h: CGFloat, s: CGFloat, l: CGFloat)) -> CGFloat {
        let dh = min(abs(color1.h - color2.h), 1.0 - abs(color1.h - color2.h)) * 10.0 // Weight hue more heavily
        let ds = min(abs(color1.s - color2.s), abs(color2.s-color1.s))
        let dl = min(abs(color1.l - color1.l), abs(color2.l-color1.l))
        
        return sqrt(dh * dh + ds * ds + dl * dl)
    }

    // VIEW STUFF
    
    func performHitTestForCenters() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            for center in self.centerPoints {
                self.placeObject(at: center)
            }
        }
    }
    
    func resetARSession() {
        print("Resetting AR session")
        switchToCameraFeed()
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            return
        }
    }
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
//        print("ARFrame updated")
    }
    
    
    //UI
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    func presentAlert(_ title: String, error: NSError) {
        DispatchQueue.main.async {
            let alertController = UIAlertController(title: title,
                                                    message: error.localizedDescription,
                                                    preferredStyle: .alert)
            let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
            alertController.addAction(okAction)
            self.present(alertController, animated: true, completion: nil)
        }
        print("presented an alert")
    }
    
    
    // AR STUFF
    
    func placeObject(at screenCoordinates: CGPoint) {
        // Print the bounds of the ARView
        let arViewBounds = arView.bounds
        print("ARView bounds: \(arViewBounds)")

        // Check if the coordinates are within the bounds of ARView
        guard arViewBounds.contains(screenCoordinates) else {
            print("Coordinates out of ARView bounds: \(screenCoordinates)")
            return
        }
        
        NSLog("Simulated Tap at coordinates: \(screenCoordinates.x), \(screenCoordinates.y)")
        
        let hitTestResults = arView.hitTest(screenCoordinates, types: [.existingPlaneUsingExtent, .estimatedHorizontalPlane, .estimatedVerticalPlane])
        NSLog("number of hit test results: \(hitTestResults.count)")
        
        if hitTestResults.isEmpty {
            print("No hit test results for coordinates: \(screenCoordinates)")
            return
        }
        
        guard let result = hitTestResults.first else {
            print("No valid hit test result found")
            return
        }

        let x = result.worldTransform.columns.3.x
        let y = result.worldTransform.columns.3.y
        let z = result.worldTransform.columns.3.z
        
        let targetPoint3d = SCNVector3(x: x, y: y, z: z)
        NSLog("targetPoint3d x: \(x), y: \(y), z: \(z)")

        let sphereNode = createSphere(at: targetPoint3d, color: UIColor.green)
        arView.scene.rootNode.addChildNode(sphereNode)
    }
    
    func placeObjects(at screenCoordinatesWithColors: [(CGPoint, UIColor, Int)]) {


        for (point, detectedColor, order) in screenCoordinatesWithColors {
            guard arView.bounds.contains(point) else {
                print("Coordinates out of ARView bounds: \(point)")
                continue
            }

            NSLog("Simulated Tap at coordinates: \(point.x), \(point.y)")

            let hitTestResults = arView.hitTest(point, types: [.existingPlaneUsingExtent, .estimatedHorizontalPlane, .estimatedVerticalPlane])
            NSLog("number of hit test results: \(hitTestResults.count)")

            guard let result = hitTestResults.first else {
                print("No hit test results for coordinates: \(point)")
                continue
            }

            let x = result.worldTransform.columns.3.x
            let y = result.worldTransform.columns.3.y
            let z = result.worldTransform.columns.3.z

            let targetPoint3d = SCNVector3(x: x, y: y, z: z)
            NSLog("targetPoint3d x: \(x), y: \(y), z: \(z)")

            let textNode = createTextNode(order: order, text: "waiting to receive data", color: detectedColor, position: targetPoint3d)
            arView.scene.rootNode.addChildNode(textNode)
            textNodes.append(textNode)
//            textNode.isHidden = true
            addChartToARScene(deviceID: order, position: targetPoint3d)
            let spherePosition = SCNVector3(x: targetPoint3d.x, y: targetPoint3d.y, z: targetPoint3d.z - 0.05) // slightly behind the text node
            let sphereNode = createSphere(at: spherePosition, color: colors.first { $0.order == order }?.color ?? UIColor.clear)
            sphereNode.isHidden = true
            arView.scene.rootNode.addChildNode(sphereNode)
            tempBlobNodes[order] = sphereNode
            setupParticleSystem(deviceID: order, position: spherePosition)
            pastThresholdInLastStep[order] = false // used for toggling blob viz on and off
            
    
        }
    }
    
    func setupParticleSystem(deviceID: Int, position: SCNVector3) {
        guard let scene = SCNScene(named: "SceneKit Asset Catalog.scnassets/SceneKit Scene.scn") else {
            fatalError("Failed to load scene")
        }

        guard let particleNode = scene.rootNode.childNode(withName: "particles", recursively: true) else {
            printNodeHierarchy(node: scene.rootNode)
            fatalError("Failed to find particle system node")
        }
        
        if let particleSystem = particleNode.particleSystems?.first {
            // Set particle system properties
            particleSystem.birthRate = 0
            particleSystem.particleColor = UIColor(red: 1, green: 1, blue: 1, alpha: 0.5)
            particleSystem.particleColorVariation = SCNVector4(0.1, 0.1, 0.1, 0.0)
            particleSystem.particleVelocity = 0.1
            particleSystem.particleVelocityVariation = 0.1
            particleSystem.particleSize = 0.03
            particleSystem.particleSizeVariation = 0.01
            let circularParticleImage = createCircularParticleImage(diameter: 50) // Adjust the diameter as needed
            particleSystem.emitterShape = SCNSphere(radius: 0.05)
            particleSystem.particleImage = circularParticleImage
            particleSystem.acceleration = SCNVector3(0, 0.3, 0)
//            particleSystem.emissionDirection = SCNVector3(0, 1, 0) // Emission direction
            particleSystem.spreadingAngle = 5 // Limit the spread angle for a more focused upward movement
        } else {
            print("No particle system found in particle node.")
        }

        
        particleNode.position = position
        particleNode.isHidden = true
        arView.scene.rootNode.addChildNode(particleNode)
        humBlobNodes[deviceID] = particleNode
    }
    
    func createCircularParticleImage(diameter: CGFloat) -> UIImage {
        let size = CGSize(width: diameter, height: diameter)
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        let context = UIGraphicsGetCurrentContext()!

        context.setFillColor(UIColor(white: 1.0, alpha: 0.5).cgColor) // White color with 0.5 alpha for translucency
        context.fillEllipse(in: CGRect(origin: .zero, size: size))

        let image = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()

        return image
    }
    
    func updateParticleSystemBirthrate(deviceID: Int, inputValue: Float, threshold: Float, maxBirthRate: CGFloat) {
        guard let particleNode = humBlobNodes[deviceID], let particleSystem = particleNode.particleSystems?.first else {
            print("Particle system not found for deviceID: \(deviceID)")
            return
        }

        let newBirthRate: CGFloat
        if inputValue < threshold {
            newBirthRate = 0
        } else {
            let slope = maxBirthRate / CGFloat(1 - threshold)
            newBirthRate = abs(slope * CGFloat(inputValue - threshold))
        }

        particleSystem.birthRate = newBirthRate
        print("updated birthrate to \(newBirthRate) for deviceID: \(deviceID) with humidity value \(inputValue)")
    }

    func printNodeHierarchy(node: SCNNode, level: Int = 0) {
        let indent = String(repeating: "  ", count: level)
        print("\(indent)- \(node.name ?? "Unnamed node")")

        for child in node.childNodes {
            printNodeHierarchy(node: child, level: level + 1)
        }
    }

    @objc func updateTextNodes(data: [String: Float]) {
        let num = Int(round(data["deviceID"]!))
        let displayText = createDisplayText(deviceID: num, data: data, selectedOptions: selectedOptions)
        
        for textNode in textNodes {
            if let textGeometry = textNode.geometry as? SCNText {
                if textNode.order == num {
                    textGeometry.string = displayText
                }
            }
        }
    }

    // add update graph functionality
    
    @objc func updateAllNodes() { // this is when we change the settings
        for (deviceID, data) in latestDataForNodes {
            let displayText = createDisplayText(deviceID: deviceID, data: data, selectedOptions: selectedOptions)
            
            for textNode in textNodes {
                if textNode.order == deviceID {
                    if let textGeometry = textNode.geometry as? SCNText {
                        textGeometry.string = displayText
                    }
                }
            }
        }
        
        // Force the AR view to refresh
        arView.scene.rootNode.childNodes.forEach { node in
            node.geometry?.firstMaterial?.diffuse.contents = UIColor.clear
            node.geometry?.firstMaterial?.diffuse.contents = UIColor.white
        }
    }
    
    func updateARContent(data: [String: Float]) {
        updateTextNodes(data: data)
        let deviceID = Int(data["deviceID"]!)
        print("received data from \(deviceID)")
        let prox = data["proximity"]!
        if prox > 40 {
            priorityNode = deviceID
            if arObjects == .proxGraph {
                for tempGraph in tempGraphNodes {
                    tempGraph.1.isHidden = true
                }
                for humGraph in humGraphNodes {
                    humGraph.1.isHidden = true
                }
                
                for proxGraph in proxGraphNodes {
                    if proxGraph.0 == deviceID {
                        proxGraph.1.isHidden = false
                    } else {
                        proxGraph.1.isHidden = true
                    }
                    
                }
            }
            
        }
    
        
        if arObjects == .blobNodes {
            let threshold = 40
            let pastThreshold = Int(data["proximity"]!) > threshold
            
            // if the value was toggled
            if (!pastThresholdInLastStep[deviceID]! && pastThreshold) {
                print("value toggled")
                
                // first, update value for next run
                pastThresholdInLastStep[deviceID] = true
                
                // toggle the data visualization
                if showingBlob[deviceID] ?? false {
                    print("hiding blob \(deviceID)")
                    showingBlob[deviceID] = false
                    tempBlobNodes[deviceID]!.isHidden = true
                    humBlobNodes[deviceID]!.isHidden = true
                } else { // we need to show the blob
                    print("showing blob \(deviceID)")
                    showingBlob[deviceID] = true
                    let roundedTemp = roundToNearestHalf(value: data["temp"]!)
                    temps[deviceID] = roundedTemp
                    tempBlobNodes[deviceID]!.isHidden = false
                    humBlobNodes[deviceID]!.isHidden = false
//                    updateParticleSystemBirthrate(deviceID: deviceID, inputValue: data["hum"]!, threshold: 40, maxBirthRate: 100)
                    updateSphere(deviceID: deviceID, color: mapToColor(value:roundedTemp))
                    return
                }
            } else {
                // update value for next run
                if pastThreshold {
                    pastThresholdInLastStep[deviceID] = true
                } else {
                    pastThresholdInLastStep[deviceID] = false
                }
            }
//            updateParticleSystemBirthrate(deviceID: deviceID, inputValue: data["hum"]!, threshold: 40, maxBirthRate: 200)
            
            let roundedTemp = roundToNearestHalf(value: data["temp"]!)
            if let tempValue = temps[deviceID] {
                if !areFloatsEqual(tempValue, roundedTemp) {
                    temps[deviceID] = roundedTemp
                    updateSphere(deviceID: deviceID, color: mapToColor(value:roundedTemp))
                }
            } else {
                temps[deviceID] = roundedTemp
                updateSphere(deviceID: deviceID, color: mapToColor(value:roundedTemp))
            }
        }
                                
        if Int(data["deviceID"]!) == priorityNode { // priority node is the one we show graphs for
            print("updating priority node with data ", data["ambient"]!)
            updateChart(for: Int(data["deviceID"]!), newTemp: data["temp"]!, newHum: data["hum"]!, newProx: data["proximity"]!)
        }
    }
    
    func areFloatsEqual(_ float1: Float, _ float2: Float, epsilon: Float = 0.00001) -> Bool {
        return abs(float1 - float2) < epsilon
    }
    
    func updateViewableParameters() {
        updateAllNodes()
    }
    
    func createDisplayText(deviceID: Int, data: [String: Float], selectedOptions: [String]) -> String {
        var displayText = "\(deviceID)\n"
        let optionsMap: [String: String] = [
            "Temperature": "temp",
            "Pressure": "pres",
            "Proximity": "proximity",
            "Humidity": "hum",
            "Ambient light": "ambient",
            "RGB light": "RGB",
            "Quaternion": "quat",
            "Acceleration": "accel",
            "Magnet": "magnet"
        ]
        for option in selectedOptions {
            if let key = optionsMap[option], let value = data[key] {
                switch option {
                case "Temperature":
                    displayText += "temperature=\(value)\n"
                case "Pressure":
                    displayText += "pressure=\(value)\n"
                case "Proximity":
                    displayText += "proximity=\(value)\n"
                case "Humidity":
                    displayText += "humidity=\(value)\n"
                case "Ambient light":
                    displayText += "ambient light=\(value)\n"
                case "RGB light":
                    if let red = data["red"], let green = data["green"], let blue = data["blue"] {
                        displayText += "RGB light: R=\(red) G=\(green) B=\(blue)\n"
                    }
                case "Quaternion":
                    if let quat_w = data["quat_w"], let quat_x = data["quat_x"], let quat_y = data["quat_y"], let quat_z = data["quat_z"] {
                        displayText += "quaternion: w=\(quat_w) x=\(quat_x) y=\(quat_y) z=\(quat_z)\n"
                    }
                case "Acceleration":
                    if let accel_x = data["accel_x"], let accel_y = data["accel_y"], let accel_z = data["accel_z"] {
                        displayText += "acceleration: x=\(accel_x) y=\(accel_y) z=\(accel_z)\n"
                    }
                case "Magnet":
                    if let magnet_x = data["magnet_x"], let magnet_y = data["magnet_y"], let magnet_z = data["magnet_z"] {
                        displayText += "magnet: x=\(magnet_x) y=\(magnet_y) z=\(magnet_z)\n"
                    }
                default:
                    break
                }
            }
        }
        return displayText
    }

    
    func roundToNearestHalf(value: Float) -> Float {
        // If the value is below 20, round it to 20
        if value < 20 {
            return 20.0
        } else if value > 30 {
            return 30.0
        } else {
            // Round the value to the nearest 0.5
            return round(value * 4) / 4.0
        }
    }
    
    func mapToColor(value: Float) -> UIColor {
        // Define the start and end colors for the gradient
//        let startColor = UIColor(red: 1.0, green: 1.0, blue: 0.0, alpha: 1.0) // Yellow
//        let endColor = UIColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0) // Red
        let startColor = UIColor(red: 0.01, green: 1.0, blue: 1.0, alpha: 1.0) // Yellow
        let endColor = UIColor(red: 1.0, green: 0.01, blue: 0.01, alpha: 1.0) // Red

        // Assume value is between 0 and 100 for the sake of this example
        // Calculate proportion for the gradient
        let proportion = CGFloat((value - 26) / 5) // Adjust the range as needed

        var startRed: CGFloat = 0
        var startGreen: CGFloat = 0
        var startBlue: CGFloat = 0
        var startAlpha: CGFloat = 0
        startColor.getRed(&startRed, green: &startGreen, blue: &startBlue, alpha: &startAlpha)

        var endRed: CGFloat = 0
        var endGreen: CGFloat = 0
        var endBlue: CGFloat = 0
        var endAlpha: CGFloat = 0
        endColor.getRed(&endRed, green: &endGreen, blue: &endBlue, alpha: &endAlpha)

        let red = startRed + proportion * (endRed - startRed)
        let green = startGreen + proportion * (endGreen - startGreen)
        let blue = startBlue + proportion * (endBlue - startBlue)

        print("mapped color is R\(red) G\(green) B\(blue)")
        return UIColor(red: red, green: green, blue: blue, alpha: 0.8)
    }

    func updateSphere(deviceID: Int, color: UIColor) {
        print("calling update sphere")
        guard let sphereNode = tempBlobNodes[deviceID] else {
            print("can't find sphere node????")
            return
        }
        
        let sphereMaterial = SCNMaterial()
        sphereMaterial.diffuse.contents = color
        tempBlobNodes[deviceID]!.geometry!.materials = [sphereMaterial]
//        sphereNode.isHidden = false
        print("updated sphere \(deviceID)")
    }
    
    func createSphere(at location: SCNVector3, color: UIColor) -> SCNNode {
        let sphereGeometry = SCNSphere(radius: 0.05) // Set the radius as needed
        let sphereMaterial = SCNMaterial()
        sphereMaterial.diffuse.contents = color
        sphereGeometry.materials = [sphereMaterial]

        let sphereNode = SCNNode(geometry: sphereGeometry)
        sphereNode.position = location
        print("created a sphere")
        return sphereNode
    }

    func createTextNode(order: Int, text: String, color: UIColor, position: SCNVector3) -> CustomSCNNode {
        let textGeometry = SCNText(string: text, extrusionDepth: 0.1)
        textGeometry.firstMaterial?.diffuse.contents = color
        textGeometry.font = UIFont.systemFont(ofSize: 1)

        let textNode = CustomSCNNode(geometry: textGeometry, order: order)
        textNode.position = position

        // Adjust the text node's orientation and size
        let (min, max) = textGeometry.boundingBox
        let dx = min.x + 0.5 * (max.x - min.x)
        let dy = min.y + 0.5 * (max.y - min.y)
        let dz = min.z + 0.5 * (max.z - min.z)
        textNode.pivot = SCNMatrix4MakeTranslation(dx, dy, dz)
        textNode.scale = SCNVector3(0.005, 0.005, 0.005)

        return textNode
    }

    func addChartToARScene(deviceID: Int, position: SCNVector3) {
        
        tempData[deviceID] = [0]
        humData[deviceID] = [0]
        proxData[deviceID] = [0]
        
        let tempChartImage = imageFromSwiftUIView(TemperatureChartView(data: tempData[deviceID]!))
        let humChartImage = imageFromSwiftUIView(HumidityChartView(data: humData[deviceID]!))
        let proxChartImage = imageFromSwiftUIView(ProximityChartView(data: proxData[deviceID]!))


        // Create an SCNPlane with the image as its texture
        let plane = SCNPlane(width: 0.3, height: 0.3) // Adjust size as needed
        let material = SCNMaterial()
        material.diffuse.contents = tempChartImage
        plane.materials = [material]

        // Create an SCNNode with the plane geometry
        let tempChartNode = SCNNode(geometry: plane)
        tempChartNode.position = position // Adjust position as needed

        // Add the chart node to the AR scene
        arView.scene.rootNode.addChildNode(tempChartNode)
        tempGraphNodes[deviceID] = tempChartNode
        tempChartNode.isHidden = true
        

        material.diffuse.contents = humChartImage
        plane.materials = [material]

        // Create an SCNNode with the plane geometry
        let humChartNode = SCNNode(geometry: plane)
        humChartNode.position = position // Adjust position as needed

        // Add the chart node to the AR scene
        arView.scene.rootNode.addChildNode(humChartNode)
        humGraphNodes[deviceID] = humChartNode
        humChartNode.isHidden = true
        
        material.diffuse.contents = proxChartImage
        plane.materials = [material]

        // Create an SCNNode with the plane geometry
        let proxChartNode = SCNNode(geometry: plane)
        proxChartNode.position = position // Adjust position as needed

        // Add the chart node to the AR scene
        arView.scene.rootNode.addChildNode(proxChartNode)
        proxGraphNodes[deviceID] = proxChartNode
        proxChartNode.isHidden = true
        
        

        ticksSinceUpdate[deviceID] = 0
    }

    func imageFromSwiftUIView<T: View>(_ view: T) -> UIImage {
        let controller = UIHostingController(rootView: view)
        let view = controller.view

        // Set the size of the hosting controller's view
        let targetSize = CGSize(width: 300, height: 300)
        view?.bounds = CGRect(origin: .zero, size: targetSize)
        view?.backgroundColor = .clear

        // Render the view to an image
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { context in
            view?.drawHierarchy(in: view!.bounds, afterScreenUpdates: true)
        }
    }
    
    func updateChart(for deviceID: Int, newTemp: Float, newHum: Float, newProx: Float) {
        
        if arObjects == .tempGraph {
            
            guard var tempPoints = tempData[deviceID] else { return }
            // Shift data points to the left and append the new value
            tempPoints.append(newTemp)
            if tempPoints.count > 100 {
                tempPoints.removeFirst()
            }
            tempData[deviceID] = tempPoints
            ticksSinceUpdate[deviceID]! += 1
            if ticksSinceUpdate[deviceID]! > 1{
                ticksSinceUpdate[deviceID] = 0
                let tempChartImage = imageFromSwiftUIView(TemperatureChartView(data: tempData[deviceID]!))
                let material = SCNMaterial()
                material.diffuse.contents = tempChartImage
                tempGraphNodes[deviceID]!.geometry!.materials = [material]
//                print("updated chart")
            }
            
        } else if arObjects == .humGraph {
            guard var humPoints = humData[deviceID] else { return }
            humPoints.append(newHum)
            if humPoints.count > 100 {
                humPoints.removeFirst()
            }
            humData[deviceID] = humPoints
            ticksSinceUpdate[deviceID]! += 1
            if ticksSinceUpdate[deviceID]! > 1{
                ticksSinceUpdate[deviceID] = 0
                let humChartImage = imageFromSwiftUIView(HumidityChartView(data: humData[deviceID]!))
                let material = SCNMaterial()
                material.diffuse.contents = humChartImage
                humGraphNodes[deviceID]!.geometry!.materials = [material]
//                print("updated chart")
            }
            
        } else if arObjects == .proxGraph {
            print("arObjects = .proxGraph")
//            print
            guard var proxPoints = proxData[deviceID] else { return }
            print("prox points is ", proxPoints)
//            var proxPoints = proxData[deviceID]!
            proxPoints.append(newProx)
            if proxPoints.count > 100 {
                proxPoints.removeFirst()
            }
            proxData[deviceID] = proxPoints
            ticksSinceUpdate[deviceID]! += 1
            if ticksSinceUpdate[deviceID]! > 1{
                ticksSinceUpdate[deviceID] = 0
                let proxChartImage = imageFromSwiftUIView(ProximityChartView(data: proxData[deviceID]!))
                let material = SCNMaterial()
                material.diffuse.contents = proxChartImage
                proxGraphNodes[deviceID]!.geometry!.materials = [material]
                print("updated chart")
            }
        }
    }

    
    // IMAGE PROCESSING
    
    func fixImageOrientation(image: UIImage) -> UIImage {
        if image.imageOrientation == .up {
            return image
        }
        
        UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
        image.draw(in: CGRect(origin: .zero, size: image.size))
        let normalizedImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        
        return normalizedImage
    }
    
    func transformImagePointToViewPoint(imagePoint: CGPoint, imageSize: CGSize, viewSize: CGSize) -> CGPoint {
        let widthScale = viewSize.width / imageSize.width
        let heightScale = viewSize.height / imageSize.height
        let viewPoint = CGPoint(x: imagePoint.x * widthScale, y: imagePoint.y * heightScale)
        return viewPoint
    }

    
    func drawContours(image: UIImage) -> (UIImage?, [CGPoint]?, [[NSNumber]]?, [NSNumber]?) {
        var centerPoints: NSArray?
        var averageColors: NSArray?
        var areas: NSArray?
        var identifiers: NSArray?
        
        let contouredImage = OpenCVWrapper.drawContours(on: image, centerPoints: &centerPoints, averageColors: &averageColors, areas: &areas, identifiers: &identifiers)
        print("returned contouredImage")

        
        if let centers = centerPoints as? [NSValue], let colors = averageColors as? [[NSNumber]], let areasArray = areas as? [NSNumber], let identifiersArray = identifiers as? [NSNumber] {
            for (index, identifier) in identifiersArray.enumerated() {
                print("identifier \(identifier) corresponds to detected color #\(colors[index])")
            }
            
            let points = centers.map { $0.cgPointValue }
            return (contouredImage, points, colors, areasArray)
        }
        
        return (contouredImage, nil, nil, nil)
    }
    
    // BLUETOOTH FUNCTIONALITY / processing incoming data
    
    func interpretBluetoothData(hexData: Data) -> [String: Float] {
        // Convert data to byte array
        let bytes = [UInt8](hexData)
        
        // Check that the data is long enough
        guard bytes.count >= 56 else {
            print("Data is too short: \(bytes.count) bytes")
            return ["error": 0.0]
        }
        
        // Discard the first two elements (just says the number of nodes)
        let validBytes = Array(bytes[2...])
        guard validBytes.count >= 54 else {
            print("Valid data is too short after dropping first 2 bytes: \(validBytes.count) bytes")
            return ["error": 1.0]
        }

        var result: [String: Float] = [:]

        // Process the remaining bytes
        let deviceID = validBytes[0]
        result["deviceID"] = Float(deviceID)

        if deviceID == 4 {
            result["proximity"] = 0
            result["ambient"] = 0
            result["red"] = 0
            result["green"] = 0
            result["blue"] = 5
            result["temp"] = 0
            result["pres"] = 0
        } else {
            let proximity = validBytes[1]
            let ambient = Int(validBytes[2]) | (Int(validBytes[3]) << 8)
            let red = Int(validBytes[4]) | (Int(validBytes[5]) << 8)
            let green = Int(validBytes[6]) | (Int(validBytes[7]) << 8)
            let blue = Int(validBytes[8]) | (Int(validBytes[9]) << 8)

            result["proximity"] = Float(proximity)
            result["ambient"] = Float(ambient)
            result["red"] = Float(red)
            result["green"] = Float(green)
            result["blue"] = Float(blue)

            let temp = Float(Int(validBytes[10]) | (Int(validBytes[11]) << 8)) / 100.0
            let pres = Float(Int(validBytes[12]) | (Int(validBytes[13]) << 8)) / 100.0
            let hum = Float(Int(validBytes[14]) | (Int(validBytes[15]) << 8)) / 100.0

            result["temp"] = temp
            result["pres"] = pres
            result["hum"] = hum

            let quat_w = Float(Int(validBytes[16]) | (Int(validBytes[17]) << 8) | (Int(validBytes[18]) << 16) | (Int(validBytes[19]) << 24)) / 100.0
            let quat_x = Float(Int(validBytes[20]) | (Int(validBytes[21]) << 8) | (Int(validBytes[22]) << 16) | (Int(validBytes[23]) << 24)) / 100.0
            let quat_y = Float(Int(validBytes[24]) | (Int(validBytes[25]) << 8) | (Int(validBytes[26]) << 16) | (Int(validBytes[27]) << 24)) / 100.0
            let quat_z = Float(Int(validBytes[28]) | (Int(validBytes[29]) << 8) | (Int(validBytes[30]) << 16) | (Int(validBytes[31]) << 24)) / 100.0

            result["quat_w"] = quat_w
            result["quat_x"] = quat_x
            result["quat_y"] = quat_y
            result["quat_z"] = quat_z

            let accel_x = Float(Int(validBytes[32]) | (Int(validBytes[33]) << 8) | (Int(validBytes[34]) << 16) | (Int(validBytes[35]) << 24)) / 100.0
            let accel_y = Float(Int(validBytes[36]) | (Int(validBytes[37]) << 8) | (Int(validBytes[38]) << 16) | (Int(validBytes[39]) << 24)) / 100.0
            let accel_z = Float(Int(validBytes[40]) | (Int(validBytes[41]) << 8) | (Int(validBytes[42]) << 16) | (Int(validBytes[43]) << 24)) / 100.0

            result["accel_x"] = accel_x
            result["accel_y"] = accel_y
            result["accel_z"] = accel_z

            let magnet_x = Float(Int(validBytes[44]) | (Int(validBytes[45]) << 8) | (Int(validBytes[46]) << 16) | (Int(validBytes[47]) << 24)) / 100.0
            let magnet_y = Float(Int(validBytes[48]) | (Int(validBytes[49]) << 8) | (Int(validBytes[50]) << 16) | (Int(validBytes[51]) << 24)) / 100.0
            let magnet_z = Float(Int(validBytes[52]) | (Int(validBytes[53]) << 8) | (Int(validBytes[54]) << 16) | (Int(validBytes[55]) << 24)) / 100.0

            result["magnet_x"] = magnet_x
            result["magnet_y"] = magnet_y
            result["magnet_z"] = magnet_z
            
//            print("temp is \(result["temp"])")
        }

        // Update the dictionary with the latest data for the deviceID
        latestDataForNodes[Int(deviceID)] = result

        return result
    }


    // MARK: - CBCentralManagerDelegate Methods
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            centralManager.scanForPeripherals(withServices: nil, options: nil)
        } else {
            print("Bluetooth is not available.")
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
//        print("Discovered \(peripheral.name ?? "unknown") at \(RSSI)")
        if peripheral.name?.contains("SensorNet") == true {
            bluefruitPeripheral = peripheral
            centralManager.stopScan()
            centralManager.connect(peripheral, options: nil)
            print("Connecting to sensor net")
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("Connected to \(peripheral.name ?? "unknown")")
        peripheral.delegate = self
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            peripheral.discoverServices(nil)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("Disconnected from \(peripheral.name ?? "unknown")")
        if let error = error {
            print("Error: \(error.localizedDescription)")
        }
        
        // Attempt to reconnect after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.centralManager.connect(peripheral, options: nil)
        }
    }

    
    // MARK: - CBPeripheralDelegate Methods
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        
        if let error = error {
            print("Error discovering services: \(error.localizedDescription)")
            return
        }
        
        print("Discovered services for \(peripheral.name ?? "unknown")")
        if let services = peripheral.services {
            for service in services {
                print("Service: \(service.uuid)")
                peripheral.discoverCharacteristics(nil, for: service)
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error {
            print("Error discovering characteristics: \(error.localizedDescription)")
            return
        }
        
        print("Discovered characteristics for service \(service.uuid)")
        if let characteristics = service.characteristics {
            for characteristic in characteristics {
                print("Characteristic: \(characteristic.uuid)")
                if characteristic.properties.contains(.read) {
                    print("Reading value for characteristic \(characteristic.uuid)")
                    peripheral.readValue(for: characteristic)
                }
                if characteristic.properties.contains(.notify) {
                    print("Setting notify for characteristic \(characteristic.uuid)")
                    peripheral.setNotifyValue(true, for: characteristic)
                }
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("Error updating value for characteristic \(characteristic.uuid): \(error.localizedDescription)")
            return
        }
        
        guard let data = characteristic.value else {
            print("No data received for characteristic \(characteristic.uuid)")
            return
        }
        let processedData = interpretBluetoothData(hexData: data)
        DispatchQueue.main.async {
            self.updateARContent(data: processedData)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("Error updating notification state for characteristic \(characteristic.uuid): \(error.localizedDescription)")
            return
        }
        
        if characteristic.isNotifying {
            print("Notification began on \(characteristic.uuid)")
        } else {
            print("Notification stopped on \(characteristic.uuid). Retrying...")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                peripheral.setNotifyValue(true, for: characteristic)
            }
        }
    }

}
    // COLOR EXTRA FUNCTIONALITY

extension Data {
    func hexEncodedString() -> String {
        return map { String(format: "%02hhx", $0) }.joined()
    }
}

extension UIColor {
    // Convert UIColor to Hex String for easy debugging
    func toHexString() -> String {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0

        getRed(&r, green: &g, blue: &b, alpha: &a)

        let rgb: Int = (Int)(r * 255) << 16 | (Int)(g * 255) << 8 | (Int)(b * 255) << 0

        return String(format: "#%06x", rgb)
    }
    
    func toHSL() -> (h: CGFloat, s: CGFloat, l: CGFloat) {
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        
        getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        
        // Convert brightness to lightness
        let lightness = (2 - saturation) * brightness / 2
        
        return (h: hue, s: saturation, l: lightness)
    }
    
    func toRGB() -> (red: CGFloat, green: CGFloat, blue: CGFloat)? {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        let success = self.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return success ? (red, green, blue) : nil
    }
}







        

    

