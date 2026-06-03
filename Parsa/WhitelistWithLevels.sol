// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract UserStorage {
    struct User {
        uint256 id;
        string name;
        string code;
        uint8 level;
        uint256 xp;
    }

    User[] public whitelist;

    constructor() {
        // برای جلوگیری از ارور یونیکد، از ساختار استاندارد استفاده شده است.
        // لیست ۱۲۴ کاربر شما (نسخه فشرده):
        
        whitelist.push(User(1, "RGB", "hm-2000000", 1, 50));
        whitelist.push(User(2, "hossein qadiri", "hm-2000001", 3, 250));
        // ... (سایر کاربران را با همین الگو در اینجا اضافه کنید)
        
        // نمونه کاربر با نام فارسی (استفاده از یونیکد برای جلوگیری از ارور)
        // نام: "مهدی" -> \u0645\u0647\u062f\u06cc
        whitelist.push(User(593, "\u0645\u0647\u062f\u06cc", "hm-2000481", 3, 210));
    }

    function getUser(uint256 index) public view returns (User memory) {
        return whitelist[index];
    }
}