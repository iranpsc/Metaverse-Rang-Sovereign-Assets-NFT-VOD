// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title AryanaIsland
 * @dev Main management contract for Aryana Island within the decentralized ecosystem.
 * This contract handles tower registrations, island metadata, and leasing logic.
 */
contract AryanaIsland is ERC721URIStorage, Ownable {
    uint256 public constant ISLAND_TOKEN_ID = 1;
    address public earthAddress; // Connection to the Parent NFT (The Earth)

    struct IslandDetails {
        string name;
        string creationDate; // Format: 1403/08/15
        uint256 timestamp; // e.g., 1730751000
        string area; // Total area in sq meters
        string usageType; // Primary land use description
    }

    struct Tower {
        address towerContract;
        string towerName;
        bool isActive;
        uint256 registeredAt;
    }

    struct RentalInfo {
        address tenant;
        uint256 expiresAt;
    }

    IslandDetails public islandInfo;
    RentalInfo public islandRental;

    // Tower Management Mapping
    mapping(address => Tower) public towers;
    address[] public towerList;

    // Events for Off-chain Tracking (Indexing)
    event TowerRegistered(address indexed towerContract, string name);
    event IslandRented(address indexed tenant, uint256 expiresAt);

    constructor(address _initialOwner) ERC721("Aryana Island", "ARYANA") Ownable(_initialOwner) {
        islandInfo = IslandDetails({
            name: "Aryana Island",
            creationDate: "1403/08/15",
            timestamp: 1730751000,
            area: "145,756,604.6",
            usageType: "Commercial and Green Space culture"
        });
    }

    /**
     * @dev Initializes the island's on-chain presence with Pinata IPFS CID.
     * @param to The recipient address of the Island NFT.
     * @param _uri The IPFS CID containing metadata.
     */
    function initializeIsland(address to, string memory _uri) external onlyOwner {
        _safeMint(to, ISLAND_TOKEN_ID);
        _setTokenURI(ISLAND_TOKEN_ID, _uri);
    }

    /**
     * @dev Links this island to the broader "The Earth" ecosystem.
     * @param _earth The contract address of the parent Earth NFT.
     */
    function connectToEarth(address _earth) external onlyOwner {
        require(_earth != address(0), "Invalid Earth address");
        earthAddress = _earth;
    }

    /**
     * @dev Registers a new Tower contract on Aryana Island.
     * @param _contract The deployed address of the Tower contract.
     * @param _name The human-readable name of the tower for easier indexing.
     */
    function registerTower(address _contract, string calldata _name) external onlyOwner {
        require(_contract != address(0), "Invalid address");
        require(towers[_contract].towerContract == address(0), "Tower already exists");

        towers[_contract] = Tower({
            towerContract: _contract,
            towerName: _name,
            isActive: true,
            registeredAt: block.timestamp
        });

        towerList.push(_contract);
        emit TowerRegistered(_contract, _name);
    }

    /**
     * @dev Core logic for leasing the entire island infrastructure.
     * @param _days Duration of the rental period in days.
     */
    function rentIsland(uint256 _days) external payable {
        // Price verification logic will be integrated here in future updates
        islandRental.tenant = msg.sender;
        islandRental.expiresAt = block.timestamp + (_days * 1 days);

        emit IslandRented(msg.sender, islandRental.expiresAt);
    }

    /**
     * @dev Public view function to check tower accessibility for the current island tenant.
     * Future versions will implement Cross-Contract Calls to verify floor availability.
     */
    function getTowerStatusForTenant(address _tower) public view returns (string memory) {
        if (islandRental.expiresAt < block.timestamp) return "Island is not currently rented";
        require(towers[_tower].isActive, "Tower is inactive");

        return "Accessing available floors in tower...";
    }

    // Helper functions for Frontend integration
    function getTotalTowers() public view returns (uint256) {
        return towerList.length;
    }

    function isIslandRented() public view returns (bool) {
        return block.timestamp < islandRental.expiresAt;
    }
}
