;; Equipment Registration Contract
;; Records details of items available for rent

;; Define data variables
(define-map equipment
{ equipment-id: (string-ascii 36) }
{
  name: (string-ascii 100),
  description: (string-ascii 500),
  category: (string-ascii 50),
  daily-rate: uint,  ;; Rate in cents per day
  hourly-rate: uint,  ;; Rate in cents per hour
  minimum-rental-period: uint,  ;; In hours
  maximum-rental-period: uint,  ;; In hours
  location: (string-ascii 100),
  owner: principal,
  registration-date: uint,
  image-url: (optional (string-ascii 200)),
  condition: (string-ascii 20),  ;; new, like-new, good, fair, poor
  available: bool,
  maintenance-status: (string-ascii 20),  ;; available, under-maintenance, retired
  insurance-required: bool,
  replacement-value: uint  ;; In cents
}
)

(define-map equipment-count-by-owner
{ owner: principal }
{ count: uint }
)

(define-map equipment-restrictions
{
  equipment-id: (string-ascii 36)
}
{
  age-restriction: (optional uint),
  license-required: bool,
  license-type: (optional (string-ascii 50)),
  certification-required: bool,
  certification-type: (optional (string-ascii 50)),
  deposit-required: bool,
  deposit-amount: uint  ;; In cents
}
)

(define-map equipment-specifications
{
  equipment-id: (string-ascii 36)
}
{
  weight-kg: (optional uint),
  dimensions: (optional (string-ascii 100)),
  power-requirements: (optional (string-ascii 100)),
  fuel-type: (optional (string-ascii 50)),
  manufacturer: (optional (string-ascii 100)),
  model: (optional (string-ascii 100)),
  year: (optional uint),
  serial-number: (optional (string-ascii 100)),
  accessories-included: (optional (string-ascii 500))
}
)

(define-map equipment-admins principal bool)

;; Define error codes
(define-constant ERR-NOT-AUTHORIZED u1)
(define-constant ERR-EQUIPMENT-EXISTS u2)
(define-constant ERR-EQUIPMENT-NOT-FOUND u3)
(define-constant ERR-INVALID-PARAMETERS u4)
(define-constant ERR-NOT-OWNER u5)

;; Initialize contract with deployer as admin
(define-data-var contract-owner principal tx-sender)

;; Check if caller is an admin
(define-read-only (is-admin)
(or
  (is-eq tx-sender (var-get contract-owner))
  (default-to false (map-get? equipment-admins tx-sender))
)
)

;; Add a new admin
(define-public (add-admin (new-admin principal))
(begin
  (asserts! (is-admin) (err ERR-NOT-AUTHORIZED))
  (ok (map-set equipment-admins new-admin true))
)
)

;; Remove an admin
(define-public (remove-admin (admin principal))
(begin
  (asserts! (is-admin) (err ERR-NOT-AUTHORIZED))
  (ok (map-delete equipment-admins admin))
)
)

;; Register new equipment
(define-public (register-equipment
(equipment-id (string-ascii 36))
(name (string-ascii 100))
(description (string-ascii 500))
(category (string-ascii 50))
(daily-rate uint)
(hourly-rate uint)
(minimum-rental-period uint)
(maximum-rental-period uint)
(location (string-ascii 100))
(image-url (optional (string-ascii 200)))
(condition (string-ascii 20))
(maintenance-status (string-ascii 20))
(insurance-required bool)
(replacement-value uint)
)
(begin
  (asserts! (is-none (map-get? equipment { equipment-id: equipment-id })) (err ERR-EQUIPMENT-EXISTS))
  (asserts! (> maximum-rental-period minimum-rental-period) (err ERR-INVALID-PARAMETERS))
  (asserts! (> minimum-rental-period u0) (err ERR-INVALID-PARAMETERS))

  ;; Update equipment count for owner
  (let (
    (owner-count (default-to { count: u0 } (map-get? equipment-count-by-owner { owner: tx-sender })))
  )
    (map-set equipment-count-by-owner
      { owner: tx-sender }
      { count: (+ (get count owner-count) u1) }
    )
  )

  ;; Register the equipment
  (ok (map-set equipment
    { equipment-id: equipment-id }
    {
      name: name,
      description: description,
      category: category,
      daily-rate: daily-rate,
      hourly-rate: hourly-rate,
      minimum-rental-period: minimum-rental-period,
      maximum-rental-period: maximum-rental-period,
      location: location,
      owner: tx-sender,
      registration-date: block-height,
      image-url: image-url,
      condition: condition,
      available: true,
      maintenance-status: maintenance-status,
      insurance-required: insurance-required,
      replacement-value: replacement-value
    }
  ))
)
)

;; Add equipment specifications
(define-public (add-equipment-specifications
(equipment-id (string-ascii 36))
(weight-kg (optional uint))
(dimensions (optional (string-ascii 100)))
(power-requirements (optional (string-ascii 100)))
(fuel-type (optional (string-ascii 50)))
(manufacturer (optional (string-ascii 100)))
(model (optional (string-ascii 100)))
(year (optional uint))
(serial-number (optional (string-ascii 100)))
(accessories-included (optional (string-ascii 500)))
)
(let (
  (equipment-details (unwrap! (map-get? equipment { equipment-id: equipment-id }) (err ERR-EQUIPMENT-NOT-FOUND)))
)
  (asserts! (is-eq (get owner equipment-details) tx-sender) (err ERR-NOT-OWNER))

  (ok (map-set equipment-specifications
    { equipment-id: equipment-id }
    {
      weight-kg: weight-kg,
      dimensions: dimensions,
      power-requirements: power-requirements,
      fuel-type: fuel-type,
      manufacturer: manufacturer,
      model: model,
      year: year,
      serial-number: serial-number,
      accessories-included: accessories-included
    }
  ))
)
)

;; Add equipment restrictions
(define-public (add-equipment-restrictions
(equipment-id (string-ascii 36))
(age-restriction (optional uint))
(license-required bool)
(license-type (optional (string-ascii 50)))
(certification-required bool)
(certification-type (optional (string-ascii 50)))
(deposit-required bool)
(deposit-amount uint)
)
(let (
  (equipment-details (unwrap! (map-get? equipment { equipment-id: equipment-id }) (err ERR-EQUIPMENT-NOT-FOUND)))
)
  (asserts! (is-eq (get owner equipment-details) tx-sender) (err ERR-NOT-OWNER))

  (ok (map-set equipment-restrictions
    { equipment-id: equipment-id }
    {
      age-restriction: age-restriction,
      license-required: license-required,
      license-type: license-type,
      certification-required: certification-required,
      certification-type: certification-type,
      deposit-required: deposit-required,
      deposit-amount: deposit-amount
    }
  ))
)
)

;; Update equipment availability
(define-public (update-equipment-availability
(equipment-id (string-ascii 36))
(available bool)
)
(let (
  (equipment-details (unwrap! (map-get? equipment { equipment-id: equipment-id }) (err ERR-EQUIPMENT-NOT-FOUND)))
)
  (asserts! (is-eq (get owner equipment-details) tx-sender) (err ERR-NOT-OWNER))

  (ok (map-set equipment
    { equipment-id: equipment-id }
    (merge equipment-details { available: available })
  ))
)
)

;; Update equipment maintenance status
(define-public (update-maintenance-status
(equipment-id (string-ascii 36))
(maintenance-status (string-ascii 20))
)
(let (
  (equipment-details (unwrap! (map-get? equipment { equipment-id: equipment-id }) (err ERR-EQUIPMENT-NOT-FOUND)))
)
  (asserts! (is-eq (get owner equipment-details) tx-sender) (err ERR-NOT-OWNER))

  (ok (map-set equipment
    { equipment-id: equipment-id }
    (merge equipment-details { maintenance-status: maintenance-status })
  ))
)
)

;; Update equipment details
(define-public (update-equipment-details
(equipment-id (string-ascii 36))
(name (string-ascii 100))
(description (string-ascii 500))
(category (string-ascii 50))
(daily-rate uint)
(hourly-rate uint)
(minimum-rental-period uint)
(maximum-rental-period uint)
(location (string-ascii 100))
(image-url (optional (string-ascii 200)))
(condition (string-ascii 20))
(insurance-required bool)
(replacement-value uint)
)
(let (
  (equipment-details (unwrap! (map-get? equipment { equipment-id: equipment-id }) (err ERR-EQUIPMENT-NOT-FOUND)))
)
  (asserts! (is-eq (get owner equipment-details) tx-sender) (err ERR-NOT-OWNER))
  (asserts! (> maximum-rental-period minimum-rental-period) (err ERR-INVALID-PARAMETERS))
  (asserts! (> minimum-rental-period u0) (err ERR-INVALID-PARAMETERS))

  (ok (map-set equipment
    { equipment-id: equipment-id }
    (merge equipment-details {
      name: name,
      description: description,
      category: category,
      daily-rate: daily-rate,
      hourly-rate: hourly-rate,
      minimum-rental-period: minimum-rental-period,
      maximum-rental-period: maximum-rental-period,
      location: location,
      image-url: image-url,
      condition: condition,
      insurance-required: insurance-required,
      replacement-value: replacement-value
    })
  ))
)
)

;; Get equipment details
(define-read-only (get-equipment (equipment-id (string-ascii 36)))
(map-get? equipment { equipment-id: equipment-id })
)

;; Get equipment specifications
(define-read-only (get-equipment-specifications (equipment-id (string-ascii 36)))
(map-get? equipment-specifications { equipment-id: equipment-id })
)

;; Get equipment restrictions
(define-read-only (get-equipment-restrictions (equipment-id (string-ascii 36)))
(map-get? equipment-restrictions { equipment-id: equipment-id })
)

;; Get equipment count by owner
(define-read-only (get-equipment-count-by-owner (owner principal))
(default-to { count: u0 } (map-get? equipment-count-by-owner { owner: owner }))
)

;; Check if equipment is available for rent
(define-read-only (is-equipment-available (equipment-id (string-ascii 36)))
(let (
  (equipment-details (unwrap-panic (map-get? equipment { equipment-id: equipment-id })))
)
  (and
    (get available equipment-details)
    (is-eq (get maintenance-status equipment-details) "available")
  )
)
)

;; Check if caller is the equipment owner
(define-read-only (is-equipment-owner (equipment-id (string-ascii 36)) (owner principal))
(let (
  (equipment-details (unwrap-panic (map-get? equipment { equipment-id: equipment-id })))
)
  (is-eq (get owner equipment-details) owner)
)
)

;; Get equipment owner
(define-read-only (get-equipment-owner (equipment-id (string-ascii 36)))
(get owner (unwrap-panic (map-get? equipment { equipment-id: equipment-id })))
)
