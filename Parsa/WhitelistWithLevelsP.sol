// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface ILevelKeyNFT {
    function mintLevelKey(address to, uint8 level) external returns (uint256);
}

interface ILevelRewardNFT {
    function mintLevelReward(address to, uint8 level) external returns (uint256);
}

contract WhitelistWithLevels {

    struct User {
        uint256 id;
        string name;
        string code;
        uint8 level;
        uint256 xp;
        address wallet;
        bool registered; // آیا کاربر در کانترکت سطوح ثبت شده؟
    }

    mapping(address => User) public usersByWallet;
    mapping(uint256 => address) public walletById;
    uint256 public userCount;

    event UserAdded(uint256 indexed id, string name, string code, uint8 level, uint256 xp, address wallet);
    event WalletAssigned(uint256 indexed id, address wallet);

    function addUser(
        uint256 id,
        string calldata name,
        string calldata code,
        uint8 level,
        uint256 xp
    ) external {
        require(walletById[id] == address(0), "User ID already exists");
        usersByWallet[address(0)] = User(id, name, code, level, xp, address(0), false);
        walletById[id] = address(0);
        userCount++;

        emit UserAdded(id, name, code, level, xp, address(0));
    }

    function assignWallet(uint256 id, address wallet) external {
        require(wallet != address(0), "Zero address");
        require(walletById[id] == address(0), "Wallet already assigned");

        User storage u = usersByWallet[address(0)];
        require(u.id == id, "User ID not found");

        u.wallet = wallet;
        u.registered = true;
        usersByWallet[wallet] = u;
        walletById[id] = wallet;

        emit WalletAssigned(id, wallet);
    }

    function getUser(address wallet) external view returns (User memory) {
        User memory u = usersByWallet[wallet];
        require(u.wallet != address(0), "Wallet not assigned");
        return u;
    }
}

// ============================================================
// اتصال به کانترکت ThirteenLevelAccessV2
// ============================================================

contract ThirteenLevelAccessWithWhitelist {
    WhitelistWithLevels public whitelist;
    ILevelKeyNFT public keyNFT;
    ILevelRewardNFT public rewardNFT;

    uint8 public constant MAX_LEVEL = 13;

    struct Player {
        bool registered;
        uint8 level;
        uint256 xp;
    }

    mapping(address => Player) public players;

    event PlayerRegistered(address indexed player, uint8 level, uint256 xp);
    event LevelAdvanced(address indexed player, uint8 fromLevel, uint8 toLevel, uint256 keyTokenId, uint256 rewardTokenId);

    constructor(
        address _whitelist,
        address _keyNFT,
        address _rewardNFT
    ) {
        whitelist = WhitelistWithLevels(_whitelist);
        keyNFT = ILevelKeyNFT(_keyNFT);
        rewardNFT = ILevelRewardNFT(_rewardNFT);
    }

    // ثبت کاربر از وایت‌لیست
    function registerFromWhitelist() external {
        WhitelistWithLevels.User memory u = whitelist.getUser(msg.sender);
        require(u.registered, "Not in whitelist");
        require(!players[msg.sender].registered, "Already registered");

        players[msg.sender] = Player({
            registered: true,
            level: u.level,
            xp: u.xp
        });

        // mint reward NFT براساس سطح اولیه کاربر
        uint256 rewardTokenId = rewardNFT.mintLevelReward(msg.sender, u.level);

        emit PlayerRegistered(msg.sender, u.level, u.xp);
        emit LevelAdvanced(msg.sender, 0, u.level, 0, rewardTokenId);
    }

    function getPlayer(address user) external view returns (bool registered, uint8 level, uint256 xp) {
        Player memory p = players[user];
        return (p.registered, p.level, p.xp);
    }
}