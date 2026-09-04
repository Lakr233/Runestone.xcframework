import Foundation

#if !SWIFT_PACKAGE
extension Bundle {
    // The framework is static, so this class lands in whatever binary linked us
    // (the app, or the dynamic RunestoneDynamic product). Xcode still embeds
    // Runestone.framework for its resources, so look for it next to us.
    static let module: Bundle = {
        let own = Bundle(for: RunestoneBundleToken.self)
        let directories = [
            own.privateFrameworksURL,
            own.bundleURL.deletingLastPathComponent(),
            Bundle.main.privateFrameworksURL,
        ]
        for url in directories.compactMap({ $0?.appendingPathComponent("Runestone.framework") }) {
            if let bundle = Bundle(url: url) {
                return bundle
            }
        }
        return own
    }()
}

private final class RunestoneBundleToken {}
#endif
