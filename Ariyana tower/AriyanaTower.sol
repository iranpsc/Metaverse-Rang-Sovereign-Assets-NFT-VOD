// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721Burnable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import {ERC721Pausable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Pausable.sol";
import {ERC721URIStorage} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import {ERC721Royalty} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Royalty.sol";

contract AriyanaTower is
    ERC721,
    ERC721Pausable,
    ERC721Burnable,
    ERC721URIStorage,
    ERC721Royalty,
    Ownable
{
    
    // setting initial owner
    
    address public immutable initialOwner;

    constructor(address _initialOwner)
        ERC721("Ariyana tower", "Ariyana")
        Ownable(_initialOwner)
    {
        initialOwner = _initialOwner;

        // fixed royalty: 6%
        _setDefaultRoyalty(_initialOwner, 600);
    }

    
    // subcategory system
    
  struct Collection {
        address contractAddress;
        address parent;
        string name;
        bool exists;
    }

    mapping(address => Collection) public collections;

    // parent => children
    mapping(address => address[]) public children;

    address[] public allCollections;

    event CollectionAdded(
        address indexed contractAddress,
        address indexed parent,
        string name
    );


    function addCollection(
        address contractAddress,
        address parent,
        string calldata name
    )
        external
        onlyOwner
    {
        require(contractAddress != address(0), "Invalid address");
        require(!collections[contractAddress].exists, "Already added");
        require(contractAddress != parent, "Self parent not allowed");

        if (parent != address(0)) {
            require(
                collections[parent].exists,
                "Parent collection not found"
            );

            children[parent].push(contractAddress);
        }

        collections[contractAddress] = Collection({
            contractAddress: contractAddress,
            parent: parent,
            name: name,
            exists: true
        });

        allCollections.push(contractAddress);

        emit CollectionAdded(
            contractAddress,
            parent,
            name
        );
    }

    function getChildren(
        address parent
    )
        external
        view
        returns (address[] memory)
    {
        return children[parent];
    }

    function getAllCollections()
        external
        view
        returns (address[] memory)
    {
        return allCollections;
    }

    function isCollection(
        address contractAddress
    )
        external
        view
        returns (bool)
    {
        return collections[contractAddress].exists;
    }

    
    // minting
   
    function safeMint(
        address to,
        uint256 tokenId,
        string memory uri
    )
        public
        onlyOwner
    {
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);
    }

    
    // pause control
    
    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    
    // metadata control (only initial owner)
    
    modifier onlyInitialOwner() {
        require(msg.sender == initialOwner, "Not initial owner");
        _;
    }

    //only new CID should be intered

    string public baseURI = "ipfs://";

    function updateTokenURI(
        uint256 tokenId,
        string calldata newURI
    )
        external
        onlyInitialOwner
    {
        _setTokenURI(
            tokenId,
            string(abi.encodePacked(baseURI, newURI))
        );
        emit MetadataUpdate(tokenId);
    }

    function _update(
        address to,
        uint256 tokenId,
        address auth
    )
        internal
        override(ERC721, ERC721Pausable)
        returns (address)
    {
        return super._update(to, tokenId, auth);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721URIStorage, ERC721Royalty)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}

 