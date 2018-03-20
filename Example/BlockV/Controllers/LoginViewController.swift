//
//  LoginViewController.swift
//  BlockV_Example
//

import UIKit
import BlockV

class LoginViewController: UIViewController {
    
    // MARK: - Outlets
    
    @IBOutlet weak var tokenTypeSegmentedControl: UISegmentedControl!
    @IBOutlet weak var userTokenTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    
    // MARK: - Properties
    
    /// Type of token selected.
    var tokenType: UserTokenType {
        get {
            switch tokenTypeSegmentedControl.selectedSegmentIndex {
            case 0: return .phone
            case 1: return .email
            default: fatalError("Unhandled index.")
            }
        }
    }
    
    // MARK: - Actions
    
    @IBAction func tokenTypeSegmentChanged(_ sender: UISegmentedControl) {
        switch sender.selectedSegmentIndex {
        case 0: configureTokenTextField(for: .phone)
        case 1: configureTokenTextField(for: .email)
        default: fatalError("Unhandled index.")
        }
        self.userTokenTextField.becomeFirstResponder()
    }
    
    /// This function performs the login operation.
    @IBAction func nextButton(_ sender: UIButton) {
        
        // show loader
        self.showNavBarActivityRight()
        
        let token = userTokenTextField.text ?? ""
        let password = passwordTextField.text ?? ""
        
        // ask the BV platform to login
        Blockv.login(withUserToken: token, type: tokenType, password: password) {
            [weak self] (userModel, error) in
            
            // reset nav bar
            self?.hideNavBarActivityRight()
            
            // handle error
            guard let model = userModel, error == nil else {
                print(">>> Error > Viewer: \(error!.localizedDescription)")
                self?.present(UIAlertController.errorAlert(error!), animated: true)
                return
            }
            
            // handle success
            self?.performSegue(withIdentifier: "seg.login.success", sender: self)
            print("Viewer > \(model)\n")
            
        }
        
    }
    
    /// This function performs the reset password operation.
    @IBAction func resetPasswordButton(_ sender: UIButton) {
        
        // show loader
        self.showNavBarActivityRight()
        
        // ensure form is valid
        let token = userTokenTextField.text ?? ""
        
        // ask the BV platform to reset the token
        Blockv.resetToken(token, type: tokenType) {
            [weak self] (userToken, error) in
            
            // hide loader
            self?.hideNavBarActivityRight()
            
            // handle error
            guard let model = userToken, error == nil else {
                print(">>> Error > Viewer: \(error!.localizedDescription)")
                self?.present(UIAlertController.errorAlert(error!), animated: true)
                return
            }
            
            // handle success
            self?.present(UIAlertController.okAlert(title: "Info",
                                              message: "An OTP has been sent to your token. Please use the OTP as a password to login."), animated: true)
            
            print("Viewer > \(model)\n")
            
        }
        
    }
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // ui setup
        configureTokenTextField(for: .phone)
        userTokenTextField.autocorrectionType = .no
        self.userTokenTextField.becomeFirstResponder()
    
    }
    
    // MARK: - Methods
    
    fileprivate func configureTokenTextField(for type: UserTokenType) {
        
        switch type {
        case .phone:
            userTokenTextField.keyboardType = .phonePad
            userTokenTextField.placeholder = "Phone number"
        case .email:
            userTokenTextField.keyboardType = .emailAddress
            userTokenTextField.placeholder = "Email address"
        }
    }
    
    // MARK: - Navigation
    
    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        // prevent the segue - we will do it programatically
        return false
    }
    
}
