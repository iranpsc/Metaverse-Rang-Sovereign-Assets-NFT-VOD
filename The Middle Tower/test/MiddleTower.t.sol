// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/MiddleTower.sol";

contract MiddleTowerTest is Test {
    MiddleTower public tower;
    address public owner = address(1);
    address public tenant = address(2);
    address public island = address(3);

    uint256 public constant RENTAL_PRICE = 0.1 ether;

    function setUp() public {
        // Deploy the contract as the owner
        vm.prank(owner);
        tower = new MiddleTower(owner, island);
    }

    // --- Minting Tests ---

    function test_MintFloor() public {
        vm.startPrank(owner);
        tower.mintFloor("ipfs://metadata", "Office", RENTAL_PRICE);

        assertEq(tower.ownerOf(1), owner);
        (string memory usage, uint256 price,,) = tower.floors(1);
        assertEq(usage, "Office");
        assertEq(price, RENTAL_PRICE);
        vm.stopPrank();
    }

    function test_RevertIf_MintExceedsMax() public {
        vm.startPrank(owner);
        // Mint 7 floors
        for (uint256 i = 0; i < 7; i++) {
            tower.mintFloor("uri", "usage", RENTAL_PRICE);
        }
        // The 8th mint should fail
        vm.expectRevert("Tower: Max floors reached");
        tower.mintFloor("uri", "usage", RENTAL_PRICE);
        vm.stopPrank();
    }

    // --- Rental Tests ---

    function test_RentFloor() public {
        vm.prank(owner);
        tower.mintFloor("uri", "Office", RENTAL_PRICE);

        vm.deal(tenant, 1 ether);
        vm.prank(tenant);
        tower.rentFloor{ value: RENTAL_PRICE * 2 }(1, 2); // Rent for 2 days

        (,, address currentTenant, uint256 expiry) = tower.floors(1);
        assertEq(currentTenant, tenant);
        assertEq(expiry, block.timestamp + 2 days);
    }

    function test_RevertIf_InsufficientPayment() public {
        vm.prank(owner);
        tower.mintFloor("uri", "Office", RENTAL_PRICE);

        vm.deal(tenant, 1 ether);
        vm.prank(tenant);
        vm.expectRevert("Tower: Insufficient payment");
        tower.rentFloor{ value: 0.05 ether }(1, 1);
    }

    function test_RevertIf_AlreadyOccupied() public {
        vm.prank(owner);
        tower.mintFloor("uri", "Office", RENTAL_PRICE);

        vm.deal(tenant, 1 ether);
        vm.prank(tenant);
        tower.rentFloor{ value: RENTAL_PRICE }(1, 1);

        // Try to rent again while occupied
        vm.prank(address(4));
        vm.deal(address(4), 1 ether);
        vm.expectRevert("Tower: Currently occupied");
        tower.rentFloor{ value: RENTAL_PRICE }(1, 1);
    }

    // --- Admin & Utility Tests ---

    function test_UpdatePrice() public {
        vm.prank(owner);
        tower.mintFloor("uri", "Office", RENTAL_PRICE);

        vm.prank(owner);
        tower.updateRentalPrice(1, 0.5 ether);

        (, uint256 newPrice,,) = tower.floors(1);
        assertEq(newPrice, 0.5 ether);
    }

    function test_Withdraw() public {
        // Rent a floor to add balance
        vm.prank(owner);
        tower.mintFloor("uri", "Office", RENTAL_PRICE);

        vm.deal(tenant, 1 ether);
        vm.prank(tenant);
        tower.rentFloor{ value: RENTAL_PRICE }(1, 1);

        uint256 ownerBalanceBefore = owner.balance;

        vm.prank(owner);
        tower.withdraw();

        assertEq(owner.balance, ownerBalanceBefore + RENTAL_PRICE);
        assertEq(address(tower).balance, 0);
    }

    function test_ContractURI() public {
        string memory uri = "ipfs://contract-metadata";
        vm.prank(owner);
        tower.setContractURI(uri);
        assertEq(tower.contractURI(), uri);
    }

    function test_IsAvailable() public {
        vm.prank(owner);
        tower.mintFloor("uri", "Office", RENTAL_PRICE);

        // Should be available initially
        assertTrue(tower.isAvailable(1));

        vm.deal(tenant, 1 ether);
        vm.prank(tenant);
        tower.rentFloor{ value: RENTAL_PRICE }(1, 1);

        // Should NOT be available after renting
        assertFalse(tower.isAvailable(1));
    }

    function test_RevertIf_WithdrawZeroBalance() public {
        vm.prank(owner);
        vm.expectRevert("Tower: No funds available");
        tower.withdraw();
    }
}
