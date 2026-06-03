import Foundation
import CoreLocation

class LocationManager:
    NSObject,
    ObservableObject,
    CLLocationManagerDelegate {
    
    private let manager = CLLocationManager()
    
    @Published var coordinate =
    CLLocationCoordinate2D(
        latitude: 43.4145,
        longitude: -3.4168
    )
    
    @Published var gpsText = "GPS WAITING"
    @Published var path: [CLLocationCoordinate2D] = []
    @Published var rtkText = "RTK STANDBY"
    @Published var zoneStatus = "ZONE WAITING"
    
    override init() {
        super.init()
        
        manager.delegate = self
        manager.desiredAccuracy =
        kCLLocationAccuracyBestForNavigation
        
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
    }
    
    func setExternalRTK(
        _ coordinate: CLLocationCoordinate2D,
        path: [CLLocationCoordinate2D]
    ) {
        
        self.coordinate = coordinate
        self.path = path
        
        gpsText = String(
            format: "RTK %.5f %.5f",
            coordinate.latitude,
            coordinate.longitude
        )
        
        rtkText = "RTK EXTERNAL"
    }
    
    func updateZone(
        settings: HardwareSettings
    ) {
        
        let current =
        CLLocation(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )
        
        let center =
        CLLocation(
            latitude: settings.trainingZone.latitude,
            longitude: settings.trainingZone.longitude
        )
        
        let distance =
        current.distance(from: center)
        
        zoneStatus =
        distance <= settings.trainingZone.radiusMeters
        ? "ZONE INSIDE"
        : "ZONE OUTSIDE"
    }
    
    func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        
        guard let location = locations.last else {
            return
        }
        
        coordinate = location.coordinate
        
        gpsText = String(
            format: "GPS %.5f %.5f",
            location.coordinate.latitude,
            location.coordinate.longitude
        )
        
        rtkText =
        location.horizontalAccuracy < 2
        ? "RTK PRECISION"
        : "RTK GPS MODE"
        
        path.append(location.coordinate)
        
        if path.count > 300 {
            path.removeFirst()
        }
    }
}
