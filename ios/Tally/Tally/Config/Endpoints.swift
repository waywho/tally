import Foundation

enum Endpoints {
    #if DEBUG
    static let baseURL = URL(string: "http://localhost:3000")!
    #else
    static let baseURL = URL(string: "https://tally.example.com")!
    #endif

    static let pathConfigurationURL = baseURL.appendingPathComponent("/api/v1/path_configuration.json")
}
