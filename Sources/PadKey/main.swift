import AppKit

@MainActor
func launch() {
    let args = CommandLine.arguments
    if let index = args.firstIndex(of: "--snapshot"), index + 1 < args.count {
        let profileIndex = args.firstIndex(of: "--profile")
        let profile = profileIndex.flatMap { $0 + 1 < args.count ? args[$0 + 1] : nil }
        Snapshot.capture(to: args[index + 1],
                         dark: args.contains("--dark"),
                         demo: args.contains("--demo"),
                         profile: profile,
                         list: args.contains("--list"))
        exit(0)
    }
    if CommandLine.arguments.contains("--test-souris") {
        Diagnostic.testMouseInjection()
        exit(0)
    }
    if CommandLine.arguments.contains("--diagnostic") {
        Diagnostic.run()
        exit(0)
    }
    let application = NSApplication.shared
    let delegate = AppDelegate()
    // NSApplication ne retient pas son delegate.
    objc_setAssociatedObject(application, "padkey.delegate", delegate, .OBJC_ASSOCIATION_RETAIN)
    application.delegate = delegate
    application.run()
}

MainActor.assumeIsolated { launch() }
