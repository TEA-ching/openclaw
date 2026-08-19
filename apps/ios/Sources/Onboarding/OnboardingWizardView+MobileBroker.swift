import Foundation

extension OnboardingWizardView {
    /// Builds a mobile broker sign-in view model when `host` matches the mobile
    /// broker naming heuristic and no valid (non-expired) session exists yet.
    /// Returns nil when the connect flow should proceed as a normal manual
    /// gateway connection (either not a broker route, or already signed in --
    /// the stored session gets picked up automatically by the real connect
    /// path's extraHeadersProvider).
    func mobileBrokerSignInViewModelIfNeeded(
        host: String,
        port: Int,
        stableID: String,
        forceReconnect: Bool) -> MobileBrokerSignInSheet.ViewModel?
    {
        guard let checkURL = URL(string: "https://\(host)"), checkURL.isMobileBrokerHost else {
            return nil
        }

        let sessionStore = KeychainAccessGroupConfig.createSessionStore()
        if (try? sessionStore.retrieveSession(forGatewayStableID: stableID)) != nil,
           !sessionStore.isAccessTokenExpired(forGatewayStableID: stableID)
        {
            return nil
        }

        let brokerConfig = MobileBrokerConfig(hostname: host, port: port, useTLS: true)
        let authClient = MobileBrokerAuthClient(config: brokerConfig)
        return MobileBrokerSignInSheet.ViewModel(
            authClient: authClient,
            sessionStore: sessionStore,
            gatewayStableID: stableID,
            onComplete: { _ in
                Task {
                    await self.connectCurrentManualGateway(
                        host: host,
                        port: port,
                        forceReconnect: forceReconnect)
                }
            },
            onDismiss: {
                self.showMobileBrokerSignIn = false
            })
    }
}
