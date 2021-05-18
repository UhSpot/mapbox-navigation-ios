import UIKit
import MapboxCoreNavigation
import MapboxDirections

/**
 `InstructionsBannerViewDelegate` provides methods for reacting to user interactions in `InstructionsBannerView`.
 */
public protocol InstructionsBannerViewDelegate: class, UnimplementedLogging {
    /**
     Called when the user taps the `InstructionsBannerView`.
     */
    func didTapInstructionsBanner(_ sender: BaseInstructionsBannerView)
    
    
    /**
     Called when the user swipes either left, right, or down on the `InstructionsBannerView`
     */
    func didSwipeInstructionsBanner(_ sender: BaseInstructionsBannerView, swipeDirection direction: UISwipeGestureRecognizer.Direction)
}

public extension InstructionsBannerViewDelegate {
    /**
     `UnimplementedLogging` prints a warning to standard output the first time this method is called.
     */
    func didTapInstructionsBanner(_ sender: BaseInstructionsBannerView) {
        logUnimplemented(protocolType: InstructionsBannerViewDelegate.self, level: .debug)
    }
    
    func didDragInstructionsBanner(_ sender: BaseInstructionsBannerView) {
        //no-op, deprecated.
    }
    
    /**
     `UnimplementedLogging` prints a warning to standard output the first time this method is called.
     */
    func didSwipeInstructionsBanner(_ sender: BaseInstructionsBannerView, swipeDirection direction: UISwipeGestureRecognizer.Direction) {
        logUnimplemented(protocolType: InstructionsBannerViewDelegate.self, level: .debug)
    }
}

private protocol InstructionsBannerViewDelegateDeprecations {
    func didDragInstructionsBanner(_ sender: BaseInstructionsBannerView)
}

/// :nodoc:
@IBDesignable
open class InstructionsBannerView: BaseInstructionsBannerView, NavigationComponent {
    public func navigationService(_ service: NavigationService, didPassVisualInstructionPoint instruction: VisualInstructionBanner, routeProgress: RouteProgress) {
        update(for: instruction)
    }
}

/// :nodoc:
open class BaseInstructionsBannerView: UIControl {
    public weak var maneuverView: ManeuverView!
    public weak var primaryLabel: PrimaryLabel!
    public weak var secondaryLabel: SecondaryLabel!
    public weak var distanceLabel: DistanceLabel!
    public weak var dividerView: UIView!
    weak var _separatorView: UIView!
    public weak var separatorView: SeparatorView!
    public weak var stepListIndicatorView: StepListIndicatorView!
    
    @IBInspectable
    public var swipeable: Bool = false
    
    @IBInspectable
    public var showStepIndicator: Bool = true {
        didSet {
            stepListIndicatorView.isHidden = !showStepIndicator
        }
    }
    
    public weak var delegate: InstructionsBannerViewDelegate? {
        didSet {
           print("oopsie woopsie")
        }
    }
    
    weak var instructionDelegate: VisualInstructionDelegate? {
        didSet {
            primaryLabel.instructionDelegate = instructionDelegate
            secondaryLabel.instructionDelegate = instructionDelegate
        }
    }
    
    var centerYConstraints = [NSLayoutConstraint]()
    var baselineConstraints = [NSLayoutConstraint]()
    
    let distanceFormatter = DistanceFormatter()
    
    public var distance: CLLocationDistance? {
        didSet {
            print("oopsie woopsie")
        }
    }
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }
    
    func commonInit() {
        setupViews()
        setupLayout()
        centerYAlignInstructions()
        setupAvailableBounds()
        //stepListIndicatorView.isHidden = !showStepIndicator
    }
    
    @objc func swipedInstructionBannerLeft(_ sender: Any) {
        if !swipeable {
            return
        }

        if let gestureRecognizer = sender as? UISwipeGestureRecognizer, gestureRecognizer.state == .ended {
            if let delegate = delegate {
                delegate.didSwipeInstructionsBanner(self, swipeDirection: .left)
            }
        }
    }
    @objc func swipedInstructionBannerRight(_ sender: Any) {
        if !swipeable {
            return
        }
        
        if let gestureRecognizer = sender as? UISwipeGestureRecognizer, gestureRecognizer.state == .ended {
            if let delegate = delegate {
                delegate.didSwipeInstructionsBanner(self, swipeDirection: .right)
            }
        }
    }
    
    @objc func swipedInstructionBannerDown(_ sender: Any) {
        if let gestureRecognizer = sender as? UISwipeGestureRecognizer, gestureRecognizer.state == .ended {
            if showStepIndicator {
                stepListIndicatorView.isHidden = !stepListIndicatorView.isHidden
            }
            
            if let delegate = delegate {
                delegate.didSwipeInstructionsBanner(self, swipeDirection: .down)
                (delegate as? InstructionsBannerViewDelegateDeprecations)?.didDragInstructionsBanner(self)
            }
        }
    }
        
    @objc func tappedInstructionsBanner(_ sender: Any) {
        print("oopsie woopsie")
    }
    
    /**
     Updates the instructions banner info with a given `VisualInstructionBanner`.
     */
    public func update(for instruction: VisualInstructionBanner?) {
        let secondaryInstruction = instruction?.secondaryInstruction
      
    }
    
    override open func prepareForInterfaceBuilder() {
        super.prepareForInterfaceBuilder()
        maneuverView.isStart = true
        let component = VisualInstruction.Component.text(text: .init(text: "Primary text label", abbreviation: nil, abbreviationPriority: nil))
        let instruction = VisualInstruction(text: nil, maneuverType: .turn, maneuverDirection: .left, components: [component])
        primaryLabel.instruction = instruction
        
        distance = 100
    }
    
    /**
     Updates the instructions banner distance info for a given `RouteStepProgress`.
     */
    public func updateDistance(for currentStepProgress: RouteStepProgress) {
        let distanceRemaining = currentStepProgress.distanceRemaining
        distance = distanceRemaining > 5 ? distanceRemaining : 0
    }
    
    // MARK: - Layout
    static let padding: CGFloat = 16
    static let maneuverViewSize = CGSize(width: 38, height: 38)
    static let stepListIndicatorViewSize = CGSize(width: 30, height: 5)
    
    func setupViews() {
        let maneuverView = ManeuverView()
        maneuverView.backgroundColor = .clear
        maneuverView.translatesAutoresizingMaskIntoConstraints = false
        //addSubview(maneuverView)
        self.maneuverView = maneuverView
        
        let distanceLabel = DistanceLabel()
        distanceLabel.translatesAutoresizingMaskIntoConstraints = false
        distanceLabel.adjustsFontSizeToFitWidth = true
        distanceLabel.minimumScaleFactor = 16.0 / 22.0
        //addSubview(distanceLabel)
        self.distanceLabel = distanceLabel
        
        let primaryLabel = PrimaryLabel()
        primaryLabel.instructionDelegate = instructionDelegate
        primaryLabel.translatesAutoresizingMaskIntoConstraints = false
        primaryLabel.allowsDefaultTighteningForTruncation = true
        primaryLabel.adjustsFontSizeToFitWidth = true
        primaryLabel.numberOfLines = 1
        primaryLabel.minimumScaleFactor = 20.0 / 30.0
        primaryLabel.lineBreakMode = .byTruncatingTail
        //addSubview(primaryLabel)
        self.primaryLabel = primaryLabel
        
        let secondaryLabel = SecondaryLabel()
        secondaryLabel.instructionDelegate = instructionDelegate
        secondaryLabel.translatesAutoresizingMaskIntoConstraints = false
        secondaryLabel.allowsDefaultTighteningForTruncation = true
        secondaryLabel.numberOfLines = 1
        secondaryLabel.minimumScaleFactor = 20.0 / 26.0
        secondaryLabel.lineBreakMode = .byTruncatingTail
        //addSubview(secondaryLabel)
        self.secondaryLabel = secondaryLabel
        
        let dividerView = UIView()
        dividerView.translatesAutoresizingMaskIntoConstraints = false
        //addSubview(dividerView)
        self.dividerView = dividerView
        
        let _separatorView = UIView()
        _separatorView.translatesAutoresizingMaskIntoConstraints = false
        //addSubview(_separatorView)
        self._separatorView = _separatorView
        
        let separatorView = SeparatorView()
        separatorView.translatesAutoresizingMaskIntoConstraints = false
        //addSubview(separatorView)
        self.separatorView = separatorView
        
        let stepListIndicatorView = StepListIndicatorView()
        stepListIndicatorView.translatesAutoresizingMaskIntoConstraints = false
        //addSubview(stepListIndicatorView)
        self.stepListIndicatorView = stepListIndicatorView
        
        addTarget(self, action: #selector(BaseInstructionsBannerView.tappedInstructionsBanner(_:)), for: .touchUpInside)

        let swipeLeftGesture = UISwipeGestureRecognizer(target: self, action: #selector(BaseInstructionsBannerView.swipedInstructionBannerLeft(_:)))
        swipeLeftGesture.direction = .left
        //addGestureRecognizer(swipeLeftGesture)
        
        let swipeRightGesture = UISwipeGestureRecognizer(target: self, action: #selector(BaseInstructionsBannerView.swipedInstructionBannerRight(_:)))
        swipeRightGesture.direction = .right
        //addGestureRecognizer(swipeRightGesture)
        
        let swipeDownGesture = UISwipeGestureRecognizer(target: self, action: #selector(BaseInstructionsBannerView.swipedInstructionBannerDown(_:)))
        swipeDownGesture.direction = .down
        //addGestureRecognizer(swipeDownGesture)
    }
    
    func setupLayout() {
        // firstColumnWidth is the width of the left side of the banner containing the maneuver view and distance label
        let firstColumnWidth = BaseInstructionsBannerView.maneuverViewSize.width + BaseInstructionsBannerView.padding * 3
        
        // Distance label
       
    }
    
    // Aligns the instruction to the center Y (used for single line primary and/or secondary instructions)
    func centerYAlignInstructions() {
        //_separatorView.isHidden = false
        baselineConstraints.forEach { $0.isActive = false }
        centerYConstraints.forEach { $0.isActive = true }
    }
    
    // Aligns primary top to the top of the maneuver view and the secondary baseline to the distance baseline (used for multiline)
    func baselineAlignInstructions() {
        //_separatorView.isHidden = true
        centerYConstraints.forEach { $0.isActive = false }
        baselineConstraints.forEach { $0.isActive = true }
    }
    
    func setupAvailableBounds() {
        // Abbreviate if the instructions do not fit on one line
     
    }
}
