import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        _ = Speaker.shared
        _ = AppContext.lex
        let nav = UINavigationController(rootViewController: HomeViewController())
        nav.isNavigationBarHidden = true
        Router.nav = nav
        let w = UIWindow(frame: UIScreen.main.bounds)
        w.rootViewController = nav
        w.makeKeyAndVisible()
        window = w
        return true
    }
}
