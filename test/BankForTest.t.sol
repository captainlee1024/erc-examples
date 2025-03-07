// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Bank} from "../src/BankForTest.sol";

/*
在foundry 中Test继承了CommonBase, 其中 VM合约在foundry revm初始化时在storage指定位置保存了vm合约的地址
abstract contract CommonBase {
    // Cheat code address, 0x7109709ECfa91a80626fF3989D68f67F5b1DD12D.
    address internal constant VM_ADDRESS = address(uint160(uint256(keccak256("hevm cheat code"))));
    // console.sol and console2.sol work by executing a staticcall to this address.
    // console 合约方法是使用该地址发送了staticcall
    address internal constant CONSOLE = 0x000000000000000000636F6e736F6c652e6c6f67;
    // Used when deploying with create2, https://github.com/Arachnid/deterministic-deployment-proxy.
    address internal constant CREATE2_FACTORY = 0x4e59b44847b379578588920cA78FbF26c0B4956C;
    // Default address for tx.origin and msg.sender, 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38.
    // 默认sender和origin是该地址
    address internal constant DEFAULT_SENDER = address(uint160(uint256(keccak256("foundry default caller"))));
    // Address of the test contract, deployed by the DEFAULT_SENDER.
    // 默认Test合约地址
    address internal constant DEFAULT_TEST_CONTRACT = 0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f;
    // Deterministic deployment address of the Multicall3 contract.
    address internal constant MULTICALL3_ADDRESS = 0xcA11bde05977b3631167028862bE2a173976CA11;
    // The order of the secp256k1 curve.
    uint256 internal constant SECP256K1_ORDER =
        115792089237316195423570985008687907852837564279074904382605163141518161494337;

    uint256 internal constant UINT256_MAX =
        115792089237316195423570985008687907853269984665640564039457584007913129639935;

    // 然后在这里使用默认地址创建了vm实例，继承Test后可以使用
    Vm internal constant vm = Vm(VM_ADDRESS);
    StdStorage internal stdstore;
}
*/

contract BankTest is Test {
    Bank public bank;

    // 会检查调用的合约是否有多个setUp()函数, 最多只能有一个
    // 也就是说每次forge test 进行合约调用时，都会检查合约abi是否包含一个setup函数，有会优先执行setup
    function setUp() public {
        bank = new Bank();
    }
    //    function setUp(uint256 a) public returns(uint256) {return a;}

    function test_Deposit() public {
        //        bank = new Bank();
        bank.depositETH{value: 1000}();
        assertEq(bank.balanceOf(address(this)), 1000);
    }

    function testFuzz_ExpectEmittedDepositEvent_topic1(address x) public {
        // start prank
        vm.deal(x, 1000000);
        vm.prank(x);
        vm.expectEmit(true, false, false, false);
        // expected event
        emit Bank.Deposit(x, 2);
        bank.depositETH{value: 1000000}();
        // end prank

        vm.deal(address(this), 1000000);
        vm.expectEmit(true, false, false, false);
        // expected event
        emit Bank.Deposit(address(this), 2);
        bank.depositETH{value: 1000000}();
    }

    function test_ExpectEmittedDepositEvent_data() public {
        vm.expectEmit(false, false, false, true);
        // expected event
        emit Bank.Deposit(address(0), 2);
        bank.depositETH{value: 2}();
    }

    function test_BalanceOf() public {
        bank.depositETH{value: 1000}();
        assertEq(bank.balanceOf(address(this)), 1000);
    }

    function testFuzz_BalanceOf(uint256 x) public {
        x = bound(x, 10, type(uint256).max);
        vm.deal(address(this), x);
        bank.depositETH{value: x / 2}();
        assertEq(bank.balanceOf(address(this)), x / 2);
    }
}
