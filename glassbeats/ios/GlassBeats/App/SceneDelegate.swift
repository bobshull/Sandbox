import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene,
               willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = MainViewController()
        window.overrideUserInterfaceStyle = .dark
        self.window = window
        window.makeKeyAndVisible()
        if #available(iOS 16.0, *) {
            windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .landscape))
            window.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
        }
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        if #available(iOS 16.0, *) {
            (scene as? UIWindowScene)?.requestGeometryUpdate(
                .iOS(interfaceOrientations: .landscape)
            )
            window?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
        }
    }

    func windowScene(_ windowScene: UIWindowScene,
                     supportedInterfaceOrientationsFor window: UIWindow) -> UIInterfaceOrientationMask {
        .landscape
    }
}
