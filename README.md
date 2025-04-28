# Decentralized Content Licensing Protocol (DCLP)

A blockchain-based protocol for transparent, trustless content licensing that protects creators' rights and provides verifiable ownership of digital assets.

## Overview

The Decentralized Content Licensing Protocol (DCLP) is a smart contract system built on Stacks blockchain that enables creators to register their digital content and license it to users under specific terms. DCLP provides a decentralized alternative to traditional content licensing platforms, eliminating intermediaries while ensuring creators receive fair compensation for their work.

## Features

- **Content Registration**: Creators can register their digital assets with unique identifiers
- **Flexible Licensing Terms**: Set custom license fees, royalty rates, and usage permissions
- **Time-Based Licenses**: All licenses have expirations, ensuring ongoing revenue for creators
- **License Transfers**: Users can transfer their licenses to other parties
- **Transparent Fee Structure**: Platform fees and creator royalties are clearly defined
- **Creator Withdrawals**: Creators can withdraw their earned royalties at any time
- **Commercial/Non-Commercial Usage**: Licenses can specify permitted usage types
- **Security Focused**: Comprehensive input validation to prevent security issues

## How It Works

1. **Content Registration**: Creators register their content by providing metadata and a content hash, setting license fees and royalty percentages.

2. **License Purchase**: Users purchase time-limited licenses for specific content, paying fees that are split between the platform and the creator.

3. **License Management**: Users can renew or transfer their licenses. The protocol maintains an immutable record of all licensing activity.

4. **Royalty Distribution**: Creators can withdraw accumulated royalties from their content licenses at any time.

## Technical Implementation

The DCLP smart contract is written in Clarity for the Stacks blockchain. It uses several data maps to track content registration, active licenses, and creator earnings.

### Main Data Structures

- `content-registry`: Stores metadata about registered content
- `active-licenses`: Tracks all active content licenses
- `creator-earnings`: Records earnings available for withdrawal by creators

### Security Features

- Comprehensive input validation for all user-provided data
- Hash verification to ensure data integrity
- Principal validation to prevent address spoofing
- String validation to prevent unexpected behavior

### Key Functions

- `register-content`: Register new digital content
- `update-content-details`: Update existing content metadata
- `purchase-license`: Acquire a license for specific content
- `renew-license`: Extend an existing license period
- `withdraw-earnings`: Allow creators to withdraw their earnings
- `transfer-license`: Transfer a license to another user

## Usage Examples

### For Creators

```clarity
;; Register a new digital artwork
(contract-call? .dclp register-content 
  0x8a9c5031b05d201a0f69f1476912cb5c2354d482f6d5c56644b8dce304a8875d
  "Sunset Over Digital Horizon"
  "A unique digital artwork exploring the intersection of nature and technology"
  u50000000 ;; 50 STX license fee
  u20 ;; 20% royalty on each license sale
  "image/digital-art"
  (some u"https://metadata.example.com/artwork/12345")
)

;; Withdraw earnings
(contract-call? .dclp withdraw-earnings)
```

### For Users

```clarity
;; Purchase a license for digital content
(contract-call? .dclp purchase-license
  0x8a9c5031b05d201a0f69f1476912cb5c2354d482f6d5c56644b8dce304a8875d
  "standard" ;; license type
  u52560 ;; 365 days (in blocks)
  none ;; no specific terms hash
  false ;; non-commercial use
)

;; Transfer a license to another user
(contract-call? .dclp transfer-license
  0x8a9c5031b05d201a0f69f1476912cb5c2354d482f6d5c56644b8dce304a8875d
  'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7
)
```

## Development

### Prerequisites

- [Clarinet](https://github.com/hirosystems/clarinet) - Clarity development environment
- [Stacks blockchain API](https://github.com/blockstack/stacks-blockchain-api) - For interacting with the blockchain

### Testing

Run the included test suite using Clarinet:

```bash
clarinet test
```

### Security Considerations

The contract implements extensive data validation to prevent potential security issues:

- All string inputs are validated for length and format
- All hash values are checked for correct size
- All user permissions are strictly enforced
- Proper error handling for all operations

## License

This project is licensed under the MIT License