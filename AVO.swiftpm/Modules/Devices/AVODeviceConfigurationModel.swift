import Foundation

struct AVODeviceConfiguration: Codable, Equatable {
    var raspberryServerEnabled: Bool = true
    var raspberryHost: String = "192.168.1.50"
    var raspberryPort: Int = 7777

    var simEnabled: Bool = true
    var simAPN: String = "internet"
    var ntripHost: String = "gnss.cantabria.es"
    var ntripPort: Int = 2101
    var ntripMount: String = ""
    var ntripUser: String = "anonimo"
    var ntripPassword: String = "anonimo"

    var rtkEnabled: Bool = true
    var imuEnabled: Bool = true
    var girthEnabled: Bool = false
    var nfcEnabled: Bool = true
    var loraEnabled: Bool = true
    var bleEnabled: Bool = true

    var streamRateHz: Int = 20
}
