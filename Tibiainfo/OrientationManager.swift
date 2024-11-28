import SwiftUI

class OrientationManager {
    static let shared = OrientationManager()
    
    private init() {}
    
    func lockOrientation(_ orientation: UIInterfaceOrientationMask) {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: orientation))
        }
    }
    
    func lockOrientation(_ orientation: UIInterfaceOrientationMask, andRotateTo rotateOrientation: UIInterfaceOrientation) {
        lockOrientation(orientation)
        UIViewController.attemptRotationToDeviceOrientation()
    }
} 