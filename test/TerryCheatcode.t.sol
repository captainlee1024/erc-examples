// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";

contract TerryContract {
    mapping(uint256 => uint256) public uToU;
    mapping(uint256 => address) public uToA;
    mapping(address => uint256) public aToU;
    mapping(address => address) public aToA;

    function setUToU(uint256 key, uint256 value) public {
        uToU[key] = value;
    }

    function setUToA(uint256 key, address value) public {
        uToA[key] = value;
    }

    function getUToU(uint256 key) public view returns (uint256) {
        return uToU[key];
    }

    function getUToA(uint256 key) public view returns (address) {
        return uToA[key];
    }

    function setAToU(address key, uint256 value) public {
        aToU[key] = value;
    }

    function setAToA(address key, address value) public {
        aToA[key] = value;
    }
}

contract TerryCheatCodeTest is Test {
    TerryContract public terryContract;

    function setUp() public {
        terryContract = new TerryContract();
    }

    function test_TerryCheatCode() public {
        address addr1 = makeAddr("addr1");
        address addr2 = makeAddr("addr2");
        address addr3 = makeAddr("addr3");
        address addr4 = makeAddr("addr4");
        terryContract.setUToU(1, 1);
        terryContract.setUToU(2, 2);
        console.logUint(uint256(vm.terryGetMappingStorageAt(address(terryContract), 0, 1)));
        console.logUint(uint256(vm.terryGetMappingStorageAt(address(terryContract), 0, 2)));
        assertEq(uint256(vm.terryGetMappingStorageAt(address(terryContract), 0, 1)), 1);
        assertEq(uint256(vm.terryGetMappingStorageAt(address(terryContract), 0, 2)), 2);

        vm.terrySetMappingStorageAt(address(terryContract), 0, 1, bytes32(uint256(3)));
        assertEq(uint256(vm.terryGetMappingStorageAt(address(terryContract), 0, 1)), 3);
        vm.terrySetMappingStorageAt(address(terryContract), 0, 2, bytes32(uint256(4)));
        assertEq(uint256(vm.terryGetMappingStorageAt(address(terryContract), 0, 2)), terryContract.getUToU(2));

        console.logAddress(addr1);
        console.logAddress(addr2);
        terryContract.setUToA(1, addr1);
        terryContract.setUToA(2, addr2);
        bytes32 getAddrWithKey1 = vm.terryGetMappingStorageAt(address(terryContract), 1, 1);
        console.logAddress(address(uint160(uint256(getAddrWithKey1))));
        assertEq(address(uint160(uint256(getAddrWithKey1))), addr1);
        bytes32 getAddrWithKey2 = vm.terryGetMappingStorageAt(address(terryContract), 1, 2);
        console.logAddress(address(uint160(uint256(getAddrWithKey2))));
        assertEq(address(uint160(uint256(getAddrWithKey2))), addr2);

        vm.terrySetMappingStorageAt(address(terryContract), 1, 1, bytes32(uint256(uint160(addr3))));
        assertEq(terryContract.getUToA(1), addr3);
        vm.terrySetMappingStorageAt(address(terryContract), 1, 2, bytes32(uint256(uint160(addr4))));
        assertEq(terryContract.getUToA(2), addr4);

        terryContract.setAToU(addr1, 3);
        terryContract.setAToU(addr2, 4);
        assertEq(uint256(vm.terryGetMappingStorageAt(address(terryContract), 2, uint256(uint160(addr1)))), 3);
        assertEq(uint256(vm.terryGetMappingStorageAt(address(terryContract), 2, uint256(uint160(addr2)))), 4);

        vm.terrySetMappingStorageAt(address(terryContract), 2, uint256(uint160(addr1)), bytes32(uint256(5)));
        assertEq(terryContract.aToU(addr1), 5);
        vm.terrySetMappingStorageAt(address(terryContract), 2, uint256(uint160(addr2)), bytes32(uint256(6)));
        assertEq(terryContract.aToU(addr2), 6);

        terryContract.setAToA(addr1, addr3);
        terryContract.setAToA(addr2, addr4);
        bytes32 getSlot3KeyAddr1 = vm.terryGetMappingStorageAt(address(terryContract), 3, uint256(uint160(addr1)));
        assertEq(address(uint160(uint256(getSlot3KeyAddr1))), addr3);
        bytes32 getSlot3KeyAddr2 = vm.terryGetMappingStorageAt(address(terryContract), 3, uint256(uint160(addr2)));
        assertEq(address(uint160(uint256(getSlot3KeyAddr2))), addr4);

        vm.terrySetMappingStorageAt(
            address(terryContract), 3, uint256(uint160(addr1)), bytes32(uint256(uint160(addr4)))
        );
        assertEq(terryContract.aToA(addr1), addr4);
        vm.terrySetMappingStorageAt(
            address(terryContract), 3, uint256(uint160(addr2)), bytes32(uint256(uint160(addr3)))
        );
        assertEq(terryContract.aToA(addr2), addr3);
    }

    function test_SetUToU() public {
        terryContract.setUToU(1, 2);
        assertEq(terryContract.getUToU(1), 2);
    }

    function test_SetUToA() public {
        terryContract.setUToA(1, address(this));
        assertEq(terryContract.getUToA(1), address(this));
    }

    function test_SetAToU() public {
        terryContract.setAToU(address(this), 1);
        assertEq(terryContract.aToU(address(this)), 1);
    }

    function test_SetAToA() public {
        terryContract.setAToA(address(this), address(this));
        assertEq(terryContract.aToA(address(this)), address(this));
    }
}
