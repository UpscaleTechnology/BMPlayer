//
//  BMSubtitles.swift
//  Pods
//
//  Created by BrikerMan on 2017/4/2.
//
//

import Foundation

public class BMSubtitles {
    public var groups: [Group] = []
    /// subtitles delay, positive:fast, negative:forward
    public var delay: TimeInterval = 0
    
    public struct Group: CustomStringConvertible {
        var index: Int
        var start: TimeInterval
        var end  : TimeInterval
        var text : String
        
        init(_ index: Int, _ start: NSString, _ end: NSString, _ text: NSString) {
            self.index = index
            self.start = Group.parseDuration(start as String)
            self.end   = Group.parseDuration(end as String)
            self.text  = text as String
        }
        
        static func parseDuration(_ fromStr:String) -> TimeInterval {
            var h: TimeInterval = 0.0, m: TimeInterval = 0.0, s: TimeInterval = 0.0, c: TimeInterval = 0.0
            let scanner = Scanner(string: fromStr)
            scanner.scanDouble(&h)
            scanner.scanString(":", into: nil)
            scanner.scanDouble(&m)
            scanner.scanString(":", into: nil)
            scanner.scanDouble(&s)
            scanner.scanString(",", into: nil)
            scanner.scanDouble(&c)
            return (h * 3600.0) + (m * 60.0) + s + (c / 1000.0)
        }
        
        public var description: String {
            return "Subtile Group ==========\nindex : \(index),\nstart : \(start)\nend   :\(end)\ntext  :\(text)"
        }
    }
    
    public init(url: URL, encoding: String.Encoding? = nil) {
        print("[BMSubtitles] Loading subtitles from: \(url)")
        DispatchQueue.global(qos: .background).async {[weak self] in
            do {
                let string: String
                if let encoding = encoding {
                    string = try String(contentsOf: url, encoding: encoding)
                } else {
                    string = try String(contentsOf: url)
                }
                self?.groups = BMSubtitles.parseSubRip(string) ?? []
                print("[BMSubtitles] Loaded \(self?.groups.count ?? 0) subtitle groups")
            } catch {
                print("| BMPlayer | [Error] failed to load \(url.absoluteString) \(error.localizedDescription)")
            }
        }
    }
    
    /**
     Search for target group for time
     
     - parameter time: target time
     
     - returns: result group or nil
     */
    public func search(for time: TimeInterval) -> Group? {
        let result = groups.first(where: { group -> Bool in
            let startTime = group.start - delay
            let endTime = group.end - delay
            return startTime <= time && endTime >= time
        })
        return result
    }
    
    /**
     Parse str string into Group Array
     
     - parameter payload: target string
     
     - returns: result group
     */
    fileprivate static func parseSubRip(_ payload: String) -> [Group]? {
        var groups: [Group] = []
        let lines = payload.components(separatedBy: .newlines)
        var i = 0
        
        while i < lines.count {
            // Skip empty lines
            while i < lines.count && lines[i].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                i += 1
            }
            
            if i >= lines.count { break }
            
            // Get subtitle index
            let indexString = lines[i].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !indexString.isEmpty,
                  let index = Int(indexString) else {
                i += 1
                continue
            }
            i += 1
            
            if i >= lines.count { break }
            
            // Get time line
            let timeLine = lines[i].trimmingCharacters(in: .whitespacesAndNewlines)
            let timeComponents = timeLine.components(separatedBy: " --> ")
            
            guard timeComponents.count == 2,
                  let startString = timeComponents.first?.trimmingCharacters(in: .whitespacesAndNewlines),
                  let endString = timeComponents.last?.trimmingCharacters(in: .whitespacesAndNewlines) else {
                i += 1
                continue
            }
            i += 1
            
            // Get subtitle text (can be multiple lines)
            var textLines: [String] = []
            while i < lines.count {
                let line = lines[i].trimmingCharacters(in: .whitespacesAndNewlines)
                if line.isEmpty {
                    break
                }
                textLines.append(line)
                i += 1
            }
            
            let text = textLines.joined(separator: "\n")
            
            if !text.isEmpty {
                let group = Group(index, startString as NSString, endString as NSString, text as NSString)
                groups.append(group)
            }
        }
        
        print("[BMSubtitles] Successfully parsed \(groups.count) subtitle groups")
        return groups
    }
}

