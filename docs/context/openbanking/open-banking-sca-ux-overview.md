# Open Banking SCA UX: AIS, PIS, redirect, decoupled, and embedded

> Markdown export of the preceding answer. The original illustrative image search is omitted; the text and screen-flow examples are retained.

For Open Banking UX, separate **what PSD2/SCA requires** from **how the bank chooses to perform authentication**. The EBA recognizes three principal approaches through dedicated interfaces: **redirect, decoupled, and embedded**, including combinations. [Open Banking Customer Experience Guidelines](https://standards.openbanking.org.uk/customer-experience-guidelines/authentication-methods/latest/)

## 1. The conceptual model

The journey involves a **TPP** (AISP or PISP), a **PSU** (customer), and an **ASPSP** (usually the bank holding the payment account). AIS requests access to account information; PIS initiates a payment.

SCA normally uses at least two independent elements drawn from **knowledge**, **possession**, and **inherence**. For remote electronic payments, dynamic linking binds authentication to the specific amount and payee. [EBA, Article 97](https://www.eba.europa.eu/regulation-and-policy/single-rulebook/interactive-single-rulebook/16226)

```text
SCA requirement
  └─ Authentication procedure
       ├─ Redirect
       ├─ Decoupled
       ├─ Embedded
       └─ Combination
```

These are interaction architectures, not different strengths of authentication.

## 2. Redirect / coupled journey

The user starts in the TPP, enters a bank-controlled environment to authenticate and authorize, then returns. On mobile, the redirect may be app to app rather than browser to browser.

```text
AIS: TPP bank selection → TPP handoff → bank sign-in/biometric
     → bank account/consent confirmation → return to TPP → connected

PIS: TPP payment review → TPP handoff → bank authentication
     → bank payment confirmation → return to TPP → payment status
```

There are two UX contexts: the TPP's handoff and return screens, and the bank's authentication and consent screens. If bank customers can use biometrics in the bank's direct channel, the bank should make that procedure available through a TPP journey. [EBA Q&A 2023_6767](https://www.eba.europa.eu/single-rule-book-qa/qna/view/publicId/2023_6767)

On mobile, a clear handoff could say: “You'll now securely continue in Example Bank.” After Face ID/fingerprint and confirmation in the bank app, a deep link returns to the TPP.

## 3. Decoupled SCA

The TPP keeps a waiting session while the customer authenticates through a separate bank-controlled channel, commonly a banking app on another device. The bank receives the request, the user reviews and approves it there, and the TPP learns the result through status updates. [Open Banking authentication methods](https://standards.openbanking.org.uk/customer-experience-guidelines/authentication-methods/latest/)

```text
TPP: Review payment → “Open your banking app” → waiting → result
                                              ↑             │
Bank app:                      notification → review → SCA/approve
```

A PIS bank prompt should show the payee and amount. Decoupled UX needs states such as **waiting for approval**, **check your phone**, **still waiting**, **try again**, **expired**, and **rejected**. It is useful for desktop or point-of-sale journeys in which the customer approves on a phone. Open Banking describes identification variants using a static customer identifier, a bank-generated identifier, a TPP-generated identifier, or an identifier saved from an earlier interaction. [Open Banking authentication methods](https://standards.openbanking.org.uk/customer-experience-guidelines/authentication-methods/latest/)

## 4. Embedded SCA

In an embedded approach, authentication information travels through the TPP's interface to the bank. The user can remain in the TPP UI, for example entering an identifier/password and then a bank-issued challenge code. In redirect and decoupled approaches, authentication data instead travel directly between the customer and bank. [EBA Q&A 2021_6044](https://www.eba.europa.eu/single-rule-book-qa/qna/view/publicId/2021_6044)

```text
TPP: Bank identifier/credential → bank challenge → code entry → result
```

The context switch disappears, but the TPP must handle the trust implications of collecting authentication data and the variation between banks' procedures. Embedded is an architecture to assess against the bank's actual supported API and applicable scheme rules, not a default screen design. [Open Banking authentication methods](https://standards.openbanking.org.uk/customer-experience-guidelines/authentication-methods/latest/)

## 5. PIS changes the UX

AIS asks: **“Let this application access these accounts and data.”** PIS asks: **“Authorize this specific transaction.”** PIS confirmation must put the payment details in front of the customer because amount and payee are security relevant for dynamic linking.

```text
CONFIRM PAYMENT
Pay          €1,250.00
To           ACME GmbH
From         Current account ••4821
Reference    Invoice 7842
[ Authorise €1,250.00 ]
Cancel
```

## 6. AIS consent UX

AIS should answer **who receives access, what data, which accounts, and for how long**. Consent and authentication remain distinct concepts even when a bank combines them visually.

```text
SHARE ACCOUNT INFORMATION
BudgetApp wants account details, balances, and transactions.
Choose accounts: ☑ Current ••4821  ☑ Savings ••8290  ☐ Joint ••1820
[ Allow access ]    Cancel

After authorization: “Accounts connected” → Continue
```

## 7. UX state model

```text
SCA_REQUIRED
  ├─ REDIRECT: handoff → bank authentication → authorization → return
  ├─ DECOUPLED: waiting → bank authentication → authorization → status
  └─ EMBEDDED: identify → challenge → authorization → status

SCA_RESULT: success | rejected | failed | pending
  ├─ AIS success → retrieve permitted account data
  └─ PIS authorization → check payment/execution status
```

Also model `USER_CANCELLED`, `SCA_EXPIRED`, `BANK_APP_NOT_INSTALLED`, `APP_SWITCH_FAILED`, `BANK_UNAVAILABLE`, `SCA_METHOD_SELECTION_REQUIRED`, `MULTIPLE_PSUS`, `CONSENT_REJECTED`, `PAYMENT_REJECTED`, and `STATUS_PENDING`.

An AIS-to-PIS journey may need account-access authentication followed by payment authentication. Under conditions discussed by the EBA, an earlier element can be reused while the payment still meets the remaining requirements, including dynamic linking. [EBA Q&A 2025_7358](https://www.eba.europa.eu/single-rule-book-qa/qna/view/publicId/2025_7358)

| Dimension | Variants |
| --- | --- |
| Service | AIS / PIS |
| Architecture | Redirect / Decoupled / Embedded / combination |
| Channel | Web→web / web→app / app→app / POS→app |
| Identification | Known PSU / enter identifier / select user |
| Authenticator | Password / OTP / bank app / biometrics / hardware |
| Consent | AIS scope / PIS transaction |
| Result | Success / pending / reject / fail / expired |
| Return | Redirect / deep link / polling / push or callback |

For a formal specification, **redirect / decoupled / embedded** is clearer than treating “coupled” as the sole opposite of “decoupled.” See the companion [wireflow matrix](open-banking-sca-wireflow-matrix.md).
