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

typealias STPPaymentAuthorizationStatusCallback = (PKPaymentAuthorizationStatus) -> Void
