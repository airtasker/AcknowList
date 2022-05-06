//
// AcknowPodParser.swift
//
// Copyright (c) 2015-2022 Vincent Tourraine (https://www.vtourraine.net)
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

import Foundation

/// Responsible for parsing a CocoaPods acknowledgements plist file.
open class AcknowPodParser {

    /// The root dictionary from the loaded plist file.
    let rootDictionary: [String: AnyObject]

    internal static let DefaultHeaderText = "This application makes use of the following third party libraries:"
    internal static let DefaultFooterText = "Generated by CocoaPods - https://cocoapods.org"

    /**
     Initializes the `AcknowPodParser` instance with a plist URL.

     - parameter plistURL: The URL to the acknowledgements plist file.

     - returns: The new `AcknowPodParser` instance.
     */
    public init(contentsOf plistURL: URL) {
        if let data = try? Data(contentsOf: plistURL),
           let root = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: AnyObject] {
            self.rootDictionary = root
        }
        else {
            self.rootDictionary = Dictionary()
        }
    }

    /**
     Initializes the `AcknowPodParser` instance with a plist path.

     - parameter plistPath: The path to the acknowledgements plist file.

     - returns: The new `AcknowPodParser` instance.
     */
    convenience public init(plistPath: String) {
        self.init(contentsOf: URL(fileURLWithPath: plistPath))
    }

    /**
     Parses the header and footer values.

     - return: a tuple with the header and footer values.
     */
    open func parseHeaderAndFooter() -> (header: String?, footer: String?) {
        let preferenceSpecifiers: AnyObject? = self.rootDictionary["PreferenceSpecifiers"]

        if let preferenceSpecifiers = preferenceSpecifiers, preferenceSpecifiers is [AnyObject] {
            let preferenceSpecifiersArray = preferenceSpecifiers as! [AnyObject]
            if let headerItem = preferenceSpecifiersArray.first,
                let footerItem = preferenceSpecifiersArray.last,
                let headerText = headerItem["FooterText"], headerItem is [String: String],
                let footerText = footerItem["FooterText"], footerItem is [String: String] {
                    return (headerText as! String?, footerText as! String?)
            }
        }

        return (nil, nil)
    }

    /**
     Parses the array of acknowledgements.

     - return: an array of `Acknow` instances.
     */
    open func parseAcknowledgements() -> [Acknow] {
        let preferenceSpecifiers: AnyObject? = rootDictionary["PreferenceSpecifiers"]

        if let preferenceSpecifiers = preferenceSpecifiers, preferenceSpecifiers is [AnyObject] {
            let preferenceSpecifiersArray = preferenceSpecifiers as! [AnyObject]

            // Remove the header and footer
            let ackPreferenceSpecifiers = preferenceSpecifiersArray.filter({ (object: AnyObject) -> Bool in
                if let firstObject = preferenceSpecifiersArray.first,
                    let lastObject = preferenceSpecifiersArray.last {
                        return (object.isEqual(firstObject) == false && object.isEqual(lastObject) == false)
                }
                return true
            })

            let acknowledgements = ackPreferenceSpecifiers.map({
                (preferenceSpecifier: AnyObject) -> Acknow in
                if let title = preferenceSpecifier["Title"] as! String?,
                    let text = preferenceSpecifier["FooterText"] as! String? {
                    let textWithoutNewlines = AcknowPodParser.filterOutPrematureLineBreaks(text: text)
                        return Acknow(title: title, text: textWithoutNewlines, license: preferenceSpecifier["License"] as? String)
                }
                else {
                    return Acknow(title: "", text: "", license: nil)
                }
            })

            return acknowledgements
        }

        return []
    }

    /**
     Filters out all premature line breaks (i.e. removes manual wrapping).

     - parameter text: The text to process.

     - returns: The text without the premature line breaks.
     */
    class func filterOutPrematureLineBreaks(text: String) -> String {
        // This regex replaces single newlines with spaces, while preserving multiple newlines used for formatting.
        // This prevents issues such as https://github.com/vtourraine/AcknowList/issues/41
        //
        // The issue arises when licenses contain premature line breaks in the middle of a sentance, often used
        // to limit license texts to 80 characters. When applied on an iPad, the resulting licenses are misaligned.
        //
        // The expression (?<=.)(\h)*(\R)(\h)*(?=.) can be broken down as:
        //
        //    (?<=.)  Positive lookbehind matching any non-newline character (matches but does not capture)
        //    (\h)*   Matches and captures zero or more horizontal spaces (trailing newlines)
        //    (\R)    Matches and captures any single Unicode-compliant newline character
        //    (\h)*   Matches and captures zero or more horizontal spaces (leading newlines)
        //    (?=.)   Positive lookahead matching any non-newline character (matches but does not capture)
        let singleNewLineFinder = try! NSRegularExpression(pattern: "(?<=.)(\\h)*(\\R)(\\h)*(?=.)")
        return singleNewLineFinder.stringByReplacingMatches(in: text, range: NSRange(0..<text.count), withTemplate: " ")
    }
}
