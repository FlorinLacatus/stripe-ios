//
//  PKPaymentAuthorizationViewController+Stripe_Blocks.swift
//  StripeiOS
//
//  Created by Ben Guo on 4/19/16.
//  Copyright © 2016 Stripe, Inc. All rights reserved.
//

import ObjectiveC
import PassKit
@_spi(STP) import StripeCore

typealias STPApplePayPaymentMethodHandlerBlock = (STPPaymentMethod, @escaping STPPaymentStatusBlock)
    -> Void
typealias STPPaymentCompletionBlock = (STPPaymentStatus, Error?) -> Void
typealias STPPaymentSummaryItemCompletionBlock = ([PKPaymentSummaryItem]) -> Void
typealias STPShippingMethodSelectionBlock = (
    PKShippingMethod, @escaping STPPaymentSummaryItemCompletionBlock
) -> Void
typealias STPShippingAddressValidationBlock = (
    STPShippingStatus, [PKShippingMethod], [PKPaymentSummaryItem]
) -> Void
typealias STPShippingAddressSelectionBlock = (
    STPAddress, @escaping STPShippingAddressValidationBlock
) -> Void
typealias STPPaymentAuthorizationBlock = (PKPayment) -> Void

typealias STPApplePayShippingMethodCompletionBlock = (
    PKPaymentAuthorizationStatus, [PKPaymentSummaryItem]?
) -> Void
typealias STPApplePayShippingAddressCompletionBlock = (
    PKPaymentAuthorizationStatus, [PKShippingMethod]?, [PKPaymentSummaryItem]?
) -> Void
class STPBlockBasedApplePayDelegate: NSObject, PKPaymentAuthorizationViewControllerDelegate {
    var apiClient: STPAPIClient?
    var onShippingAddressSelection: STPShippingAddressSelectionBlock?
    var onShippingMethodSelection: STPShippingMethodSelectionBlock?
    var onPaymentAuthorization: STPPaymentAuthorizationBlock?
    var onPaymentMethodCreation: STPApplePayPaymentMethodHandlerBlock?
    var onFinish: STPPaymentCompletionBlock?
    var lastError: Error?
    var didSucceed = false

    // Remove all this once we drop iOS 11 support
    func paymentAuthorizationViewController(
        _ controller: PKPaymentAuthorizationViewController,
        didAuthorizePayment payment: PKPayment,
        completion: @escaping (PKPaymentAuthorizationStatus) -> Void
    ) {
        onPaymentAuthorization?(payment)

        let paymentMethodCreateCompletion: ((STPPaymentMethod?, Error?) -> Void)? = {
            result,
            paymentMethodCreateError in
            if let paymentMethodCreateError = paymentMethodCreateError {
                self.lastError = paymentMethodCreateError
                completion(.failure)
                return
            }
            guard let result = result else {
                self.lastError = NSError.stp_genericFailedToParseResponseError()
                completion(.failure)
                return
            }
            self.onPaymentMethodCreation?(
                result,
                { status, error in
                    if status != .success || error != nil {
                        self.lastError = error
                        completion(.failure)
                        if controller.presentingViewController == nil {
                            // If we call completion() after dismissing, didFinishWithStatus is NOT called.
                            self._finish()
                        }
                        return
                    }
                    self.didSucceed = true
                    completion(.success)
                    if controller.presentingViewController == nil {
                        // If we call completion() after dismissing, didFinishWithStatus is NOT called.
                        self._finish()
                    }
                }
            )
        }
        if let paymentMethodCreateCompletion = paymentMethodCreateCompletion {
            apiClient?.createPaymentMethod(with: payment, completion: paymentMethodCreateCompletion)
        }
    }

    func paymentAuthorizationViewController(
        _ controller: PKPaymentAuthorizationViewController,
        didSelect shippingMethod: PKShippingMethod,
        completion: @escaping (PKPaymentAuthorizationStatus, [PKPaymentSummaryItem]) -> Void
    ) {
        onShippingMethodSelection?(
            shippingMethod,
            { summaryItems in
                completion(PKPaymentAuthorizationStatus.success, summaryItems)
            }
        )
    }

    func paymentAuthorizationViewController(
        _ controller: PKPaymentAuthorizationViewController,
        didSelectShippingContact contact: PKContact,
        handler completion: @escaping (PKPaymentRequestShippingContactUpdate) -> Void
    ) {
        let stpAddress = STPAddress(pkContact: contact)
        onShippingAddressSelection?(
            stpAddress,
            { status, shippingMethods, summaryItems in
                if status == .invalid {
                    let genericShippingError = NSError(
                        domain: PKPaymentErrorDomain,
                        code: PKPaymentError.shippingContactInvalidError.rawValue,
                        userInfo: nil
                    )
                    completion(
                        PKPaymentRequestShippingContactUpdate(
                            errors: [genericShippingError],
                            paymentSummaryItems: summaryItems,
                            shippingMethods: shippingMethods
                        )
                    )
                } else {
                    completion(
                        PKPaymentRequestShippingContactUpdate(
                            errors: nil,
                            paymentSummaryItems: summaryItems,
                            shippingMethods: shippingMethods
                        )
                    )
                }
            }
        )
    }

    func paymentAuthorizationViewControllerDidFinish(
        _ controller: PKPaymentAuthorizationViewController
    ) {
        _finish()
    }

    func _finish() {
        if didSucceed {
            onFinish?(.success, nil)
        } else if let lastError = lastError {
            onFinish?(.error, lastError)
        } else {
            onFinish?(.userCancellation, nil)
        }
    }
}

typealias STPPaymentAuthorizationStatusCallback = (PKPaymentAuthorizationStatus) -> Void
