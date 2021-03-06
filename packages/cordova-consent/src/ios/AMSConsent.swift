@objc(AMSConsent)
class AMSConsent: CDVPlugin {
    static var forms = Dictionary<Int, Any>()
    
    var readyCallbackId: String!
    
    override func pluginInitialize() {
        super.pluginInitialize()
    }
    
    deinit {
        readyCallbackId = nil
    }
    
    @objc(ready:)
    func ready(command: CDVInvokedUrlCommand) {
        readyCallbackId = command.callbackId
        
        self.emit(eventType: "ready")
    }
    
    @objc(isRequestLocationInEeaOrUnknown:)
    func isRequestLocationInEeaOrUnknown(command: CDVInvokedUrlCommand) {
        let result = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: PACConsentInformation.sharedInstance.isRequestLocationInEEAOrUnknown)
        self.commandDelegate!.send(result, callbackId: command.callbackId)
    }
    
    @objc(addTestDevice:)
    func addTestDevice(command: CDVInvokedUrlCommand) {
        guard let deviceId = command.argument(at: 0) as? String
            else {
                let result = CDVPluginResult(status: CDVCommandStatus_ERROR, messageAs: false)
                self.commandDelegate!.send(result, callbackId: command.callbackId)
                return
        }
        PACConsentInformation.sharedInstance.debugIdentifiers?.append(deviceId)
        
        let result = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: true)
        self.commandDelegate!.send(result, callbackId: command.callbackId)
    }
    
    @objc(setDebugGeography:)
    func setDebugGeography(command: CDVInvokedUrlCommand) {
        guard let geography = command.argument(at: 0) as? String
            else {
                let result = CDVPluginResult(status: CDVCommandStatus_ERROR, messageAs: false)
                self.commandDelegate!.send(result, callbackId: command.callbackId)
                return
        }
        
        if geography == "EEA" {
            PACConsentInformation.sharedInstance.debugGeography = PACDebugGeography.EEA
        } else if geography == "NOT_EEA" {
            PACConsentInformation.sharedInstance.debugGeography = PACDebugGeography.notEEA
        } else {
            PACConsentInformation.sharedInstance.debugGeography = PACDebugGeography.disabled
        }
        let result = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: true)
        self.commandDelegate!.send(result, callbackId: command.callbackId)
    }
    
    @objc(checkConsent:)
    func checkConsent(command: CDVInvokedUrlCommand) {
        guard let publisherIds = command.argument(at: 0) as? Array<String>
            else {
                let result = CDVPluginResult(status: CDVCommandStatus_ERROR, messageAs: false)
                self.commandDelegate!.send(result, callbackId: command.callbackId)
                return
        }
        PACConsentInformation.sharedInstance.requestConsentInfoUpdate(forPublisherIdentifiers: publisherIds) {(_ error: Error?) -> Void in
            if let error = error {
                let result = CDVPluginResult(status: CDVCommandStatus_ERROR, messageAs: error.localizedDescription)
                self.commandDelegate!.send(result, callbackId: command.callbackId)
            } else {
                let status =
                    PACConsentInformation.sharedInstance.consentStatus
                let result = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: "\(status)")
                self.commandDelegate!.send(result, callbackId: command.callbackId)
            }
        }
    }
    
    @objc(loadConsentForm:)
    func loadConsentForm(command: CDVInvokedUrlCommand) {
        guard let opts = command.argument(at: 0) as? NSDictionary,
            let id = opts.value(forKey: "id") as? Int,
            let privacyUrlStr = opts.value(forKey: "privacyUrl") as? String,
            let privacyUrl = URL(string: privacyUrlStr),
            let form = PACConsentForm(applicationPrivacyPolicyURL: privacyUrl)
            else {
                let result = CDVPluginResult(status: CDVCommandStatus_ERROR, messageAs: false)
                self.commandDelegate!.send(result, callbackId: command.callbackId)
                return
        }
        form.shouldOfferPersonalizedAds = true
        form.shouldOfferNonPersonalizedAds = true
        form.shouldOfferAdFree = true
        AMSConsent.forms[id] = form
        form.load {(_ error: Error?) -> Void in
            if let error = error {
                self.emit(eventType: "consent.form.error", data: [
                    "errorDescription": error.localizedDescription])
                return
            } else {
                self.emit(eventType: "consent.form.loaded")
            }
        }
        
        let result = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: true)
        self.commandDelegate!.send(result, callbackId: command.callbackId)
    }
    
    @objc(showConsentForm:)
    func showConsentForm(command: CDVInvokedUrlCommand) {
        guard let opts = command.argument(at: 0) as? NSDictionary,
            let id = opts.value(forKey: "id") as? Int,
            let form = AMSConsent.forms[id] as? PACConsentForm
            else {
                let result = CDVPluginResult(status: CDVCommandStatus_ERROR, messageAs: false)
                self.commandDelegate!.send(result, callbackId: command.callbackId)
                return
        }
        
        form.present(from: self.viewController) { (error, userPrefersAdFree) in
            if let error = error {
                // Handle error.
                let result = CDVPluginResult(status: CDVCommandStatus_ERROR, messageAs: error.localizedDescription)
                self.commandDelegate!.send(result, callbackId: command.callbackId)
            } else if userPrefersAdFree {
                // User prefers to use a paid version of the app.
                let result = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: true)
                self.commandDelegate!.send(result, callbackId: command.callbackId)
            } else {
                // Check the user's consent choice.
                let status =
                    PACConsentInformation.sharedInstance.consentStatus
                let result = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: "\(status)")
                self.commandDelegate!.send(result, callbackId: command.callbackId)
            }
        }
    }
    
    func emit(eventType: String, data: Any = false) {
        let result = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: ["type": eventType, "data": data])
        result?.setKeepCallbackAs(true)
        self.commandDelegate!.send(result, callbackId: readyCallbackId)
    }
}

