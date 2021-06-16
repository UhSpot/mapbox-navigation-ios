import UIKit
import MapboxCoreNavigation
import MapboxNavigation
import Mapbox
import CoreLocation
import AVFoundation
import MapboxDirections
import Turf

class UhSpotViewController: UIViewController, MGLMapViewDelegate {
    var destination: MGLPointAnnotation!
    let directions = Directions.shared
    var navigationService: NavigationService!
    var simulateLocation = false

    var userIndexedRoute: IndexedRoute?
    
    var userRouteOptions: RouteOptions?
    
    @IBOutlet var mapView: NavigationMapView!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        let locationManager = simulateLocation ? SimulatedLocationManager(route: userIndexedRoute!.0) : NavigationLocationManager()
        navigationService = MapboxNavigationService(route: userIndexedRoute!.0, routeIndex: userIndexedRoute!.1, routeOptions: userRouteOptions!, locationSource: locationManager, simulating: simulateLocation ? .always : .onPoorGPS)
        
        mapView.delegate = self
        mapView.compassView.isHidden = true
        

        // Add listeners for progress updates
        resumeNotifications()

        // Start navigation
        navigationService.start()
        
        // Center map on user
        mapView.recenterMap()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // This applies a default style to the top banner.
        DayStyle().apply()
    }

    deinit {
        suspendNotifications()
    }

    func resumeNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(progressDidChange(_ :)), name: .routeControllerProgressDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(rerouted(_:)), name: .routeControllerDidReroute, object: nil)
    }

    func suspendNotifications() {
        NotificationCenter.default.removeObserver(self, name: .routeControllerProgressDidChange, object: nil)
        NotificationCenter.default.removeObserver(self, name: .routeControllerDidReroute, object: nil)
        NotificationCenter.default.removeObserver(self, name: .routeControllerDidPassVisualInstructionPoint, object: nil)
    }

    func mapView(_ mapView: MGLMapView, didFinishLoading style: MGLStyle) {
        self.mapView.show([navigationService.route])
    }

    // Notifications sent on all location updates
    @objc func progressDidChange(_ notification: NSNotification) {
        // do not update if we are previewing instruction steps
        
        let routeProgress = notification.userInfo![RouteController.NotificationUserInfoKey.routeProgressKey] as! RouteProgress
        let location = notification.userInfo![RouteController.NotificationUserInfoKey.locationKey] as! CLLocation
        
        // Add maneuver arrow
        if routeProgress.currentLegProgress.followOnStep != nil {
            mapView.addArrow(route: routeProgress.route, legIndex: routeProgress.legIndex, stepIndex: routeProgress.currentLegProgress.stepIndex + 1)
        } else {
            mapView.removeArrow()
        }
        
        
        // Update the user puck
        mapView.updateCourseTracking(location: location, animated: true)
    }

    // Fired when the user is no longer on the route.
    // Update the route on the map.
    @objc func rerouted(_ notification: NSNotification) {
        self.mapView.removeWaypoints()
        self.mapView.show([navigationService.route])
    }

    @IBAction func cancelButtonPressed(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }
    
    @IBAction func recenterMap(_ sender: Any) {
        mapView.recenterMap()
    }


    

}
