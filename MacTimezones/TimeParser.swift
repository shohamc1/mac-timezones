import Foundation

class TimeParser {
    // Regex patterns for different time formats
    private let timePatterns = [
        // 9PM EST, 9 PM EST, 9:00PM EST, 9:00 PM EST
        // Also matches if there's text before the time (e.g. "March 21st 9PM EST")
        #".*?(\d{1,2})(?::|)(?:(\d{2})|)\s*([AaPp][Mm])\s+([A-Za-z]{3,4})\s*$"#,
        
        // 21:00 EST, 21:00EST
        // Also matches if there's text before the time
        #".*?(\d{1,2}):(\d{2})(?:\s*)([A-Za-z]{3,4})\s*$"#,
        
        // 9PM, 9 PM, 9:00PM, 9:00 PM (no timezone - assume UTC)
        // Also matches if there's text before the time
        #".*?(\d{1,2})(?::|)(?:(\d{2})|)\s*([AaPp][Mm])\s*$"#,
        
        // 21:00 (no timezone - assume UTC)
        // Also matches if there's text before the time
        #".*?(\d{1,2}):(\d{2})\s*$"#
    ]
    
    // Dictionary to map timezone abbreviations to identifiers
    private let timezoneMap: [String: String] = [
        "EST": "America/New_York",
        "EDT": "America/New_York",
        "CST": "America/Chicago",
        "CDT": "America/Chicago",
        "MST": "America/Denver",
        "MDT": "America/Denver",
        "PST": "America/Los_Angeles",
        "PDT": "America/Los_Angeles",
        "GMT": "GMT",
        "UTC": "UTC",
        "BST": "Europe/London",
        "IST": "Asia/Kolkata",
        "JST": "Asia/Tokyo",
        "AEST": "Australia/Sydney",
        "AEDT": "Australia/Sydney"
    ]
    
    // Parse time from string and convert to local timezone
    func parseAndConvertTime(from text: String, targetTimezone: TimeZone) -> (String, String)? {
        print("Parsing text: \(text)")
        
        for (index, pattern) in timePatterns.enumerated() {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
                
                if let match = regex.firstMatch(in: text, range: nsRange) {
                    // Extract matched components
                    let components = (0..<match.numberOfRanges).compactMap { index -> String? in
                        let matchRange = match.range(at: index)
                        if matchRange.location != NSNotFound,
                           let range = Range(matchRange, in: text) {
                            let component = String(text[range])
                            print("Component \(index): '\(component)'")
                            return component.isEmpty ? nil : component
                        }
                        return nil
                    }
                    
                    print("Matched pattern \(index) with components: \(components)")
                    
                    // For pattern 0 (9PM EST), we need at least 4 components:
                    // 0: full match
                    // 1: hour
                    // 2: AM/PM
                    // 3: timezone
                    if index == 0 && components.count < 4 {
                        print("Not enough components for pattern 0, continuing...")
                        continue
                    }
                    
                    if components.count >= 3 {
                        if let result = processTimeComponents(components, patternIndex: index, targetTimezone: targetTimezone) {
                            return result
                        }
                    }
                }
            }
        }
        
        return nil
    }
    
    private func processTimeComponents(_ components: [String], patternIndex: Int, targetTimezone: TimeZone) -> (String, String)? {
        print("Processing components: \(components) from pattern \(patternIndex)")
        
        // Different patterns will have different component arrangements
        var hour: Int
        var minute: Int = 0
        var isPM: Bool = false
        var timezoneString: String = "UTC" // Default timezone
        
        if patternIndex == 0 {
            // Pattern: 9PM EST, 9 PM EST, 9:00PM EST, 9:00 PM EST
            guard components.count >= 4 else {
                print("Not enough components for pattern 0")
                return nil
            }
            
            hour = Int(components[1]) ?? 0
            print("Hour component: '\(components[1])' parsed as: \(hour)")
            
            // AM/PM is in group 2, timezone in group 3
            let amPmIndicator = components[2].uppercased()
            isPM = amPmIndicator == "PM"
            print("AM/PM component: '\(components[2])' parsed as: \(amPmIndicator), isPM: \(isPM)")
            
            timezoneString = components[3]
            print("Timezone component: '\(components[3])'")
            
            print("Matched 9PM EST pattern. Hour: \(hour), Minute: \(minute), AM/PM: \(amPmIndicator), isPM: \(isPM), Timezone: \(timezoneString)")
            
        } else if patternIndex == 1 {
            // Pattern: 21:00 EST, 21:00EST
            hour = Int(components[1]) ?? 0
            minute = Int(components[2]) ?? 0
            timezoneString = components[3]
            print("Matched 21:00 EST pattern. Hour: \(hour), Minute: \(minute), Timezone: \(timezoneString)")
            
        } else if patternIndex == 2 {
            // Pattern: 9PM, 9 PM, 9:00PM, 9:00 PM (no timezone)
            hour = Int(components[1]) ?? 0
            
            // Handle optional minutes
            if components.count > 2 && !components[2].isEmpty {
                minute = Int(components[2]) ?? 0
            }
            
            let amPmIndicator = components[2].uppercased()
            isPM = amPmIndicator == "PM"
            print("Matched 9PM pattern. Hour: \(hour), Minute: \(minute), AM/PM: \(amPmIndicator), isPM: \(isPM)")
            
        } else if patternIndex == 3 {
            // Pattern: 21:00 (no timezone)
            hour = Int(components[1]) ?? 0
            minute = Int(components[2]) ?? 0
            print("Matched 21:00 pattern. Hour: \(hour), Minute: \(minute)")
        } else {
            print("Unknown pattern index: \(patternIndex)")
            return nil
        }
        
        // Adjust hour for PM
        if isPM && hour < 12 {
            hour += 12
            print("Adjusted hour for PM: \(hour)")
        } else if !isPM && hour == 12 {
            hour = 0
            print("Adjusted 12AM to hour 0")
        }
        
        // Create date components
        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute
        
        // Get current date components for year, month, day
        let currentDate = Date()
        let calendar = Calendar.current
        let currentDateComponents = calendar.dateComponents([.year, .month, .day], from: currentDate)
        
        dateComponents.year = currentDateComponents.year
        dateComponents.month = currentDateComponents.month
        dateComponents.day = currentDateComponents.day
        
        print("Date components: \(dateComponents)")
        
        // Get timezone identifier
        let timezoneIdentifier = timezoneMap[timezoneString.uppercased()] ?? "UTC"
        print("Timezone identifier: \(timezoneIdentifier)")
        
        // Create source timezone
        guard let sourceTimeZone = TimeZone(identifier: timezoneIdentifier) else {
            print("Failed to create source timezone")
            return nil
        }
        
        // Create calendar with source timezone
        var sourceCalendar = Calendar.current
        sourceCalendar.timeZone = sourceTimeZone
        
        // Create date in source timezone
        guard let sourceDate = sourceCalendar.date(from: dateComponents) else {
            print("Failed to create source date")
            return nil
        }
        
        print("Source date: \(sourceDate)")
        
        // Format the original time
        let originalFormatter = DateFormatter()
        originalFormatter.dateFormat = "h:mm a"
        originalFormatter.timeZone = sourceTimeZone
        let originalTimeString = originalFormatter.string(from: sourceDate)
        
        // Format the converted time using the target timezone
        let targetFormatter = DateFormatter()
        targetFormatter.dateFormat = "h:mm a"
        targetFormatter.timeZone = targetTimezone
        
        // Check if the day has changed by comparing dates in their respective timezones
        var sourceCalendarForDay = Calendar.current
        sourceCalendarForDay.timeZone = sourceTimeZone
        
        var targetCalendarForDay = Calendar.current
        targetCalendarForDay.timeZone = targetTimezone
        
        let sourceComponents = sourceCalendarForDay.dateComponents([.year, .month, .day], from: sourceDate)
        let targetComponents = targetCalendarForDay.dateComponents([.year, .month, .day], from: sourceDate)
        
        print("Source components: \(sourceComponents)")
        print("Target components: \(targetComponents)")
        
        var dayIndicator = ""
        if let sourceDay = sourceComponents.day, let targetDay = targetComponents.day,
           let sourceMonth = sourceComponents.month, let targetMonth = targetComponents.month {
            // Check if we've crossed a month boundary
            if sourceMonth != targetMonth {
                if sourceMonth < targetMonth || (sourceMonth == 12 && targetMonth == 1) {
                    dayIndicator = " +1"
                } else {
                    dayIndicator = " -1"
                }
            } else if sourceDay != targetDay {
                if sourceDay < targetDay {
                    dayIndicator = " +1"
                } else {
                    dayIndicator = " -1"
                }
            }
        }
        
        let convertedTimeString = "\(targetFormatter.string(from: sourceDate))\(dayIndicator)"
        print("Day indicator: '\(dayIndicator)'")
        
        print("Original: \(originalTimeString), Converted: \(convertedTimeString)")
        
        return (originalTimeString, convertedTimeString)
    }
    
    func detectTimezone(from timeString: String) -> TimeZone? {
        // Dictionary of common timezone abbreviations
        let timezoneAbbreviations = [
            "EST": -5 * 3600,
            "EDT": -4 * 3600,
            "CST": -6 * 3600,
            "CDT": -5 * 3600,
            "MST": -7 * 3600,
            "MDT": -6 * 3600,
            "PST": -8 * 3600,
            "PDT": -7 * 3600,
            "GMT": 0,
            "UTC": 0
        ]
        
        // Convert to lowercase for case-insensitive comparison
        let lowercasedTimeString = timeString.lowercased()
        
        // Check for timezone abbreviations
        for (abbreviation, offset) in timezoneAbbreviations {
            if lowercasedTimeString.contains(abbreviation.lowercased()) {
                print("Detected timezone abbreviation: \(abbreviation)")
                return TimeZone(secondsFromGMT: offset)
            }
        }
        
        // Fallback to offset detection (existing code)
        let patterns = [
            #"UTC([+-]\d{1,2}):?(\d{2})?"#,
            #"GMT([+-]\d{1,2}):?(\d{2})?"#,
            #"([+-]\d{1,2}):?(\d{2})"#
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: timeString, range: NSRange(timeString.startIndex..., in: timeString)) {
                
                let hourRange = Range(match.range(at: 1), in: timeString)
                let minuteRange = Range(match.range(at: 2), in: timeString)
                
                if let hourRange = hourRange,
                   let hours = Int(timeString[hourRange]) {
                    let minutes = minuteRange.flatMap { Int(timeString[$0]) } ?? 0
                    let secondsFromGMT = (hours * 3600) + (minutes * 60)
                    return TimeZone(secondsFromGMT: secondsFromGMT)
                }
            }
        }
        
        print("No timezone detected in: \(timeString)")
        return nil
    }
} 