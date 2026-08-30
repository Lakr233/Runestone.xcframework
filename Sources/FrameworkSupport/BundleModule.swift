import Foundation

#if !SWIFT_PACKAGE
extension Bundle {
    static var module: Bundle { Bundle(for: RunestoneBundleToken.self) }
}

private final class RunestoneBundleToken {}
#endif
