//  Converted to Swift 5.8.1 by Swiftify v5.8.28463 - https://swiftify.com/
import Foundation
import XCTest

@testable@_spi(STP) import Stripe
@testable@_spi(STP) import StripeCore
@testable@_spi(STP) import StripePayments
@testable@_spi(STP) import StripePaymentSheet
@testable@_spi(STP) import StripePaymentsUI
//
//  STPPaymentMethodFPXTest.swift
//  StripeiOS Tests
//
//  Created by David Estes on 8/26/19.
//  Copyright © 2019 Stripe, Inc. All rights reserved.
//

class STPPaymentMethodFPXTest: XCTestCase {
    func exampleJson() -> [AnyHashable : Any]? {
        return [
            "bank": "maybank2u",
        ]
    }

    func testDecodedObjectFromAPIResponseRequiredFields() {
        let requiredFields: [String]? = []

        for field in requiredFields ?? [] {
            var response = exampleJson()
            response?.removeValue(forKey: field)

            XCTAssertNil(STPPaymentMethodFPX.decodedObject(fromAPIResponse: response))
        }

        XCTAssert(STPPaymentMethodFPX.decodedObject(fromAPIResponse: exampleJson()))
    }

    func testDecodedObjectFromAPIResponseMapping() {
        let response = exampleJson()
        let fpx = STPPaymentMethodFPX.decodedObject(fromAPIResponse: response)
        XCTAssertEqual(fpx?.bankIdentifierCode, "maybank2u")
    }
}
