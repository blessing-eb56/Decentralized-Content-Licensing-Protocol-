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

;; Helper function to calculate royalty amount
(define-private (calculate-royalty-amount (fee uint) (royalty-percent uint))
  (/ (* fee royalty-percent) u100))

;; Helper function to calculate platform fee
(define-private (calculate-platform-fee (fee uint))
  (/ (* fee (var-get platform-fee-percent)) u100))

;; Helper function to check if license is still valid
(define-private (is-license-valid (expiry uint))
  (<= block-height expiry))

;; Helper function to validate principal is not the zero address
(define-private (is-valid-principal (address principal))
  (not (is-eq address 'SP000000000000000000002Q6VF78)))

;; Helper function to validate hash
(define-private (is-valid-hash (hash (buff 32)))
  (is-eq (len hash) u32))

;; Helper function to validate optional hash
(define-private (is-valid-optional-hash (hash (optional (buff 32))))
  (match hash
    evidence-data (is-valid-hash evidence-data)
    true))

;; Helper function to validate royalty percentage
(define-private (is-valid-royalty (royalty uint))
  (<= royalty (var-get max-royalty-percent)))

;; Function to register new content
(define-public (register-content 
    (content-hash (buff 32)) 
    (title (string-utf8 100)) 
    (description (string-utf8 500)) 
    (license-fee uint)
    (royalty-percent uint)
    (content-type (string-ascii 50))
    (metadata-url (optional (string-utf8 256)))
  )
  (begin
    (asserts! (contract-not-paused) ERR_CONTRACT_PAUSED)
    (asserts! (is-valid-hash content-hash) ERR_INVALID_HASH_SIZE)
    (asserts! (is-none (map-get? content-registry { content-hash: content-hash })) ERR_CONTENT_ALREADY_REGISTERED)
    (asserts! (>= license-fee (var-get minimum-license-fee)) ERR_MINIMUM_FEE_NOT_MET)
    (asserts! (is-valid-royalty royalty-percent) ERR_ROYALTY_TOO_HIGH)
    
    (map-set content-registry { content-hash: content-hash }
      {
        creator: tx-sender,
        title: title,
        description: description,
        license-fee: license-fee,
        royalty-percent: royalty-percent,
        created-at: block-height,
        content-type: content-type,
        metadata-url: metadata-url
      }
    )
    (print { event: "content-registered", content-hash: content-hash, creator: tx-sender, title: title })
    (ok true)))

;; Function to update content details
(define-public (update-content-details
    (content-hash (buff 32))
    (title (string-utf8 100))
    (description (string-utf8 500))
    (license-fee uint)
    (royalty-percent uint)
    (content-type (string-ascii 50))
    (metadata-url (optional (string-utf8 256)))
  )
  (begin
    (asserts! (contract-not-paused) ERR_CONTRACT_PAUSED)
    (let (
      (content-data (unwrap! (map-get? content-registry { content-hash: content-hash }) ERR_CONTENT_NOT_FOUND))
      (creator (get creator content-data))
    )
      (asserts! (is-eq tx-sender creator) ERR_CREATOR_ONLY)
      (asserts! (>= license-fee (var-get minimum-license-fee)) ERR_MINIMUM_FEE_NOT_MET)
      (asserts! (is-valid-royalty royalty-percent) ERR_ROYALTY_TOO_HIGH)
      
      (map-set content-registry { content-hash: content-hash }
        {
          creator: creator,
          title: title,
          description: description,
          license-fee: license-fee,
          royalty-percent: royalty-percent,
          created-at: (get created-at content-data),
          content-type: content-type,
          metadata-url: metadata-url
        }
      )
      (print { event: "content-updated", content-hash: content-hash, creator: creator, title: title })
      (ok true))))

;; Function to purchase a license for content
(define-public (purchase-license 
    (content-hash (buff 32)) 
    (license-type (string-ascii 20))
    (period uint)
    (terms-hash (optional (buff 32)))
    (commercial-use bool)
  )
  (begin
    (asserts! (contract-not-paused) ERR_CONTRACT_PAUSED)
    (let (
      (caller tx-sender)
      (content-data (unwrap! (map-get? content-registry { content-hash: content-hash }) ERR_CONTENT_NOT_FOUND))
      (creator (get creator content-data))
      (license-fee (get license-fee content-data))
      (royalty-percent (get royalty-percent content-data))
      (license-period (if (> period u0) period STANDARD_LICENSE_PERIOD))
      (license-key { content-hash: content-hash, licensee: caller })
      (existing-license (map-get? active-licenses license-key))
      (platform-fee (calculate-platform-fee license-fee))
      (creator-royalty (calculate-royalty-amount license-fee royalty-percent))
      (total-fee (+ license-fee platform-fee))
      (current-creator-earnings (default-to u0 (map-get? creator-earnings creator)))
    )
      (asserts! (is-valid-optional-hash terms-hash) ERR_INVALID_HASH_SIZE)
      (asserts! (or (is-none existing-license) 
                   (not (is-license-valid (get expiry (unwrap! existing-license ERR_LICENSE_NOT_FOUND))))) 
               ERR_ALREADY_LICENSED)

      ;; Transfer the total fee
      (match (stx-transfer? total-fee caller (as-contract tx-sender))
        success (begin
          ;; Update revenue pool with platform fee
          (var-set revenue-pool (+ (var-get revenue-pool) platform-fee))
          
          ;; Update creator earnings
          (map-set creator-earnings creator (+ current-creator-earnings creator-royalty))
          
          ;; Set the license
          (map-set active-licenses license-key
            {
              license-type: license-type,
              fee-paid: license-fee,
              expiry: (+ block-height license-period),
              terms-hash: terms-hash,
              commercial-use: commercial-use
            }
          )
          
          (print { 
            event: "license-purchased", 
            content-hash: content-hash, 
            licensee: caller,
            license-type: license-type,
            fee-paid: license-fee,
            platform-fee: platform-fee,
            creator-royalty: creator-royalty,
            expiry: (+ block-height license-period),
            commercial-use: commercial-use
          })
          
          (ok true))
        error (err error)))))

;; Function to renew a license
(define-public (renew-license (content-hash (buff 32)) (additional-period uint))
  (begin
    (asserts! (contract-not-paused) ERR_CONTRACT_PAUSED)
    (let (
      (caller tx-sender)
      (license-key { content-hash: content-hash, licensee: caller })
      (license-data (unwrap! (map-get? active-licenses license-key) ERR_NOT_LICENSED))
      (content-data (unwrap! (map-get? content-registry { content-hash: content-hash }) ERR_CONTENT_NOT_FOUND))
      (creator (get creator content-data))
      (license-fee (get license-fee content-data))
      (royalty-percent (get royalty-percent content-data))
      (platform-fee (calculate-platform-fee license-fee))
      (creator-royalty (calculate-royalty-amount license-fee royalty-percent))
      (total-fee (+ license-fee platform-fee))
      (current-creator-earnings (default-to u0 (map-get? creator-earnings creator)))
      (current-expiry (get expiry license-data))
    )
      (asserts! (> additional-period u0) ERR_ZERO_AMOUNT)
      
      ;; Transfer the total fee
      (match (stx-transfer? total-fee caller (as-contract tx-sender))
        success (begin
          ;; Update revenue pool with platform fee
          (var-set revenue-pool (+ (var-get revenue-pool) platform-fee))
          
          ;; Update creator earnings
          (map-set creator-earnings creator (+ current-creator-earnings creator-royalty))
          
          ;; Update the license expiry
          (map-set active-licenses license-key
            {
              license-type: (get license-type license-data),
              fee-paid: (+ (get fee-paid license-data) license-fee),
              expiry: (+ current-expiry additional-period),
              terms-hash: (get terms-hash license-data),
              commercial-use: (get commercial-use license-data)
            }
          )
          
          (print { 
            event: "license-renewed", 
            content-hash: content-hash, 
            licensee: caller,
            fee-paid: license-fee,
            platform-fee: platform-fee,
            creator-royalty: creator-royalty,
            new-expiry: (+ current-expiry additional-period)
          })
          
          (ok true))
        error (err error)))))

;; Function for creators to withdraw their earnings
(define-public (withdraw-earnings)
  (begin
    (asserts! (contract-not-paused) ERR_CONTRACT_PAUSED)
    (let (
      (caller tx-sender)
      (earnings (default-to u0 (map-get? creator-earnings caller)))
    )
      (asserts! (> earnings u0) ERR_INSUFFICIENT_FUNDS)
      
      ;; Transfer the earnings
      (match (as-contract (stx-transfer? earnings tx-sender caller))
        success (begin
          ;; Reset the creator's earnings
          (map-delete creator-earnings caller)
          
          (print { 
            event: "earnings-withdrawn", 
            creator: caller,
            amount: earnings
          })
          
          (ok earnings))
        error (err error)))))

;; Function to transfer license to another user
(define-public (transfer-license (content-hash (buff 32)) (new-licensee principal))
  (begin
    (asserts! (contract-not-paused) ERR_CONTRACT_PAUSED)
    (asserts! (is-valid-principal new-licensee) ERR_INVALID_PRINCIPAL)
    (let (
      (caller tx-sender)
      (current-license-key { content-hash: content-hash, licensee: caller })
      (new-license-key { content-hash: content-hash, licensee: new-licensee })
      (license-data (unwrap! (map-get? active-licenses current-license-key) ERR_NOT_LICENSED))
      (current-expiry (get expiry license-data))
    )
      (asserts! (is-license-valid current-expiry) ERR_LICENSE_PERIOD_EXPIRED)
      (asserts! (is-none (map-get? active-licenses new-license-key)) ERR_ALREADY_LICENSED)
      
      ;; Delete current license
      (map-delete active-licenses current-license-key)
      
      ;; Create new license for recipient
      (map-set active-licenses new-license-key license-data)
      
      (print { 
        event: "license-transferred", 
        content-hash: content-hash, 
        from: caller,
        to: new-licensee,
        license-type: (get license-type license-data),
        expiry: current-expiry
      })
      
      (ok true))))

;; Function to check if a license has expired and update its status
(define-public (check-license-status (content-hash (buff 32)) (licensee principal))
  (begin
    (asserts! (is-valid-principal licensee) ERR_INVALID_PRINCIPAL)
    (let (
      (license-key { content-hash: content-hash, licensee: licensee })
      (license-data (unwrap! (map-get? active-licenses license-key) ERR_LICENSE_NOT_FOUND))
      (expiry (get expiry license-data))
    )
      (if (>= block-height expiry)
          (begin
            ;; License has expired, remove it
            (map-delete active-licenses license-key)
            (print { event: "license-expired", content-hash: content-hash, licensee: licensee })
            (ok true))
          (ok false)))))

;; Admin functions

;; Function to change the contract owner
(define-public (change-contract-owner (new-owner principal))
  (begin
    (asserts! (contract-not-paused) ERR_CONTRACT_PAUSED)
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (asserts! (is-valid-principal new-owner) ERR_INVALID_PRINCIPAL)
    (print { event: "contract-owner-changed", old-owner: (var-get contract-owner), new-owner: new-owner })
    (ok (var-set contract-owner new-owner))))

;; Function to pause contract in emergency
(define-public (set-contract-pause (paused bool))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (ok (var-set contract-paused paused))))

;; Function to set minimum license fee
(define-public (set-minimum-license-fee (amount uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (asserts! (> amount u0) ERR_ZERO_AMOUNT)
    (print { event: "minimum-license-fee-changed", old-minimum: (var-get minimum-license-fee), new-minimum: amount })
    (ok (var-set minimum-license-fee amount))))

;; Function to set platform fee percentage
(define-public (set-platform-fee-percent (percent uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (asserts! (<= percent u20) ERR_FEE_EXCEEDS_LIMIT) ;; Maximum 20% platform fee
    (print { event: "platform-fee-changed", old-fee: (var-get platform-fee-percent), new-fee: percent })
    (ok (var-set platform-fee-percent percent))))

;; Function to set maximum royalty percentage
(define-public (set-max-royalty-percent (percent uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (asserts! (<= percent u80) ERR_FEE_EXCEEDS_LIMIT) ;; Cannot exceed 80%
    (print { event: "max-royalty-changed", old-max: (var-get max-royalty-percent), new-max: percent })
    (ok (var-set max-royalty-percent percent))))

;; Function to withdraw platform fees
(define-public (withdraw-platform-fees)
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (let ((pool-balance (var-get revenue-pool)))
      (asserts! (> pool-balance u0) ERR_POOL_EMPTY)
      (match (as-contract (stx-transfer? pool-balance tx-sender (var-get contract-owner)))
        success (begin
          (var-set revenue-pool u0)
          (print { event: "platform-fees-withdrawn", amount: pool-balance, recipient: (var-get contract-owner) })
          (ok pool-balance))
        error (err error)))))

;; Read-only functions

;; Function to get the current revenue pool balance
(define-read-only (get-revenue-pool-balance)
  (ok (var-get revenue-pool)))

;; Function to get content details
(define-read-only (get-content-details (content-hash (buff 32)))
  (match (map-get? content-registry { content-hash: content-hash })
    content-data (ok content-data)
    ERR_CONTENT_NOT_FOUND))

;; Function to check if content exists
(define-read-only (content-exists (content-hash (buff 32)))
  (is-some (map-get? content-registry { content-hash: content-hash })))

;; Function to check if user has valid license
(define-read-only (has-valid-license (content-hash (buff 32)) (licensee principal))
  (match (map-get? active-licenses { content-hash: content-hash, licensee: licensee })
    license-data (ok (is-license-valid (get expiry license-data)))
    (ok false)))

;; Function to get license details
(define-read-only (get-license-details (content-hash (buff 32)) (licensee principal))
  (match (map-get? active-licenses { content-hash: content-hash, licensee: licensee })
    license-data (ok { 
      license-type: (get license-type license-data),
      fee-paid: (get fee-paid license-data),
      expiry: (get expiry license-data),
      terms-hash: (get terms-hash license-data),
      commercial-use: (get commercial-use license-data),
      is-valid: (is-license-valid (get expiry license-data)),
      remaining-blocks: (- (get expiry license-data) block-height)
    })
    ERR_LICENSE_NOT_FOUND))

;; Function to get creator earnings
(define-read-only (get-creator-earnings (creator principal))
  (ok (default-to u0 (map-get? creator-earnings creator))))

;; Function to get contract statistics
(define-read-only (get-contract-stats)
  (ok {
    revenue-pool: (var-get revenue-pool),
    is-paused: (var-get contract-paused),
    owner: (var-get contract-owner),
    minimum-license-fee: (var-get minimum-license-fee),
    platform-fee-percent: (var-get platform-fee-percent),
    max-royalty-percent: (var-get max-royalty-percent),
    standard-license-period: STANDARD_LICENSE_PERIOD
  }))