//  Converted to Swift 5.8.1 by Swiftify v5.8.28463 - https://swiftify.com/
import Foundation
import XCTest

@testable@_spi(STP) import Stripe
@testable@_spi(STP) import StripeCore
@testable@_spi(STP) import StripePayments
@testable@_spi(STP) import StripePaymentSheet
@testable@_spi(STP) import StripePaymentsUI
//
//  STPConfirmCardOptionsTest.swift
//  StripeiOS Tests
//
//  Created by Cameron Sabol on 1/10/20.
//  Copyright © 2020 Stripe, Inc. All rights reserved.
//

class STPConfirmCardOptionsTest: XCTestCase {
    func testCVC() {
        let cardOptions = STPConfirmCardOptions()

        XCTAssertNil(cardOptions.cvc)
        XCTAssertNil(cardOptions.network)

        cardOptions.cvc = "123"
        XCTAssertEqual(cardOptions.cvc, "123")
        cardOptions.network = "visa"
        XCTAssertEqual(cardOptions.network, "visa")
    }

    func testEncoding() {
        let propertyMap = STPConfirmCardOptions.propertyNamesToFormFieldNamesMapping()
        let expected = [
            "cvc": "cvc",
            "network": "network"
        ]
        XCTAssertEqual(propertyMap, expected)
    }
}
