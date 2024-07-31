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

	function test_ContractDeployedSuccessfully() public {
		// on verifie que l owner est bien le sender du msg de creation 
		address  _owner = pool.owner();
		assertEq(owner, _owner);

		uint256 _end = pool.end(); // public var = automatic getter with the same name
		assertEq(block.timestamp + duration, _end);

		uint256 _goal = pool.goal();
		assertEq(goal, _goal);
	}
}
