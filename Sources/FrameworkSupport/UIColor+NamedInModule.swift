import UIKit

extension UIColor {
    convenience init(namedInModule name: String) {
        self.init(named: name, in: .module, compatibleWith: nil)!
    }
}
