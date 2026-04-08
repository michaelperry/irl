import SwiftUI
import SceneKit

/// A dynamic 3D Earth that shows the correct face based on current time,
/// applies realistic day/night lighting, and optionally shows pins where you've posted.
struct EarthView: UIViewRepresentable {

    var size: CGFloat = 300
    var autoRotate: Bool = true
    var pins: [PostLocation] = []

    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.backgroundColor = .clear
        scnView.allowsCameraControl = false
        scnView.autoenablesDefaultLighting = false
        scnView.isUserInteractionEnabled = false
        scnView.antialiasingMode = .multisampling4X

        let scene = SCNScene()
        scnView.scene = scene

        // Earth sphere
        let sphere = SCNSphere(radius: 1.0)
        sphere.segmentCount = 96

        let material = SCNMaterial()
        material.diffuse.contents = UIImage(named: "EarthTexture")
        material.diffuse.wrapS = .repeat
        material.diffuse.wrapT = .repeat
        material.specular.contents = UIColor(white: 0.15, alpha: 1)
        material.shininess = 0.1
        material.ambient.contents = UIColor(white: 0.06, alpha: 1)
        sphere.materials = [material]

        let earthNode = SCNNode(geometry: sphere)
        earthNode.name = "earth"

        let rotation = currentEarthRotation()
        earthNode.eulerAngles = SCNVector3(
            x: Float(-23.4 * .pi / 180),
            y: Float(rotation),
            z: 0
        )
        scene.rootNode.addChildNode(earthNode)

        // Add pins
        for pin in pins {
            let pinNode = createPinNode(latitude: pin.latitude, longitude: pin.longitude, earthRotation: rotation)
            earthNode.addChildNode(pinNode)
        }

        if autoRotate {
            let spin = SCNAction.rotateBy(x: 0, y: CGFloat.pi * 2, z: 0, duration: 120)
            earthNode.runAction(SCNAction.repeatForever(spin))
        }

        // Sun light
        let sunLight = SCNLight()
        sunLight.type = .directional
        sunLight.intensity = 1200
        sunLight.color = UIColor(red: 1.0, green: 0.98, blue: 0.95, alpha: 1)
        sunLight.castsShadow = false

        let sunNode = SCNNode()
        sunNode.light = sunLight
        let sunAngle = sunLightAngle()
        sunNode.eulerAngles = SCNVector3(
            x: Float(sunAngle.elevation),
            y: Float(sunAngle.azimuth),
            z: 0
        )
        scene.rootNode.addChildNode(sunNode)

        // Ambient
        let ambientLight = SCNLight()
        ambientLight.type = .ambient
        ambientLight.intensity = 80
        ambientLight.color = UIColor(red: 0.4, green: 0.6, blue: 1.0, alpha: 1)
        let ambientNode = SCNNode()
        ambientNode.light = ambientLight
        scene.rootNode.addChildNode(ambientNode)

        // Camera
        let camera = SCNCamera()
        camera.fieldOfView = 45
        camera.zNear = 0.1
        camera.zFar = 100
        let cameraNode = SCNNode()
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(x: 0, y: 0, z: 3.0)
        scene.rootNode.addChildNode(cameraNode)

        // Atmosphere
        let atmosphereSphere = SCNSphere(radius: 1.02)
        atmosphereSphere.segmentCount = 64
        let atmosphereMaterial = SCNMaterial()
        atmosphereMaterial.diffuse.contents = UIColor(red: 0.3, green: 0.6, blue: 1.0, alpha: 0.08)
        atmosphereMaterial.transparent.contents = UIColor(white: 1, alpha: 0.08)
        atmosphereMaterial.isDoubleSided = true
        atmosphereMaterial.lightingModel = .constant
        atmosphereSphere.materials = [atmosphereMaterial]
        let atmosphereNode = SCNNode(geometry: atmosphereSphere)
        scene.rootNode.addChildNode(atmosphereNode)
        if autoRotate {
            let spin = SCNAction.rotateBy(x: 0, y: CGFloat.pi * 2, z: 0, duration: 120)
            atmosphereNode.runAction(SCNAction.repeatForever(spin))
        }

        return scnView
    }

    func updateUIView(_ uiView: SCNView, context: Context) {}

    // MARK: - Pin creation

    private func createPinNode(latitude: Double, longitude: Double, earthRotation: Double) -> SCNNode {
        let radius: Float = 1.01

        // Convert lat/lon to 3D position on sphere
        let latRad = Float(latitude * .pi / 180)
        let lonRad = Float(longitude * .pi / 180)

        let x = radius * cos(latRad) * sin(lonRad)
        let y = radius * sin(latRad)
        let z = radius * cos(latRad) * cos(lonRad)

        // Pin sphere (small glowing dot)
        let pinSphere = SCNSphere(radius: 0.02)
        pinSphere.segmentCount = 16
        let pinMaterial = SCNMaterial()
        pinMaterial.diffuse.contents = UIColor(red: 0, green: 0.8, blue: 0.4, alpha: 1) // earth green
        pinMaterial.lightingModel = .constant // always bright
        pinSphere.materials = [pinMaterial]

        let pinNode = SCNNode(geometry: pinSphere)
        pinNode.position = SCNVector3(x: x, y: y, z: z)

        // Glow halo
        let glowSphere = SCNSphere(radius: 0.04)
        glowSphere.segmentCount = 12
        let glowMaterial = SCNMaterial()
        glowMaterial.diffuse.contents = UIColor(red: 0, green: 0.8, blue: 0.4, alpha: 0.25)
        glowMaterial.lightingModel = .constant
        glowMaterial.isDoubleSided = true
        glowSphere.materials = [glowMaterial]

        let glowNode = SCNNode(geometry: glowSphere)
        glowNode.position = SCNVector3(x: x, y: y, z: z)

        // Pulse animation on glow
        let pulse = SCNAction.sequence([
            SCNAction.scale(to: 1.3, duration: 1.0),
            SCNAction.scale(to: 1.0, duration: 1.0)
        ])
        glowNode.runAction(SCNAction.repeatForever(pulse))

        let containerNode = SCNNode()
        containerNode.addChildNode(pinNode)
        containerNode.addChildNode(glowNode)

        return containerNode
    }

    // MARK: - Earth rotation

    private func currentEarthRotation() -> Double {
        // Approximate user's longitude from timezone offset
        // GMT-8 (PST) → longitude ≈ -120°, GMT+1 (CET) → longitude ≈ 15°, etc.
        let localOffset = Double(TimeZone.current.secondsFromGMT()) / 3600.0
        let userLongitude = localOffset * 15.0 // degrees

        // SceneKit: Y rotation = 0 shows texture center (0° longitude / prime meridian)
        // Positive Y rotation spins Earth eastward (shows western longitudes)
        // To face the user's longitude toward camera, rotate by negative longitude
        let rotation = -userLongitude * .pi / 180.0
        return rotation
    }

    // MARK: - Sun light

    private func sunLightAngle() -> (azimuth: Double, elevation: Double) {
        let now = Date()
        let calendar = Calendar(identifier: .gregorian)
        let utcTimeZone = TimeZone(identifier: "UTC")!
        let components = calendar.dateComponents(in: utcTimeZone, from: now)

        let hours = Double(components.hour ?? 12)
        let minutes = Double(components.minute ?? 0)
        let fractionalHour = hours + minutes / 60.0

        let sunAzimuth = (fractionalHour - 12.0) * 15.0 * .pi / 180.0

        let dayOfYear = Double(calendar.ordinality(of: .day, in: .year, for: now) ?? 172)
        let declination = 23.4 * sin((360.0 / 365.0) * (dayOfYear - 81) * .pi / 180.0)
        let sunElevation = -declination * .pi / 180.0

        return (azimuth: sunAzimuth, elevation: sunElevation)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        EarthView(size: 300, pins: [
            PostLocation(latitude: 37.7749, longitude: -122.4194), // SF
            PostLocation(latitude: 40.7128, longitude: -74.0060),  // NYC
            PostLocation(latitude: 51.5074, longitude: -0.1278),   // London
        ])
        .frame(width: 300, height: 300)
    }
}
