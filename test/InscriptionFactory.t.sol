// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/InscriptionCloneFactory.sol";
import "../src/Inscription.sol";

contract InscriptionCloneFactoryTest is Test{
    InscriptionCloneFactory factory;
    Inscription impl;
    address owner = address(0x123);
    address user = address(0x456);
    address user2 = address(0x101112);
    address nonOwner = address(0x789);

    function setUp() public {
        vm.startPrank(owner);
        impl = new Inscription("TestImpl", "TI"); // 部署实现合约
        factory = new InscriptionCloneFactory(address(impl)); // 部署工厂合约
        vm.stopPrank();

        // 给用户和工厂分配一些 ETH
        vm.deal(user, 10 ether);
        vm.deal(user2, 10 ether);
        vm.deal(address(factory), 5 ether);
    }

    // 测试 deployInscription
    function testDeployInscription() public {
        vm.prank(user);
        address proxy = factory.deployInscription("TestToken", "TEST", 1000e18, 10e18, 0.1 ether);

        Inscription inscription = Inscription(proxy);
        assertEq(inscription.name(), "TestToken");
        assertEq(inscription.symbol(), "TEST");
        assertEq(inscription.totalSupply(), 1000e18);
        assertEq(inscription.perMint(), 10e18);
        assertEq(inscription.price(), 0.1 ether);
        assertEq(inscription.circulatingSupply(), 0);
    }

    // 测试 mintInscription 是否成功，并且费用是否按比例分账
    function testMintInscription() public {
        // 部署代理
        vm.prank(user);
        address proxy = factory.deployInscription("TestToken", "TEST", 1000e18, 1e18, 1);

        // 记录初始余额
        uint256 implOwnerBalanceBefore = owner.balance; // _implOwner 是 owner
        uint256 proxyOwnerBalanceBefore = user.balance; // 代理拥有者是 user
//        uint256 userBalanceBefore = user.balance;
        uint256 user2BalanceBefore = user2.balance; // 去mint

        // 用户调用 mintInscription，发送 2 ETH
        vm.prank(user2);
        factory.mintInscription{value: 2 ether}(proxy);

        Inscription inscription = Inscription(proxy);
        assertEq(inscription.balanceOf(user2), 1e18); // perMint = 10e18
        assertEq(inscription.circulatingSupply(), 1e18);

        // 验证 ETH 分割 (50%/50%)
        assertEq(owner.balance, implOwnerBalanceBefore + 0.5 ether); // _implOwner 分得 0.5 ETH
        assertEq(user.balance, proxyOwnerBalanceBefore + 0.5 ether); // user即proxy owner 分得 0.5 ETH
        assertEq(user2.balance, user2BalanceBefore - 2 ether + 1 ether); // 用户发送 2 ETH，退回 1 ETH
    }


    // 测试 mintInscription 超过totalSupply失败
    function testMintExceedsSupply() public {
        vm.prank(user);
        address proxy = factory.deployInscription("TestToken", "TEST", 2e18, 1e18, 1);

        vm.startPrank(user);
        factory.mintInscription{value: 1 ether}(proxy); // 10e18
        factory.mintInscription{value: 1 ether}(proxy); // 20e18

        vm.expectRevert("Exceeds total supply");
        factory.mintInscription{value: 1 ether}(proxy); // 超过 20e18
        vm.stopPrank();
    }

    // 测试 sendEther 仅限 owner
    function testSendEtherByOwner() public {
        address payable recipient = payable(address(0xABC));
        uint256 recipientBalanceBefore = recipient.balance;

        vm.prank(owner);
        factory.sendEther(recipient, 1 ether);

        assertEq(recipient.balance, recipientBalanceBefore + 1 ether);
        assertEq(address(factory).balance, 4 ether); // 初始 5 ETH - 1 ETH
    }

    // 测试 sendEther 非 owner 调用失败
    function testSendEtherByNonOwner() public {
        address payable recipient = payable(address(0xABC));

        vm.prank(nonOwner);

        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", nonOwner));
        factory.sendEther(recipient, 1 ether);
    }

    // 测试 mintInscription 未发送 ETH 失败
    function testMintInscriptionNoEth() public {
        vm.prank(user);
        address proxy = factory.deployInscription("TestToken", "TEST", 1000e18, 10e18, 0.1 ether);

        vm.prank(user);
        vm.expectRevert("Must send some ETH");
        factory.mintInscription(proxy);
    }


}
