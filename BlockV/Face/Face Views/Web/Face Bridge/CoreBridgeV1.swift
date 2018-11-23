//
//  BlockV AG. Copyright (c) 2018, all rights reserved.
//
//  Licensed under the BlockV SDK License (the "License"); you may not use this file or
//  the BlockV SDK except in compliance with the License accompanying it. Unless
//  required by applicable law or agreed to in writing, the BlockV SDK distributed under
//  the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF
//  ANY KIND, either express or implied. See the License for the specific language
//  governing permissions and limitations under the License.
//

import Foundation

//FIXME: Sould API calls use weak capture?

/// Core Bridge Version 1.0.0
class CoreBridgeV1: CoreBridge {

    // MARK: - Enums

    /// Represents the contract for the Web bridge (version 1).
    enum MessageName: String {
        case initialize         = "vatom.init"
        case getVatom           = "vatom.get"
        case getVatomChildren   = "vatom.children.get"
        case performAction      = "vatom.performAction"
        case getUserProfile     = "user.profile.fetch"
        case getUserAvatar      = "user.avatar.fetch"
    }

    // MARK: - Properties

    /// Reference to the face view which this bridge is interacting with.
    weak var faceView: FaceView?

    // MARK: - Initializer

    required init(faceView: FaceView) {
        self.faceView = faceView
    }

    // MARK: - Face Brige

    /// Returns `true` if the bridge is capable of processing the message and `false` otherwise.
    func canProcessMessage(_ message: String) -> Bool {
        if MessageName(rawValue: message) == nil {
            return false
        }
        return true
    }

    /// Processes the face script message and calls the completion handler with the result for encoding.
    func processMessage(_ scriptMessage: FaceScriptMessage, completion: @escaping Completion) {

        /*
         Sanity Check
         Explict force unwrap - the program is in an invalid state if the message cannot be created.
         */
        let message = MessageName(rawValue: scriptMessage.name)!
        printBV(info: "CoreBride_1: \(message)")

        // switch and route message
        switch message {
        case .initialize:
            self.setupBridge(completion)
        case .getVatom:
            // ensure caller supplied params
            guard let vatomID = scriptMessage.object["id"]?.stringValue else {
                let error = BridgeError.caller("Missing vAtom ID.")
                completion(nil, error)
                return
            }
            self.getVatom(withID: vatomID, completion: completion)

        case .getVatomChildren:
            // ensure caller supplied params
            guard let vatomID = scriptMessage.object["id"]?.stringValue else {
                let error = BridgeError.caller("Missing vAtom ID.")
                completion(nil, error)
                return
            }
            self.listChildren(forVatomID: vatomID, completion: completion)

        case .getUserProfile:
            // ensure caller supplied params
            guard let userID = scriptMessage.object["userID"]?.stringValue else {
                let error = BridgeError.caller("Missing user ID.")
                completion(nil, error)
                return
            }
            self.getPublicUser(forUserID: userID, completion: completion)

        case .getUserAvatar:
            // ensure caller supplied params
            guard let userID = scriptMessage.object["userID"]?.stringValue else {
                let error = BridgeError.caller("Missing user ID.")
                completion(nil, error)
                return
            }
            self.getPublicAvatarURL(forUserID: userID, completion: completion)

        case .performAction:
            // ensure caller supplied params
            guard
                let actionName = scriptMessage.object["actionName"]?.stringValue,
                let actionData = scriptMessage.object["actionData"]?.objectValue
                else {
                    let error = BridgeError.caller("Missing 'actionName' or 'actionData'.")
                    completion(nil, error)
                    return
            }
            self.performAction(name: actionName, payload: actionData, completion: completion)
        }

    }

    // MARK: - Bridge Responses

    private struct BRSetup: Encodable {
        let viewMode: String
        let user: BRUser
        let vatomInfo: BRVatom
        let viewer: [String: String] = [:]
    }

    private struct BRVatom: Encodable {
        let id: String
        let properties: JSON
        let resources: [String: URL]
    }

    private struct BRUser: Encodable {
        let id: String
        let firstName: String
        let lastName: String
        let avatarURL: String
    }

    // MARK: - Message Handling

    /// Invoked when a face would like to create the web bridge.
    ///
    /// Creates the bridge initializtion JSON object.
    ///
    /// - Parameter completion: Completion handler to call with JSON object to be passed to the webpage.
    private func setupBridge(_ completion: @escaping Completion) {

        // santiy check
        guard let faceView = self.faceView else {
            let error = BridgeError.viewer("Invalid state.")
            completion(nil, error)
            return
        }

        // view mode
        let viewMode = faceView.faceModel.properties.constraints.viewMode

        // async fetch current user
        BLOCKv.getCurrentUser { [weak self] (user, error) in

            // ensure no error
            guard let user = user, error == nil else {
                let bridgeError = BridgeError.viewer("Unable to fetch current user.")
                completion(nil, bridgeError)
                return
            }
            // encode url
            var encodedURL: URL?
            if let url = user.avatarURL {
                encodedURL = try? BLOCKv.encodeURL(url)
            }
            // build user
            let userInfo = BRUser(id: user.id,
                                  firstName: user.firstName,
                                  lastName: user.lastName,
                                  avatarURL: encodedURL?.absoluteString ?? "")

            // fetch backing vAtom
            self?.getVatomsFormatted(withIDs: [faceView.vatom.id], completion: { (vatoms, error) in

                // ensure no error
                guard error == nil else {
                    let bridgeError = BridgeError.viewer("Unable to fetch backing vAtom.")
                    completion(nil, bridgeError)
                    return
                }
                // ensure a single vatom
                guard let firstVatom = vatoms.first else {
                    let bridgeError = BridgeError.viewer("Unable to fetch backing vAtom.")
                    completion(nil, bridgeError)
                    return
                }
                // create bridge response
                let vatomInfo = BRVatom(id: firstVatom.id,
                                        properties: firstVatom.properties,
                                        resources: firstVatom.resources)
                let response = BRSetup(viewMode: viewMode,
                                       user: userInfo,
                                       vatomInfo: vatomInfo)
                // json-data encode the model
                guard let data = try? JSONEncoder.blockv.encode(response) else {
                    let bridgeError = BridgeError.viewer("Unable to encode response.")
                    completion(nil, bridgeError)
                    return
                }
                completion(data, nil)
            })

        }

    }

    /// Fetches the vAtom specified by the id.
    private func getVatom(withID id: String, completion: @escaping Completion) {

        self.getVatomsFormatted(withIDs: [id]) { (formattedVatoms, error) in

            // ensure no error
            guard error == nil else {
                completion(nil, error!)
                return
            }
            // ensure there is at least one vatom
            guard let formattedVatom = formattedVatoms.first else {
                completion(nil, BridgeError.viewer("vAtom not found."))
                return
            }
            let response = ["vatomInfo": formattedVatom]

            // json-data encode the model
            guard let data = try? JSONEncoder.blockv.encode(response) else {
                let bridgeError = BridgeError.viewer("Unable to encode response.")
                completion(nil, bridgeError)
                return
            }
            completion(data, nil)

        }

    }

    /// Fetches the children for the specifed vAtom.
    ///
    /// This method uses the inventory endpoint. Therefore, only *owned* vAtoms are returned.
    private func listChildren(forVatomID id: String, completion: @escaping Completion) {

        self.listChildrenFormatted(forVatomID: id) { (formattedVatoms, error) in

            // ensure no error
            guard error == nil else {
                completion(nil, error!)
                return
            }
            let vatomItems = formattedVatoms.map { ["vatomInfo": $0] }
            let response = ["items": vatomItems]
            // json-data encode the model
            guard let data = try? JSONEncoder.blockv.encode(response) else {
                let bridgeError = BridgeError.viewer("Unable to encode response.")
                completion(nil, bridgeError)
                return
            }
            completion(data, nil)
        }

    }

    /// Fetches the publically available properties of the user specified by the id.
    private func getPublicUser(forUserID id: String, completion: @escaping Completion) {

        BLOCKv.getPublicUser(withID: id) { (user, error) in

            // ensure no error
            guard let user = user, error == nil else {
                let bridgeError = BridgeError.viewer("Unable to fetch public user: \(id).")
                completion(nil, bridgeError)
                return
            }
            // encode url
            var encodedURL: URL?
            if let url = user.properties.avatarURL {
                encodedURL = try? BLOCKv.encodeURL(url)
            }
            // build response
            let response = BRUser(id: user.id,
                                  firstName: user.properties.firstName,
                                  lastName: user.properties.lastName,
                                  avatarURL: encodedURL?.absoluteString ?? "")

            // json-data encode the model
            guard let data = try? JSONEncoder.blockv.encode(response) else {
                let bridgeError = BridgeError.viewer("Unable to encode response.")
                completion(nil, bridgeError)
                return
            }
            completion(data, nil)

        }

    }

    private struct PublicAvatarFormat: Encodable {
        let id: String
        let avatarURL: String
    }

    /// Fetches the avatar URL of the user specified by the id.
    private func getPublicAvatarURL(forUserID id: String, completion: @escaping Completion) {

        BLOCKv.getPublicUser(withID: id) { (user, error) in

            // ensure no error
            guard let user = user, error == nil else {
                let bridgeError = BridgeError.viewer("Unable to fetch public user: \(id).")
                completion(nil, bridgeError)
                return
            }
            // encode url
            var encodedURL: URL?
            if let url = user.properties.avatarURL {
                encodedURL = try? BLOCKv.encodeURL(url)
            }
            // create avatar response
            let response = PublicAvatarFormat(id: user.id, avatarURL: encodedURL?.absoluteString ?? "")
            // json-data encode the model
            guard let data = try? JSONEncoder.blockv.encode(response) else {
                let bridgeError = BridgeError.viewer("Unable to encode response.")
                completion(nil, bridgeError)
                return
            }
            completion(data, nil)

        }

    }

    /// Performs the action.
    private func performAction(name: String, payload: [String: JSON], completion: @escaping Completion) {

        //FIXME: Add `userConsentRequired` check.

        //NOTE: The Client networking layer uses JSONSerialisation which does not play well with JSON.
        // Options:
        // a) Client must be updated to use JSON
        // b) Right here, JSON must be converted to [String: Any] (an inefficient conversion)

        do {
            // HACK: Convert JSON to Data to [String: Any]
            let data = try JSONEncoder.blockv.encode(payload)
            guard let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw BridgeError.viewer("Unable to encode data.")
            }
            BLOCKv.performAction(name: name, payload: dict) { (data, error) in
                // ensure no error
                guard let data = data, error == nil else {
                    let bridgeError = BridgeError.viewer("Unable to perform action: \(name).")
                    completion(nil, bridgeError)
                    return
                }
                completion(data, nil)
            }
        } catch {
            let error = BridgeError.viewer("Unable to encode data.")
            completion(nil, error)
        }
    }

}

// MARK: - Helpers

/*
 Vatoms are represented in a specific way in Face Bridge 1. These helpers convert the SDKs completion types
 into the Bridge Response (BR) completion types.
 */
private extension CoreBridgeV1 {

    /// Completes with the vAtom in bridge format.
    private typealias BFVatomCompletion = (_ formattedVatoms: [BRVatom], _ error: BridgeError?) -> Void

    /// Fetches the vAtom and completes with the *bridge format* representation.
    ///
    /// The method uses the vatom endpoint. Therefore, only *owned* vAtoms are returned.
    private func getVatomsFormatted(withIDs ids: [String], completion: @escaping BFVatomCompletion) {

        BLOCKv.getVatoms(withIDs: ids) { (vatoms, error) in

            // ensure no error
            guard error == nil else {
                let bridgeError = BridgeError.viewer("Unable to fetch backing vAtom.")
                completion([], bridgeError)
                return
            }
            // ensure there is at least one vatom
            guard let vatom = vatoms.first else {
                completion([], BridgeError.viewer("vAtom not found."))
                return
            }
            // convert vAtom into bridge format
            self.formatVatoms([vatom], completion: { (formattedVatoms) in
                let fvs = formattedVatoms
                completion(fvs, nil)
            })

        }

    }

    /// Fetches the children for the specifed vAtom.
    ///
    /// This method uses the inventory endpoint. Therefore, only *owned* vAtoms are returned.
    private func listChildrenFormatted(forVatomID id: String, completion: @escaping BFVatomCompletion) {

        BLOCKv.getInventory(id: id) { (vatoms, error) in

            // ensure no error
            guard error == nil else {
                let bridgeError = BridgeError.viewer("Unable to fetch children for vAtom \(id).")
                completion([], bridgeError)
                return
            }
            // format vatoms
            self.formatVatoms(vatoms, completion: { (formattedVatoms) in
                let fvs = formattedVatoms
                completion(fvs, nil)
            })

        }

    }

    private typealias FormatCompletion = (_ formattedVatoms: [BRVatom]) -> Void

    /// Returns the vatom transformed into the bridge format.
    ///
    /// Resources are encoded.
    private func formatVatoms(_ vatoms: [VatomModel], completion: @escaping FormatCompletion) {

        var formattedVatoms = [BRVatom]()
        for vatom in vatoms {
            // combine root and private props
            if let properties = try? JSON(codable: vatom.props) {
                if let privateProps = vatom.private {
                    // merge private properties into root properties
                    let combinedProperties = properties.updated(applying: privateProps)
                    // encode resource urls
                    var encodedResources: [String: URL] = [:]
                    vatom.props.resources.forEach { encodedResources[$0.name] = $0.encodedURL()}
                    let vatomF = BRVatom(id: vatom.id,
                                         properties: combinedProperties,
                                         resources: encodedResources)
                    formattedVatoms.append(vatomF)
                }
            } else {
                printBV(error: "vAtom to JSON failed: vAtom: \(vatom.id).")
            }

        }
        completion(formattedVatoms)
    }

}

extension VatomResourceModel {

    /// Returns the resource formatted and encoded for the bridge.
    fileprivate func encodedURL() -> URL {
        return (try? BLOCKv.encodeURL(self.url)) ?? self.url
    }

}
