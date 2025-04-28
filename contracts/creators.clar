;; Decentralized Content Licensing Protocol (DCLP)

;; Define error constants with specific messages
(define-constant ERR_INVALID_AMOUNT (err u100))
(define-constant ERR_INSUFFICIENT_FUNDS (err u101))
(define-constant ERR_LICENSE_NOT_FOUND (err u102))
(define-constant ERR_UNAUTHORIZED (err u103))
(define-constant ERR_ALREADY_LICENSED (err u104))
(define-constant ERR_INVALID_PRINCIPAL (err u105))
(define-constant ERR_NOT_LICENSED (err u106))
(define-constant ERR_ZERO_AMOUNT (err u107))
(define-constant ERR_RENEWAL_ALREADY_PROCESSED (err u108))
(define-constant ERR_POOL_EMPTY (err u109))
(define-constant ERR_LICENSE_NOT_EXPIRED (err u110))
(define-constant ERR_FEE_EXCEEDS_LIMIT (err u111))
(define-constant ERR_CONTRACT_PAUSED (err u112))
(define-constant ERR_FEE_CALCULATION_FAILED (err u113))
(define-constant ERR_LICENSE_PERIOD_EXPIRED (err u114))
(define-constant ERR_MINIMUM_FEE_NOT_MET (err u115))
(define-constant ERR_INVALID_HASH_SIZE (err u116))
(define-constant ERR_INVALID_LICENSEE (err u117))
(define-constant ERR_CONTENT_ALREADY_REGISTERED (err u118))
(define-constant ERR_CONTENT_NOT_FOUND (err u119))
(define-constant ERR_INVALID_LICENSE_TERMS (err u120))
(define-constant ERR_CREATOR_ONLY (err u121))
(define-constant ERR_ROYALTY_TOO_HIGH (err u122))

;; Define the contract main variables
(define-data-var revenue-pool uint u0)
(define-data-var contract-owner principal tx-sender)
(define-data-var contract-paused bool false)
(define-data-var minimum-license-fee uint u1000000) ;; Minimum license fee in microSTX
(define-data-var platform-fee-percent uint u5) ;; 5% platform fee
(define-data-var max-royalty-percent uint u50) ;; Maximum 50% royalty rate

;; Define maps
(define-map content-registry 
  { content-hash: (buff 32) }
  { 
    creator: principal, 
    title: (string-utf8 100),
    description: (string-utf8 500),
    license-fee: uint,
    royalty-percent: uint,
    created-at: uint,
    content-type: (string-ascii 50),
    metadata-url: (optional (string-utf8 256))
  }
)

(define-map active-licenses 
  { content-hash: (buff 32), licensee: principal }
  {
    license-type: (string-ascii 20),
    fee-paid: uint,
    expiry: uint,
    terms-hash: (optional (buff 32)),
    commercial-use: bool
  }
)

(define-map creator-earnings principal uint)

;; Define the license expiration period (e.g., 365 days in blocks, assuming 144 blocks per day)
(define-constant STANDARD_LICENSE_PERIOD u52560)

;; Define guard for paused contract
(define-private (contract-not-paused)
  (not (var-get contract-paused)))

