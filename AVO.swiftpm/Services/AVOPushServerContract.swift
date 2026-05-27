import Foundation

// MARK: - AVO Push Server Contract
// La app ya registra el token APNs mediante AVORemotePushManager.
// Para notificaciones con app cerrada, Raspberry debe enviar push remota APNs/Firebase usando ese token.
// Este archivo deja explícito el contrato esperado por servidor para v1.1.1 build 24.

struct AVOPushServerRegistrationPayload: Codable {
    let apnsToken: String
    let bundleId: String
    let deviceName: String
    let systemName: String
    let systemVersion: String
    let platform: String
    let environment: String
    let app: String
}

struct AVOPushServerEventPayload: Codable {
    let horse: String
    let event: String
    let title: String
    let body: String
    let priority: String
    let timestamp: Date
}
