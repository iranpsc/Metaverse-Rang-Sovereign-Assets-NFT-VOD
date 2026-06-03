// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract WhitelistWithLevelsAdvanced {

    struct User {
        uint256 id;
        string name;
        string code;
        uint8 level;
        uint256 xp;
        address wallet; // حالا می‌توان ولت را پویا اختصاص داد
    }

    mapping(address => User) public usersByWallet; // دسترسی سریع بر اساس آدرس ولت
    mapping(uint256 => address) public walletById;  // نگاشت آیدی به آدرس ولت
    uint256 public userCount;

    event UserAdded(uint256 indexed id, string name, string code, uint8 level, uint256 xp, address wallet);
    event WalletAssigned(uint256 indexed id, address wallet);

    // اضافه کردن کاربر بدون ولت اولیه
    function addUser(
        uint256 id,
        string calldata name,
        string calldata code,
        uint8 level,
        uint256 xp
    ) external {
        require(walletById[id] == address(0), "User ID already exists");

        usersByWallet[address(0)] = User(id, name, code, level, xp, address(0));
        walletById[id] = address(0);
        userCount++;

        emit UserAdded(id, name, code, level, xp, address(0));
    }

    // اختصاص ولت به کاربر
    function assignWallet(uint256 id, address wallet) external {
        require(wallet != address(0), "Zero address");
        require(walletById[id] == address(0), "Wallet already assigned");

        // پیدا کردن کاربر با آیدی
        User storage u = usersByWallet[address(0)];
        require(u.id == id, "User ID not found");

        u.wallet = wallet;
        usersByWallet[wallet] = u;
        walletById[id] = wallet;

        emit WalletAssigned(id, wallet);
    }

    // دریافت اطلاعات کاربر با ولت
    function getUserByWallet(address wallet) external view returns (
        uint256 id,
        string memory name,
        string memory code,
        uint8 level,
        uint256 xp
    ) {
        User memory u = usersByWallet[wallet];
        require(u.wallet != address(0), "Wallet not assigned");
        return (u.id, u.name, u.code, u.level, u.xp);
    }

    // دریافت اطلاعات کاربر با آیدی
    function getUserById(uint256 id) external view returns (
        uint256 userId,
        string memory name,
        string memory code,
        uint8 level,
        uint256 xp,
        address wallet
    ) {
        address walletAddr = walletById[id];
        require(walletAddr != address(0), "Wallet not assigned");
        User memory u = usersByWallet[walletAddr];
        return (u.id, u.name, u.code, u.level, u.xp, u.wallet);
    }
}