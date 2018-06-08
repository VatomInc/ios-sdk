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

/// This extension groups together all BLOCKv Platform requests.
extension BLOCKv {
    
    // MARK: Register
    
    /// Registers a user on the BLOCKv platform. Accepts a user token (phone or email).
    ///
    /// - Parameters:
    ///   - token: A user token value, i.e. phone number or email.
    ///   - type: The type of the token `phone` or `email`.
    ///   - userInfo: A simple struct that holds properties of the user, e.g. first name.
    ///               Only the properties to be registered should be set.
    ///   - completion: The completion handler to call when the request is completed.
    ///                 This handler is executed on the main queue.
    public static func register(withUserToken token: String, type: UserTokenType, userInfo: UserInfo? = nil,
                                completion: @escaping (UserModel?, BVError?) -> Void) {
        let registerToken = UserToken(value: token, type: type)
        self.register(tokens: [registerToken], userInfo: userInfo, completion: completion)
    }
    
    /// Registers a user on the BLOCKv platform. Accepts an OAuth token.
    ///
    /// - Parameters:
    ///   - oauthToken: An OAuth token from a supported OAuth provider, e.g. Facebook.
    ///   - userInfo: A simple struct that holds properties of the user, e.g. first name.
    ///               Only the properties to be registered should be set.
    ///   - completion: The completion handler to call when the request is completed.
    ///                 This handler is executed on the main queue.
    public static func register(withOAuthToken oauthToken: OAuthTokenRegisterParams, userInfo: UserInfo? = nil,
                                completion: @escaping (UserModel?, BVError?) -> Void) {
        self.register(tokens: [oauthToken], userInfo: userInfo, completion: completion)
    }
    
    /// Registers a user on the BLOCKv platform.
    ///
    /// This call allows for multiple tokens (e.g. phone, email, or OAuth) to be associated
    /// with the user's account.
    ///
    /// Note: After registration the user is considered to be logged in and is
    /// authorized to perform requests.
    public static func register(tokens: [RegisterTokenParams], userInfo: UserInfo? = nil,
                                completion: @escaping (UserModel?, BVError?) -> Void) {
        
        let endpoint = API.Session.register(tokens: tokens, userInfo: userInfo)
        
        self.client.request(endpoint) { (baseModel, error) in
            
            // extract model, ensure no error
            guard var authModel = baseModel?.payload, error == nil else {
                DispatchQueue.main.async {
                    completion(nil, error)
                }
                return
            }
            
            // model is available
            DispatchQueue.main.async {
                // persist credentials
                CredentialStore.saveRefreshToken(authModel.refreshToken)
                CredentialStore.saveAssetProviders(authModel.assetProviders)
                
                // encode the model's urls
                authModel.user.encodeEachURL(using: blockvURLEncoder, assetProviders: CredentialStore.assetProviders)
                
                completion(authModel.user, nil)
            }
            
        }
        
    }
    
    // MARK: Login
    
    /// Logs a user into the BLOCKv platform. Accepts a user token (phone or email).
    ///
    /// - Parameters:
    ///   - token: A user token value, i.e. phone number or email.
    ///   - type: The type of the token `phone` or `email`.
    ///   - password: The user's password.
    ///   - completion: The completion handler to call when the request is completed.
    ///                 This handler is executed on the main queue.
    public static func login(withUserToken token: String, type: UserTokenType, password: String,
                             completion: @escaping (UserModel?, BVError?) -> Void) {
        let params = UserTokenLoginParams(value: token, type: type, password: password)
        self.login(tokenParams: params, completion: completion)
    }
    
    /// Logs a user into the BLOCKv platform. Accepts an OAuth token.
    ///
    /// - Parameters:
    ///   - oauthToken: The OAuth token issued by the OAuth provider.
    ///   - provider: The OAuth provider, e.g. Facebook.
    ///   - completion: The completion handler to call when the request is completed.
    ///                 This handler is executed on the main queue.
    public static func login(withOAuthToken oauthToken: String, provider: String,
                             completion: @escaping (UserModel?, BVError?) -> Void) {
        let params = OAuthTokenLoginParams(provider: provider, oauthToken: oauthToken)
        self.login(tokenParams: params, completion: completion)
    }
    
    /// Logs a user into the BLOCKv platform. Accepts a guest ID.
    ///
    /// - Parameters:
    ///   - id: User identifier generated by the BLOCKv platform.
    ///   - completion: The completion handler to call when the request is completed.
    ///                 This handler is executed on the main queue.
    public static func login(withGuestID id: String, completion: @escaping (UserModel?, BVError?) -> Void) {
        let params = GuestIdLoginParams(id: id)
        self.login(tokenParams: params, completion: completion)
    }
    
    /// Login using token params
    fileprivate static func login(tokenParams: LoginTokenParams,
                                  completion: @escaping (UserModel?, BVError?) -> Void) {
        
        let endpoint = API.Session.login(tokenParams: tokenParams)
        
        self.client.request(endpoint) { (baseModel, error) in
            
            // extract model, ensure no error
            guard var authModel = baseModel?.payload, error == nil else {
                DispatchQueue.main.async {
                    completion(nil, error)
                }
                return
            }
            
            // model is available
            DispatchQueue.main.async {
                
                // persist credentials
                CredentialStore.saveRefreshToken(authModel.refreshToken)
                CredentialStore.saveAssetProviders(authModel.assetProviders)
                
                // encode the model's urls
                authModel.user.encodeEachURL(using: blockvURLEncoder, assetProviders: CredentialStore.assetProviders)
                // completion
                completion(authModel.user, nil)
            }
            
        }
        
    }
    
    // MARK: Verify
    
    /// Verifies ownership of a token by submitting the verification code to the BLOCKv Platform.
    ///
    /// - Parameters:
    ///   - token: A user token value, i.e. phone number or email.
    ///   - type: The type of the token `phone` or `email`.
    ///   - code: The verification code send to the user's token (phone or email).
    ///   - completion: The completion handler to call when the request is completed.
    ///                 This handler is executed on the main queue.
    public static func verifyUserToken(_ token: String, type: UserTokenType, code: String,
                                       completion: @escaping (UserToken?, BVError?) -> Void) {
        
        let userToken = UserToken(value: token, type: type)
        let endpoint = API.CurrentUser.verifyToken(userToken, code: code)
        
        self.client.request(endpoint) { (baseModel, error) in
            
            // extract model, ensure no error
            guard let userTokenModel = baseModel?.payload, error == nil else {
                DispatchQueue.main.async {
                    completion(nil, error)
                }
                return
            }
            
            // model is available
            DispatchQueue.main.async {
                completion(userTokenModel, nil)
            }
            
        }
        
    }
    
    // MARK: Token Code
    
    /// Resets a user token. This will remove the user's password and trigger
    /// a One-Time-Pin (OTP) to be sent to the supplied user token.
    ///
    /// Note: This OTP may be used in place of a password to login.
    ///
    /// - Parameters:
    ///   - token: A user token value, i.e. phone number or email.
    ///   - type: The type of the token `phone` or `email`.
    ///   - completion: The completion handler to call when the request is completed.
    ///                 This handler is executed on the main queue.
    public static func resetToken(_ token: String, type: UserTokenType,
                                  completion: @escaping (UserToken?, BVError?) -> Void) {
        
        let userToken = UserToken(value: token, type: type)
        let endpoint = API.CurrentUser.resetToken(userToken)
        
        self.client.request(endpoint) { (baseModel, error) in
            
            // extract model, ensure no error
            guard let userTokenModel = baseModel?.payload, error == nil else {
                DispatchQueue.main.async {
                    completion(nil, error)
                }
                return
            }
            
            // model is available
            DispatchQueue.main.async {
                completion(userTokenModel, nil)
            }
            
        }
        
    }
    
    /// Resets the verification process. Sends a verification item to the user's token (phone or email).
    ///
    /// This verification item should be used to verifiy the user's ownership of the token (phone or email).
    /// Note: the type of verification is dependent on the configuration of the app id on the developer portal.
    ///
    /// - Parameters:
    ///   - token: A user token value, i.e. phone number or email.
    ///   - type: The type of the token `phone` or `email`.
    ///   - completion: The completion handler to call when the request is completed.
    ///                 This handler is executed on the main queue.
    public static func resetVerification(forUserToken token: String, type: UserTokenType,
                                         completion: @escaping (UserToken?, BVError?) -> Void) {
        
        let userToken = UserToken(value: token, type: type)
        let endpoint = API.CurrentUser.resetTokenVerification(forToken: userToken)
        
        self.client.request(endpoint) { (baseModel, error) in
            
            // extract model, handle error
            guard let userTokenModel = baseModel?.payload, error == nil else {
                DispatchQueue.main.async {
                    completion(nil, error)
                }
                return
            }
            
            // model is available
            DispatchQueue.main.async {
                completion(userTokenModel, nil)
            }
            
        }
        
    }
    
    // MARK: User
    
    /// Fetches the current user's profile information from the BLOCKv Platform.
    ///
    ///   - completion: The completion handler to call when the request is completed.
    ///                 This handler is executed on the main queue.
    public static func getCurrentUser(completion: @escaping (UserModel?, BVError?) -> Void) {
        
        let endpoint = API.CurrentUser.get()
        
        self.client.request(endpoint) { (baseModel, error) in
            
            // extract model, ensure no error
            guard var userModel = baseModel?.payload, error == nil else {
                DispatchQueue.main.async {
                    completion(nil, error)
                }
                return
            }
            
            // model is available
            DispatchQueue.main.async {
                
                // encode the model's urls
                userModel.encodeEachURL(using: blockvURLEncoder, assetProviders: CredentialStore.assetProviders)
                
                completion(userModel, nil)
            }
            
        }
        
    }
    
    /// Fetches the current user's token description from the BLOCKv Platform.
    ///
    ///   - completion: The completion handler to call when the request is completed.
    ///                 This handler is executed on the main queue.
    public static func getCurrentUserTokens(completion: @escaping ([FullTokenModel]?, BVError?) -> Void) {
        
        let endpoint = API.CurrentUser.getTokens()
        
        self.client.request(endpoint) { (baseModel, error) in
            
            // extract model, handle error
            guard let fullTokens = baseModel?.payload, error == nil else {
                DispatchQueue.main.async {
                    completion(nil, error)
                }
                return
            }
            
            // model is available
            DispatchQueue.main.async {
                completion(fullTokens, nil)
            }
            
        }
        
    }
    
    /// Removes the token from the current user's token list on the BLOCKv Platform.
    ///
    /// - Parameters:
    ///   - tokenId: Unique identifier of the token to be deleted.
    ///   - completion: The completion handler to call when the request is completed.
    ///                 This handler is executed on the main queue.
    public static func deleteCurrentUserToken(_ tokenId: String, completion: @escaping (BVError?) -> Void) {
        
        let endpoint = API.CurrentUser.deleteToken(id: tokenId)
        
        self.client.request(endpoint) { (baseModel, error) in
            
            guard let _ = baseModel?.payload, error == nil else {
                DispatchQueue.main.async {
                    completion(error)
                }
                return
            }
            
            // call was successful
            DispatchQueue.main.async {
                completion(nil)
            }
            
        }
        
    }
    
    /// Updates the specified token to be the current user's default token on the BLOCKv Platform.
    ///
    /// Backend description:
    /// Flag to indicate if this token is the primary token. The primary token is used when no other
    /// token is explicitly selected, for example to send messages. This will automatically set the
    /// is_primary flag of an existing token to false , because only one token can be the primary token.
    ///
    /// - Parameters:
    ///   - tokenId: Unique identiifer of the token.
    ///   - completion: The completion handler to call when the request is completed.
    ///                 This handler is executed on the main queue.
    public static func setCurrentUserDefaultToken(_ tokenId: String, completion: @escaping (BVError?) -> Void) {
        
        let endpoint = API.CurrentUser.setDefaultToken(id: tokenId)
        
        self.client.request(endpoint) { (baseModel, error) in
            
            //
            guard let _ = baseModel?.payload, error == nil else {
                DispatchQueue.main.async {
                    completion(error)
                }
                return
            }
            
            // call was succesful
            DispatchQueue.main.async {
                completion(nil)
            }
            
        }
        
    }
    
    /// Updates the current user's profile on the BLOCKv Platform.
    ///
    /// - Parameters:
    ///   - userInfo: A simple struct that holds the properties of the user, e.g. their first name.
    ///               Only the properties to be updated should be set.
    ///   - completion: The completion handler to call when the request is completed.
    ///                 This handler is executed on the main queue.
    public static func updateCurrentUser(_ userInfo: UserInfo,
                                         completion: @escaping (UserModel?, BVError?) -> Void) {
        
        let endpoint = API.CurrentUser.update(userInfo: userInfo)
        
        self.client.request(endpoint) { (baseModel, error) in
            
            // extract model, ensure no error
            guard let userModel = baseModel?.payload, error == nil else {
                DispatchQueue.main.async {
                    completion(nil, error)
                }
                return
            }
            
            // model is available
            DispatchQueue.main.async {
                completion(userModel, nil)
            }
            
        }
        
    }
    
    /// Uploads an avatar image to the BlockV Platform.
    ///
    /// It is recommended that scalling and cropping be done before calling this method.
    ///
    /// - Parameters:
    ///   - image: The image to upload.
    ///   - completion: The completion handler to call when the request is completed.
    ///                 This handler is executed on the main queue.
    public static func uploadAvatar(_ image: UIImage,
                                    progressCompletion: @escaping (_ percent: Float) -> Void,
                                    completion: @escaping (BVError?) -> Void) {
        
        //TODO: Perhaps this method should require Data instead of UIImage?
        
        // create image data
        guard let imageData = UIImagePNGRepresentation(image) else {
            let error = BVError.custom(reason: "\nBV SDK >>> Error: Conversion to png respresetation returned nil.")
            completion(error)
            return
        }
        
        // build endpoint
        let endpoint = API.CurrentUser.uploadAvatar(imageData)
        
        self.client.upload(endpoint, progressCompletion: progressCompletion) { (baseModel, error) in
            
            // extract model, ensure no error
            guard let _ = baseModel?.payload, error == nil else {
                DispatchQueue.main.async {
                    completion(error)
                }
                return
            }
            
            // model is available
            DispatchQueue.main.async {
                completion(nil)
            }
            
        }
        
    }
    
    // MARK: Logout
    
    /// Log out the current user.
    ///
    /// The current user will no longer be authorized to perform user scoped requests on the
    /// BLOCKv platfrom.
    ///
    /// - Parameter completion: The completion handler to call when the request is completed.
    ///                 This handler is executed on the main queue.
    public static func logout(completion: @escaping (BVError?) -> Void) {
        
        let endpoint = API.CurrentUser.logOut()
        
        self.client.request(endpoint) { (baseModel, error) in
            
            // reset
            reset()
            
            // extract model, ensure no error
            guard let _ = baseModel?.payload, error == nil else {
                DispatchQueue.main.async {
                    completion(error!)
                }
                return
            }
            
            // model is available
            DispatchQueue.main.async {
                completion(nil)
            }
            
        }
        
    }
    
    // MARK: Vatoms
    
    /// Fetches the current user's inventory of vAtoms. The completion handler is passed in a
    /// `GroupModel` which  includes the returned vAtoms as well as the configured Faces and Actions.
    ///
    /// - Parameters:
    ///   - parentID: Allows you to specify a parent ID. If a period "." is supplied the root
    ///               inventory will be retrieved (i.e. all vAtom's without a parent) - this is the
    ///               default. If a vAtom ID is passed in, only the child vAtoms are returned.
    ///   - page: The number of the page for which the vAtoms are returned. If omitted or set as
    ///           zero, the first page is returned.
    ///   - limit: Defines the number of vAtoms per response page (up to 100). If omitted or set as
    ///            zero, the max number is returned.
    ///   - completion: The completion handler to call when the request is completed.
    ///                 This handler is executed on the main queue.
    public static func getInventory(parentID: String = ".",
                                    page: Int = 0,
                                    limit: Int = 0,
                                    completion: @escaping (GroupModel?, BVError?) -> Void) {
        
        let endpoint = API.UserVatom.getInventory(parentID: parentID, page: page, limit: limit)
        
        self.client.request(endpoint) { (baseModel, error) in
            
            // extract model, ensure no error
            guard var groupModel = baseModel?.payload, error == nil else {
                DispatchQueue.main.async {
                    completion(nil, error!)
                }
                return
            }
            
            // model is available
            
            // url encoding - this is awful. maybe encode on init?
            for vatomIndex in 0..<groupModel.vatoms.count {
                for resourceIndex in 0..<groupModel.vatoms[vatomIndex].resources.count {
                    groupModel.vatoms[vatomIndex].resources[resourceIndex].encodeEachURL(using: blockvURLEncoder, assetProviders: CredentialStore.assetProviders)
                }
            }
            
            DispatchQueue.main.async {
                completion(groupModel, nil)
            }
            
        }
        
    }
    
    /// Fetches vAtoms by providing an array of vAtom IDs. The response includes the vAtoms as well
    /// as the configured Faces and Actions in a `GroupModel`.
    ///
    /// - Parameters:
    ///   - ids: Array of vAtom IDs
    ///   - completion: The completion handler to call when the request is completed.
    ///                 This handler is executed on the main queue.
    public static func getVatoms(withIDs ids: [String], completion: @escaping (GroupModel?, BVError?) -> Void) {
        
        let endpoint = API.UserVatom.getVatoms(withIDs: ids)
        
        self.client.request(endpoint) { (baseModel, error) in
            
            // extract model, ensure no error
            guard var groupModel = baseModel?.payload, error == nil else {
                DispatchQueue.main.async {
                    completion(nil, error!)
                }
                return
            }
            
            // model is available
            
            // url encoding - this is awful. maybe encode on init?
            for vatomIndex in 0..<groupModel.vatoms.count {
                for resourceIndex in 0..<groupModel.vatoms[vatomIndex].resources.count {
                    groupModel.vatoms[vatomIndex].resources[resourceIndex].encodeEachURL(using: blockvURLEncoder, assetProviders: CredentialStore.assetProviders)
                }
            }
            
            DispatchQueue.main.async {
                completion(groupModel, nil)
            }
            
        }
        
    }
    
    /// Searches for vAtoms on the BLOCKv Platform.
    ///
    /// - Parameters:
    ///   - builder: A discover query builder object. Use the builder to simplify constructing
    ///              discover queries.
    ///   - completion: The completion handler to call when the request is completed.
    ///                 This handler is executed on the main queue.
    public static func discover(_ builder: DiscoverQueryBuilder, completion: @escaping (GroupModel?, BVError?) -> Void) {
        self.discover(payload: builder.toDictionary(), completion: completion)
    }
    
    /// Searches for vAtoms on the BLOCKv Platform.
    ///
    /// - Parameters:
    ///   - payload: Dictionary
    ///   - completion: The completion handler to call when the request is completed.
    ///                 This handler is executed on the main queue.
    public static func discover(payload: [String: Any], completion: @escaping (GroupModel?, BVError?) -> Void) {
        
        let endpoint = API.VatomDiscover.discover(payload)
        
        self.client.request(endpoint) { (baseModel, error) in
            
            // extract model, handle error
            guard var groupModel = baseModel?.payload, error == nil else {
                DispatchQueue.main.async {
                    print(error!.localizedDescription)
                    completion(nil, error!)
                }
                return
            }
            
            // model is available
            
            // url encoding - this is awful. maybe encode on init?
            for vatomIndex in 0..<groupModel.vatoms.count {
                for resourceIndex in 0..<groupModel.vatoms[vatomIndex].resources.count {
                    groupModel.vatoms[vatomIndex].resources[resourceIndex].encodeEachURL(using: blockvURLEncoder, assetProviders: CredentialStore.assetProviders)
                }
            }
            
            DispatchQueue.main.async {
                //print(model)
                completion(groupModel, nil)
            }
            
        }
        
    }
    
    // MARK: Actions
    
    /// Fetches all the actions configured for a template.
    ///
    /// - Parameters:
    ///   - id: Uniquie identified of the template.
    ///   - completion: The completion handler to call when the call is completed.
    ///                 This handler is executed on the main queue.
    public static func getActions(forTemplateID id: String,
                                  completion: @escaping ([Action]?, BVError?) -> Void) {
        
        let endpoint = API.UserActions.getActions(forTemplateID: id)
        
        self.client.request(endpoint) { (baseModel, error) in
            
            // extract array of actions, ensure no error
            guard let actions = baseModel?.payload, error == nil else {
                DispatchQueue.main.async {
                    completion(nil, error!)
                }
                return
            }
            
            // data is available
            DispatchQueue.main.async {
                completion(actions, nil)
            }
            
        }
        
    }
    
    /// Performs an action on the BLOCKv Platform.
    ///
    /// This is the most flexible of the action calls and should be used as a last resort.
    ///
    /// - Parameters:
    ///   - name: Name of the action to perform, e.g. "Drop".
    ///   - payload: Body payload that will be sent as JSON in the request body.
    ///   - completion: The completion handler to call when the action is completed.
    ///                 This handler is executed on the main queue.
    public static func performAction(name: String, payload: [String : Any],
                                     completion: @escaping (Data?, BVError?) -> Void) {
        
        let endpoint = API.VatomAction.custom(name: name, payload: payload)
        
        self.client.request(endpoint) { (data, error) in
            
            // extract data, ensure no error
            guard let data = data, error == nil else {
                DispatchQueue.main.async {
                    completion(nil, error!)
                }
                return
            }
            
            // data is available
            DispatchQueue.main.async {
                completion(data, nil)
            }
        }
        
    }
    
    /// Performs an acquire action on a vAtom.
    ///
    /// Often, only a vAtom's ID is known, e.g. scanning a QR code with an embeded vAtom
    /// ID. This call is useful is such circumstances.
    ///
    /// - Parameters:
    ///   - id: The id of the vAtom to acquire.
    ///   - completion: The completion handler to call when the action is completed.
    ///                 This handler is executed on the main queue.
    public static func acquireVatom(withID id: String,
                                    completion: @escaping (Data?, BVError?) -> Void) {
        
        let body = ["this.id": id]
        
        // perform the action
        self.performAction(name: "Acquire", payload: body) { (data, error) in
            completion(data, error)
        }
        
    }
    
}
