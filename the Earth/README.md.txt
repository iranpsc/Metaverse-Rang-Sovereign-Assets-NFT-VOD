# The Earth NFT

## Overview

The Earth NFT is the root digital asset within the NFT ecosystem.

It represents the entire Earth as a unique ERC-721 token and serves as the highest-level ownership layer for subsequent geographic and real-estate assets.

---

## Technical Specifications

- Standard: ERC-721
- Solidity Version: 0.8.27
- OpenZeppelin Libraries
- ERC721URIStorage
- ERC721Royalty
- ERC721Pausable
- ERC721Burnable

---

## Token Information

Name: The Earth

Symbol: EARTH

Token Type: Non-Fungible Token (NFT)

---

## Metadata

Metadata is stored on IPFS.

The contract uses individual tokenURI assignments during minting.

Example:

ipfs://<CID>/TheEarth.json

---

## Features

- Minting
- Burning
- Royalty Support
- Pause / Unpause
- Ownership Control

---

## Royalty

Default royalty fee: 6%

---

## License

MIT