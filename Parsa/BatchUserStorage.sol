// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract BatchUserStorage {
    struct Wallet { uint256 psc; uint256 blue; uint256 red; uint256 yellow; uint256 irr; uint256 satisfaction; uint256 effect; }
    struct User { uint256 id; string name; string code; Wallet wallet; }

    mapping(string => User) public users;

    // تابع Batch برای اضافه کردن گروهی کاربران
    function addUsersBatch(
        uint256[] memory _ids, 
        string[] memory _names, 
        string[] memory _codes,
        uint256[] memory _wallets // ساختار تخت برای سادگی: [psc1, blue1... psc2, blue2...]
    ) public {
        for (uint i = 0; i < _ids.length; i++) {
            users[_codes[i]] = User(
                _ids[i], _names[i], _codes[i],
                Wallet(_wallets[i*7], _wallets[i*7+1], _wallets[i*7+2], _wallets[i*7+3], _wallets[i*7+4], _wallets[i*7+5], _wallets[i*7+6])
            );
        }
    }
}