// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title The Earth NFT
 * @author Ali Nasirlou
 * @notice Contract for managing global regional assets in the Metarang ecosystem.
 */
contract TheEarth is ERC721URIStorage, Ownable {
    uint256 private _nextTokenId;

    struct RegionDetails {
        string name;
        string coordinates; // e.g., "35.6892° N, 51.3890° E"
        uint256 area;
        string regionType;
    }

    mapping(uint256 => RegionDetails) public regions;

    constructor() ERC721("The Earth NFT", "EARTH") Ownable(msg.sender) {}

    function mintRegion(
        address to,
        string memory tokenURI,
        string memory name,
        string memory coordinates,
        uint256 area,
        string memory regionType
    ) public onlyOwner {
        uint256 tokenId = _nextTokenId++;
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, tokenURI);

        regions[tokenId] = RegionDetails(name, coordinates, area, regionType);
    }

    function getRegionDetails(uint256 tokenId) public view returns (RegionDetails memory) {
        return regions[tokenId];
    }
}