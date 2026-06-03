// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";

interface ILevelRewardNFT {
    function mintLevelReward(address to, uint8 level) external returns (uint256);
}

contract ProductionLevelSystem is Ownable {

    uint8 public constant MAX_LEVEL = 13;
    uint8 public constant MAX_STEP = 7;
    uint256 public constant WELCOME_XP = 50;

    ILevelRewardNFT public rewardNFT;

    struct Player {
        bool registered;
        uint8 level;
        uint8 step;
        uint256 xp;
    }

    mapping(address => Player) public players;
    mapping(address => bool) public whitelist;

    mapping(uint8 => mapping(uint8 => uint256)) public stepXPRequired;
    mapping(uint8 => uint256) public levelPrice;

    event Registered(address indexed user);
    event StepAdvanced(address indexed user, uint8 level, uint8 fromStep, uint8 toStep);
    event LevelAdvanced(address indexed user, uint8 fromLevel, uint8 toLevel);

    //  FIX اصلی اینجاست
    constructor(address _rewardNFT, address initialOwner)
        Ownable(initialOwner)
    {
        rewardNFT = ILevelRewardNFT(_rewardNFT);

        for (uint8 level = 1; level <= MAX_LEVEL; level++) {
            levelPrice[level] = uint256(level - 1) * 0.01 ether;

            for (uint8 step = 1; step <= MAX_STEP; step++) {
                stepXPRequired[level][step] = uint256(step - 1) * 50;
            }
        }

        // whitelist placeholders
        // whitelist[0x...]=true;
    }

    function register() external {
        require(whitelist[msg.sender], "Not whitelisted");
        require(!players[msg.sender].registered, "Already registered");

        players[msg.sender] = Player(true, 1, 1, WELCOME_XP);

        rewardNFT.mintLevelReward(msg.sender, 1);

        emit Registered(msg.sender);
    }

    function advanceStep() external {
        Player storage p = players[msg.sender];
        require(p.registered, "Not registered");
        require(p.step < MAX_STEP, "Max step");

        uint8 nextStep = p.step + 1;
        require(p.xp >= stepXPRequired[p.level][nextStep], "XP low");

        emit StepAdvanced(msg.sender, p.level, p.step, nextStep);
        p.step = nextStep;
    }

    function buyNextLevelKeyAndAdvance() external payable {
        Player storage p = players[msg.sender];

        require(p.registered, "Not registered");
        require(p.step == MAX_STEP, "Step not complete");
        require(p.level < MAX_LEVEL, "Max level");

        uint8 nextLevel = p.level + 1;
        require(msg.value == levelPrice[nextLevel], "Wrong ETH");

        rewardNFT.mintLevelReward(msg.sender, nextLevel);

        emit LevelAdvanced(msg.sender, p.level, nextLevel);

        p.level = nextLevel;
        p.step = 1;
    }

    function addWhitelist(address user) external onlyOwner {
        whitelist[user] = true;
    }
}