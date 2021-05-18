import UIKit

extension BottomBannerViewController {
    func setupRootViews() {
        let children = [bottomBannerView, bottomPaddingView]
        view.addSubviews(children)
        setupRootViewConstraints()
    }
    
    func setupRootViewConstraints() {
        let constraints = [
            bottomBannerView.topAnchor.constraint(equalTo: view.topAnchor),
            bottomBannerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomBannerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomBannerView.bottomAnchor.constraint(equalTo: bottomPaddingView.topAnchor),
            
            bottomPaddingView.topAnchor.constraint(equalTo: view.safeBottomAnchor),
            bottomPaddingView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomPaddingView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomPaddingView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ]
        
        NSLayoutConstraint.activate(constraints)
    }
    
    func setupBottomBanner() {
                
        let horizontalDividerView = SeparatorView()
        horizontalDividerView.translatesAutoresizingMaskIntoConstraints = false
        bottomBannerView.addSubview(horizontalDividerView)
        self.horizontalDividerView = horizontalDividerView
        
        setupConstraints()
    }
    
    fileprivate func setupConstraints() {
        setupVerticalCompactLayout(&verticalCompactConstraints)
        setupVerticalRegularLayout(&verticalRegularConstraints)
        reinstallConstraints()
    }
    
    fileprivate func setupVerticalCompactLayout(_ c: inout [NSLayoutConstraint]) {
        c.append(bottomBannerView.heightAnchor.constraint(equalToConstant: 50))
        
        
        c.append(horizontalDividerView.heightAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale))
        c.append(horizontalDividerView.topAnchor.constraint(equalTo: bottomBannerView.topAnchor))
        c.append(horizontalDividerView.leadingAnchor.constraint(equalTo:bottomBannerView.leadingAnchor))
        c.append(horizontalDividerView.trailingAnchor.constraint(equalTo: bottomBannerView.trailingAnchor))
        
       
    }
    
    fileprivate func setupVerticalRegularLayout(_ c: inout [NSLayoutConstraint]) {
        c.append(bottomBannerView.heightAnchor.constraint(equalToConstant: 80))
        
        c.append(horizontalDividerView.heightAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale))
        c.append(horizontalDividerView.topAnchor.constraint(equalTo: bottomBannerView.topAnchor))
        c.append(horizontalDividerView.leadingAnchor.constraint(equalTo: bottomBannerView.leadingAnchor))
        c.append(horizontalDividerView.trailingAnchor.constraint(equalTo: bottomBannerView.trailingAnchor))
        
        
    }
    
    open func reinstallConstraints() {
        verticalCompactConstraints.forEach { $0.isActive = traitCollection.verticalSizeClass == .compact }
        verticalRegularConstraints.forEach { $0.isActive = traitCollection.verticalSizeClass != .compact }
    }
    
    open override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        reinstallConstraints()
    }
}
