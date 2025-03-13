import SwiftUI
import AppKit

// Add a TimezonePickerView
struct TimezonePickerView: View {
    @Binding var selectedTimezone: TimeZone
    @Environment(\.presentationMode) var presentationMode
    @State private var searchText: String = ""
    
    var body: some View {
        VStack {
            Text("Select Timezone")
                .font(.headline)
                .padding()
            
            // Search bar
            TextField("Search by offset (e.g., +5:30)", text: $searchText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)
            
            List {
                // Current timezone first
                if matchesSearch(timezone: TimeZone.current) {
                    Button(action: {
                        selectedTimezone = TimeZone.current
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        HStack {
                            Text("\(TimezonePickerView.formatOffset(TimeZone.current)) (Current)")
                            Spacer()
                            if selectedTimezone == TimeZone.current {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
                
                // Other timezones
                ForEach(filteredTimezones(), id: \.self) { timezone in
                    Button(action: {
                        selectedTimezone = timezone
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        HStack {
                            Text(TimezonePickerView.formatOffset(timezone))
                            Spacer()
                            if selectedTimezone == timezone {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
        }
        .frame(width: 200, height: 400) // Reduced width since we're only showing offsets
    }
    
    private func filteredTimezones() -> [TimeZone] {
        let allTimezones = TimeZone.knownTimeZoneIdentifiers.compactMap { TimeZone(identifier: $0) }
        
        guard !searchText.isEmpty else {
            // Use a Set to filter duplicates based on offset
            var uniqueTimezones = Set<Int>()
            return allTimezones.filter {
                let isUnique = uniqueTimezones.insert($0.secondsFromGMT()).inserted
                return isUnique && $0 != TimeZone.current
            }
        }
        
        // Try to parse the search text as an offset
        if let offset = parseOffset(searchText) {
            // Return only the first timezone that matches the offset
            if let firstMatch = allTimezones.first(where: { $0.secondsFromGMT() == offset && $0 != TimeZone.current }) {
                return [firstMatch]
            }
            return []
        }
        
        // Fallback to identifier search if offset parsing fails
        return allTimezones.filter {
            $0.identifier.localizedCaseInsensitiveContains(searchText) && $0 != TimeZone.current
        }
    }
    
    // Make formatOffset a static method
    static func formatOffset(_ timezone: TimeZone) -> String {
        let hours = timezone.secondsFromGMT() / 3600
        let minutes = abs(timezone.secondsFromGMT() % 3600) / 60
        return String(format: "UTC%+03d:%02d", hours, minutes)
    }
    
    private func parseOffset(_ text: String) -> Int? {
        let pattern = #"^([+-]?)(\d{1,2}):?(\d{2})?$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else {
            return nil
        }
        
        let signRange = Range(match.range(at: 1), in: text)
        let hourRange = Range(match.range(at: 2), in: text)
        let minuteRange = Range(match.range(at: 3), in: text)
        
        guard let hourString = hourRange.map({ String(text[$0]) }),
              let hours = Int(hourString) else {
            return nil
        }
        
        let minutes = minuteRange.flatMap { Int(String(text[$0])) } ?? 0
        let sign = signRange.map { String(text[$0]) } ?? "+"
        
        let totalSeconds = (hours * 3600) + (minutes * 60)
        return sign == "-" ? -totalSeconds : totalSeconds
    }
    
    private func matchesSearch(timezone: TimeZone) -> Bool {
        guard !searchText.isEmpty else { return true }
        
        if let offset = parseOffset(searchText) {
            return timezone.secondsFromGMT() == offset
        }
        
        return timezone.identifier.localizedCaseInsensitiveContains(searchText)
    }
}

@main
struct MacTimezonesApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    private var statusItem: NSStatusItem!
    @Published var lastConvertedTime: String = "No time detected yet"
    @Published var selectedTimezone: TimeZone = TimeZone.current
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "clock", accessibilityDescription: "Mac Timezones")
        }
        
        buildMenu()
        startClipboardMonitoring()
    }
    
    private func buildMenu() {
        let menu = NSMenu()
        
        // Add current time conversion
        let timeItem = NSMenuItem()
        let timeView = NSHostingView(rootView: VStack(alignment: .leading, spacing: 4) {
            Text(lastConvertedTime)
                .font(.system(size: 12))
            
            if lastConvertedTime != "No time detected yet" {
                if let detectedTimezone = TimeParser().detectTimezone(from: lastConvertedTime) {
                    Text("Detected Offset: \(TimezonePickerView.formatOffset(detectedTimezone))")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                } else {
                    Text("Detected Offset: Unknown")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
            
            Text("Selected Offset: \(TimezonePickerView.formatOffset(selectedTimezone))")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        })
        timeView.frame = NSRect(x: 0, y: 0, width: 200, height: 60)
        timeItem.view = timeView
        menu.addItem(timeItem)
        
        // Add separator
        menu.addItem(NSMenuItem.separator())
        
        // Add timezone selector
        let timezoneItem = NSMenuItem(title: "Select Timezone", action: nil, keyEquivalent: "")
        let timezoneMenu = NSMenu()
        
        // Add current timezone
        let currentTimezoneItem = NSMenuItem(
            title: "\(TimezonePickerView.formatOffset(TimeZone.current)) (Current)",
            action: #selector(selectTimezone(_:)),
            keyEquivalent: ""
        )
        currentTimezoneItem.representedObject = TimeZone.current
        currentTimezoneItem.state = selectedTimezone == TimeZone.current ? .on : .off
        timezoneMenu.addItem(currentTimezoneItem)
        
        // Add other timezones
        let uniqueTimezones = TimeZone.knownTimeZoneIdentifiers
            .compactMap { TimeZone(identifier: $0) }
            .reduce(into: Set<Int>()) { result, timezone in
                if result.insert(timezone.secondsFromGMT()).inserted {
                    let item = NSMenuItem(
                        title: TimezonePickerView.formatOffset(timezone),
                        action: #selector(selectTimezone(_:)),
                        keyEquivalent: ""
                    )
                    item.representedObject = timezone
                    item.state = selectedTimezone == timezone ? .on : .off
                    timezoneMenu.addItem(item)
                }
            }
        
        timezoneItem.submenu = timezoneMenu
        menu.addItem(timezoneItem)
        
        // Add separator
        menu.addItem(NSMenuItem.separator())
        
        // Add Quit item
        let quitItem = NSMenuItem(
            title: "Quit",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        menu.addItem(quitItem)
        
        statusItem.menu = menu
    }
    
    @objc private func selectTimezone(_ sender: NSMenuItem) {
        if let timezone = sender.representedObject as? TimeZone {
            selectedTimezone = timezone
            buildMenu() // Rebuild menu to update states
            checkClipboard() // Update time conversion
        }
    }
    
    private func startClipboardMonitoring() {
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkClipboard()
        }
    }
    
    func checkClipboard() {
        if let clipboardString = NSPasteboard.general.string(forType: .string) {
            processClipboardContent(clipboardString)
        }
    }
    
    private func processClipboardContent(_ content: String) {
        if let (originalTime, convertedTime) = TimeParser().parseAndConvertTime(
            from: content,
            targetTimezone: self.selectedTimezone
        ) {
            let resultString = "\(originalTime) → \(convertedTime)"
            self.lastConvertedTime = resultString
            
            // Update the menu with both the result and detected timezone
            if let detectedTimezone = TimeParser().detectTimezone(from: content) {
                print("Detected timezone in original text: \(detectedTimezone.identifier)")
            } else {
                print("No timezone detected in original text: \(content)")
            }
            
            self.buildMenu() // Update menu with new time
        }
    }
}
