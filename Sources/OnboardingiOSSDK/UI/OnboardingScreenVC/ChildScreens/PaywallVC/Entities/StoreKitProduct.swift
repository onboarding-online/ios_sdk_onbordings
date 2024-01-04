//
//  File.swift
//  
//
//  Created by Oleg Kuplin on 04.01.2024.
//

import Foundation
import StoreKit

struct StoreKitProduct: Hashable {
    
    let id: String
    let title: String
    let description: String
    let price: Double
    let localizedPrice: String
    let currencyCode: String
    let locale: Locale
    let skProduct: SKProduct
    let isWithTrial: Bool
    let type: StoreKitProductType
    let discounts: [StoreKitProductDiscount]

    var isSubscription: Bool { subscriptionDescription != nil }
        
    var subscriptionDescription: StoreKitSubscriptionDescription? {
        switch type {
        case .subscription(let description):
            return description
        case .oneTimePurchase:
            return nil
        }
    }
    
    init?(skProduct: SKProduct) {
        guard let localizedPrice = skProduct.localizedPrice else {
            OnboardingLogger.logError("Failed to get localized price for SKProduct: \(skProduct.productIdentifier)")
            return nil
        }
        self.localizedPrice = localizedPrice
        
        guard let currencyCode = skProduct.currencyCode else {
            OnboardingLogger.logError("Failed to get currencyCode for SKProduct: \(skProduct.productIdentifier). Locale: \(skProduct.priceLocale)")
            return nil
        }
        self.currencyCode = currencyCode
        
        self.id = skProduct.productIdentifier
        self.title = skProduct.localizedTitle
        self.description = skProduct.localizedDescription
        self.price = skProduct.price.doubleValue
        self.locale = skProduct.priceLocale
        self.skProduct = skProduct
        self.isWithTrial = skProduct.isWithTrial
        
        if let subscriptionPeriod = skProduct.subscriptionPeriod?.period {
            var trialDescription: StoreKitSubscriptionTrialDescription?
            
            if let introductionPrice = skProduct.introductoryPrice,
               let localizedPrice = skProduct.introductionLocalizedPrice {
                trialDescription = .init(period: introductionPrice.subscriptionPeriod.period,
                                         periodDuration: introductionPrice.subscriptionPeriod.numberOfUnits,
                                         localizedPrice: localizedPrice)
            }
            
            let subscription = StoreKitSubscriptionDescription(localizedPrice: self.localizedPrice,
                                                               period: subscriptionPeriod,
                                                               trialDescription: trialDescription)
            self.type = .subscription(description: subscription)
        } else {
            self.type = .oneTimePurchase
        }
        if let introOffer = skProduct.introductoryPrice {
            self.discounts = [StoreKitProductDiscount(skProductDiscount: introOffer)].compactMap( { $0 })
        } else {
            self.discounts = skProduct.discounts.compactMap({ StoreKitProductDiscount(skProductDiscount: $0) })
        }
    }
    
    static func == (lhs: StoreKitProduct, rhs: StoreKitProduct) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
