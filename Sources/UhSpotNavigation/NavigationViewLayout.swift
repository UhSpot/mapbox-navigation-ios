import UIKit

extension NavigationView {
    func setupConstraints() {
        mapView.topAnchor.constraint(equalTo: topAnchor).isActive = true
        mapView.leadingAnchor.constraint(equalTo: leadingAnchor).isActive = true
        mapView.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true
        mapView.trailingAnchor.constraint(equalTo: trailingAnchor).isActive = true
  
     
        resumeButton.leadingAnchor.constraint(equalTo: safeLeadingAnchor, constant: 10).isActive = true

        wayNameView.centerXAnchor.constraint(equalTo: centerXAnchor).isActive = true
        wayNameView.bottomAnchor.constraint(equalTo: bottomBannerContainerView.topAnchor, constant: -10).isActive = true
}

}
