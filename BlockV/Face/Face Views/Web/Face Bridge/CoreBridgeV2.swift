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

/// Core Bridge (Version 2.0.0)
///
/// Bridges into the Core module.
class CoreBridgeV2: CoreBridge {

    // MARK: - Enums

    /// Represents the contract for the Web bridge (version 2).
    enum MessageName: String {
        case initialize         = "core.init"
        case getUser            = "core.user.get"
        case getVatomChildren   = "core.vatom.children.get"
        case getVatom           = "core.vatom.get"
        case performAction      = "core.action.perform"
//        case resourceEncode     = "core.resource.encode"
    }

    var faceView: FaceView?

    // MARK: - Initializer

    required init(faceView: FaceView) {
        self.faceView = faceView
    }

    // MARK: - Face Brige

    /// Returns `true` if the bridge is capable of processing the message and `false` otherwise.
    func canProcessMessage(_ message: String) -> Bool {
        return !(MessageName(rawValue: message) == nil)
    }

    /// Processes the face script message and calls the completion handler with the result for encoding.
    func processMessage(_ scriptMessage: FaceScriptMessage, completion: @escaping CoreBridgeV2.Completion) {

        let message = MessageName(rawValue: scriptMessage.name)!
        printBV(info: "CoreBride_2: \(message)")

        // switch and route message
        switch message {
        case .initialize:
            self.setupBridge(completion)
        case .getVatom:
            // ensure caller supplied params
            guard let identifiers = (scriptMessage.object["ids"]?.arrayValue?.compactMap { $0.stringValue }) else {
                let error = BridgeError.caller("Missing 'ids' key.")
                completion(nil, error)
                return
            }
            self.getVatoms(withIDs: identifiers, completion: completion)
        case .getVatomChildren:
            // ensure caller supplied params
            guard let vatomID = scriptMessage.object["id"]?.stringValue else {
                let error = BridgeError.caller("Missing 'id' key.")
                completion(nil, error)
                return
            }
            self.listChildren(forVatomID: vatomID, completion: completion)
        case .getUser:
            // ensure caller supplied params
            guard let userID = scriptMessage.object["id"]?.stringValue else {
                let error = BridgeError.caller("Missing 'id' key.")
                completion(nil, error)
                return
            }
            self.getPublicUser(userID: userID, completion: completion)
        case .performAction:
            // ensure caller supplied params
            guard
                let vatomID = scriptMessage.object["vatom_id"]?.stringValue, //FIXME: Remove - I don't think this is needed.
                let actionName = scriptMessage.object["action_name"]?.stringValue,
                let payload = scriptMessage.object["payload"]?.objectValue
                else {
                    let error = BridgeError.caller("Missing 'vatom_id', 'action_name' or 'action_data'.")
                    completion(nil, error)
                    return
            }
            self.performAction(name: actionName, payload: payload, completion: completion)
        }

    }

    // MARK: - Bridge Responses

    private struct BRSetup: Encodable {
        let vatom: VatomModel
        let face: FaceModel
    }

    private struct BRUser: Encodable {

        struct Properties: Encodable {
            let firstName: String
            let lastName: String
            let avatarURI: String

            enum CodingKeys: String, CodingKey { //swiftlint:disable:this nesting
                case firstName = "first_name"
                case lastName  = "last_name"
                case avatarURI = "avatar_uri"
            }
        }

        let id: String
        let properties: Properties

    }

    // MARK: - Message Handling

    /// Invoked when a face would like to create the web bridge.
    ///
    /// Creates the bridge initializtion JSON data.
    ///
    /// - Parameter completion: Completion handler to call with JSON data to be passed to the webpage.
    private func setupBridge(_ completion: @escaping Completion) {

        // santiy check
        guard let faceView = self.faceView else {
            let error = BridgeError.viewer("Invalid state.")
            completion(nil, error)
            return
        }

        let vatom = faceView.vatom
        let face = faceView.faceModel

        let response = BRSetup(vatom: vatom, face: face)

        // json-data encode the model
        guard let data = try? JSONEncoder.blockv.encode(response) else {
            let bridgeError = BridgeError.viewer("Unable to encode response.")
            completion(nil, bridgeError)
            return
        }
        completion(data, nil)

    }

    /// Fetches the vAtom specified by the id.
    private func getVatoms(withIDs ids: [String], completion: @escaping Completion) {

        BLOCKv.getVatoms(withIDs: ids) { (vatoms, error) in

            // ensure no error
            guard error == nil else {
                let bridgeError = BridgeError.viewer("Unable to fetch vAtoms.")
                completion(nil, bridgeError)
                return
            }

            let response = ["vatoms": vatoms]

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

        BLOCKv.getInventory(id: id) { (vatoms, error) in

            // ensure no error
            guard error == nil else {
                let bridgeError = BridgeError.viewer("Unable to fetch children for vAtom \(id).")
                completion(nil, bridgeError)
                return
            }

            let response = ["vatoms": vatoms]

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
    private func getPublicUser(userID id: String, completion: @escaping Completion) {

        BLOCKv.getPublicUser(withID: id) { (user, error) in

            // ensure no error
            guard let user = user, error == nil else {
                let bridgeError = BridgeError.viewer("Unable to fetch public user: \(id).")
                completion(nil, bridgeError)
                return
            }

            // build response
            let properties = BRUser.Properties(firstName: user.properties.firstName,
                                               lastName: user.properties.lastName,
                                               avatarURI: user.properties.avatarURL?.absoluteString ?? "")
            let response = BRUser(id: user.id, properties: properties)

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
