import Foundation

/**
 * WordPress Configuration
 */
@objc class AppConfiguration: NSObject {
    @objc static let isJetpack: Bool = false
    @objc static let allowSiteCreation: Bool = true
    @objc static let jetpackLogin: Bool = false
    @objc static let allowSignUp: Bool = true
}
