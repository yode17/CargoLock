;; CargoLock - Smart Escrow System for Cargo Delivery
;; Automatically releases payments when cargo reaches GPS coordinates and meets condition requirements

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_SHIPMENT_NOT_FOUND (err u101))
(define-constant ERR_INVALID_AMOUNT (err u102))
(define-constant ERR_SHIPMENT_EXISTS (err u103))
(define-constant ERR_INVALID_INPUT (err u104))
(define-constant ERR_SHIPMENT_COMPLETED (err u105))
(define-constant ERR_CONDITIONS_NOT_MET (err u106))
(define-constant ERR_INSUFFICIENT_FUNDS (err u107))
(define-constant ERR_INVALID_STATUS (err u108))

;; Validation constants
(define-constant MAX_TEMP u373) ;; Max 100C (373K)
(define-constant MIN_TEMP u233) ;; Min -40C (233K)
(define-constant MAX_HUMIDITY u100) ;; Max 100 percent
(define-constant MAX_SHOCK u1000) ;; Max 1000 G-force
(define-constant MAX_COORDINATE u18000000) ;; Max coordinate * 100000 for precision
(define-constant MIN_COORDINATE u0) ;; Min coordinate (0 for unsigned)
(define-constant MAX_PAYMENT u100000000) ;; Max 100M STX
(define-constant MIN_PAYMENT u1) ;; Min 1 STX
(define-constant MAX_SHIPMENT_ID u1000000) ;; Max shipment ID

;; Shipment status constants
(define-constant STATUS_CREATED u1)
(define-constant STATUS_IN_TRANSIT u2)
(define-constant STATUS_DELIVERED u3)
(define-constant STATUS_CANCELLED u4)

;; Data Variables
(define-data-var shipment-counter uint u0)
(define-data-var total-escrowed uint u0)
(define-data-var total-released uint u0)

;; Data Maps
(define-map shipments
  { shipment-id: uint }
  {
    shipper: principal,
    carrier: principal,
    receiver: principal,
    payment-amount: uint,
    target-lat: uint,
    target-lng: uint,
    temp-min: uint,
    temp-max: uint,
    humidity-max: uint,
    shock-max: uint,
    status: uint,
    created-at: uint,
    delivered-at: uint
  }
)

(define-map delivery-confirmations
  { shipment-id: uint }
  {
    current-lat: uint,
    current-lng: uint,
    temperature: uint,
    humidity: uint,
    shock-level: uint,
    timestamp: uint,
    oracle: principal
  }
)

(define-map authorized-oracles
  { oracle: principal }
  { authorized: bool }
)

;; Input validation functions
(define-private (validate-coordinates (lat uint) (lng uint))
  (and 
    (<= lat MAX_COORDINATE)
    (<= lng MAX_COORDINATE)
    (>= lat MIN_COORDINATE)
    (>= lng MIN_COORDINATE)
  )
)

(define-private (validate-conditions (temp-min uint) (temp-max uint) (humidity-max uint) (shock-max uint))
  (and
    (>= temp-min MIN_TEMP)
    (<= temp-max MAX_TEMP)
    (<= humidity-max MAX_HUMIDITY)
    (<= shock-max MAX_SHOCK)
    (<= temp-min temp-max)
  )
)

(define-private (validate-payment (amount uint))
  (and (>= amount MIN_PAYMENT) (<= amount MAX_PAYMENT))
)

(define-private (validate-sensor-data (temp uint) (humidity uint) (shock uint))
  (and
    (>= temp MIN_TEMP)
    (<= temp MAX_TEMP)
    (<= humidity MAX_HUMIDITY)
    (<= shock MAX_SHOCK)
  )
)

(define-private (validate-shipment-id (shipment-id uint))
  (and (> shipment-id u0) (<= shipment-id MAX_SHIPMENT_ID))
)

(define-private (validate-principal (user principal))
  (not (is-eq user (as-contract tx-sender)))
)

(define-private (calculate-distance (lat1 uint) (lng1 uint) (lat2 uint) (lng2 uint))
  (let (
    (lat-diff (if (>= lat1 lat2) (- lat1 lat2) (- lat2 lat1)))
    (lng-diff (if (>= lng1 lng2) (- lng1 lng2) (- lng2 lng1)))
  )
    (+ lat-diff lng-diff) ;; Simplified Manhattan distance
  )
)

;; Public Functions

;; Create a new shipment escrow
(define-public (create-shipment 
  (carrier principal)
  (receiver principal)
  (target-lat uint)
  (target-lng uint)
  (temp-min uint)
  (temp-max uint)
  (humidity-max uint)
  (shock-max uint)
  (payment-amount uint))
  (let (
    (shipment-id (+ (var-get shipment-counter) u1))
    (shipper tx-sender)
  )
    (asserts! (validate-principal carrier) ERR_INVALID_INPUT)
    (asserts! (validate-principal receiver) ERR_INVALID_INPUT)
    (asserts! (validate-coordinates target-lat target-lng) ERR_INVALID_INPUT)
    (asserts! (validate-conditions temp-min temp-max humidity-max shock-max) ERR_INVALID_INPUT)
    (asserts! (validate-payment payment-amount) ERR_INVALID_INPUT)
    (asserts! (is-none (map-get? shipments { shipment-id: shipment-id })) ERR_SHIPMENT_EXISTS)

    ;; Transfer payment to escrow
    (try! (stx-transfer? payment-amount shipper (as-contract tx-sender)))

    ;; Update counter and total escrowed
    (var-set shipment-counter shipment-id)
    (var-set total-escrowed (+ (var-get total-escrowed) payment-amount))

    ;; Create shipment record
    (map-set shipments
      { shipment-id: shipment-id }
      {
        shipper: shipper,
        carrier: carrier,
        receiver: receiver,
        payment-amount: payment-amount,
        target-lat: target-lat,
        target-lng: target-lng,
        temp-min: temp-min,
        temp-max: temp-max,
        humidity-max: humidity-max,
        shock-max: shock-max,
        status: STATUS_CREATED,
        created-at: block-height,
        delivered-at: u0
      }
    )

    (ok shipment-id)
  )
)

;; Start shipment (carrier confirms pickup)
(define-public (start-shipment (shipment-id uint))
  (let (
    (shipment-data (unwrap! (map-get? shipments { shipment-id: shipment-id }) ERR_SHIPMENT_NOT_FOUND))
  )
    (asserts! (validate-shipment-id shipment-id) ERR_INVALID_INPUT)
    (asserts! (is-eq tx-sender (get carrier shipment-data)) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get status shipment-data) STATUS_CREATED) ERR_INVALID_STATUS)

    (map-set shipments
      { shipment-id: shipment-id }
      (merge shipment-data { status: STATUS_IN_TRANSIT })
    )

    (ok true)
  )
)

;; Confirm delivery with sensor data (oracle function)
(define-public (confirm-delivery 
  (shipment-id uint)
  (current-lat uint)
  (current-lng uint)
  (temperature uint)
  (humidity uint)
  (shock-level uint))
  (let (
    (shipment-data (unwrap! (map-get? shipments { shipment-id: shipment-id }) ERR_SHIPMENT_NOT_FOUND))
    (oracle tx-sender)
    (oracle-auth (default-to { authorized: false } (map-get? authorized-oracles { oracle: oracle })))
  )
    (asserts! (validate-shipment-id shipment-id) ERR_INVALID_INPUT)
    (asserts! (get authorized oracle-auth) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get status shipment-data) STATUS_IN_TRANSIT) ERR_INVALID_STATUS)
    (asserts! (validate-coordinates current-lat current-lng) ERR_INVALID_INPUT)
    (asserts! (validate-sensor-data temperature humidity shock-level) ERR_INVALID_INPUT)

    ;; Store delivery confirmation
    (map-set delivery-confirmations
      { shipment-id: shipment-id }
      {
        current-lat: current-lat,
        current-lng: current-lng,
        temperature: temperature,
        humidity: humidity,
        shock-level: shock-level,
        timestamp: block-height,
        oracle: oracle
      }
    )

    ;; Check if conditions are met and release payment
    (try! (process-delivery shipment-id))

    (ok true)
  )
)

;; Process delivery and release payment if conditions met
(define-private (process-delivery (shipment-id uint))
  (let (
    (shipment-data (unwrap! (map-get? shipments { shipment-id: shipment-id }) ERR_SHIPMENT_NOT_FOUND))
    (delivery-data (unwrap! (map-get? delivery-confirmations { shipment-id: shipment-id }) ERR_SHIPMENT_NOT_FOUND))
    (distance (calculate-distance 
      (get target-lat shipment-data) 
      (get target-lng shipment-data)
      (get current-lat delivery-data)
      (get current-lng delivery-data)))
    (temp-ok (and 
      (>= (get temperature delivery-data) (get temp-min shipment-data))
      (<= (get temperature delivery-data) (get temp-max shipment-data))))
    (humidity-ok (<= (get humidity delivery-data) (get humidity-max shipment-data)))
    (shock-ok (<= (get shock-level delivery-data) (get shock-max shipment-data)))
    (location-ok (<= distance u50000)) ;; Within 0.5 degree tolerance
    (conditions-met (and temp-ok humidity-ok shock-ok location-ok))
  )
    (if conditions-met
      (begin
        ;; Release payment to carrier
        (try! (as-contract (stx-transfer? 
          (get payment-amount shipment-data) 
          tx-sender 
          (get carrier shipment-data))))

        ;; Update shipment status
        (map-set shipments
          { shipment-id: shipment-id }
          (merge shipment-data { 
            status: STATUS_DELIVERED,
            delivered-at: block-height
          })
        )

        ;; Update total released
        (var-set total-released (+ (var-get total-released) (get payment-amount shipment-data)))

        (ok true)
      )
      ERR_CONDITIONS_NOT_MET
    )
  )
)

;; Cancel shipment (shipper can cancel if not in transit)
(define-public (cancel-shipment (shipment-id uint))
  (let (
    (shipment-data (unwrap! (map-get? shipments { shipment-id: shipment-id }) ERR_SHIPMENT_NOT_FOUND))
  )
    (asserts! (validate-shipment-id shipment-id) ERR_INVALID_INPUT)
    (asserts! (is-eq tx-sender (get shipper shipment-data)) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get status shipment-data) STATUS_CREATED) ERR_INVALID_STATUS)

    ;; Refund payment to shipper
    (try! (as-contract (stx-transfer? 
      (get payment-amount shipment-data) 
      tx-sender 
      (get shipper shipment-data))))

    ;; Update status
    (map-set shipments
      { shipment-id: shipment-id }
      (merge shipment-data { status: STATUS_CANCELLED })
    )

    (ok true)
  )
)

;; Admin function to authorize oracles
(define-public (authorize-oracle (oracle principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (validate-principal oracle) ERR_INVALID_INPUT)
    (map-set authorized-oracles
      { oracle: oracle }
      { authorized: true }
    )
    (ok true)
  )
)

;; Admin function to revoke oracle authorization
(define-public (revoke-oracle (oracle principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (validate-principal oracle) ERR_INVALID_INPUT)
    (map-set authorized-oracles
      { oracle: oracle }
      { authorized: false }
    )
    (ok true)
  )
)

;; Read-only Functions

;; Get shipment information
(define-read-only (get-shipment (shipment-id uint))
  (map-get? shipments { shipment-id: shipment-id })
)

;; Get delivery confirmation
(define-read-only (get-delivery-confirmation (shipment-id uint))
  (map-get? delivery-confirmations { shipment-id: shipment-id })
)

;; Check if oracle is authorized
(define-read-only (is-oracle-authorized (oracle principal))
  (default-to false (get authorized (map-get? authorized-oracles { oracle: oracle })))
)

;; Get shipment status
(define-read-only (get-shipment-status (shipment-id uint))
  (match (map-get? shipments { shipment-id: shipment-id })
    shipment-data (some (get status shipment-data))
    none
  )
)

;; Get global statistics
(define-read-only (get-global-stats)
  {
    total-shipments: (var-get shipment-counter),
    total-escrowed: (var-get total-escrowed),
    total-released: (var-get total-released),
    active-escrow: (- (var-get total-escrowed) (var-get total-released))
  }
)

;; Check delivery conditions
(define-read-only (check-delivery-conditions (shipment-id uint))
  (match (map-get? shipments { shipment-id: shipment-id })
    shipment-data
    (match (map-get? delivery-confirmations { shipment-id: shipment-id })
      delivery-data
      (let (
        (distance (calculate-distance 
          (get target-lat shipment-data) 
          (get target-lng shipment-data)
          (get current-lat delivery-data)
          (get current-lng delivery-data)))
        (temp-ok (and 
          (>= (get temperature delivery-data) (get temp-min shipment-data))
          (<= (get temperature delivery-data) (get temp-max shipment-data))))
        (humidity-ok (<= (get humidity delivery-data) (get humidity-max shipment-data)))
        (shock-ok (<= (get shock-level delivery-data) (get shock-max shipment-data)))
        (location-ok (<= distance u50000))
      )
        (some {
          location-match: location-ok,
          temperature-ok: temp-ok,
          humidity-ok: humidity-ok,
          shock-ok: shock-ok,
          all-conditions-met: (and temp-ok humidity-ok shock-ok location-ok),
          distance: distance
        })
      )
      none
    )
    none
  )
)