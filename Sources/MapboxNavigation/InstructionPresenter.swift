import UIKit
import MapboxDirections

protocol InstructionPresenterDataSource: AnyObject {
    var availableBounds: (() -> CGRect)! { get }
    var font: UIFont! { get }
    var textColor: UIColor! { get }
    var shieldHeight: CGFloat { get }
    func shieldColor(from textColor: String) -> UIColor
}

typealias DataSource = InstructionPresenterDataSource

extension NSAttributedString.Key {
    /**
     A string containing an abbreviation that can be substituted for the substring when there is not enough room to display the original substring.
     */
    static let abbreviation = NSAttributedString.Key(rawValue: "MBVisualInstructionComponentAbbreviation")
    
    /**
     A number indicating the priority for which the substring should be substituted with the abbreviation specified by the `NSAttributedString.Key.abbreviation` key.
     
     A substring with a lower abbreviation priority value should be abbreviated before a substring with a higher abbreviation priority value.
     */
    static let abbreviationPriority = NSAttributedString.Key(rawValue: "MBVisualInstructionComponentAbbreviationPriority")
}

class InstructionPresenter {
    private let instruction: VisualInstruction
    private weak var dataSource: DataSource?

    required init(_ instruction: VisualInstruction,
                  dataSource: DataSource,
                  spriteRepository: SpriteRepository = .shared,
                  traitCollection: UITraitCollection,
                  downloadCompletion: ShieldDownloadCompletion?) {
        self.instruction = instruction
        self.dataSource = dataSource
        self.spriteRepository = spriteRepository
        self.traitCollection = traitCollection
        self.onShieldDownload = downloadCompletion
    }

    typealias ShieldDownloadCompletion = (NSAttributedString) -> ()
    
    let onShieldDownload: ShieldDownloadCompletion?

    private let spriteRepository: SpriteRepository
    
    private let traitCollection: UITraitCollection
    
    func attributedText() -> NSAttributedString {
        guard let source = self.dataSource,
              let attributedTextRepresentation = self.attributedTextRepresentation(of: instruction,
                                                                                   dataSource: source,
                                                                                   spriteRepository: spriteRepository,
                                                                                   onImageDownload: completeShieldDownload).mutableCopy() as? NSMutableAttributedString else {
            return NSAttributedString()
        }
        
        // Collect abbreviation priorities embedded in the attributed text representation.
        let wholeRange = NSRange(location: 0, length: attributedTextRepresentation.length)
        var priorities = IndexSet()
        attributedTextRepresentation.enumerateAttribute(.abbreviationPriority,
                                                        in: wholeRange,
                                                        options: .longestEffectiveRangeNotRequired) { (priority, range, stop) in
            if let priority = priority as? Int {
                priorities.insert(priority)
            }
        }
        
        // Progressively abbreviate the attributed text representation, starting with the highest-priority abbreviations.
        let availableBounds = source.availableBounds()
        for currentPriority in priorities.sorted(by: <) {
            // If the attributed text representation already fits, we’re done.
            if attributedTextRepresentation.size().width <= availableBounds.width {
                break
            }
            
            // Look for substrings with the current abbreviation priority and replace them with the embedded abbreviations.
            let wholeRange = NSRange(location: 0, length: attributedTextRepresentation.length)
            attributedTextRepresentation.enumerateAttribute(.abbreviationPriority,
                                                            in: wholeRange,
                                                            options: []) { (priority, range, stop) in
                var abbreviationRange = range
                if priority as? Int == currentPriority,
                   let abbreviation = attributedTextRepresentation.attribute(.abbreviation,
                                                                             at: range.location,
                                                                             effectiveRange: &abbreviationRange) as? String {
                    assert(abbreviationRange == range, "Abbreviation and abbreviation priority should be applied to the same effective range.")
                    attributedTextRepresentation.replaceCharacters(in: abbreviationRange, with: abbreviation)
                }
            }
        }
        
        return attributedTextRepresentation
    }
    
    func attributedTextRepresentation(of instruction: VisualInstruction,
                                      dataSource: DataSource,
                                      spriteRepository: SpriteRepository,
                                      onImageDownload: @escaping CompletionHandler) -> NSAttributedString {
        var components = instruction.components
        
        let isShield: (_ key: VisualInstruction.Component?) -> Bool = { (component) in
            guard let key = component?.cacheKey else { return false }
            switch component {
            case .image(let representation, _):
                let image = spriteRepository.getShieldIcon(shield: representation.shield)
                ?? spriteRepository.legacyCache.image(forKey: key)
                return image != nil
            default:
                return spriteRepository.legacyCache.image(forKey: key) != nil
            }
        }
        
        components.removeSeparators { (precedingComponent, component, followingComponent) -> Bool in
            if case .exit(_) = component {
                // Remove exit components, which appear next to exit code components. Exit code components can be styled unambiguously, making the exit component redundant.
                return true
            } else if isShield(precedingComponent), case .delimiter(_) = component, isShield(followingComponent) {
                // Remove delimiter components flanked by image components, which the response includes only for backwards compatibility with text-only clients.
                return true
            } else {
                return false
            }
        }
        
        let defaultAttributes: [NSAttributedString.Key: Any] = [
            .font: dataSource.font as Any,
            .foregroundColor: dataSource.textColor as Any
        ]
        let attributedTextRepresentations = components.map { (component) -> NSAttributedString in
            switch component {
            case .delimiter(let text):
                return NSAttributedString(string: text.text, attributes: defaultAttributes)
            case .text(let text):
                let attributedString = NSMutableAttributedString(string: text.text, attributes: defaultAttributes)
                // Annotate the attributed text representation with an abbreviation.
                if let abbreviation = text.abbreviation, let abbreviationPriority = text.abbreviationPriority {
                    let wholeRange = NSRange(location: 0, length: attributedString.length)
                    attributedString.addAttributes([
                        .abbreviation: abbreviation,
                        .abbreviationPriority: abbreviationPriority,
                    ], range: wholeRange)
                }
                return attributedString
            case .image(let representation, let alternativeText):
                // Ideally represent the image component as a shield image.
                return attributedString(for: representation, in: spriteRepository, dataSource: dataSource, onImageDownload: onImageDownload)
                    // Fall back to a generic shield if no shield image is available.
                    ?? genericShield(text: alternativeText.text, dataSource: dataSource, cacheKey: component.cacheKey!)
                    // Finally, fall back to a plain text representation if the generic shield couldn’t be rendered.
                    ?? NSAttributedString(string: alternativeText.text, attributes: defaultAttributes)
            case .exit(_):
                preconditionFailure("Exit components should have been removed above")
            case .exitCode(let text):
                let exitSide: ExitSide = instruction.maneuverDirection == .left ? .left : .right
                return exitShield(side: exitSide,
                                  text: text.text,
                                  dataSource: dataSource,
                                  cacheKey: component.cacheKey!)
                    ?? NSAttributedString(string: text.text, attributes: defaultAttributes)
            case .lane(_, _, _):
                preconditionFailure("Lane component has no attributed string representation.")
            case .guidanceView(_, let alternativeText):
                return NSAttributedString(string: alternativeText.text, attributes: defaultAttributes)
            }
        }
        let separator = NSAttributedString(string: " ", attributes: defaultAttributes)
        return attributedTextRepresentations.joined(separator: separator)
    }
    
    func attributedString(for representation: VisualInstruction.Component.ImageRepresentation,
                          in repository: SpriteRepository,
                          dataSource: DataSource,
                          onImageDownload: @escaping CompletionHandler) -> NSAttributedString? {
        if let shield = representation.shield {
            // For US state road, use the legacy shield first, then fall back to use the generic shield icon.
            // The shield name for US state road is `circle-white` in Streets source v8 style.
            // For non US state road, use the generic shield icon first, then fall back to use the legacy shield.
            if shield.name == "circle-white" {
                if let legacyIcon = repository.legacyCache.image(forKey: representation.legacyCacheKey) {
                    return legacyAttributedString(for: legacyIcon, dataSource: dataSource)
                } else if representation.legacyCacheKey != nil {
                    spriteRepository.updateRepresentation(for: representation, completion: onImageDownload)
                    return nil
                }
            }
            if let shieldAttributedString = shieldAttributedString(for: representation, in: repository, dataSource: dataSource) {
                return shieldAttributedString
            }
        }

        if let legacyIcon = repository.legacyCache.image(forKey: representation.legacyCacheKey) {
            return legacyAttributedString(for: legacyIcon, dataSource: dataSource)
        }

        // Return nothing in the meantime, triggering downstream behavior (generic shield or text).
        // Update the SpriteRepository with the ImageRepresentation only when it has valid shield or legacy shield.
        if representation.shield != nil || representation.legacyCacheKey != nil {
            spriteRepository.updateRepresentation(for: representation, completion: onImageDownload)
        }
        return nil
    }
    
    private func legacyAttributedString(for legacyIcon: UIImage,
                                        dataSource: DataSource) -> NSAttributedString {
        let attachment = ShieldAttachment()
        attachment.font = dataSource.font
        attachment.image = legacyIcon
        return NSAttributedString(attachment: attachment)
    }

    private func shieldAttributedString(for representation: VisualInstruction.Component.ImageRepresentation,
                                        in repository: SpriteRepository,
                                        dataSource: DataSource) -> NSAttributedString? {
        guard let shield = representation.shield,
              let cachedImage = repository.getShieldIcon(shield: shield) else { return nil }

        let attachment = ShieldAttachment()
        attachment.font = dataSource.font
        let shieldColor = dataSource.shieldColor(from: shield.textColor)
        let fontSize = dataSource.font.with(multiplier: 0.4)
        attachment.image = cachedImage.withCenteredText(shield.text,
                                                        color: shieldColor,
                                                        font: fontSize)
        return NSAttributedString(attachment: attachment)
    }
    
    private func genericShield(text: String,
                               dataSource: DataSource,
                               cacheKey: String) -> NSAttributedString? {
        let additionalKey = GenericRouteShield.criticalHash(styleID: spriteRepository.styleID,
                                                            dataSource: dataSource,
                                                            traitCollection: traitCollection)
        let attachment = GenericShieldAttachment()
        
        let key = [cacheKey, additionalKey].joined(separator: "-")
        if let image = spriteRepository.legacyCache.image(forKey: key) {
            attachment.image = image
        } else {
            let genericRouteShield = GenericRouteShield(pointSize: dataSource.font.pointSize,
                                                        text: text)
            
            var appearance = GenericRouteShield.appearance()
            if traitCollection.userInterfaceIdiom == .carPlay {
                let carPlayTraitCollection = UITraitCollection(userInterfaceIdiom: .carPlay)
                
                if #available(iOS 12.0, *) {
                    let traitCollection = UITraitCollection(traitsFrom: [
                        carPlayTraitCollection,
                        UITraitCollection(userInterfaceStyle: self.traitCollection.userInterfaceStyle)
                    ])
                    
                    appearance = GenericRouteShield.appearance(for: traitCollection)
                } else {
                    appearance = GenericRouteShield.appearance(for: carPlayTraitCollection)
                }
            }
            
            genericRouteShield.foregroundColor = appearance.foregroundColor
            genericRouteShield.borderWidth = appearance.borderWidth
            genericRouteShield.borderColor = appearance.borderColor
            genericRouteShield.cornerRadius = appearance.cornerRadius
            
            guard let image = takeSnapshot(on: genericRouteShield) else { return nil }
            spriteRepository.legacyCache.store(image, forKey: key, toDisk: false, completion: nil)
            attachment.image = image
        }
        
        attachment.font = dataSource.font

        return NSAttributedString(attachment: attachment)
    }
    
    private func exitShield(side: ExitSide = .right,
                            text: String,
                            dataSource: DataSource,
                            cacheKey: String) -> NSAttributedString? {
        let additionalKey = ExitView.criticalHash(side: side,
                                                  styleID: spriteRepository.styleID,
                                                  dataSource: dataSource,
                                                  traitCollection: traitCollection)
        let attachment = ExitAttachment()

        let key = [cacheKey, additionalKey].joined(separator: "-")
        if let image = spriteRepository.legacyCache.image(forKey: key) {
            attachment.image = image
        } else {
            let exitView = ExitView(pointSize: dataSource.font.pointSize,
                                    side: side,
                                    text: text)
            
            var appearance = ExitView.appearance()
            if traitCollection.userInterfaceIdiom == .carPlay {
                let carPlayTraitCollection = UITraitCollection(userInterfaceIdiom: .carPlay)
                
                if #available(iOS 12.0, *) {
                    let traitCollection = UITraitCollection(traitsFrom: [
                        carPlayTraitCollection,
                        UITraitCollection(userInterfaceStyle: self.traitCollection.userInterfaceStyle)
                    ])
                    
                    appearance = ExitView.appearance(for: traitCollection)
                } else {
                    appearance = ExitView.appearance(for: carPlayTraitCollection)
                }
            }
            
            exitView.foregroundColor = appearance.foregroundColor
            exitView.borderWidth = appearance.borderWidth
            exitView.borderColor = appearance.borderColor
            exitView.cornerRadius = appearance.cornerRadius
            
            guard let image = takeSnapshot(on: exitView) else { return nil }
            spriteRepository.legacyCache.store(image, forKey: key, toDisk: false, completion: nil)
            attachment.image = image
        }
        
        attachment.font = dataSource.font
        
        return NSAttributedString(attachment: attachment)
    }
    
    private func completeShieldDownload() {
        onShieldDownload?(attributedText())
    }
    
    private func takeSnapshot(on view: UIView) -> UIImage? {
        let window: UIWindow?
        if let hostView = dataSource as? UIView, let hostWindow = hostView.window {
            window = hostWindow
        } else {
            window = UIApplication.shared.delegate?.window ?? nil
        }
        
        // Temporarily add the view to the view hierarchy for UIAppearance to work its magic.
        window?.addSubview(view)
        let image = view.imageRepresentation
        view.removeFromSuperview()
        return image
    }
}

protocol ImagePresenter: TextPresenter {
    var image: UIImage? { get }
}

protocol TextPresenter {
    var text: String? { get }
    var font: UIFont { get }
}

class ImageInstruction: NSTextAttachment, ImagePresenter {
    var font: UIFont = UIFont.systemFont(ofSize: UIFont.systemFontSize)
    var text: String?
    
    override func attachmentBounds(for textContainer: NSTextContainer?,
                                   proposedLineFragment lineFrag: CGRect,
                                   glyphPosition position: CGPoint,
                                   characterIndex charIndex: Int) -> CGRect {
        guard let image = image else {
            return super.attachmentBounds(for: textContainer,
                                          proposedLineFragment: lineFrag,
                                          glyphPosition: position,
                                          characterIndex: charIndex)
        }
        let yOrigin = (font.capHeight - image.size.height).rounded() / 2
        return CGRect(x: 0, y: yOrigin, width: image.size.width, height: image.size.height)
    }
}

class TextInstruction: ImageInstruction {}
class ShieldAttachment: ImageInstruction {}
class GenericShieldAttachment: ShieldAttachment {}
class ExitAttachment: ImageInstruction {}
