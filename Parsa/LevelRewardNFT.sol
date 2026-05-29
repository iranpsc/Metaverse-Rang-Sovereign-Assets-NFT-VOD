// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract LevelRewardNFT is ERC721, Ownable {
    error NotMinter();
    error InvalidLevel();

    uint8 public constant MAX_LEVEL = 13;

    address public minter;
    uint256 private nextTokenId = 1;
    string private baseTokenURI;

    mapping(uint256 => uint8) public tokenLevel;

    event MinterChanged(address indexed oldMinter, address indexed newMinter);
    event LevelRewardMinted(address indexed to, uint8 indexed level, uint256 indexed tokenId);

    constructor(string memory _baseTokenURI)
        ERC721("Thirteen Level Reward", "TLREWARD")
        Ownable(msg.sender)
    {
        baseTokenURI = _baseTokenURI;
    }

    modifier onlyMinter() {
        if (msg.sender != minter) revert NotMinter();
        _;
    }

    function setMinter(address _minter) external onlyOwner {
        address oldMinter = minter;
        minter = _minter;
        emit MinterChanged(oldMinter, _minter);
    }

    function setBaseURI(string calldata _baseTokenURI) external onlyOwner {
        baseTokenURI = _baseTokenURI;
    }

    function mintLevelReward(address to, uint8 level) external onlyMinter returns (uint256 tokenId) {
        if (level == 0 || level > MAX_LEVEL) revert InvalidLevel();

        tokenId = nextTokenId++;
        tokenLevel[tokenId] = level;

        _safeMint(to, tokenId);

        emit LevelRewardMinted(to, level, tokenId);
    }

    function _baseURI() internal view override returns (string memory) {
        return baseTokenURI;
    }
}
