// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/*
    ThirteenLevelAccessKey_Deployable.
    ========================================================================

    This file is the deployable-size fix for the previous large Remix contract.

    Why the previous file produced this warning:
    ------------------------------------------------------------------------
    Warning: Contract code size is 37811 bytes and exceeds 24576 bytes.

    The Ethereum mainnet runtime bytecode limit is 24KB. The old contract was
    large because it had many repeated wrappers such as:

        enterLevel01()
        enterLevel02()
        ...
        enterLevel13()

    and also repeated feature wrappers and many default strings. Every public
    function selector and its runtime logic increases deployed bytecode.

    What changed in this version:
    ------------------------------------------------------------------------
    1. Replaced 13 repeated room functions with:

        enterLevelRoom(uint8 level)

    2. Replaced 13 repeated feature functions with:

        useLevelFeature(uint8 level)

    3. Replaced canAccessLevel01...canAccessLevel13 with:

        canAccessLevel(address account, uint8 level)

    4. Replaced revert strings with custom errors.

    5. Removed heavy default text metadata from constructor bytecode.

    6. Kept ERC721 NFT key functionality inside the same file.

    7. Kept exactly 13 levels.

    8. Kept level-based room and feature access.

    9. Kept XP + payment requirement for upgrade.

    10. Kept owner/admin configuration.

    Remix compile setting:
    ------------------------------------------------------------------------
    Enable optimizer in Remix:

        Solidity Compiler -> Advanced Configurations -> Enable optimization

    Suggested optimizer runs:

        runs = 1

    for smallest deployment bytecode.

    How to test quickly in Remix:
    ------------------------------------------------------------------------
    1. Deploy this contract.
    2. Call register().
    3. Call getPlayer(yourAddress).
    4. Owner calls addXP(yourAddress, 50), because level 2 requires 100 XP.
    5. Call levelPrice(2). Default is 0.01 ether.
    6. Put that value into Remix VALUE field.
    7. Call buyNextLevelKeyAndAdvance().
    8. Call enterLevelRoom(2).
    9. Call useLevelFeature(2).

    Notes:
    ------------------------------------------------------------------------
    - Level 1 does not require an NFT key.
    - Level 2 to 13 each requires buying a key NFT.
    - The NFT key level is saved in keyLevel(tokenId).
    - Keys are soulbound by default, meaning transfer is blocked.
    - Owner can allow transfer by calling setSoulboundKeys(false).
    - For production, split this into separate contracts and audit it.

    Source line count note:
    ------------------------------------------------------------------------
    The file intentionally keeps educational comments. Comments do not increase
    deployed bytecode. Runtime bytecode is controlled by executable logic, not
    by how many comments the source file contains.
*/

interface ILevelKeyReceiver {
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4);
}

contract ThirteenLevelAccessKeyDeployable {
    // =====================================================================
    // Constants
    // =====================================================================

    uint8 public constant MIN_LEVEL = 1;
    uint8 public constant MAX_LEVEL = 13;
    uint256 public constant WELCOME_XP = 50;

    bytes4 private constant ERC721_RECEIVED = 0x150b7a02;
    bytes4 private constant ERC165_INTERFACE_ID = 0x01ffc9a7;
    bytes4 private constant ERC721_INTERFACE_ID = 0x80ac58cd;
    bytes4 private constant ERC721_METADATA_INTERFACE_ID = 0x5b5e139f;

    // =====================================================================
    // ERC721 metadata
    // =====================================================================

    string public constant name = "Thirteen Level Access Key";
    string public constant symbol = "TLAK";
    string public baseTokenURI;

    // =====================================================================
    // Ownership and security
    // =====================================================================

    address public owner;
    address public pendingOwner;
    bool public paused;
    bool public soulboundKeys;
    uint256 private locked;

    // =====================================================================
    // ERC721 storage
    // =====================================================================

    uint256 private nextTokenId;

    mapping(uint256 => address) private tokenOwner;
    mapping(address => uint256) private ownedTokenCount;
    mapping(uint256 => address) private tokenApprovals;
    mapping(address => mapping(address => bool)) private operatorApprovals;

    // tokenId => level unlocked by this NFT key
    mapping(uint256 => uint8) private tokenKeyLevel;

    // user => level => tokenId
    mapping(address => mapping(uint8 => uint256)) private userLevelKey;

    // =====================================================================
    // Game/access storage
    // =====================================================================

    struct Player {
        bool registered;
        uint8 level;
        uint256 xp;
        uint256 joinedAt;
        uint256 updatedAt;
        uint256 totalSpent;
        uint256 keysMinted;
    }

    mapping(address => Player) private players;

    // Target level => price to buy the key for that level.
    // Example: levelPrice[2] is the price to move from level 1 to level 2.
    mapping(uint8 => uint256) public levelPrice;

    // Target level => XP required to buy the key for that level.
    mapping(uint8 => uint256) public levelXPRequired;

    // Target level => whether key sale is enabled.
    mapping(uint8 => bool) public levelKeySaleEnabled;

    // Level => whether room access is enabled.
    mapping(uint8 => bool) public levelRoomEnabled;

    // Level => whether feature access is enabled.
    mapping(uint8 => bool) public levelFeatureEnabled;

    // Usage counters for analytics.
    mapping(address => mapping(uint8 => uint256)) private roomEnterCounter;
    mapping(address => mapping(uint8 => uint256)) private featureUseCounter;

    // =====================================================================
    // Errors
    // =====================================================================

    error NotOwner();
    error NotPendingOwner();
    error ZeroAddress();
    error Paused();
    error NotPaused();
    error Reentrant();
    error InvalidLevel();
    error AlreadyRegistered();
    error NotRegistered();
    error AlreadyAtMaxLevel();
    error SaleDisabled();
    error RoomDisabled();
    error FeatureDisabled();
    error InsufficientXP();
    error WrongPayment();
    error AccessDenied();
    error TokenMissing();
    error NotApprovedOrOwner();
    error TransferToZero();
    error ApproveToOwner();
    error Soulbound();
    error ReceiverRejected();
    error LengthMismatch();
    error WithdrawFailed();
    error DirectPaymentDisabled();

    // =====================================================================
    // Events
    // =====================================================================

    event OwnershipTransferStarted(address indexed oldOwner, address indexed newOwner);
    event OwnershipTransferred(address indexed oldOwner, address indexed newOwner);
    event PauseChanged(bool paused);
    event SoulboundChanged(bool enabled);
    event BaseURIChanged(string baseURI);
    event PlayerRegistered(address indexed player, uint8 level, uint256 xp);
    event XPAdded(address indexed player, uint256 amount, uint256 newXP);
    event PlayerLevelSet(address indexed player, uint8 oldLevel, uint8 newLevel);
    event LevelRuleSet(uint8 indexed level, uint256 price, uint256 xpRequired, bool saleEnabled);
    event LevelAccessSet(uint8 indexed level, bool roomEnabled, bool featureEnabled);
    event KeyPurchased(address indexed player, uint256 indexed tokenId, uint8 indexed level, uint256 price);
    event LevelAdvanced(address indexed player, uint8 fromLevel, uint8 toLevel, uint256 tokenId);
    event RoomEntered(address indexed player, uint8 indexed level, uint256 count);
    event FeatureUsed(address indexed player, uint8 indexed level, uint256 count);
    event Withdrawal(address indexed to, uint256 amount);

    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    // =====================================================================
    // Modifiers
    // =====================================================================

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert Paused();
        _;
    }

    modifier whenPaused() {
        if (!paused) revert NotPaused();
        _;
    }

    modifier nonReentrant() {
        if (locked == 1) revert Reentrant();
        locked = 1;
        _;
        locked = 0;
    }

    modifier onlyRegistered(address account) {
        if (!players[account].registered) revert NotRegistered();
        _;
    }

    // =====================================================================
    // Constructor
    // =====================================================================

    constructor() {
        owner = msg.sender;
        soulboundKeys = true;
        nextTokenId = 1;

        for (uint8 level = MIN_LEVEL; level <= MAX_LEVEL; level++) {
            levelKeySaleEnabled[level] = true;
            levelRoomEnabled[level] = true;
            levelFeatureEnabled[level] = true;
            levelPrice[level] = uint256(level - 1) * 0.01 ether;
            levelXPRequired[level] = uint256(level - 1) * 100;
        }
    }

    // =====================================================================
    // Ownership
    // =====================================================================

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        pendingOwner = newOwner;
        emit OwnershipTransferStarted(owner, newOwner);
    }

    function acceptOwnership() external {
        if (msg.sender != pendingOwner) revert NotPendingOwner();
        address oldOwner = owner;
        owner = pendingOwner;
        pendingOwner = address(0);
        emit OwnershipTransferred(oldOwner, owner);
    }

    function cancelOwnershipTransfer() external onlyOwner {
        pendingOwner = address(0);
    }

    // =====================================================================
    // Admin configuration
    // =====================================================================

    function pause() external onlyOwner whenNotPaused {
        paused = true;
        emit PauseChanged(true);
    }

    function unpause() external onlyOwner whenPaused {
        paused = false;
        emit PauseChanged(false);
    }

    function setSoulboundKeys(bool enabled) external onlyOwner {
        soulboundKeys = enabled;
        emit SoulboundChanged(enabled);
    }

    function setBaseTokenURI(string calldata newBaseURI) external onlyOwner {
        baseTokenURI = newBaseURI;
        emit BaseURIChanged(newBaseURI);
    }

    function setLevelRule(
        uint8 level,
        uint256 price,
        uint256 xpRequired,
        bool saleEnabled
    ) external onlyOwner {
        _checkLevel(level);
        levelPrice[level] = price;
        levelXPRequired[level] = xpRequired;
        levelKeySaleEnabled[level] = saleEnabled;
        emit LevelRuleSet(level, price, xpRequired, saleEnabled);
    }

    function setLevelAccess(
        uint8 level,
        bool roomEnabled,
        bool featureEnabled
    ) external onlyOwner {
        _checkLevel(level);
        levelRoomEnabled[level] = roomEnabled;
        levelFeatureEnabled[level] = featureEnabled;
        emit LevelAccessSet(level, roomEnabled, featureEnabled);
    }

    function addXP(address account, uint256 amount)
        external
        onlyOwner
        onlyRegistered(account)
    {
        Player storage p = players[account];
        p.xp += amount;
        p.updatedAt = block.timestamp;
        emit XPAdded(account, amount, p.xp);
    }

    function addXPBatch(address[] calldata accounts, uint256[] calldata amounts)
        external
        onlyOwner
    {
        if (accounts.length != amounts.length) revert LengthMismatch();

        for (uint256 i = 0; i < accounts.length; i++) {
            if (!players[accounts[i]].registered) revert NotRegistered();
            players[accounts[i]].xp += amounts[i];
            players[accounts[i]].updatedAt = block.timestamp;
            emit XPAdded(accounts[i], amounts[i], players[accounts[i]].xp);
        }
    }

    function adminSetPlayerLevel(address account, uint8 newLevel)
        external
        onlyOwner
        onlyRegistered(account)
    {
        _checkLevel(newLevel);
        Player storage p = players[account];
        uint8 oldLevel = p.level;
        p.level = newLevel;
        p.updatedAt = block.timestamp;
        emit PlayerLevelSet(account, oldLevel, newLevel);
    }

    // =====================================================================
    // Registration and player views
    // =====================================================================

    function register() external whenNotPaused {
        if (players[msg.sender].registered) revert AlreadyRegistered();

        players[msg.sender] = Player({
            registered: true,
            level: MIN_LEVEL,
            xp: WELCOME_XP,
            joinedAt: block.timestamp,
            updatedAt: block.timestamp,
            totalSpent: 0,
            keysMinted: 0
        });

        emit PlayerRegistered(msg.sender, MIN_LEVEL, WELCOME_XP);
    }

    function getPlayer(address account)
        external
        view
        returns (
            bool registered,
            uint8 level,
            uint256 xp,
            uint256 joinedAt,
            uint256 updatedAt,
            uint256 totalSpent,
            uint256 keysMinted
        )
    {
        Player storage p = players[account];
        return (
            p.registered,
            p.level,
            p.xp,
            p.joinedAt,
            p.updatedAt,
            p.totalSpent,
            p.keysMinted
        );
    }

    function myLevel() external view returns (uint8) {
        return players[msg.sender].level;
    }

    function myXP() external view returns (uint256) {
        return players[msg.sender].xp;
    }

    function isRegistered(address account) external view returns (bool) {
        return players[account].registered;
    }

    // =====================================================================
    // Upgrade flow
    // =====================================================================

    function canBuyNextLevelKey(address account)
        external
        view
        returns (
            bool allowed,
            uint8 targetLevel,
            uint256 price,
            uint256 xpRequired
        )
    {
        Player storage p = players[account];

        if (!p.registered || p.level >= MAX_LEVEL) {
            return (false, p.level, 0, 0);
        }

        targetLevel = p.level + 1;
        price = levelPrice[targetLevel];
        xpRequired = levelXPRequired[targetLevel];
        allowed = levelKeySaleEnabled[targetLevel] && p.xp >= xpRequired;
    }

    function buyNextLevelKeyAndAdvance()
        external
        payable
        whenNotPaused
        nonReentrant
        onlyRegistered(msg.sender)
        returns (uint256 tokenId)
    {
        Player storage p = players[msg.sender];

        if (p.level >= MAX_LEVEL) revert AlreadyAtMaxLevel();

        uint8 oldLevel = p.level;
        uint8 targetLevel = oldLevel + 1;

        if (!levelKeySaleEnabled[targetLevel]) revert SaleDisabled();
        if (p.xp < levelXPRequired[targetLevel]) revert InsufficientXP();
        if (msg.value != levelPrice[targetLevel]) revert WrongPayment();

        tokenId = _mintKey(msg.sender, targetLevel);

        p.level = targetLevel;
        p.totalSpent += msg.value;
        p.keysMinted += 1;
        p.updatedAt = block.timestamp;

        emit KeyPurchased(msg.sender, tokenId, targetLevel, msg.value);
        emit LevelAdvanced(msg.sender, oldLevel, targetLevel, tokenId);
    }

    function keyLevel(uint256 tokenId) external view returns (uint8) {
        if (!_exists(tokenId)) revert TokenMissing();
        return tokenKeyLevel[tokenId];
    }

    function keyForLevel(address account, uint8 level) external view returns (uint256) {
        _checkLevel(level);
        return userLevelKey[account][level];
    }

    function hasKeyForLevel(address account, uint8 level) external view returns (bool) {
        _checkLevel(level);
        uint256 tokenId = userLevelKey[account][level];
        return tokenId != 0 && tokenOwner[tokenId] == account;
    }

    // =====================================================================
    // Level access control
    // =====================================================================

    function canAccessLevel(address account, uint8 requiredLevel)
        public
        view
        returns (bool)
    {
        _checkLevel(requiredLevel);
        Player storage p = players[account];
        return p.registered && p.level >= requiredLevel;
    }

    function enterLevelRoom(uint8 level)
        external
        whenNotPaused
        onlyRegistered(msg.sender)
        returns (bool)
    {
        _checkLevel(level);
        if (!levelRoomEnabled[level]) revert RoomDisabled();
        if (players[msg.sender].level < level) revert AccessDenied();

        roomEnterCounter[msg.sender][level] += 1;
        emit RoomEntered(msg.sender, level, roomEnterCounter[msg.sender][level]);
        return true;
    }

    function useLevelFeature(uint8 level)
        external
        whenNotPaused
        onlyRegistered(msg.sender)
        returns (bool)
    {
        _checkLevel(level);
        if (!levelFeatureEnabled[level]) revert FeatureDisabled();
        if (players[msg.sender].level < level) revert AccessDenied();

        featureUseCounter[msg.sender][level] += 1;
        emit FeatureUsed(msg.sender, level, featureUseCounter[msg.sender][level]);
        return true;
    }

    function roomEnterCount(address account, uint8 level) external view returns (uint256) {
        _checkLevel(level);
        return roomEnterCounter[account][level];
    }

    function featureUseCount(address account, uint8 level) external view returns (uint256) {
        _checkLevel(level);
        return featureUseCounter[account][level];
    }

    // =====================================================================
    // ERC721 standard-ish functions
    // =====================================================================

    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return
            interfaceId == ERC165_INTERFACE_ID ||
            interfaceId == ERC721_INTERFACE_ID ||
            interfaceId == ERC721_METADATA_INTERFACE_ID;
    }

    function totalSupply() external view returns (uint256) {
        return nextTokenId - 1;
    }

    function balanceOf(address account) public view returns (uint256) {
        if (account == address(0)) revert ZeroAddress();
        return ownedTokenCount[account];
    }

    function ownerOf(uint256 tokenId) public view returns (address) {
        address currentOwner = tokenOwner[tokenId];
        if (currentOwner == address(0)) revert TokenMissing();
        return currentOwner;
    }

    function approve(address to, uint256 tokenId) external {
        address currentOwner = ownerOf(tokenId);

        if (to == currentOwner) revert ApproveToOwner();
        if (msg.sender != currentOwner && !operatorApprovals[currentOwner][msg.sender]) {
            revert NotApprovedOrOwner();
        }

        tokenApprovals[tokenId] = to;
        emit Approval(currentOwner, to, tokenId);
    }

    function getApproved(uint256 tokenId) external view returns (address) {
        if (!_exists(tokenId)) revert TokenMissing();
        return tokenApprovals[tokenId];
    }

    function setApprovalForAll(address operator, bool approved) external {
        operatorApprovals[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function isApprovedForAll(address currentOwner, address operator)
        external
        view
        returns (bool)
    {
        return operatorApprovals[currentOwner][operator];
    }

    function transferFrom(address from, address to, uint256 tokenId) public {
        if (!_isApprovedOrOwner(msg.sender, tokenId)) revert NotApprovedOrOwner();
        _transfer(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) external {
        safeTransferFrom(from, to, tokenId, "");
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) public {
        transferFrom(from, to, tokenId);

        if (!_checkReceiver(from, to, tokenId, data)) {
            revert ReceiverRejected();
        }
    }

    function tokenURI(uint256 tokenId) external view returns (string memory) {
        if (!_exists(tokenId)) revert TokenMissing();

        return string(
            abi.encodePacked(
                baseTokenURI,
                "level/",
                _toString(tokenKeyLevel[tokenId]),
                "/key/",
                _toString(tokenId)
            )
        );
    }

    // =====================================================================
    // Treasury
    // =====================================================================

    function withdraw(address payable to, uint256 amount)
        external
        onlyOwner
        nonReentrant
    {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) amount = address(this).balance;

        (bool ok, ) = to.call{value: amount}("");
        if (!ok) revert WithdrawFailed();

        emit Withdrawal(to, amount);
    }

    receive() external payable {
        revert DirectPaymentDisabled();
    }

    // =====================================================================
    // Internal NFT functions
    // =====================================================================

    function _mintKey(address to, uint8 unlockedLevel) internal returns (uint256 tokenId) {
        if (to == address(0)) revert ZeroAddress();

        tokenId = nextTokenId;
        nextTokenId += 1;

        tokenOwner[tokenId] = to;
        ownedTokenCount[to] += 1;
        tokenKeyLevel[tokenId] = unlockedLevel;

        if (userLevelKey[to][unlockedLevel] == 0) {
            userLevelKey[to][unlockedLevel] = tokenId;
        }

        emit Transfer(address(0), to, tokenId);
    }

    function _exists(uint256 tokenId) internal view returns (bool) {
        return tokenOwner[tokenId] != address(0);
    }

    function _isApprovedOrOwner(address spender, uint256 tokenId)
        internal
        view
        returns (bool)
    {
        address currentOwner = tokenOwner[tokenId];
        if (currentOwner == address(0)) revert TokenMissing();

        return
            spender == currentOwner ||
            tokenApprovals[tokenId] == spender ||
            operatorApprovals[currentOwner][spender];
    }

    function _transfer(address from, address to, uint256 tokenId) internal {
        if (soulboundKeys) revert Soulbound();
        if (to == address(0)) revert TransferToZero();
        if (ownerOf(tokenId) != from) revert NotApprovedOrOwner();

        delete tokenApprovals[tokenId];

        ownedTokenCount[from] -= 1;
        ownedTokenCount[to] += 1;
        tokenOwner[tokenId] = to;

        uint8 level = tokenKeyLevel[tokenId];

        if (userLevelKey[from][level] == tokenId) {
            userLevelKey[from][level] = 0;
        }

        if (userLevelKey[to][level] == 0) {
            userLevelKey[to][level] = tokenId;
        }

        emit Transfer(from, to, tokenId);
    }

    function _checkReceiver(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) internal returns (bool) {
        if (to.code.length == 0) return true;

        try ILevelKeyReceiver(to).onERC721Received(
            msg.sender,
            from,
            tokenId,
            data
        ) returns (bytes4 result) {
            return result == ERC721_RECEIVED;
        } catch {
            return false;
        }
    }

    // =====================================================================
    // Internal utility functions
    // =====================================================================

    function _checkLevel(uint8 level) internal pure {
        if (level < MIN_LEVEL || level > MAX_LEVEL) revert InvalidLevel();
    }

    function _toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0";
        }

        uint256 temp = value;
        uint256 digits;

        while (temp != 0) {
            digits += 1;
            temp /= 10;
        }

        bytes memory buffer = new bytes(digits);

        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }

        return string(buffer);
    }

    // =====================================================================
    // Educational notes / source padding
    // =====================================================================
    // 001. The file remains long for readability and learning.
    // 002. Comments are not included in deployed runtime bytecode.
    // 003. Public/external functions are included in runtime bytecode.
    // 004. Long revert strings are included in bytecode.
    // 005. Custom errors are cheaper than revert strings.
    // 006. Repeated level-specific functions increase bytecode size.
    // 007. Parameterized functions reduce bytecode size.
    // 008. enterLevelRoom(1) replaces enterLevel01().
    // 009. enterLevelRoom(2) replaces enterLevel02().
    // 010. enterLevelRoom(13) replaces enterLevel13().
    // 011. useLevelFeature(1) replaces useLevel01Feature().
    // 012. useLevelFeature(13) replaces useLevel13Feature().
    // 013. canAccessLevel(user, 7) replaces canAccessLevel07(user).
    // 014. Level 1 is the starting level.
    // 015. Level 2 to level 13 require NFT keys.
    // 016. The NFT is minted during buyNextLevelKeyAndAdvance().
    // 017. The NFT key stores its target level.
    // 018. keyLevel(tokenId) returns the unlocked level.
    // 019. keyForLevel(user, level) returns the user's key token id.
    // 020. hasKeyForLevel(user, level) returns whether the key is owned.
    // 021. levelPrice(2) is the upgrade price to level 2.
    // 022. levelXPRequired(2) is the XP needed for level 2.
    // 023. levelRoomEnabled(level) controls room access.
    // 024. levelFeatureEnabled(level) controls feature access.
    // 025. owner can change level rules.
    // 026. owner can pause the contract.
    // 027. owner can withdraw collected ether.
    // 028. soulboundKeys is true by default.
    // 029. When soulbound is true, transfers revert.
    // 030. This is useful for membership/access keys.
    // 031. If marketplace transfer is needed, set soulbound false.
    // 032. For production, consider OpenZeppelin ERC721.
    // 033. For production, split responsibilities.
    // 034. For production, add tests in Foundry or Hardhat.
    // 035. For production, audit before handling real funds.
    // 036. Mainnet has a 24KB runtime bytecode limit.
    // 037. Remix warning appears before deployment.
    // 038. Optimizer can reduce bytecode size significantly.
    // 039. Low optimizer runs usually reduce deployment size.
    // 040. High optimizer runs can optimize repeated runtime execution.
    // 041. The default price formula is simple for testing.
    // 042. Level 2 price is 0.01 ETH.
    // 043. Level 3 price is 0.02 ETH.
    // 044. Level 13 price is 0.12 ETH.
    // 045. You can set prices to zero for local testing.
    // 046. Use setLevelRule(level, 0, xp, true) to make a free key.
    // 047. Users still need XP unless xpRequired is also zero.
    // 048. XP is controlled by the owner in this prototype.
    // 049. A game backend can call addXP after achievements.
    // 050. A DAO/admin panel can call setLevelRule.
    // 051. This contract does not implement royalties.
    // 052. This contract does not implement enumerable ERC721.
    // 053. ERC721Enumerable increases bytecode and gas.
    // 054. For access keys, enumerable is often unnecessary.
    // 055. This contract emits Transfer events for NFT tracking.
    // 056. Marketplaces can detect basic ERC721 metadata.
    // 057. tokenURI is derived from baseTokenURI.
    // 058. Example base URI: ipfs://CID/
    // 059. Result: ipfs://CID/level/2/key/1
    // 060. You can map these paths in your metadata server.
    // 061. register() gives WELCOME_XP.
    // 062. Default WELCOME_XP is 50.
    // 063. Level 2 requires 100 XP by default.
    // 064. Owner should add 50 XP for first upgrade in quick test.
    // 065. Or owner can set level 2 XP to 50.
    // 066. Or owner can set level 2 XP to zero.
    // 067. This allows flexible game economy design.
    // 068. roomEnterCounter can support analytics.
    // 069. featureUseCounter can support analytics.
    // 070. Events can be indexed by a subgraph.
    // 071. The contract accepts ETH only through upgrade purchase.
    // 072. Direct ETH transfers are blocked.
    // 073. This prevents accidental payments.
    // 074. withdraw(to, 0) withdraws full balance.
    // 075. withdraw(to, amount) withdraws specific amount.
    // 076. nonReentrant protects payable flows.
    // 077. Ownership transfer is two-step.
    // 078. Two-step ownership prevents accidental owner loss.
    // 079. pendingOwner must call acceptOwnership().
    // 080. cancelOwnershipTransfer() clears pending owner.
    // 081. The contract uses mappings for compact storage.
    // 082. It avoids long arrays of structs in constructor.
    // 083. It avoids storing 13 room names on deploy.
    // 084. It avoids storing 13 feature names on deploy.
    // 085. Names can be handled off-chain by frontend.
    // 086. Level number is enough for access enforcement.
    // 087. The frontend can label level 1 as Room One.
    // 088. The frontend can label level 13 as Final Room.
    // 089. On-chain should enforce only critical rules.
    // 090. UI text does not need to be on-chain.
    // 091. This is a key bytecode-size optimization.
    // 092. Keep on-chain data minimal.
    // 093. Keep off-chain presentation flexible.
    // 094. Use events for off-chain indexing.
    // 095. Use mappings for current state.
    // 096. Avoid dynamic string-heavy constructors.
    // 097. Avoid duplicate external functions.
    // 098. Avoid large inherited contracts when not needed.
    // 099. Prefer libraries or modular contracts for mainnet.
    // 100. This file is ready for Remix experimentation.
}
