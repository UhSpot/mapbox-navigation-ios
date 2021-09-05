import CoreLocation
import UIKit
import MapboxDirections
import MapboxCoreNavigation

/**
 A view controller that displays the current maneuver instruction as a “card” resembling a user notification. A subsequent maneuver is always partially visible on one side of the view; swiping to one side reveals the full maneuver.
 
 This class is an alternative to the more traditional banner interface provided by the `TopBannerViewController` class. To use `InstructionsCardViewController`, create an instance of it and pass it into the `NavigationOptions(styles:navigationService:voiceController:topBanner:bottomBanner:)` method.
 */
open class UhSpotCardViewController: UIViewController {
    typealias InstructionsCardCollectionLayout = UICollectionViewFlowLayout
    
    public var routeProgress: RouteProgress?
    var cardSize: CGSize {
        var cardSize = CGSize(width: Int(floor(UIScreen.main.bounds.width * 0.8)), height: 140)
        
        /* TODO: Identify the traitCollections to define the width of the cards */
        if let customSize = cardCollectionDelegate?.uhspotCardCollection(self, cardSizeFor: traitCollection) {
            cardSize = customSize
        }

        return cardSize
    }
    
    var uhspotCollectionView: UICollectionView!
    var instructionsCardLayout: InstructionsCardCollectionLayout!
    
    lazy var junctionView: JunctionView = {
        let view: JunctionView = .forAutoLayout()
        view.isHidden = true
        view.applyDefaultCornerRadiusShadow(cornerRadius: 4, shadowOpacity: 0.4)
        return view
    }()
    
    public private(set) var isInPreview = false
    public var currentStepIndex: Int?
    
    public var steps: [RouteStep]? {
        guard let stepIndex = routeProgress?.currentLegProgress.stepIndex, let steps = routeProgress?.currentLeg.steps else { return nil }
        var mutatedSteps = steps
        if mutatedSteps.count > 1 {
            mutatedSteps = Array(mutatedSteps.suffix(from: stepIndex))
            mutatedSteps.removeLast()
        }
        return mutatedSteps
    }
    
    var distancesFromCurrentLocationToManeuver: [CLLocationDistance]? {
        guard let progress = routeProgress, let steps = steps else { return nil }
        let distanceRemaining = progress.currentLegProgress.currentStepProgress.distanceRemaining
        let distanceBetweenSteps = [distanceRemaining] + progress.remainingSteps.map {$0.distance}
        guard let firstDistance = distanceBetweenSteps.first else { return nil }
        
        var distancesFromCurrentLocationToManeuver = [CLLocationDistance]()
        distancesFromCurrentLocationToManeuver.reserveCapacity(steps.count)
        
        var cumulativeDistance: CLLocationDistance = firstDistance > 5 ? firstDistance : 0
        distancesFromCurrentLocationToManeuver.append(cumulativeDistance)
        
        for index in 1..<distanceBetweenSteps.endIndex {
            let safeIndex = index < distanceBetweenSteps.endIndex ? index : distanceBetweenSteps.endIndex - 1
            let previousDistance = distanceBetweenSteps[safeIndex-1]
            let currentDistance = distanceBetweenSteps[safeIndex]
            let cardDistance = previousDistance + currentDistance
            cumulativeDistance += cardDistance > 5 ? cardDistance : 0
            distancesFromCurrentLocationToManeuver.append(cumulativeDistance)
        }
        
        return distancesFromCurrentLocationToManeuver
    }
    
    /**
     The InstructionsCardCollection delegate.
     */
    public weak var cardCollectionDelegate: InstructionsCardCollectionDelegate?
    
    fileprivate var contentOffsetBeforeSwipe = CGPoint(x: 0, y: 0)
    fileprivate var indexBeforeSwipe = IndexPath(row: 0, section: 0)
    fileprivate let cardCollectionCellIdentifier = NSStringFromClass(InstructionsCardCell.self)
    fileprivate let direction: UICollectionView.ScrollPosition = UIApplication.shared.userInterfaceLayoutDirection == .leftToRight ? .left : .right
    
    override open func viewDidLoad() {
        super.viewDidLoad()
        
        /* TODO: Custom dataSource */
        
        view.backgroundColor = .clear
        view.translatesAutoresizingMaskIntoConstraints = false
        view.clipsToBounds = false
        
        instructionsCardLayout = InstructionsCardCollectionLayout()
        instructionsCardLayout.scrollDirection = .horizontal
        uhspotCollectionView = UICollectionView(frame: .zero, collectionViewLayout: instructionsCardLayout)
        uhspotCollectionView.register(InstructionsCardCell.self, forCellWithReuseIdentifier: cardCollectionCellIdentifier)
        uhspotCollectionView.contentOffset = CGPoint(x: -5.0, y: 0.0)
        uhspotCollectionView.contentInset = UIEdgeInsets(top: 5.0, left: 5.0, bottom: 5.0, right: 5.0)
        uhspotCollectionView.dataSource = self
        uhspotCollectionView.delegate = self
        uhspotCollectionView.showsVerticalScrollIndicator = false
        uhspotCollectionView.showsHorizontalScrollIndicator = false
        uhspotCollectionView.backgroundColor = .clear
        uhspotCollectionView.isPagingEnabled = true
        uhspotCollectionView.translatesAutoresizingMaskIntoConstraints = false
        
        addSubviews()
        setConstraints()
        addObservers()
    }
    
    deinit {
        removeObservers()
    }
    
    // MARK: - Notification observer methods
    
    func addObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(orientationDidChange(_:)), name: UIDevice.orientationDidChangeNotification, object: nil)
    }
    
    func removeObservers() {
        NotificationCenter.default.removeObserver(self, name: UIDevice.orientationDidChangeNotification, object: nil)
    }
    
    @objc func orientationDidChange(_ notification: Notification) {
        instructionsCardLayout.invalidateLayout()
        handlePagingforScrollToItem(indexPath: indexBeforeSwipe)
    }
    
    open override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        instructionsCardLayout.invalidateLayout()
    }
    
    func addSubviews() {
        [uhspotCollectionView, junctionView].forEach(view.addSubview(_:))
    }
    
    func setConstraints() {
        let instructionCollectionViewContraints: [NSLayoutConstraint] = [
            uhspotCollectionView.topAnchor.constraint(equalTo: view.safeTopAnchor, constant: 5.0),
            uhspotCollectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            uhspotCollectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            uhspotCollectionView.heightAnchor.constraint(equalToConstant: cardSize.height),
            uhspotCollectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ]
        
        NSLayoutConstraint.activate(instructionCollectionViewContraints)
        
        let junctionViewConstraints: [NSLayoutConstraint] = [
            junctionView.topAnchor.constraint(equalTo: uhspotCollectionView.bottomAnchor),
            junctionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            junctionView.widthAnchor.constraint(equalToConstant: cardSize.width),
            junctionView.heightAnchor.constraint(equalTo: junctionView.widthAnchor, multiplier: 0.6) // aspect ratio fit
        ]
        
        NSLayoutConstraint.activate(junctionViewConstraints)
    }
    
    open func reloadDataSource() {
        if currentStepIndex == nil, let progress = routeProgress {
            currentStepIndex = progress.currentLegProgress.stepIndex
            uhspotCollectionView.reloadData()
        } else if let progress = routeProgress, let stepIndex = currentStepIndex, stepIndex != progress.currentLegProgress.stepIndex {
            currentStepIndex = progress.currentLegProgress.stepIndex
            uhspotCollectionView.reloadData()
        } else {
            updateVisibleInstructionCards(at: uhspotCollectionView.indexPathsForVisibleItems)
        }
    }
    
    open func updateVisibleInstructionCards(at indexPaths: [IndexPath]) {
        guard let legProgress = routeProgress?.currentLegProgress else { return }
        let remainingSteps = legProgress.remainingSteps
        guard let currentCardStep = remainingSteps.first else { return }
        for index in indexPaths.startIndex..<indexPaths.endIndex {
            let indexPath = indexPaths[index]
            if let container = instructionContainerView(at: indexPath), indexPath.row < remainingSteps.endIndex {
                let visibleStep = remainingSteps[indexPath.row]
                let distance = currentCardStep == visibleStep ? legProgress.currentStepProgress.distanceRemaining : visibleStep.distance
                container.updateInstructionCard(distance: distance)
            }
        }
    }
    
    func snapToIndexPath(_ indexPath: IndexPath) {
        guard let itemCount = steps?.count, itemCount >= 0 && indexPath.row < itemCount else { return }
        handlePagingforScrollToItem(indexPath: indexPath)
    }
    
    public func handlePagingforScrollToItem(indexPath: IndexPath) {
        if #available(iOS 14.0, *) {
            instructionsCardLayout.collectionView?.isPagingEnabled = false
            instructionsCardLayout.collectionView?.scrollToItem(at: indexPath, at: direction, animated: true)
            instructionsCardLayout.collectionView?.isPagingEnabled = true
            return
        }
        instructionsCardLayout.collectionView?.scrollToItem(at: indexPath, at: direction, animated: true)
    }
    
    public func stopPreview() {
        guard isInPreview else { return }
        uhspotCollectionView.scrollToItem(at: IndexPath(row: 0, section: 0), at: .left, animated: false)
        isInPreview = false
    }
    
    public func instructionContainerView(at indexPath: IndexPath) -> InstructionsCardContainerView? {
        guard let cell = uhspotCollectionView.cellForItem(at: indexPath),
              cell.subviews.count > 1 else {
            return nil
        }
        
        return cell.subviews[1] as? InstructionsCardContainerView
    }
    
    fileprivate func snappedIndexPath() -> IndexPath {
        guard let collectionView = instructionsCardLayout.collectionView, let itemCount = steps?.count else {
            return IndexPath(row: 0, section: 0)
        }
        
        let estimatedIndex = Int(round((collectionView.contentOffset.x + collectionView.contentInset.left) / (cardSize.width + 10.0)))
        let indexInBounds = max(0, min(itemCount - 1, estimatedIndex))
        return IndexPath(row: indexInBounds, section: 0)
    }
    
    fileprivate func scrollTargetIndexPath(for scrollView: UIScrollView, with velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) -> IndexPath {
        targetContentOffset.pointee = scrollView.contentOffset
        let itemCount = steps?.count ?? 0
        let velocityThreshold: CGFloat = 0.4
        
        let hasVelocityToSlideToNext = indexBeforeSwipe.row + 1 < itemCount && velocity.x > velocityThreshold
        let hasVelocityToSlidePrev = indexBeforeSwipe.row - 1 >= 0 && velocity.x < -velocityThreshold
        let didSwipe = hasVelocityToSlideToNext || hasVelocityToSlidePrev
        
        let scrollTargetIndexPath: IndexPath!
        
        if didSwipe {
            if hasVelocityToSlideToNext {
                scrollTargetIndexPath = IndexPath(row: indexBeforeSwipe.row + 1, section: 0)
            } else {
                scrollTargetIndexPath = IndexPath(row: indexBeforeSwipe.row - 1, section: 0)
            }
        } else {
            if scrollView.contentOffset.x - contentOffsetBeforeSwipe.x < -cardSize.width / 2 {
                scrollTargetIndexPath = IndexPath(row: indexBeforeSwipe.row - 1, section: 0)
            } else if scrollView.contentOffset.x - contentOffsetBeforeSwipe.x > cardSize.width / 2 {
                scrollTargetIndexPath = IndexPath(row: indexBeforeSwipe.row + 1, section: 0)
            } else {
                scrollTargetIndexPath = indexBeforeSwipe
            }
        }
        return scrollTargetIndexPath
    }
}

extension UhSpotCardViewController: UICollectionViewDelegate {
    public func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        indexBeforeSwipe = snappedIndexPath()
        contentOffsetBeforeSwipe = scrollView.contentOffset
    }
    
    public func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        let indexPath = scrollTargetIndexPath(for: scrollView, with: velocity, targetContentOffset: targetContentOffset)
        snapToIndexPath(indexPath)
        
        isInPreview = true
        let previewIndex = indexPath.row
        
        assert(previewIndex >= 0, "Preview Index should not be negative")
        if isInPreview, let steps = steps, previewIndex >= 0, previewIndex < steps.endIndex {
            let step = steps[previewIndex]
            cardCollectionDelegate?.uhspotCardCollection(self, didPreview: step)
        }
    }
}

extension UhSpotCardViewController: UICollectionViewDataSource {
    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return steps?.count ?? 0
    }
    
    open func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: cardCollectionCellIdentifier, for: indexPath) as! InstructionsCardCell
        
        guard let steps = steps, indexPath.row < steps.endIndex, let distanceRemaining = routeProgress?.currentLegProgress.currentStepProgress.distanceRemaining else {
            return cell
        }
        
        cell.container.delegate = self
        
        let step = steps[indexPath.row]
        let firstStep = indexPath.row == 0
        let distance = firstStep ? distanceRemaining : step.distance
        cell.configure(for: step, distance: distance)
        
        return cell
    }
}

extension UhSpotCardViewController: UICollectionViewDelegateFlowLayout {
    public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        return CGSize(width: cardSize.width, height: cardSize.height - 10)
    }
}

extension UhSpotCardViewController: NavigationComponent {
    public func navigationService(_ service: NavigationService, didUpdate progress: RouteProgress, with location: CLLocation, rawLocation: CLLocation) {
        routeProgress = progress
        reloadDataSource()
    }
    
    public func navigationService(_ service: NavigationService, didPassVisualInstructionPoint instruction: VisualInstructionBanner, routeProgress: RouteProgress) {
        self.routeProgress = routeProgress
        junctionView.update(for: instruction, service: service)
        reloadDataSource()
    }
    
    public func navigationService(_ service: NavigationService, didRerouteAlong route: Route, at location: CLLocation?, proactive: Bool) {
        self.currentStepIndex = nil
        self.routeProgress = service.routeProgress
        reloadDataSource()
    }
}

extension UhSpotCardViewController: InstructionsCardContainerViewDelegate {
    public func primaryLabel(_ primaryLabel: InstructionLabel, willPresent instruction: VisualInstruction, as presented: NSAttributedString) -> NSAttributedString? {
        return cardCollectionDelegate?.primaryLabel(primaryLabel, willPresent: instruction, as: presented)
    }
    
    public func secondaryLabel(_ secondaryLabel: InstructionLabel, willPresent instruction: VisualInstruction, as presented: NSAttributedString) -> NSAttributedString? {
        return cardCollectionDelegate?.secondaryLabel(secondaryLabel, willPresent: instruction, as: presented)
    }
}

extension UhSpotCardViewController: NavigationMapInteractionObserver {
    public func navigationViewController(didCenterOn location: CLLocation) {
        stopPreview()
    }
}
