import SwiftUI

@main
struct MacTimezonesApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject, ClipboardMonitorDelegate {
    private var statusItem: NSStatusItem!
    private var clipboardMonitor: ClipboardMonitor!
    @Published var lastConvertedTime: String = "No time detected yet"
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create the status item in the menu bar
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "clock", accessibilityDescription: "Mac Timezones")
        }
        
        // Setup the menu
        setupMenu()
        
        // Initialize clipboard monitor
        clipboardMonitor = ClipboardMonitor()
        clipboardMonitor.delegate = self
        clipboardMonitor.startMonitoring()
    }
    
    private func setupMenu() {
        let menu = NSMenu()
        
        menu.addItem(NSMenuItem(title: lastConvertedTime, action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))
        
        statusItem.menu = menu
    }
    
    func updateLastConvertedTime(time: String) {
        lastConvertedTime = time
        setupMenu() // Refresh the menu with the new time
    }
    
    @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}

// Delegate protocol for clipboard changes
protocol ClipboardMonitorDelegate: AnyObject {
    func updateLastConvertedTime(time: String)
}

// Class to monitor clipboard changes
class ClipboardMonitor {
    weak var delegate: ClipboardMonitorDelegate?
    private var timer: Timer?
    private var lastChangeCount: Int = 0
    private let timeParser = TimeParser()
    
    func startMonitoring() {
        // Check clipboard every 0.5 seconds
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkClipboard()
        }
    }
    
    private func checkClipboard() {
        let pasteboard = NSPasteboard.general
        let changeCount = pasteboard.changeCount
        
        // Only process if the clipboard has changed
        if changeCount != lastChangeCount {
            lastChangeCount = changeCount
            
            if let clipboardString = pasteboard.string(forType: .string) {
                processClipboardContent(clipboardString)
            }
        }
    }
    
    private func processClipboardContent(_ content: String) {
        if let (originalTime, convertedTime) = timeParser.parseAndConvertTime(from: content) {
            let resultString = "\(originalTime) → \(convertedTime)"
            delegate?.updateLastConvertedTime(time: resultString)
        }
    }
} 