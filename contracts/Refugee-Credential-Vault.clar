(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-already-exists (err u103))
(define-constant err-expired (err u104))

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

(define-map verification-requests
  { credential-id: uint, verifier: principal }
  { requested-at: uint, status: (string-ascii 16) }
)

(define-map owner-credential-count
  { owner: principal }
  { count: uint }
)

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
    (let
      ((current-count (default-to u0 (get count (map-get? owner-credential-count { owner: recipient })))))
      (map-set owner-credential-count
        { owner: recipient }
        { count: (+ current-count u1) }
      )
    )
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

(define-public (request-verification (credential-id uint))
  (let
    ((credential (unwrap! (map-get? credentials {credential-id: credential-id}) err-not-found)))
    (map-set verification-requests
      { credential-id: credential-id, verifier: tx-sender }
      { requested-at: stacks-block-height, status: "pending" }
    )
    (ok true)))

(define-public (approve-verification (credential-id uint) (verifier principal))
  (let
    ((credential (unwrap! (map-get? credentials {credential-id: credential-id}) err-not-found)))
    (asserts! (is-eq tx-sender (get owner credential)) err-unauthorized)
    (map-set verification-requests
      { credential-id: credential-id, verifier: verifier }
      { requested-at: stacks-block-height, status: "approved" }
    )
    (ok true)))

(define-read-only (verify-credential (credential-id uint))
  (let
    ((credential (unwrap! (map-get? credentials {credential-id: credential-id}) err-not-found))
     (verification (map-get? verification-requests { credential-id: credential-id, verifier: tx-sender })))
    (asserts! (> (get expiry-date credential) stacks-block-height) err-expired)
    (match verification
      verified-request
        (begin
          (asserts! (is-eq (get status verified-request) "approved") err-unauthorized)
          (ok {
            credential-id: credential-id,
            issuer: (get issuer credential),
            institution: (get institution credential),
            credential-type: (get credential-type credential),
            issue-date: (get issue-date credential),
            expiry-date: (get expiry-date credential),
            verified: (get verified credential),
            issuer-active: (is-authorized-issuer (get issuer credential))
          }))
      err-unauthorized)))

(define-read-only (get-owned-credential-count (owner principal))
   (default-to u0 (get count (map-get? owner-credential-count { owner: owner }))))

(define-public (revoke-credential (credential-id uint))
  (let
    ((credential (unwrap! (map-get? credentials {credential-id: credential-id}) err-not-found)))
    (asserts! (is-eq tx-sender (get issuer credential)) err-unauthorized)
    (try! (nft-burn? credential-token credential-id (get owner credential)))
    (map-delete credentials {credential-id: credential-id})
    (map-delete access-permissions {credential-id: credential-id, viewer: (get owner credential)})
    (let
      ((current-count (default-to u0 (get count (map-get? owner-credential-count { owner: (get owner credential) })))))
      (map-set owner-credential-count
        { owner: (get owner credential) }
        { count: (if (> current-count u0) (- current-count u1) u0) }
      )
    )
    (ok true)))