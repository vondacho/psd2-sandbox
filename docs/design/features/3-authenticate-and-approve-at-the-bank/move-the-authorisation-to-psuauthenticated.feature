# Generated from docs/design/examplemap/3-authenticate-and-approve-at-the-bank/move-the-authorisation-to-psuauthenticated.examplemap by tools/emgherkin.py -- do not edit.
# Source of truth is the example map; regenerate after changing it.

@bank-xs2a @spec-14.16 @walking-skeleton @ready
Feature: Move the authorisation to psuAuthenticated
  As Bank product owner
  I want the authorisation sub-resource updated as the PSU progresses
  So that the TPP can read a truthful scaStatus

  @spec-14.16
  Rule: The scaStatus follows the PSU: received, psuIdentified when the PSU-ID is entered, psuAuthenticated when the password is verified

    @nominal @walking-skeleton
    Scenario: Before anything, received
      Given consent 123cons456 just created
      When the TPP calls GET /v1/consents/123cons456/authorisations/123auth567
      Then the answer is {scaStatus: received}

    @nominal @walking-skeleton
    Scenario: After the PSU-ID is entered, psuIdentified
      Given Anna typed anna.mueller and the CIAM resolved the identity
      When the TPP reads the scaStatus
      Then the answer is psuIdentified
      And the consent's psuId is anna.mueller

    @nominal @walking-skeleton
    Scenario: After the password is verified, psuAuthenticated
      Given Anna's password was verified
      When the TPP reads the scaStatus
      Then the answer is psuAuthenticated

    @edge @mvp
    Scenario: A wrong password leaves the status at psuIdentified
      Given Anna typed a wrong password twice
      When the TPP reads the scaStatus
      Then the answer is psuIdentified

    @error @mvp
    Scenario: A locked identity fails the authorisation
      Given the fifth wrong password locked anna.mueller
      When the TPP reads the scaStatus
      Then the answer is failed
      And the consent status is rejected

  @spec-14.16
  Rule: The status moves forward only, and terminal states never change

    @edge @mvp
    Scenario: Reloading the login page does not reset the status
      Given scaStatus is psuAuthenticated
      When Anna reloads the CIAM page
      Then scaStatus is still psuAuthenticated

    @edge @mvp
    Scenario: An outcome message arriving late cannot move failed back
      Given scaStatus is failed
      When a delayed message 'psuAuthenticated' arrives from the CIAM
      Then scaStatus stays failed and the message is logged as ignored

    @edge @mvp
    Scenario: finalised is terminal
      Given scaStatus is finalised
      When any further update arrives
      Then scaStatus stays finalised

  @security
  Rule: The authorisation is readable by the creating TPP only

    @nominal @walking-skeleton
    Scenario: The TPP reads its own authorisation
      Given the TPP's QWAC
      When GET /v1/consents/123cons456/authorisations/123auth567 is called
      Then the answer is 200

    @error @mvp
    Scenario: C cannot read the TPP's authorisation
      Given C's QWAC
      When GET /v1/consents/123cons456/authorisations/123auth567 is called
      Then the answer is 403 CONSENT_UNKNOWN

    @error @mvp
    Scenario: An unknown authorisation id answers RESOURCE_UNKNOWN
      Given the TPP's QWAC
      When GET /v1/consents/123cons456/authorisations/nope is called
      Then the answer is 404 RESOURCE_UNKNOWN

  Rule: The CIAM updates the authorisation through the internal contract, with the PSU

    @nominal @walking-skeleton
    Scenario: The internal update carries scaStatus and psuId
      Given Anna's password was verified in session sess-1
      When the CIAM calls POST /internal/consents/123cons456/authorisations/123auth567
      Then the body is {scaStatus: psuAuthenticated, psuId: anna.mueller}

    @error @mvp
    Scenario: An update for an authorisation of another consent is refused
      Given authorisation 123auth567 belongs to 123cons456
      When the CIAM posts to /internal/consents/111cons222/authorisations/123auth567
      Then consent management answers 404
