// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";

interface ILevelKeyNFT {
    function mintLevelKey(address to, uint8 level) external returns (uint256 tokenId);
}

interface ILevelRewardNFT {
    function mintLevelReward(address to, uint8 level) external returns (uint256 tokenId);
}

contract ThirteenLevelAccess is Ownable {
    error AlreadyRegistered();
    error NotRegistered();
    error InvalidLevel();
    error MaxLevelReached();
    error SaleDisabled();
    error NotEnoughXP();
    error WrongPayment();
    error Reentrancy();
    error TransferFailed();

    uint8 public constant MAX_LEVEL = 13;

    struct Player {
        bool registered;
        uint8 level;
        uint256 xp;
    }

    struct LevelRule {
        uint128 price;
        uint64 xpRequired;
        bool saleEnabled;
    }

    ILevelKeyNFT public keyNFT;
    ILevelRewardNFT public rewardNFT;

    mapping(address => Player) private players;
    mapping(uint8 => LevelRule) public levelRules;

    mapping(address => mapping(uint8 => uint256)) public keyTokenOf;
    mapping(address => mapping(uint8 => uint256)) public rewardTokenOf;

    bool private locked;

    event Registered(address indexed user, uint256 rewardTokenId);
    event XPAdded(address indexed user, uint256 amount, uint256 totalXP);
    event LevelRuleUpdated(uint8 indexed level, uint128 price, uint64 xpRequired, bool saleEnabled);
    event LevelAdvanced(
        address indexed user,
        uint8 indexed fromLevel,
        uint8 indexed toLevel,
        uint256 keyTokenId,
        uint256 rewardTokenId
    );

    constructor(address _keyNFT, address _rewardNFT) Ownable(msg.sender) {
        keyNFT = ILevelKeyNFT(_keyNFT);
        rewardNFT = ILevelRewardNFT(_rewardNFT);

        for (uint8 i = 2; i <= MAX_LEVEL; i++) {
            levelRules[i] = LevelRule({
                price: uint128(uint256(i - 1) * 0.01 ether),
                xpRequired: uint64(uint256(i - 1) * 100),
                saleEnabled: true
            });
        }
    }

    modifier nonReentrant() {
        if (locked) revert Reentrancy();
        locked = true;
        _;
        locked = false;
    }

    function register() external nonReentrant {
        if (players[msg.sender].registered) revert AlreadyRegistered();

        players[msg.sender] = Player({
            registered: true,
            level: 1,
            xp: 50
        });

        uint256 rewardTokenId = rewardNFT.mintLevelReward(msg.sender, 1);
        rewardTokenOf[msg.sender][1] = rewardTokenId;

        emit Registered(msg.sender, rewardTokenId);
    }

    function buyNextLevelKeyAndAdvance() external payable nonReentrant {
        Player storage player = players[msg.sender];

        if (!player.registered) revert NotRegistered();
        if (player.level >= MAX_LEVEL) revert MaxLevelReached();

        uint8 fromLevel = player.level;
        uint8 nextLevel = fromLevel + 1;

        LevelRule memory rule = levelRules[nextLevel];

        if (!rule.saleEnabled) revert SaleDisabled();
        if (player.xp < rule.xpRequired) revert NotEnoughXP();
        if (msg.value != rule.price) revert WrongPayment();

        player.level = nextLevel;

        uint256 keyTokenId = keyNFT.mintLevelKey(msg.sender, nextLevel);
        uint256 rewardTokenId = rewardNFT.mintLevelReward(msg.sender, nextLevel);

        keyTokenOf[msg.sender][nextLevel] = keyTokenId;
        rewardTokenOf[msg.sender][nextLevel] = rewardTokenId;

        emit LevelAdvanced(msg.sender, fromLevel, nextLevel, keyTokenId, rewardTokenId);
    }

    function addXP(address user, uint256 amount) external onlyOwner {
        if (!players[user].registered) revert NotRegistered();

        players[user].xp += amount;

        emit XPAdded(user, amount, players[user].xp);
    }

    function setLevelRule(
        uint8 level,
        uint128 price,
        uint64 xpRequired,
        bool saleEnabled
    ) external onlyOwner {
        if (level <= 1 || level > MAX_LEVEL) revert InvalidLevel();

        levelRules[level] = LevelRule({
            price: price,
            xpRequired: xpRequired,
            saleEnabled: saleEnabled
        });

        emit LevelRuleUpdated(level, price, xpRequired, saleEnabled);
    }

    function canAccessLevel(address user, uint8 level) public view returns (bool) {
        if (level == 0 || level > MAX_LEVEL) return false;

        Player memory player = players[user];

        return player.registered && player.level >= level;
    }

    function enterLevelRoom(uint8 level) external view returns (bool) {
        if (!canAccessLevel(msg.sender, level)) revert InvalidLevel();
        return true;
    }

    function useLevelFeature(uint8 level) external view returns (bool) {
        if (!canAccessLevel(msg.sender, level)) revert InvalidLevel();
        return true;
    }

    function getPlayer(address user)
        external
        view
        returns (
            bool registered,
            uint8 level,
            uint256 xp
        )
    {
        Player memory player = players[user];
        return (player.registered, player.level, player.xp);
    }

    function withdraw(address payable to) external onlyOwner {
        uint256 amount = address(this).balance;

        (bool ok, ) = to.call{value: amount}("");
        if (!ok) revert TransferFailed();
    }
}
