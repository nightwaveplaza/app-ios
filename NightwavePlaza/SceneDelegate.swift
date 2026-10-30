import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    // UIKit creates the window and root controller from the scene's Web storyboard.
    var window: UIWindow?

    func sceneWillEnterForeground(_ scene: UIScene) {
        (window?.rootViewController as? MainViewController)?.sceneWillEnterForeground()
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        (window?.rootViewController as? MainViewController)?.sceneDidEnterBackground()
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        (window?.rootViewController as? MainViewController)?.sceneDidEnterBackground()
    }
}
