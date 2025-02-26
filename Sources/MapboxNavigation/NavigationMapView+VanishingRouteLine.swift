import CoreLocation
import UIKit
import MapboxDirections
import MapboxCoreNavigation
import MapboxMaps

extension NavigationMapView {

    struct RoutePoints {
        var nestedList: [[[CLLocationCoordinate2D]]]
        var flatList: [CLLocationCoordinate2D]
    }
    
    struct RouteLineGranularDistances {
        var distance: Double
        var distanceArray: [RouteLineDistancesIndex]
    }
    
    struct RouteLineDistancesIndex {
        var point: CLLocationCoordinate2D
        var distanceRemaining: Double
    }
    
    // MARK: Customizing and Displaying the Route Line(s)
    
    func initPrimaryRoutePoints(route: Route) {
        routePoints = parseRoutePoints(route: route)
        routeLineGranularDistances = calculateGranularDistances(routePoints?.flatList ?? [])
    }
    
    /**
     Tranform the route data into nested arrays of legs -> steps -> coordinates.
     The first and last point of adjacent steps overlap and are duplicated.
     */
    func parseRoutePoints(route: Route) -> RoutePoints {
        let nestedList = route.legs.map { (routeLeg: RouteLeg) -> [[CLLocationCoordinate2D]] in
            return routeLeg.steps.map { (routeStep: RouteStep) -> [CLLocationCoordinate2D] in
                if let routeShape = routeStep.shape {
                    return routeShape.coordinates
                } else {
                    return []
                }
            }
        }
        let flatList = nestedList.flatMap { $0.flatMap { $0.compactMap { $0 } } }
        return RoutePoints(nestedList: nestedList, flatList: flatList)
    }
    
    /**
     Update the existing primary route line during active navigation.
     
     - parameter routeProgress: The current `RouteProgress`.
     - parameter coordinate: The current user location coordinate.
     - parameter redraw: A `Bool` value to decide whether the route is new. When style changes, `RouteController` did refresh route or reroute, the value
     should be set to `true`. When `RouteController` did update the `RouteProgress`, the value should be set to `false`.
     */
    public func updateRouteLine(routeProgress: RouteProgress, coordinate: CLLocationCoordinate2D?, shouldRedraw: Bool = false) {
        if shouldRedraw {
            show([routeProgress.route], legIndex: routeProgress.legIndex)
        }
        
        guard routeLineTracksTraversal && routes != nil else { return }
        guard !routeProgress.routeIsComplete else {
            removeRoutes()
            removeContinuousAlternativesRoutes()
            return
        }
        
        updateUpcomingRoutePointIndex(routeProgress: routeProgress)
        if shouldRedraw {
            offRouteDistanceCheckEnabled = false
            travelAlongRouteLine(to: coordinate)
            offRouteDistanceCheckEnabled = true
        } else {
            travelAlongRouteLine(to: coordinate)
        }
    }
    
    /**
     Find and cache the index of the upcoming [RouteLineDistancesIndex].
     */
    public func updateUpcomingRoutePointIndex(routeProgress: RouteProgress) {
        guard let completeRoutePoints = routePoints else {
            routeRemainingDistancesIndex = nil
            return
        }
        let currentLegProgress = routeProgress.currentLegProgress
        let currentStepProgress = routeProgress.currentLegProgress.currentStepProgress
        let currentLegSteps = completeRoutePoints.nestedList[routeProgress.legIndex]
        var allRemainingPoints = 0
        /**
         Find the count of remaining points in the current step.
         */
        let lineString = currentStepProgress.step.shape ?? LineString([])
        if currentStepProgress.distanceTraveled <= 0 {
            allRemainingPoints += currentLegSteps[currentLegProgress.stepIndex].dropLast().count
        } else if let startIndex = lineString.indexedCoordinateFromStart(distance: currentStepProgress.distanceTraveled)?.index,
                  lineString.coordinates.indices.contains(startIndex) {
            allRemainingPoints += lineString.coordinates.suffix(from: startIndex + 1).dropLast().count
        }
        
        /**
         Add to the count of remaining points all of the remaining points on the current leg, after the current step.
         */
        if currentLegProgress.stepIndex < currentLegSteps.endIndex {
            allRemainingPoints += currentLegSteps.suffix(from: currentLegProgress.stepIndex + 1).dropLast().flatMap{ $0.compactMap{ $0 } }.count
        }
        
        /**
         Add to the count of remaining points all of the remaining legs.
         */
        if routeProgress.legIndex < completeRoutePoints.nestedList.endIndex {
            allRemainingPoints += completeRoutePoints.nestedList.suffix(from: routeProgress.legIndex + 1).flatMap{ $0 }.map{ $0.count }.reduce(0, +)
        }
        
        /**
         After calculating the number of remaining points and the number of all points,  calculate the index of the upcoming point.
         */
        let allPoints = completeRoutePoints.flatList.count
        routeRemainingDistancesIndex = allPoints - allRemainingPoints - 1
    }
    
    func calculateGranularDistances(_ coordinates: [CLLocationCoordinate2D]) -> RouteLineGranularDistances? {
        if coordinates.isEmpty { return nil }
        var distance = 0.0
        var indexArray = [RouteLineDistancesIndex?](repeating: nil, count: coordinates.count)
        for index in stride(from: coordinates.count - 1, to: 0, by: -1) {
            let curr = coordinates[index]
            let prev = coordinates[index - 1]
            distance += curr.projectedDistance(to: prev)
            indexArray[index - 1] = RouteLineDistancesIndex(point: prev, distanceRemaining: distance)
        }
        indexArray[coordinates.count - 1] = RouteLineDistancesIndex(point: coordinates[coordinates.count - 1], distanceRemaining: 0.0)
        return RouteLineGranularDistances(distance: distance, distanceArray: indexArray.compactMap{ $0 })
    }
    
    func findDistanceToNearestPointOnCurrentLine(coordinate: CLLocationCoordinate2D, granularDistances: RouteLineGranularDistances, upcomingIndex: Int) -> CLLocationDistance {
        guard granularDistances.distanceArray.indices.contains(upcomingIndex) else { return 0.0 }

        var coordinates = [CLLocationCoordinate2D]()
        
        /**
         Takes the passed 10 points and the upcoming point of route to form a sliced polyline for distance calculation, incase of the curved shape of route.
         */
        for index in max(0, upcomingIndex - 10)...upcomingIndex  {
            let point = granularDistances.distanceArray[index].point
            coordinates.append(point)
        }

        let polyline = LineString(coordinates)

        if let closestCoordinateOnRoute = polyline.closestCoordinate(to: coordinate)?.coordinate {
            return coordinate.distance(to: closestCoordinateOnRoute)
        } else {
            return 0.0
        }
    }
    
    /**
     Updates the fractionTraveled along the route line from the origin point to the indicated point.
     
     - parameter coordinate: Current position of the user location.
     */
    func updateFractionTraveled(coordinate: CLLocationCoordinate2D) {
        guard let granularDistances = routeLineGranularDistances,
              let index = routeRemainingDistancesIndex,
              granularDistances.distanceArray.indices.contains(index) else { return }
        let traveledIndex = granularDistances.distanceArray[index]
        let upcomingPoint = traveledIndex.point
        
        if index > 0 && offRouteDistanceCheckEnabled {
            let distanceToLine = findDistanceToNearestPointOnCurrentLine(coordinate: coordinate, granularDistances: granularDistances, upcomingIndex: index + 1)
            if distanceToLine > offRouteDistanceUpdateThreshold {
                return
            }
        }
        
        /**
         Take the remaining distance from the upcoming point on the route and extends it by the exact position of the puck.
         */
        let remainingDistance = traveledIndex.distanceRemaining + upcomingPoint.projectedDistance(to: coordinate)
        
        /**
         Calculate the percentage of the route traveled.
         */
        if granularDistances.distance >= remainingDistance {
            let offset = (1.0 - remainingDistance / granularDistances.distance)
            if offset >= 0 {
                fractionTraveled = offset
            }
        }
    }
    
    /**
     Updates the route style layer and its casing style layer to gradually disappear as the user location puck travels along the displayed route.
     
     - parameter coordinate: Current position of the user location.
     */
    public func travelAlongRouteLine(to coordinate: CLLocationCoordinate2D?) {
        guard let route = routes?.first else { return }
        
        guard pendingCoordinateForRouteLine != coordinate,
              let preCoordinate = pendingCoordinateForRouteLine,
              let currentCoordinate = coordinate else { return }
        
        let distance = preCoordinate.distance(to: currentCoordinate)
        let meterPerPixel = getMetersPerPixelAtLatitude(currentCoordinate.latitude, Double(mapView.cameraState.zoom))
        guard distance >= meterPerPixel else { return }
            
        updateFractionTraveled(coordinate: currentCoordinate)
        
        let mainRouteLayerIdentifier = route.identifier(.route(isMainRoute: true))
        let mainRouteCasingLayerIdentifier = route.identifier(.routeCasing(isMainRoute: true))
        let restrictedAreaLayerIdentifier = route.identifier(.restrictedRouteAreaRoute)
        
        if fractionTraveled >= 1.0 {
            // In case if route was fully travelled - remove main route and its casing.
            do {
                try mapView.mapboxMap.style.removeLayer(withId: mainRouteLayerIdentifier)
                try mapView.mapboxMap.style.removeLayer(withId: mainRouteCasingLayerIdentifier)
                try mapView.mapboxMap.style.removeLayer(withId: restrictedAreaLayerIdentifier)
            } catch {
                Log.error("Failed to remove main route line layer.", category: .navigationUI)
            }
            
            fractionTraveled = 0.0
            return
        }
        
        let mainRouteLayerGradient = updateRouteLineGradientStops(fractionTraveled: fractionTraveled, gradientStops: currentLineGradientStops, baseColor: trafficUnknownColor)
        let mainRouteLayerGradientExpression = Expression.routeLineGradientExpression(mainRouteLayerGradient, lineBaseColor: trafficUnknownColor, isSoft: crossfadesCongestionSegments)
        setLayerLineGradient(for: mainRouteLayerIdentifier, exp: mainRouteLayerGradientExpression)
        
        let mainRouteCasingLayerGradient = routeLineCongestionGradient(route, fractionTraveled: fractionTraveled)
        let mainRouteCasingLayerGradientExpression = Expression.routeLineGradientExpression(mainRouteCasingLayerGradient, lineBaseColor: routeCasingColor)
        setLayerLineGradient(for: mainRouteCasingLayerIdentifier, exp: mainRouteCasingLayerGradientExpression)
        
        if showsRestrictedAreasOnRoute {
            let restrictedAreaLayerGradient = updateRouteLineGradientStops(fractionTraveled: fractionTraveled, gradientStops: currentRestrictedAreasStops, baseColor: routeRestrictedAreaColor)
            let restrictedAreaLayerGradientExpression = Expression.routeLineGradientExpression(restrictedAreaLayerGradient, lineBaseColor: traversedRouteColor)
            setLayerLineGradient(for: restrictedAreaLayerIdentifier, exp: restrictedAreaLayerGradientExpression)
        }
        
        pendingCoordinateForRouteLine = coordinate
    }
    
    func setLayerLineGradient(for layerId: String, exp: Expression) {
        if let data = try? JSONEncoder().encode(exp.self),
           let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []) {
            do {
                try mapView.mapboxMap.style.setLayerProperty(for: layerId,
                                                             property: "line-gradient",
                                                             value: jsonObject)
            } catch {
                Log.error("Failed to update route line gradient.", category: .navigationUI)
            }
        }
    }
    
    func lineLayerColorIfPresent(from route: Route?) -> UIColor? {
        guard let route = route else { return nil }
        
        var overriddenLineLayerColor: UIColor? = nil
        let mainRouteLayerIdentifier = route.identifier(.route(isMainRoute: true))
        let mainRouteSourceIdentifier = route.identifier(.source(isMainRoute: true, isSourceCasing: false))
        if let lineLayer = delegate?.navigationMapView(self,
                                                       routeLineLayerWithIdentifier: mainRouteLayerIdentifier,
                                                       sourceIdentifier: mainRouteSourceIdentifier),
           let color = lineLayer.lineColor {
            
            switch color {
            case .constant(let constant):
                overriddenLineLayerColor = UIColor(constant)
            case .expression(_):
                break
            }
        }
        
        return overriddenLineLayerColor
    }
    
    func lineLayerCasingColorIfPresent(from route: Route?) -> UIColor? {
        guard let route = route else { return nil }
        
        var overriddenLineLayerCasingColor: UIColor? = nil
        let mainRouteCasingLayerIdentifier = route.identifier(.routeCasing(isMainRoute: true))
        let mainRouteCasingSourceIdentifier = route.identifier(.source(isMainRoute: true, isSourceCasing: true))
        if let lineLayer = delegate?.navigationMapView(self,
                                                       routeCasingLineLayerWithIdentifier: mainRouteCasingLayerIdentifier,
                                                       sourceIdentifier: mainRouteCasingSourceIdentifier),
           let color = lineLayer.lineColor {
            
            switch color {
            case .constant(let constant):
                overriddenLineLayerCasingColor = UIColor(constant)
            case .expression(_):
                break
            }
        }
        
        return overriddenLineLayerCasingColor
    }
    
    func updateRouteLineGradientStops(fractionTraveled: Double, gradientStops: [Double: UIColor], baseColor: UIColor) -> [Double: UIColor] {
        // minimumSegment records the nearest smaller or equal stop and associated congestion color of the `fractionTraveled`, and then apply its color to the `fractionTraveled` stop.
        var minimumSegment: (Double, UIColor) = (0.0, baseColor)
        var filteredGradientStops = [Double: UIColor]()
        
        let overriddenLineLayerColor = lineLayerColorIfPresent(from: routes?.first)
        
        for (key, value) in gradientStops {
            if key > fractionTraveled {
                filteredGradientStops[key] = overriddenLineLayerColor ?? value
            } else if key >= minimumSegment.0 {
                minimumSegment = (key, overriddenLineLayerColor ?? value)
            }
        }
        
        filteredGradientStops[0.0] = traversedRouteColor
        let  nextDownFractionTraveled = Double(CGFloat(fractionTraveled).nextDown)
        if nextDownFractionTraveled >= 0.0 {
            filteredGradientStops[nextDownFractionTraveled] = traversedRouteColor
        }
        filteredGradientStops[fractionTraveled] = minimumSegment.1

        return filteredGradientStops
    }
    
    struct LineGradientSettings {
        let fractionTraveled: Double
        let isSoft: Bool
        let startingColor: UIColor
        let baseColor: UIColor
        let featureColor: (Turf.Feature) -> UIColor
    }
    
    func routeLineFeaturesGradient(_ routeLineFeatures: [Turf.Feature]? = nil, lineSettings: LineGradientSettings) -> [Double: UIColor] {
        var gradientStops = [Double: UIColor]()
        var distanceTraveled = 0.0
        
        if let routeLineFeatures = routeLineFeatures {
            let routeDistance = routeLineFeatures.compactMap { feature -> LocationDistance? in
                if case let .lineString(lineString) = feature.geometry {
                    return lineString.distance()
                } else {
                    return nil
                }
            }.reduce(0, +)
            // lastRecordSegment records the last segmentEndPercentTraveled and associated congestion color added to the gradientStops.
            var lastRecordSegment: (Double, UIColor) = (0.0, traversedRouteColor)
            // minimumSegment records the nearest smaller or equal stop and associated congestion color of the `fractionTraveled`, and then apply its color to the `fractionTraveled` stop.
            var minimumSegment: (Double, UIColor) = (0.0, lineSettings.startingColor)

            for (index, feature) in routeLineFeatures.enumerated() {
                let associatedFeatureColor = lineSettings.featureColor(feature)

                guard case let .lineString(lineString) = feature.geometry,
                      let distance = lineString.distance() else {
                    return gradientStops
                }
                let minimumPercentGap = 0.0000000000000002
                let stopGap = (routeDistance > 0.0) ? max(min(GradientCongestionFadingDistance, distance * 0.1) / routeDistance, minimumPercentGap) : minimumPercentGap
                
                if index == routeLineFeatures.startIndex {
                    minimumSegment = (0.0, associatedFeatureColor)
                    distanceTraveled = distanceTraveled + distance
                    
                    if index + 1 < routeLineFeatures.count {
                        let segmentEndPercentTraveled = distanceTraveled / routeDistance
                        let currentGradientStop = lineSettings.isSoft ? segmentEndPercentTraveled - stopGap : Double(CGFloat(segmentEndPercentTraveled).nextDown)
                        if currentGradientStop > lineSettings.fractionTraveled {
                            gradientStops[currentGradientStop] = associatedFeatureColor
                            lastRecordSegment = (currentGradientStop, associatedFeatureColor)
                        }
                        else {
                            minimumSegment = (0.0, traversedRouteColor)
                        }
                    }
                    
                    continue
                }
                
                if index == routeLineFeatures.endIndex - 1 {
                    if associatedFeatureColor == lastRecordSegment.1 {
                        gradientStops[lastRecordSegment.0] = nil
                    } else {
                        let segmentStartPercentTraveled = distanceTraveled / routeDistance
                        let currentGradientStop = lineSettings.isSoft ? segmentStartPercentTraveled + stopGap : Double(CGFloat(segmentStartPercentTraveled).nextUp)
                        if currentGradientStop > fractionTraveled {
                            gradientStops[currentGradientStop] = associatedFeatureColor
                        } else if currentGradientStop >= minimumSegment.0 {
                            minimumSegment = (currentGradientStop, associatedFeatureColor)
                        }
                    }
                    
                    continue
                }
                
                if associatedFeatureColor == lastRecordSegment.1 {
                    gradientStops[lastRecordSegment.0] = nil
                } else {
                    let segmentStartPercentTraveled = distanceTraveled / routeDistance
                    let currentGradientStop = lineSettings.isSoft ? segmentStartPercentTraveled + stopGap : Double(CGFloat(segmentStartPercentTraveled).nextUp)
                    if currentGradientStop > lineSettings.fractionTraveled {
                        gradientStops[currentGradientStop] = associatedFeatureColor
                    } else if currentGradientStop >= minimumSegment.0 {
                        minimumSegment = (currentGradientStop, associatedFeatureColor)
                    }
                }
                
                distanceTraveled = distanceTraveled + distance
                let segmentEndPercentTraveled = distanceTraveled / routeDistance
                let currentGradientStop = lineSettings.isSoft ? segmentEndPercentTraveled - stopGap : Double(CGFloat(segmentEndPercentTraveled).nextDown)
                
                if currentGradientStop > lineSettings.fractionTraveled {
                    gradientStops[currentGradientStop] = associatedFeatureColor
                    lastRecordSegment = (currentGradientStop, associatedFeatureColor)
                } else if currentGradientStop >= minimumSegment.0 {
                    minimumSegment = (currentGradientStop, associatedFeatureColor)
                }
            }
            
            gradientStops[0.0] = traversedRouteColor
            let currentGradientStop = Double(CGFloat(lineSettings.fractionTraveled).nextDown)
            if currentGradientStop >= 0.0 {
                gradientStops[currentGradientStop] = traversedRouteColor
            }
            gradientStops[lineSettings.fractionTraveled] = minimumSegment.1
        } else {
            let percentTraveled = CGFloat(lineSettings.fractionTraveled)
            gradientStops[0.0] = traversedRouteColor
            if percentTraveled.nextDown >= 0.0 {
                gradientStops[Double(percentTraveled.nextDown)] = traversedRouteColor
            }
            gradientStops[Double(percentTraveled)] = lineSettings.baseColor
        }
        
        return gradientStops
    }
    
    func routeLineCongestionGradient(_ route: Route? = nil,
                                     congestionFeatures: [Turf.Feature]? = nil,
                                     fractionTraveled: Double,
                                     isMain: Bool = true,
                                     isSoft: Bool = false) -> [Double: UIColor] {
        // If `congestionFeatures` is set to nil - check if overridden route line casing is used.
        let overriddenLineLayerColor: UIColor?
        if let _ = congestionFeatures {
            overriddenLineLayerColor = lineLayerColorIfPresent(from: route)
        } else {
            overriddenLineLayerColor = lineLayerCasingColorIfPresent(from: route)
        }
        
        let lineSettings = LineGradientSettings(fractionTraveled: fractionTraveled,
                                                isSoft: isSoft,
                                                startingColor: overriddenLineLayerColor ?? (isMain ? .trafficUnknown : .alternativeTrafficUnknown),
                                                baseColor: overriddenLineLayerColor ?? routeCasingColor,
                                                featureColor: {
            if let overriddenLineLayerColor = overriddenLineLayerColor {
                return overriddenLineLayerColor
            } else {
                if case let .boolean(isCurrentLeg) = $0.properties?[CurrentLegAttribute],
                   isCurrentLeg {
                    if case let .string(congestionLevel) = $0.properties?[CongestionAttribute] {
                        return self.congestionColor(for: congestionLevel, isMain: isMain)
                    } else {
                        return self.congestionColor(for: nil, isMain: isMain)
                    }
                }
                
                return self.routeCasingColor
            }
        })
        
        return routeLineFeaturesGradient(congestionFeatures, lineSettings: lineSettings)
    }
    
    func alternativeRouteLineGradient(_ fractionTraveled: Double, baseColor: UIColor) -> [Double: UIColor] {
        var gradient = [0.0: .defaultTraversedRouteColor,
                        1.0: baseColor]
        if fractionTraveled != 0.0 && fractionTraveled != 1.0 {
            gradient[fractionTraveled] = baseColor
        }
        
        return gradient
    }
    
    /**
     Given a congestion level, return its associated color.
     */
    func congestionColor(for congestionLevel: String?, isMain: Bool) -> UIColor {
        switch congestionLevel {
        case "low":
            return isMain ? trafficLowColor : alternativeTrafficLowColor
        case "moderate":
            return isMain ? trafficModerateColor : alternativeTrafficModerateColor
        case "heavy":
            return isMain ? trafficHeavyColor : alternativeTrafficHeavyColor
        case "severe":
            return isMain ? trafficSevereColor : alternativeTrafficSevereColor
        default:
            return isMain ? trafficUnknownColor : alternativeTrafficUnknownColor
        }
    }
    
    func routeLineRestrictionsGradient(_ restrictionFeatures: [Turf.Feature], fractionTraveled: Double) -> [Double: UIColor] {
        let lineSettings = LineGradientSettings(fractionTraveled: fractionTraveled,
                                                isSoft: false,
                                                startingColor: traversedRouteColor,
                                                baseColor: routeRestrictedAreaColor,
                                                featureColor: {
            if case let .boolean(isRestricted) = $0.properties?[RestrictedRoadClassAttribute],
               isRestricted {
                return self.routeRestrictedAreaColor
            }
            
            return .defaultTraversedRouteColor // forcing hiding non-restricted areas
        })
        
        return routeLineFeaturesGradient(restrictionFeatures, lineSettings: lineSettings)
    }
}
