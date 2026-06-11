import AppKit
import CoreText

/// Registers the bundled Myriad Pro OTFs at launch so `Font.custom(...)` resolves.
enum FontRegistrar {
    static func registerBundledFonts() {
        let names = ["MyriadPro-Regular", "MyriadPro-Semibold", "MyriadPro-Black"]
        for name in names {
            guard let url = Bundle.main.url(forResource: name, withExtension: "otf") else {
                NSLog("Claude Dials: missing bundled font \(name).otf")
                continue
            }
            var error: Unmanaged<CFError>?
            if !CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) {
                // Already-registered is harmless; log anything else.
                if let err = error?.takeRetainedValue() {
                    NSLog("Claude Dials: font register \(name): \(err)")
                }
            }
        }
    }
}
