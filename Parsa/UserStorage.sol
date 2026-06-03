// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract UserStorage {
    struct Gem {
        string png_file;
        string fbx_file;
    }

    struct Level {
        uint256 id;
        string name;
        string slug;
        Gem gem;
    }

    struct Wallet {
        uint256 psc;
        uint256 blue;
        uint256 red;
        uint256 yellow;
        uint256 irr;
        uint256 satisfaction;
        uint256 effect;
    }

    struct User {
        uint256 id;
        string name;
        string code;
        Wallet wallet;
        Level[] levels;
    }

    mapping(string => User) public users;

    function addUser(
        uint256 _id, string memory _name, string memory _code,
        uint256[7] memory _w
    ) public {
        users[_code].id = _id;
        users[_code].name = _name;
        users[_code].code = _code;
        users[_code].wallet = Wallet(_w[0], _w[1], _w[2], _w[3], _w[4], _w[5], _w[6]);
    }

    function addLevel(string memory _code, uint256 _id, string memory _name, string memory _slug, string memory _png, string memory _fbx) public {
        users[_code].levels.push(Level(_id, _name, _slug, Gem(_png, _fbx)));
    }
}