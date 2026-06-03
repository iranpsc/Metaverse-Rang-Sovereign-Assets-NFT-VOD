// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MerkleWhitelist is Ownable {

    bytes32 public merkleRoot;

    mapping(address => bool) public claimed;

    error NotWhitelisted();
    error AlreadyClaimed();

    event MerkleRootUpdated(bytes32 root);
    event Claimed(address indexed user);

    constructor(bytes32 _root) Ownable(msg.sender) {
        merkleRoot = _root;
    }

    // =========================
    // ADMIN
    // =========================

    function setMerkleRoot(bytes32 _root) external onlyOwner {
        merkleRoot = _root;
        emit MerkleRootUpdated(_root);
    }

    // =========================
    // VERIFY
    // =========================

    function isWhitelisted(
        address user,
        bytes32[] calldata proof
    ) public view returns (bool) {

        bytes32 leaf = keccak256(abi.encodePacked(user));

        return MerkleProof.verify(proof, merkleRoot, leaf);
    }

    // =========================
    // CLAIM / REGISTER GATE
    // =========================

    function claim(
        bytes32[] calldata proof
    ) external {

        if (claimed[msg.sender]) revert AlreadyClaimed();

        bytes32 leaf = keccak256(abi.encodePacked(msg.sender));

        bool ok = MerkleProof.verify(proof, merkleRoot, leaf);

        if (!ok) revert NotWhitelisted();

        claimed[msg.sender] = true;

        emit Claimed(msg.sender);
    }
}