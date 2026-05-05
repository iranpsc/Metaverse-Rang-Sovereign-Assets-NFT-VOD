// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title MiddleTower NFT Collection
 * @author YourName/Organization
 * @notice This contract manages a 7-floor tower where each floor is an NFT and can be rented.
 */
contract MiddleTower is ERC721URIStorage, Ownable {
    address public islandAddress;
    string private _contractURI_Link;
    uint256 public nextTokenId = 1;
    uint256 public constant MAX_FLOORS = 7;

    struct FloorInfo {
        string usage; // e.g., "Penthouse", "Gym", "Office"
        uint256 rentalPrice; // Price per day in WEI
        address currentTenant; // Address of the person renting
        uint256 rentalExpiresAt; // Timestamp when rental ends
    }

    // Mapping from Token ID to its Floor Details
    mapping(uint256 => FloorInfo) public floors;

    event FloorMinted(uint256 indexed tokenId, string usage, uint256 price);
    event FloorRented(uint256 indexed tokenId, address indexed tenant, uint256 expiry);
    event PriceUpdated(uint256 indexed tokenId, uint256 newPrice);

    /**
     * @param _initialOwner The address that will have admin rights
     * @param _island The address of the main island contract (for ecosystem integration)
     */
    constructor(address _initialOwner, address _island)
        ERC721("Middle Tower", "MID")
        Ownable(_initialOwner)
    {
        islandAddress = _island;
    }

    /**
     * @dev Sets the metadata for the entire collection (used by marketplaces like OpenSea)
     */
    function setContractURI(string memory _uri) external onlyOwner {
        _contractURI_Link = _uri;
    }

    function contractURI() public view returns (string memory) {
        return _contractURI_Link;
    }

    /**
     * @notice Mints a new floor NFT (Only up to 7 floors)
     * @param _uri Metadata URI for the floor (IPFS link)
     * @param _usage Description of the floor's purpose
     * @param _price Rental price per day in WEI
     */
    function mintFloor(string memory _uri, string memory _usage, uint256 _price)
        external
        onlyOwner
    {
        require(nextTokenId <= MAX_FLOORS, "Tower: Max floors reached");

        uint256 tokenId = nextTokenId;
        _safeMint(msg.sender, tokenId);
        _setTokenURI(tokenId, _uri);

        floors[tokenId] = FloorInfo(_usage, _price, address(0), 0);

        emit FloorMinted(tokenId, _usage, _price);
        nextTokenId++;
    }

    /**
     * @notice Updates the rental price of a specific floor
     */
    function updateRentalPrice(uint256 _tokenId, uint256 _newPrice) external onlyOwner {
        require(_ownerOf(_tokenId) != address(0), "Tower: Nonexistent floor");
        floors[_tokenId].rentalPrice = _newPrice;
        emit PriceUpdated(_tokenId, _newPrice);
    }

    /**
     * @notice Rent a floor for a specific number of days
     * @param _tokenId The ID of the floor to rent
     * @param _days Number of days to rent
     */
    function rentFloor(uint256 _tokenId, uint256 _days) external payable {
        require(_ownerOf(_tokenId) != address(0), "Tower: Floor does not exist");
        require(msg.value >= floors[_tokenId].rentalPrice * _days, "Tower: Insufficient payment");
        require(block.timestamp > floors[_tokenId].rentalExpiresAt, "Tower: Currently occupied");

        floors[_tokenId].currentTenant = msg.sender;
        floors[_tokenId].rentalExpiresAt = block.timestamp + (_days * 1 days);

        emit FloorRented(_tokenId, msg.sender, floors[_tokenId].rentalExpiresAt);
    }

    /**
     * @notice Check if a floor is currently available for rent
     */
    function isAvailable(uint256 _tokenId) public view returns (bool) {
        return block.timestamp > floors[_tokenId].rentalExpiresAt;
    }

    /**
     * @dev Withdraw collected rental fees to the owner's address
     */
    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "Tower: No funds available");

        (bool success,) = payable(owner()).call{ value: balance }("");
        require(success, "Tower: Transfer failed");
    }
}
