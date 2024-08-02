// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Test.sol";
import { Pool } from "../src/Pool.sol";

contract PoolTest is Test {

	address owner = makeAddr("user0");
	address addr1 = makeAddr("user1");
	address addr2 = makeAddr("user2");
	address addr3 = makeAddr("user3");

	uint256 duration = 4 weeks; // timestamp 
	uint256 goal = 10 ether;

	Pool pool; // contract a tester

	// beforeach
	function setUp() public {
		// la prochaine actioon est realisee par le parametre owner passe 
		vm.prank(owner);
		pool = new Pool(duration, goal);
	}

	// Deployment
	function test_ContractDeployedSuccessfully() public {
		// on verifie que l owner est bien le sender du msg de creation 
		address  _owner = pool.owner();
		assertEq(owner, _owner);

		uint256 _end = pool.end(); // public var = automatic getter with the same name
		assertEq(block.timestamp + duration, _end);

		uint256 _goal = pool.goal();
		assertEq(goal, _goal);
	}

	// Contribute 
	/// on va du haut vers le bas 
	function test_revertWhen_EndIsReached() public {
		// foundry function changing the current timestamp of the vm (moving fast to reach end)
		vm.warp(pool.end() + 3600);

		// on recupere le selecteur de la custom error. 
		bytes4 selector = bytes4 (keccak256("CollectIsFinished()"));

		// on s'attend à l'erreur
		vm.expectRevert(abi.encodeWithSelector(selector));

		vm.prank(addr1);
		// par défaut, une address n'a pas d'argent sur son compte
		vm.deal(addr1, 1 ether);
		pool.contribute{value: 1 ether}();
	}

	function test_revertWhen_NotEnoughFunds() public {
		bytes4 selector = bytes4 (keccak256("NotEnoughFunds()"));

		vm.expectRevert(abi.encodeWithSelector(selector));

		vm.prank(addr1);
		pool.contribute();  // ne passe pas d argent
	}

	// test de l'emission d event 
	function test_ExpectEmit_SuccessfullContribute(uint96 _amount) public { // un param a une fonction de test de foundry est aleatoire
		// fuzzing 
		vm.assume(_amount > 0);
		vm.expectEmit(true, false, false, true); // un topic pour un event est un param en mode index. On peut en avoir jusqu'a 3 par event. Ici on a que l'address en indexed
		emit Pool.Contribute(address(addr1), _amount);

		vm.prank(addr1);
		vm.deal(addr1, _amount);
		pool.contribute{value: _amount}();
	}

	// verifier que l address est bien ajouté au mapping quand il contribute
	function test_ContributorMappedSuccessfully() public {
		vm.prank(addr1);
		vm.deal(addr1, 1 ether);
		pool.contribute{value: 0.5 ether}();

		uint256 contribution = pool.contributions(addr1);
	    	assertEq(contribution, 0.5 ether);
	}


	// Withdraw

	function test_RevertWhen_NotTheOwner() public {
		// on va chercher la def de la custom error faite par openzeppelin
		bytes4 selector = bytes4 (keccak256("OwnableUnauthorizedAccount(address)"));

		vm.expectRevert(abi.encodeWithSelector(selector, addr1));
		vm.prank(addr1);
		pool.withdraw();
	}

	function test_RevertWhen_EndIsNotReached() public {
		bytes4 selector = bytes4 (keccak256("CollectNotFinished()"));
		vm.expectRevert(abi.encodeWithSelector(selector));

		vm.prank(owner);
		pool.withdraw();
	}

	function test_RevertWhen_GoalIsNotReached() public {
		vm.prank(addr1);
		vm.deal(addr1, 5 ether);
		pool.contribute{value: 5 ether}();

		vm.warp(pool.end() + 3600);

		bytes4 selector = bytes4 (keccak256("CollectNotFinished()"));
		vm.expectRevert(abi.encodeWithSelector(selector));
		
		vm.prank(owner);
		pool.withdraw();
	}
	
	// le contract de test est propriétaire de la pool et n a pas de receive ni de fallback  donc nv deploiement
	function test_RevertWhen_WithdrawFailedToSendEther() public {
		pool = new Pool(duration, goal);
		
		vm.prank(addr1);
		vm.deal(addr1, 6 ether);
		pool.contribute{value: 6 ether}();
		
		vm.prank(addr2);
		vm.deal(addr2, 6 ether);
		pool.contribute{value: 6 ether}();

		vm.warp(pool.end() + 3600);
		bytes4 selector = bytes4 (keccak256("FailedToSendEther()"));
		vm.expectRevert(abi.encodeWithSelector(selector));

		pool.withdraw();

	}	

	function test_Withdraw() public {
		vm.prank(addr1);
		vm.deal(addr1, 6 ether);
		pool.contribute{value: 6 ether}();
		
		vm.prank(addr2);
		vm.deal(addr2, 6 ether);
		pool.contribute{value: 6 ether}();

		vm.warp(pool.end() + 3600);

		vm.prank(owner);
		pool.withdraw();

	}

	// Refund
	function test_RevertWhen_CollectNotFinished() public {
		vm.prank(addr1);
		vm.deal(addr1, 6 ether);
		pool.contribute{value: 6 ether}();
		
		vm.prank(addr2);
		vm.deal(addr2, 6 ether);
		pool.contribute{value: 6 ether}();

		bytes4 selector = bytes4 (keccak256("CollectNotFinished()"));
		vm.expectRevert(abi.encodeWithSelector(selector));

		vm.prank(addr1);
		pool.refund();
	}

	function test_RevertWhen_GoalAlreadyReached() public {
		vm.prank(addr1);
		vm.deal(addr1, 6 ether);
		pool.contribute{value: 6 ether}();
		
		vm.prank(addr2);
		vm.deal(addr2, 6 ether);
		pool.contribute{value: 6 ether}();

		vm.warp(pool.end() + 3600);

		bytes4 selector = bytes4 (keccak256("GoalAlreadyReached()"));
		vm.expectRevert(abi.encodeWithSelector(selector));

		pool.refund();
	}

	function test_RevertWhen_NoContribution() public {
		vm.prank(addr1);
		vm.deal(addr1, 6 ether);
		pool.contribute{value: 6 ether}();
		
		vm.prank(addr2);
		vm.deal(addr2, 6 ether);
		pool.contribute{value: 1 ether}();

		vm.warp(pool.end() + 3600);

		bytes4 selector = bytes4 (keccak256("NoContribution()"));
		vm.expectRevert(abi.encodeWithSelector(selector));

		vm.prank(addr3);
		pool.refund();
	}


	function test_RevertWhen_RefundFailedToSendEther() public {
		vm.deal(address(this), 2 ether);
		pool.contribute{value: 2 ether}();

		vm.prank(addr1);
		vm.deal(addr1, 5 ether);
		pool.contribute{value: 5 ether}();

		vm.warp(pool.end() + 3600);

		bytes4 selector = bytes4(keccak256("FailedToSendEther()"));
		vm.expectRevert(abi.encodeWithSelector(selector));

		// exec par le contract de test qui n a ni receive ni fallback donc devrait revert
		pool.refund();
	}
	
	function test_Refund() public {
		pool = new Pool(duration, goal);
	        
		vm.prank(addr1);
		vm.deal(addr1, 6 ether);
		pool.contribute{value: 6 ether}();
		
		vm.prank(addr2);
		vm.deal(addr2, 6 ether);
		pool.contribute{value: 1 ether}();

		vm.warp(pool.end() + 3600);
		uint256 balanceBefore = address(addr2).balance;

		vm.prank(addr2);
		pool.refund();


		uint256 balanceAfter = address(addr2).balance;
		assertEq(balanceAfter - balanceBefore, 1 ether);
	}

}
