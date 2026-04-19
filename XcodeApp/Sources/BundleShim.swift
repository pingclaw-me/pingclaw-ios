import Foundation

// In SwiftPM, Bundle.module points to the package's resource bundle.
// In a plain Xcode target, resources are in the main bundle.
// This extension makes Bundle.module work in both contexts.
#if !SWIFT_PACKAGE
extension Bundle {
    static var module: Bundle { .main }
}
#endif
