# 🎓 Refugee Credential Vault

A decentralized system for storing and verifying academic and professional credentials for displaced persons and refugees.

## 🌟 Features

- NFT-based credential storage
- Verified institutional issuers
- Permissioned access control
- Secure credential sharing
- Immutable credential records
- Credential revocation mechanism

## 📝 Contract Functions

### For Administrators
- `register-issuer`: Add authorized credential issuers
- `revoke-issuer`: Remove issuer authorization

### For Issuers
- `mint-credential`: Create new verified credentials

### For Credential Owners
- `grant-access`: Share credentials with specified viewers
- `revoke-access`: Remove viewing permissions
- `transfer-credential`: Transfer credential ownership to another principal
- `revoke-credential`: Permanently remove a credential (issuer only)

### Read-Only Functions
- `get-credential`: View credential details (if authorized)
- `is-authorized-issuer`: Check issuer status

## 🚀 Getting Started

1. Clone the repository
2. Install Clarinet
3. Deploy using `clarinet deploy`

## 🔐 Security

All credentials are stored as NFTs with strict access controls. Only verified issuers can mint credentials, and only credential owners can manage viewing permissions.

## 💡 Use Cases

- Academic certificates
- Professional qualifications
- Training certifications
- Work experience verification

## 🔄 Credential Transfer

Credential owners can now seamlessly transfer their credentials to new owners, enabling scenarios like inheritance, organizational changes, or credential portability across different systems. This feature maintains the integrity of the credential while allowing flexible ownership transitions.
```

Git commit message:
```
feat: implement Refugee Credential Vault MVP with NFT-based storage and access control
```

PR Title:
```
MVP: Refugee Credential Vault Smart Contract Implementation
```

PR Description:
```
This PR introduces the initial MVP for the Refugee Credential Vault system:

Key Features:
- NFT-based credential storage system
- Authorized issuer management
- Secure credential minting
- Granular access control
- Time-based credential sharing

The implementation focuses on core functionality while maintaining security and scalability. All core features are implemented with proper access controls and error handling.

Testing:
- Contract successfully deployed on testnet
- All functions verified working as expected
- Access control mechanisms validated

Next Steps:
- Add credential revocation
- Implement batch operations
- Add metadata standards
- Enhance permission system

## 🔄 Credential Renewal

Issuers can now renew credentials by updating their expiry dates, ensuring long-term validity without reminting. This feature streamlines credential lifecycle management for educational and professional qualifications, providing flexibility for ongoing verification needs and reducing administrative overhead for institutions.

