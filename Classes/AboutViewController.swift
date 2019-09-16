import UIKit

let HOMEPAGE_URL = "https://github.com/chadaustin/passdrop"

class AboutViewController: UIViewController {
    @IBOutlet var homepage: UIButton?
    @IBOutlet var version: UILabel?

    override func viewDidLoad() {
        super.viewDidLoad()
        self.edgesForExtendedLayout = []

        homepage?.setTitle(HOMEPAGE_URL, for: .normal)
        let version = Bundle.main.object(forInfoDictionaryKey: kCFBundleVersionKey as String)!
        self.version?.text = "Version \(version)"
    }

    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        return .portrait
    }

    override var shouldAutorotate: Bool {
        return true
    }

    @IBAction
    func handleEvent(_ sender: AnyObject) {
        guard let button = sender as? UIButton else {
            return
        }
        if button == homepage {
            UIApplication.shared.openURL(URL(string: HOMEPAGE_URL)!)
        }
    }
}
