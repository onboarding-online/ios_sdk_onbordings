//
//  PaywallListSubscriptionCell.swift
//  
//
//  Created by Oleg Kuplin on 26.12.2023.
//

import UIKit
import ScreensGraph

final class PaywallListSubscriptionCell: UICollectionViewCell {

    @IBOutlet private weak var contentContainerView: UIView!
    @IBOutlet private weak var checkbox: PaywallCheckboxView!
    @IBOutlet private weak var durationLabel: UILabel!
    @IBOutlet private weak var priceLabel: UILabel!
    @IBOutlet private weak var pricePerMonthLabel: UILabel!
    @IBOutlet private weak var contentLeadingConstraint: NSLayoutConstraint!
    
    @IBOutlet private weak var savedMoneyView: SavedMoneyView!
    private var currentSavedMoneyViewConstraints: [NSLayoutConstraint] = []
    
    private var item: ItemTypeSubscription! = nil

    override func awakeFromNib() {
        super.awakeFromNib()
        
        clipsToBounds = false
        savedMoneyView.translatesAutoresizingMaskIntoConstraints = false
        contentContainerView.layer.cornerRadius = 16
        contentContainerView.layer.borderColor = UIColor.blue.cgColor
        contentLeadingConstraint.constant = UIScreen.isIphoneSE1 ? 12 : 24
    }

}

// MARK: - Open methods
extension PaywallListSubscriptionCell {
    
    func setWith(configuration: PaywallVC.ListSubscriptionCellConfiguration,
                    isSelected: Bool,
                 subscriptionItem: ItemTypeSubscription, listWithStyles: SubscriptionList, product: StoreKitProduct) {
        
        
        self.item = subscriptionItem
        
        setBadgePosition(configuration.badgePosition, settings: item.badge)
        setSelected(isSelected, listWithStyles: listWithStyles)
        
        setupLabels(subscriptionItem: subscriptionItem, product: product)
    }
    
    func setupLabels(subscriptionItem: ItemTypeSubscription, product: StoreKitProduct) {
        durationLabel.apply(text: subscriptionItem.period)
        priceLabel.apply(text: subscriptionItem.price)
        pricePerMonthLabel.apply(text: subscriptionItem.description)
        
        durationLabel.text =  subscriptionItem.period.textFor(product: product)
        priceLabel.text = subscriptionItem.price.textFor(product: product)
        pricePerMonthLabel.text = subscriptionItem.description.textFor(product: product)
    }
    
    func setWith(configuration: PaywallVC.ListOneTimePurchaseCellConfiguration,
                 isSelected: Bool) {
        // TODO: - Use different cell
//        setBadgePosition(configuration.badgePosition)
//        setSelected(isSelected)
    }
}

// MARK: - Private methods
private extension PaywallListSubscriptionCell {
    
    func setSelected(_ isSelected: Bool, listWithStyles: SubscriptionList) {
        checkbox.isOn = isSelected
        
        if isSelected {
            setSelected(selectedBlock: listWithStyles.selectedBlock)
        } else {
            setDefault(style: listWithStyles.styles)
        }
    }
    
    func setDefault(style: SubscriptionListBlock) {
        contentContainerView.layer.borderWidth = style.borderWidth ?? 0
        contentContainerView.layer.borderColor = style.borderColor?.hexStringToColor.cgColor
        contentContainerView.backgroundColor = style.backgroundColor?.hexStringToColor ?? .black.withAlphaComponent(0.05)
        
        contentContainerView.applyFigmaShadow(x: 0, y: 1, blur: 0, spread: 0, color: .black, alpha: 0.05)
    }
    
    func setSelected(selectedBlock: SelectedSubscriptionListItemBlock) {
        contentContainerView.layer.borderWidth = selectedBlock.styles.borderWidth ?? 0
        contentContainerView.layer.borderColor = selectedBlock.styles.borderColor?.hexStringToColor.cgColor
        contentContainerView.backgroundColor = selectedBlock.styles.backgroundColor?.hexStringToColor ?? .black.withAlphaComponent(0.05)
        
        contentContainerView.applyFigmaShadow(x: 0, y: 20, blur: 40, spread: 0, color: .black, alpha: 0.15)
    }
    
    
    func setBadgePosition(_ position: SavedMoneyBadgePosition, settings: Badge?) {
       
        NSLayoutConstraint.deactivate(currentSavedMoneyViewConstraints)

        var constraints: [NSLayoutConstraint] = [savedMoneyView.heightAnchor.constraint(equalToConstant: 24),
                                                 savedMoneyView.centerYAnchor.constraint(equalTo: topAnchor)]
        
        if let badge = settings {
            savedMoneyView.isHidden = false
            
            savedMoneyView.backgroundColor = badge.styles.backgroundColor?.hexStringToColor
            savedMoneyView.layer.borderWidth = badge.styles.borderWidth ?? 0
            savedMoneyView.layer.cornerRadius = badge.styles.borderRadius ?? 0

            savedMoneyView.label.apply(badge: settings)
            switch badge.styles.position {
            case .topleft:
                constraints.append(savedMoneyView.leadingAnchor.constraint(equalTo: contentContainerView.leadingAnchor, constant: 16))
            case .topcenter:
                constraints.append(savedMoneyView.centerXAnchor.constraint(equalTo: centerXAnchor))
            case .topright:
                constraints.append(contentContainerView.trailingAnchor.constraint(equalTo: savedMoneyView.trailingAnchor, constant: 16))
            default:
                constraints.append(savedMoneyView.leadingAnchor.constraint(equalTo: contentContainerView.leadingAnchor, constant: 16))
            }
        } else {
            savedMoneyView.isHidden = true
        }
        
        NSLayoutConstraint.activate(constraints)
        currentSavedMoneyViewConstraints = constraints
    }
    
}

// MARK: - Open methods
extension PaywallListSubscriptionCell {
    enum SavedMoneyBadgePosition {
        case none, left, center, right
    }
}
