(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-already-exists (err u103))

(define-non-fungible-token credential-token uint)

(define-map credentials
  { credential-id: uint }
  {
    owner: principal,
    issuer: principal,
    credential-type: (string-ascii 64),
    institution: (string-ascii 128),
    issue-date: uint,
    expiry-date: uint,
    metadata-uri: (string-ascii 256),
    verified: bool
  }
)

(define-map authorized-issuers
  { issuer: principal }
  { active: bool }
)

(define-map access-permissions
  { credential-id: uint, viewer: principal }
  { can-view: bool, granted-at: uint, expires-at: uint }
)

(define-data-var last-credential-id uint u0)

(define-public (register-issuer (issuer principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (map-set authorized-issuers
      { issuer: issuer }
      { active: true }
    )
    (ok true)))

(define-public (revoke-issuer (issuer principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (map-set authorized-issuers
      { issuer: issuer }
      { active: false }
    )
    (ok true)))

(define-read-only (is-authorized-issuer (issuer principal))
  (default-to
    false
    (get active (map-get? authorized-issuers { issuer: issuer }))))

(define-public (mint-credential
    (credential-type (string-ascii 64))
    (institution (string-ascii 128))
    (issue-date uint)
    (expiry-date uint)
    (metadata-uri (string-ascii 256))
    (recipient principal))
  (let
    ((new-id (+ (var-get last-credential-id) u1)))
    (asserts! (is-authorized-issuer tx-sender) err-unauthorized)
    (try! (nft-mint? credential-token new-id recipient))
    (map-set credentials
      { credential-id: new-id }
      {
        owner: recipient,
        issuer: tx-sender,
        credential-type: credential-type,
        institution: institution,
        issue-date: issue-date,
        expiry-date: expiry-date,
        metadata-uri: metadata-uri,
        verified: true
      }
    )
    (var-set last-credential-id new-id)
    (ok new-id)))

(define-public (grant-access
    (credential-id uint)
    (viewer principal)
    (expires-at uint))
  (let
    ((credential (unwrap! (map-get? credentials {credential-id: credential-id}) err-not-found)))
    (asserts! (is-eq tx-sender (get owner credential)) err-unauthorized)
    (map-set access-permissions
      { credential-id: credential-id, viewer: viewer }

      { can-view: true, granted-at: stacks-block-height, expires-at: expires-at }
    )
    (ok true)))
(define-public (revoke-access (credential-id uint) (viewer principal))
  (let
    ((credential (unwrap! (map-get? credentials {credential-id: credential-id}) err-not-found)))
    (asserts! (is-eq tx-sender (get owner credential)) err-unauthorized)
    (map-set access-permissions
      { credential-id: credential-id, viewer: viewer }
      { can-view: false, granted-at: stacks-block-height, expires-at: u0 }
    )
    (ok true)))

(define-read-only (get-credential (credential-id uint))
  (let
    ((credential (unwrap! (map-get? credentials {credential-id: credential-id}) err-not-found))
     (permission (default-to 
      { can-view: false, granted-at: u0, expires-at: u0 }
      (map-get? access-permissions { credential-id: credential-id, viewer: tx-sender }))))
    (asserts! (or
      (is-eq tx-sender (get owner credential))
      (and
        (get can-view permission)
        (< stacks-block-height (get expires-at permission))
      )) err-unauthorized)
    (ok credential)))