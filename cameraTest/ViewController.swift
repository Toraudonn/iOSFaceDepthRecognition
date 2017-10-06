//
//  ViewController.swift
//  cameraTest
//
//  Created by Haruya Ishikawa on 2017/09/30.
//  Copyright © 2017 Haruya Ishikawa. All rights reserved.
//

import UIKit
import SceneKit
import ARKit
import Vision

class ViewController: UIViewController, ARSCNViewDelegate, ARSessionDelegate {

    // MARK: - UI
    @IBOutlet var sceneView: ARSCNView!
    @IBOutlet weak var button: UIButton!
    
    // MARK: - Variables
    var timer = Timer()
    var timerOn = false
    
    let globalQueue = DispatchQueue.global()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view's delegate
        sceneView.delegate = self // view delegate

        // Show statistics such as fps and timing information
        sceneView.showsStatistics = true
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()

        // Run the view's session
        sceneView.session.run(configuration)
        configuration.planeDetection = .horizontal
        sceneView.session.delegate = self // session delegate
        
        self.timer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(self.Tick), userInfo: nil, repeats: true)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        // Pause the view's session
        sceneView.session.pause()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Release any cached data, images, etc that aren't in use.
    }

     //MARK: - ARSCNViewDelegate/ARSessionDelegate

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        /// 毎回 -> lagggggggggggg!!!!!
        
//        globalQueue.async {
//            self.faceDetection(frame)
//        }
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user

    }

    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay

    }

    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required

    }
    
    // MARK: - Test Face Recognition
    
    private var faceLayers = [CAShapeLayer]()
    
    @IBAction func touchButton(_ sender: Any) {
        timerOn = !timerOn
    }
    
    @objc func Tick () {
        if timerOn == true {
            globalQueue.async {
                self.faceDetection(self.sceneView.session.currentFrame!)
                
            }
        }
        else {
            DispatchQueue.main.async {
                // remove box
                self.sceneView.scene.rootNode.childNode(withName: "a box", recursively: true)?.removeFromParentNode()
                
                self.faceLayers.forEach{ $0.removeFromSuperlayer() }
                self.faceLayers.removeAll()
            }
        }
    }
    
    func faceDetection(_ frame: ARFrame) {

        let facesRequest = VNDetectFaceRectanglesRequest { request, error in
            guard error == nil else {
                print("Face request error: \(error!.localizedDescription)")
                return
            }
            
            guard let observations = request.results as? [VNFaceObservation] else {
                print("No face observations")
                return
            }
            
            //---> UI
            DispatchQueue.main.async {
                self.faceLayers.forEach{ $0.removeFromSuperlayer() }
                self.faceLayers.removeAll()
                self.addFaceRectangles(forObservations: observations)
            }
            
        }
        
        let image = CIImage.init(cvPixelBuffer: frame.capturedImage).oriented(.right)
        try? VNImageRequestHandler(ciImage: image).perform([facesRequest])

        guard let location = get3DPosition() else {
            print("no feature point found")
            return
        }
        // add box
        addObject(location)
    }
    
    // add yellow rectangle box on 2D space
    func addFaceRectangles(forObservations observations: [VNFaceObservation]) {
        for observation in observations {
            let layer = CAShapeLayer()
            //print(observation.boundingBox)
            let rect = transformBoundingBox(observation.boundingBox)
            let path = UIBezierPath(rect: rect)
            
            layer.path = path.cgPath
            layer.fillColor = UIColor.clear.cgColor
            layer.strokeColor = UIColor.yellow.cgColor
            layer.lineWidth = 4
            self.sceneView.layer.addSublayer(layer)
            self.faceLayers.append(layer)
        }
    }
    
    func get3DPosition() -> SCNVector3? {
        guard let layer = faceLayers.first else { return nil }
        let path = layer.path
        guard let location = determineWorldCoord((path?.boundingBox)!) else { return nil }
        //print(location)
        return location
    }
    
    func determineWorldCoord(_ boundingBox: CGRect) -> SCNVector3? {
        let arHitTestResults = sceneView.hitTest(CGPoint(x: boundingBox.midX, y: boundingBox.midY), types: [.featurePoint])
        
        // Filter results that are to close
        if let closestResult = arHitTestResults.filter({ $0.distance > 0.10 }).first {
            //            print("vector distance: \(closestResult.distance)")
            return SCNVector3.positionFromTransform(closestResult.worldTransform)
        }
        return nil
    }
    
    func addObject(_ location: SCNVector3) {
        var boxGeometry: SCNBox!
        boxGeometry = SCNBox(width: 0.1, height: 0.1, length: 0.01, chamferRadius: 0)
        let boxNode = SCNNode(geometry: boxGeometry)
        
        // location
        boxNode.position = location
        boxNode.physicsBody = SCNPhysicsBody(type: .kinematic, shape: SCNPhysicsShape(geometry: boxGeometry, options: nil))
        
        boxNode.isHidden = false
        boxNode.name = "a box"
        
        let material = SCNMaterial()
        material.diffuse.contents = UIColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.8)
        boxNode.geometry?.firstMaterial = material
        boxNode.geometry?.firstMaterial?.isDoubleSided = true
        
        // add to child node of the object
        sceneView.scene.rootNode.addChildNode(boxNode)
    }
    
    // changing the size of the boundbox for face detection
    private func transformBoundingBox(_ boundingBox: CGRect) -> CGRect {
        let size = CGSize(width: boundingBox.width * sceneView.bounds.width,
                      height: boundingBox.height * sceneView.bounds.height)
        let origin = CGPoint(x: boundingBox.minX * sceneView.bounds.width,
                         y: (1 - boundingBox.maxY) * sceneView.bounds.height)
        
        return CGRect(origin: origin, size: size)
    }
}



