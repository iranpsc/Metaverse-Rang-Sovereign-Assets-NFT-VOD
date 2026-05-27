// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract LevelAssets1155 is ERC1155, Ownable {
    error NotMinter();
    error InvalidLevel();
    error InvalidAssetIndex();
    error AssetNotConfigured();
    error SoulboundAsset();

    uint8 public constant MAX_LEVEL = 13;
    uint8 public constant MAX_ASSET_INDEX = 10;

    enum AssetPolicy {
        Soulbound,
        Transferable
    }

    struct AssetConfig {
        bool exists;
        uint8 level;
        AssetPolicy policy;
        uint256 claimAmount;
    }

    address public minter;

    mapping(uint256 => AssetConfig) private assetConfigs;

    event MinterChanged(address indexed oldMinter, address indexed newMinter);

    event AssetConfigured(
        uint256 indexed assetId,
        uint8 indexed level,
        uint8 indexed assetIndex,
        AssetPolicy policy,
        uint256 claimAmount,
        bool exists
    );

    event LevelAssetMinted(
        address indexed to,
        uint256 indexed assetId,
        uint256 amount
    );

    constructor(string memory metadataURI)
        ERC1155(metadataURI)
        Ownable(msg.sender)
    {}

    modifier onlyMinter() {
        if (msg.sender != minter) revert NotMinter();
        _;
    }

    function setMinter(address newMinter) external onlyOwner {
        address oldMinter = minter;
        minter = newMinter;

        emit MinterChanged(oldMinter, newMinter);
    }

    function setURI(string calldata newURI) external onlyOwner {
        _setURI(newURI);
    }

    function assetId(uint8 level, uint8 assetIndex)
        public
        pure
        returns (uint256)
    {
        if (level == 0 || level > MAX_LEVEL) revert InvalidLevel();

        if (assetIndex == 0 || assetIndex > MAX_ASSET_INDEX) {
            revert InvalidAssetIndex();
        }

        return uint256(level) * 100 + uint256(assetIndex);
    }

    function configureAsset(
        uint8 level,
        uint8 assetIndex,
        AssetPolicy policy,
        uint256 claimAmount,
        bool exists
    ) public onlyOwner {
        if (exists && claimAmount == 0) {
            revert AssetNotConfigured();
        }

        uint256 id = assetId(level, assetIndex);

        assetConfigs[id] = AssetConfig({
            exists: exists,
            level: level,
            policy: policy,
            claimAmount: claimAmount
        });

        emit AssetConfigured(
            id,
            level,
            assetIndex,
            policy,
            claimAmount,
            exists
        );
    }

    function configureDefaultAssets() external onlyOwner {
        for (uint8 level = 1; level <= MAX_LEVEL; level++) {
            configureAsset(level, 1, AssetPolicy.Soulbound, 1, true);
            configureAsset(level, 2, AssetPolicy.Soulbound, 1, true);
            configureAsset(level, 3, AssetPolicy.Transferable, 1, true);
            configureAsset(level, 4, AssetPolicy.Transferable, 1, true);
            configureAsset(level, 5, AssetPolicy.Transferable, 1, true);
        }
    }

    function getAsset(uint256 id)
        external
        view
        returns (
            bool exists,
            uint8 level,
            uint8 policy,
            uint256 claimAmount
        )
    {
        AssetConfig memory config = assetConfigs[id];

        return (
            config.exists,
            config.level,
            uint8(config.policy),
            config.claimAmount
        );
    }

    function mintAsset(
        address to,
        uint256 id,
        uint256 amount
    ) external onlyMinter {
        AssetConfig memory config = assetConfigs[id];

        if (!config.exists) revert AssetNotConfigured();

        _mint(to, id, amount, "");

        emit LevelAssetMinted(to, id, amount);
    }

    function _update(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory values
    ) internal override {
        if (from != address(0) && to != address(0)) {
            for (uint256 i = 0; i < ids.length; i++) {
                AssetConfig memory config = assetConfigs[ids[i]];

                if (config.policy == AssetPolicy.Soulbound) {
                    revert SoulboundAsset();
                }
            }
        }

        super._update(from, to, ids, values);
    }
}