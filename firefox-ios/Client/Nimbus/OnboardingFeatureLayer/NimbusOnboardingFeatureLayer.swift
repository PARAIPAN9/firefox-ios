// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import Shared

import protocol MozillaAppServices.NimbusMessagingHelperProtocol

/// A translation layer for the `onboardingFrameworkFeature.fml`
///
/// Responsible for creating a model for onboarding from the information
/// available in the fml, regardless of experiment. All updates to the
/// structure of the fml will have to be reflected in this class, especially
/// because defaults are not provided herein, but in the fml.
class NimbusOnboardingFeatureLayer: NimbusOnboardingFeatureLayerProtocol {
    private var helperUtility: NimbusMessagingHelperUtilityProtocol

    init(with helperUtility: NimbusMessagingHelperUtilityProtocol = NimbusMessagingHelperUtility()) {
        self.helperUtility = helperUtility
    }

    func getOnboardingModel(
        for onboardingType: OnboardingType,
        from nimbus: FxNimbus = FxNimbus.shared
    ) -> OnboardingViewModel {
        let framework = nimbus.features.onboardingFrameworkFeature.value()

        let cards = getOrderedOnboardingCards(
            for: onboardingType,
            from: framework.cards,
            withConditions: framework.conditions)

        return OnboardingViewModel(
            cards: cards,
            isDismissible: framework.dismissable)
    }

    private func getOrderedOnboardingCards(
        for onboardingType: OnboardingType,
        from cardData: [String: NimbusOnboardingCardData],
        withConditions conditionTable: [String: String]
    ) -> [OnboardingCardInfoModel] {
        // Sorting the cards this way, instead of a simple sort, to account for human
        // error in the order naming. If a card name is misspelled, it will be ignored
        // and not included in the list of cards.
        return getOnboardingCards(
            from: cardData.filter { $0.value.onboardingType == onboardingType && $0.value.uiVariant == nil },
            withConditions: conditionTable
        )
        .sorted(by: { $0.order < $1.order })
        // We have to update the a11yIdRoot using the correct order of the cards
        .enumerated()
        .map { index, card in
            return OnboardingCardInfoModel(
                cardType: card.cardType,
                name: card.name,
                order: card.order,
                title: card.title,
                body: card.body,
                link: card.link,
                buttons: card.buttons,
                multipleChoiceButtons: card.multipleChoiceButtons,
                onboardingType: card.onboardingType,
                a11yIdRoot: "\(card.a11yIdRoot)\(index)",
                imageID: card.imageID,
                instructionsPopup: card.instructionsPopup)
        }
    }

    private func getOnboardingCards(
        from cardData: [String: NimbusOnboardingCardData],
        withConditions conditionTable: [String: String]
    ) -> [OnboardingCardInfoModel] {
        let a11yOnboarding = AccessibilityIdentifiers.Onboarding.onboarding
        let a11yUpgrade = AccessibilityIdentifiers.Upgrade.upgrade

        // If `NimbusMessagingHelper` creation fails, we cannot continue with
        // evaluating card triggers based on their JEXL prerequisites.
        // Therefore, we return an empty array.
        guard let helper = helperUtility.createNimbusMessagingHelper() else { return [] }

        return cardData.compactMap { cardName, cardData in
            if cardIsValid(with: cardData, using: conditionTable, and: helper) {
                return OnboardingCardInfoModel(
                    cardType: cardData.cardType,
                    name: cardName,
                    order: cardData.order,
                    title: String(
                        format: cardData.title,
                        AppName.shortName.rawValue),
                    body: String(
                        format: cardData.body,
                        AppName.shortName.rawValue,
                        AppName.shortName.rawValue),
                    link: getOnboardingLink(from: cardData.link),
                    buttons: getOnboardingCardButtons(from: cardData.buttons),
                    multipleChoiceButtons: getOnboardingMultipleChoiceButtons(from: cardData.multipleChoiceButtons),
                    onboardingType: cardData.onboardingType,
                    a11yIdRoot: cardData.onboardingType == .freshInstall ? a11yOnboarding : a11yUpgrade,
                    imageID: getOnboardingHeaderImageID(from: cardData.image),
                    instructionsPopup: getPopupInfoModel(
                        from: cardData.instructionsPopup,
                        withA11yID: "")
                )
            }

            return nil
        }
    }

    /// Returns an optional array of ``OnboardingButtonInfoModel`` given the data.
    /// A card is not viable without buttons.
    private func getOnboardingCardButtons(
        from cardButtons: NimbusOnboardingButtons
    ) -> OnboardingButtons {
        return OnboardingButtons(
            primary: OnboardingButtonInfoModel(
                title: String(format: cardButtons.primary.title,
                              AppName.shortName.rawValue),
                action: cardButtons.primary.action),
            secondary: cardButtons.secondary.map {
                OnboardingButtonInfoModel(title: $0.title, action: $0.action)
            })
    }

    private func getOnboardingMultipleChoiceButtons(
        from cardButtons: [NimbusOnboardingMultipleChoiceButton]
    ) -> [OnboardingMultipleChoiceButtonModel] {
        return cardButtons.map { button in
            return OnboardingMultipleChoiceButtonModel(
                title: button.title,
                action: button.action,
                imageID: getOnboardingMultipleChoiceButtonImageID(from: button.image)
            )
        }
    }

    private func getOnboardingLink(
        from cardLink: NimbusOnboardingLink?
    ) -> OnboardingLinkInfoModel? {
        guard let cardLink = cardLink,
              let url = URL(string: cardLink.url)
        else { return nil }

        return OnboardingLinkInfoModel(title: cardLink.title, url: url)
    }

    private func getOnboardingMultipleChoiceButtonImageID(
        from identifier: NimbusOnboardingMultipleChoiceButtonImage
    ) -> String {
        switch identifier {
        case .themeSystem: return ImageIdentifiers.Onboarding.MultipleChoiceButtonImages.themeSystem
        case .themeDark: return ImageIdentifiers.Onboarding.MultipleChoiceButtonImages.themeDark
        case .themeLight: return ImageIdentifiers.Onboarding.MultipleChoiceButtonImages.themeLight
        case .toolbarTop: return ImageIdentifiers.Onboarding.MultipleChoiceButtonImages.toolbarTop
        case .toolbarBottom: return ImageIdentifiers.Onboarding.MultipleChoiceButtonImages.toolbarBottom
        }
    }

    private func getPopupInfoModel(
        from data: NimbusOnboardingInstructionPopup?,
        withA11yID a11yID: String
    ) -> OnboardingInstructionsPopupInfoModel? {
        guard let data else { return nil }

        return OnboardingInstructionsPopupInfoModel(
            title: data.title,
            instructionSteps: data.instructions
                .map { String(format: $0, AppName.shortName.rawValue) },
            buttonTitle: data.buttonTitle,
            buttonAction: data.buttonAction,
            a11yIdRoot: a11yID)
    }
}
