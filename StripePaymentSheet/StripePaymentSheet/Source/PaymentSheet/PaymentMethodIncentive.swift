//
//  PaymentMethodIncentive.swift
//  StripePaymentSheet
//
//  Created by Till Hellmund on 11/19/24.
//

import Foundation
@_spi(STP) import StripePayments

struct PaymentMethodIncentive {

    private let identifier: String
    let displayText: String
    
    init(identifier: String, displayText: String) {
        self.identifier = identifier
        self.displayText = displayText
    }

    func takeIfAppliesTo(_ paymentMethodType: PaymentSheet.PaymentMethodType) -> PaymentMethodIncentive? {
        switch paymentMethodType {
        case .stripe, .external:
            return nil
        case .instantDebits, .linkCardBrand:
            return identifier == "link_instant_debits" ? self : nil
        }
    }
}

extension PaymentMethodIncentive {

    init?(from incentive: LinkConsumerIncentive) {
        guard let displayText = incentive.incentiveDisplayText else {
            return nil
        }
        
        self.identifier = incentive.incentiveParams.paymentMethod
        self.displayText = displayText
    }
}
