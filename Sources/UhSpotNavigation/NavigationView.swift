import UIKit

/**
 A view that represents the root view of the MapboxNavigation drop-in UI.
 
 ## Components
 
 1. InstructionsBannerView
 2. InformationStackView
 3. BottomBannerView
 4. ResumeButton
 5. WayNameLabel
 6. FloatingStackView
 7. NavigationMapView
 8. SpeedLimitView
 
 ```
 +--------------------+
 |         1          |
 +--------------------+
 |         2          |
 +---+------------+---+
 | 8 |            |   |
 +---+            | 6 |
 |                |   |
 |         7      +---+
 |                    |
 |                    |
 |                    |
 +------------+       |
 |  4  ||  5  |       |
 +------------+-------+
 |         3          |
 +--------------------+
 ```
 */
@IBDesignable
open class NavigationView: UIView {
    private enum Constants {
        static let endOfRouteHeight: CGFloat = 260.0
        static let buttonSpacing: CGFloat = 8.0
    }
       
    
    private enum Images {
        static let overview = UIImage(named: "overview", in: .mapboxNavigation, compatibleWith: nil)!.withRenderingMode(.alwaysTemplate)
        static let volumeUp = UIImage(named: "volume_up", in: .mapboxNavigation, compatibleWith: nil)!.withRenderingMode(.alwaysTemplate)
        static let volumeOff =  UIImage(named: "volume_off", in: .mapboxNavigation, compatibleWith: nil)!.withRenderingMode(.alwaysTemplate)
        static let feedback = UIImage(named: "feedback", in: .mapboxNavigation, compatibleWith: nil)!.withRenderingMode(.alwaysTemplate)
    }
    
    lazy var mapView: NavigationMapView = {
        let map: NavigationMapView = .forAutoLayout(frame: self.bounds)
        map.navigationMapViewDelegate = delegate
        map.courseTrackingDelegate = delegate
        map.showsUserLocation = true
        return map
    }()
    
    
    lazy var overviewButton = FloatingButton.rounded(image: Images.overview)
    lazy var muteButton = FloatingButton.rounded(image: Images.volumeUp, selectedImage: Images.volumeOff)
    lazy var reportButton = FloatingButton.rounded(image: Images.feedback)
    
    
    var floatingButtons : [UIButton]? {
        didSet {
            clearStackViews()
            setupStackViews()
        }
    }
    
    lazy var resumeButton: ResumeButton = .forAutoLayout()
    
    lazy var wayNameView: WayNameView = {
        let view: WayNameView = .forAutoLayout(hidden: true)
        view.clipsToBounds = true
        view.layer.borderWidth = 1.0 / UIScreen.main.scale
        return view
    }()
    
    lazy var speedLimitView: SpeedLimitView = .forAutoLayout(hidden: true)
    
    lazy var topBannerContainerView: BannerContainerView = .forAutoLayout()
    
    lazy var bottomBannerContainerView: BannerContainerView = .forAutoLayout()

    weak var delegate: NavigationViewDelegate? {
        didSet {
            updateDelegates()
        }
    }
    
    //MARK: - Initializers
    
    convenience init(delegate: NavigationViewDelegate) {
        self.init(frame: .zero)
        self.delegate = delegate
        updateDelegates() //this needs to be called because didSet's do not fire in init contexts.
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }
    
    func commonInit() {
        setupViews()
    }
    
    
    func setupViews() {
        let children: [UIView] = [
            mapView,
            topBannerContainerView,
            resumeButton,
            wayNameView,
            speedLimitView,
            bottomBannerContainerView
        ]
        
        addSubviews(children)
    }
    
    open override func prepareForInterfaceBuilder() {
        super.prepareForInterfaceBuilder()
        DayStyle().apply()
        [mapView, topBannerContainerView, bottomBannerContainerView].forEach( { $0.prepareForInterfaceBuilder() })
        wayNameView.text = "Street Label"
    }
    
    private func updateDelegates() {
        mapView.navigationMapViewDelegate = delegate
        mapView.courseTrackingDelegate = delegate
    }
}

protocol NavigationViewDelegate: NavigationMapViewDelegate, InstructionsBannerViewDelegate, NavigationMapViewCourseTrackingDelegate, VisualInstructionDelegate {
    func navigationView(_ view: NavigationView, didTapCancelButton: CancelButton)
}
