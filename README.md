# ThirteenLevelAccessKeyDeployable

A deployable Solidity smart contract that combines:

* ERC721 NFT Access Keys
* 13-Level Progression System
* XP-Based Advancement
* Paid Level Unlocks
* Room & Feature Access Control
* Soulbound NFT Support
* Ownership & Administration
* Treasury Management
* Analytics Counters

This contract is designed as an educational and deployable prototype for Web3 games, metaverse projects, membership platforms, learning systems, and NFT-gated ecosystems.

---

# Overview

The system allows users to:

1. Register as a player
2. Receive starting XP
3. Progress through 13 levels
4. Purchase NFT access keys for higher levels
5. Unlock rooms and features
6. Access gated functionality based on level
7. Generate on-chain activity records

The contract also includes a lightweight ERC721 implementation to reduce deployment bytecode size and remain compatible with Remix deployment limits.

---

# Key Features

## 13-Level Progression

Players begin at Level 1.

To reach the next level they must:

* Earn enough XP
* Pay the required ETH amount
* Purchase the next level key

Levels:

| Level | Access Key Required |
| ----- | ------------------- |
| 1     | No                  |
| 2-13  | Yes                 |

---

## XP System

Every registered player receives:

```solidity
WELCOME_XP = 50
```

XP is required to unlock higher levels.

Default XP requirements:

| Target Level | XP Required |
| ------------ | ----------- |
| 2            | 100         |
| 3            | 200         |
| 4            | 300         |
| ...          | ...         |
| 13           | 1200        |

Admin can modify requirements using:

```solidity
setLevelRule()
```

---

## NFT Access Keys

Each level upgrade mints an ERC721 NFT.

Example:

* Upgrade to Level 2
* Mint Level 2 Key NFT

NFT stores:

```solidity
tokenId
levelUnlocked
owner
```

Query examples:

```solidity
keyLevel(tokenId)
```

```solidity
keyForLevel(user, level)
```

```solidity
hasKeyForLevel(user, level)
```

---

## Soulbound Support

By default all keys are soulbound.

Meaning:

* Cannot transfer
* Cannot sell
* Cannot move between wallets

Default:

```solidity
soulboundKeys = true
```

Admin may enable transfers:

```solidity
setSoulboundKeys(false)
```

---

# Registration Flow

## Register

```solidity
register()
```

Creates:

```text
registered = true
level = 1
xp = 50
```

Emits:

```solidity
PlayerRegistered
```

---

# Level Upgrade Flow

## Check Eligibility

```solidity
canBuyNextLevelKey(user)
```

Returns:

* allowed
* targetLevel
* price
* xpRequired

---

## Upgrade

```solidity
buyNextLevelKeyAndAdvance()
```

Requirements:

* Registered
* Not max level
* Enough XP
* Correct payment
* Sale enabled

Results:

* NFT minted
* Level increased
* Statistics updated

Events:

```solidity
KeyPurchased
LevelAdvanced
```

---

# Room Access System

Rooms are level-gated.

Example:

```solidity
enterLevelRoom(5)
```

Requirements:

* Registered
* Room enabled
* Player level >= 5

Event:

```solidity
RoomEntered
```

Analytics counter increases automatically.

---

# Feature Access System

Features are level-gated.

Example:

```solidity
useLevelFeature(8)
```

Requirements:

* Registered
* Feature enabled
* Level requirement met

Event:

```solidity
FeatureUsed
```

Analytics counter increases automatically.

---

# Analytics Tracking

The contract records usage data.

Room usage:

```solidity
roomEnterCount(user, level)
```

Feature usage:

```solidity
featureUseCount(user, level)
```

Useful for:

* dashboards
* leaderboards
* game analytics
* achievement systems

---

# Administration

## Pause Contract

```solidity
pause()
```

Disable:

* registrations
* upgrades
* level access actions

Resume:

```solidity
unpause()
```

---

## XP Management

Single user:

```solidity
addXP(user, amount)
```

Batch update:

```solidity
addXPBatch(users, amounts)
```

---

## Modify Level Rules

```solidity
setLevelRule(
    level,
    price,
    xpRequired,
    saleEnabled
)
```

Example:

```solidity
setLevelRule(
    5,
    0.05 ether,
    500,
    true
)
```

---

## Modify Access

```solidity
setLevelAccess(
    level,
    roomEnabled,
    featureEnabled
)
```

Allows:

* disabling rooms
* disabling features
* maintenance windows

---

# Ownership

Uses a secure two-step ownership transfer.

Step 1:

```solidity
transferOwnership(newOwner)
```

Step 2:

```solidity
acceptOwnership()
```

Benefits:

* prevents accidental ownership loss
* improves operational security

---

# Treasury

ETH enters the contract only through level purchases.

Direct transfers are blocked.

```solidity
receive()
```

will revert.

Withdraw funds:

```solidity
withdraw(to, amount)
```

Withdraw all:

```solidity
withdraw(to, 0)
```

---

# ERC721 Compatibility

Implemented interfaces:

* ERC165
* ERC721
* ERC721 Metadata

Functions:

```solidity
balanceOf()
ownerOf()
approve()
getApproved()
setApprovalForAll()
transferFrom()
safeTransferFrom()
tokenURI()
```

---

# Metadata Structure

Example Base URI:

```text
ipfs://QmExampleCID/
```

Generated URI:

```text
ipfs://QmExampleCID/level/2/key/1
```

Structure:

```text
/baseURI/
    level/
        {level}/
            key/
                {tokenId}
```

---

# Events

Important events:

```solidity
PlayerRegistered
XPAdded
PlayerLevelSet
LevelRuleSet
LevelAccessSet
KeyPurchased
LevelAdvanced
RoomEntered
FeatureUsed
Withdrawal
Transfer
Approval
ApprovalForAll
```

These can be indexed using:

* The Graph
* Subsquid
* Custom indexers
* Backend listeners

---

# Security Features

Implemented protections:

### Custom Errors

Lower gas consumption than revert strings.

### Reentrancy Protection

```solidity
nonReentrant
```

Used on:

* upgrades
* withdrawals

### Pausable System

Emergency shutdown support.

### Soulbound Protection

Prevents unauthorized NFT transfers.

### Two-Step Ownership

Prevents ownership mistakes.

### Direct ETH Rejection

Avoids accidental deposits.

---

# Deployment

## Remix

Compiler:

```text
0.8.24
```

Optimizer:

```text
Enabled
Runs = 1
```

Deploy:

```solidity
ThirteenLevelAccessKeyDeployable
```

---

# Quick Test

### Step 1

Deploy contract.

### Step 2

Register:

```solidity
register()
```

### Step 3

Check profile:

```solidity
getPlayer(address)
```

### Step 4

Grant XP:

```solidity
addXP(address, 50)
```

### Step 5

Read level price:

```solidity
levelPrice(2)
```

Expected:

```text
0.01 ETH
```

### Step 6

Send payment.

### Step 7

Upgrade:

```solidity
buyNextLevelKeyAndAdvance()
```

### Step 8

Access room:

```solidity
enterLevelRoom(2)
```

### Step 9

Use feature:

```solidity
useLevelFeature(2)
```

---

# Recommended Production Architecture

For production environments this contract should be separated into:

### Core Access Contract

Handles:

* XP
* Levels
* Progression

### NFT Contract

Handles:

* ERC721 keys
* Metadata

### Treasury Contract

Handles:

* payments
* withdrawals

### Reward Contract

Handles:

* achievements
* rewards

### Analytics Layer

Handles:

* indexing
* dashboards
* reporting

---

# Use Cases

* NFT Membership Platforms
* Metaverse Access Systems
* Web3 Learning Platforms
* Play-to-Earn Games
* DAO Membership Tiers
* Premium Communities
* Event Access Control
* Digital Certification Systems
* GameFi Progression Systems

---

# License

MIT License

Copyright (c) ThirteenLevelAccessKeyDeployable
