pragma solidity ^0.8.10;

import "../lib/Deployer.sol";

contract RelayerHubTest is Deployer {
    event relayerRegister(address _relayer);
    event relayerUnRegister(address _relayer);
    event paramChange(string key, bytes value);
    event updateRelayerEvent(address _from, address _to);
    event removeManagerByGovEvent(address _manager);

    uint256 public requiredDeposit;
    uint256 public dues;

    function setUp() public {
        requiredDeposit = relayerHub.requiredDeposit();
        dues = relayerHub.dues();
    }

    // new relayer register is suspended
    function testRegister() public {
        address newRelayer = addrSet[addrIdx++];
        vm.prank(newRelayer, newRelayer);
        vm.expectRevert(bytes("register suspended"));
        relayerHub.register{value : 100 ether}();
    }

    function testAddManager() public {
        RelayerHub newRelayerHub = helperGetNewRelayerHub();

        bytes memory keyAddManager = "addManager";
        address manager = payable(addrSet[addrIdx++]);
        address newRelayer = payable(addrSet[addrIdx++]);
        bytes memory valueManagerBytes = abi.encodePacked(bytes20(uint160(manager)));
        require(valueManagerBytes.length == 20, "length of manager address mismatch in tests");

        updateParamByGovHub(keyAddManager, valueManagerBytes, address(newRelayerHub));

        // check if manager is there and can add a relayer
        vm.prank(manager, manager);
        vm.expectEmit(true, true, false, true);
        emit updateRelayerEvent(payable(address(0)), newRelayer);
        newRelayerHub.registerManagerAddRelayer(newRelayer);

        // do illegal call
        vm.prank(newRelayer, newRelayer);
        vm.expectRevert(bytes("manager does not exist"));
        newRelayerHub.registerManagerAddRelayer(manager);

        // check if relayer is added
        bool isRelayerTrue = newRelayerHub.isRelayer(newRelayer);
        assertTrue(isRelayerTrue);

        // check if manager is added
        bool isManagerTrue = newRelayerHub.isManager(manager);
        assertTrue(isManagerTrue);

        // remove manager test i.e. for removeManager()
        bytes memory keyRemoveManager = "removeManager";
        vm.expectEmit(true, true, false, true);
        emit removeManagerByGovEvent(manager);
        updateParamByGovHub(keyRemoveManager, valueManagerBytes, address(newRelayerHub));

        // check if relayer got removed
        bool isRelayerFalse = newRelayerHub.isRelayer(newRelayer);
        assertFalse(isRelayerFalse);

        // check if manager got removed
        bool isManagerFalse = newRelayerHub.isManager(manager);
        assertFalse(isManagerFalse);

        // check if the manager can remove himself
        updateParamByGovHub(keyAddManager, valueManagerBytes, address(newRelayerHub));
        vm.prank(manager, manager);
        newRelayerHub.removeManagerByHimself();
    }

    // this checks if the previously existing unregister() function can support safe exit for existing relayers after hardfork
    // this indirectly tests whether update() was called or not
    function testunregister() public {
        RelayerHub newRelayerHub = helperGetNewRelayerHub();

        address existingRelayer1 = 0xb005741528b86F5952469d80A8614591E3c5B632;
        vm.prank(existingRelayer1, existingRelayer1);
        newRelayerHub.unregister();

        address existingRelayer2 = 0x446AA6E0DC65690403dF3F127750da1322941F3e;
        vm.prank(existingRelayer2, existingRelayer2);
        newRelayerHub.unregister();

        address nonExistingRelayer = 0x9fB29AAc15b9A4B7F17c3385939b007540f4d791;
        vm.prank(nonExistingRelayer, nonExistingRelayer);
        vm.expectRevert(bytes("relayer do not exist"));
        newRelayerHub.unregister();
    }

    // helperGetNewRelayerHub() deploys the new RelayerHub into the existing mainnet data so that we can test
    //  data compatibility
    function helperGetNewRelayerHub() internal returns (RelayerHub) {
        RelayerHub newRelayerHub;

        bytes memory relayerCode = vm.getDeployedCode("RelayerHub.sol");
        vm.etch(RELAYERHUB_CONTRACT_ADDR, relayerCode);
        newRelayerHub = RelayerHub(RELAYERHUB_CONTRACT_ADDR);

        return newRelayerHub;
    }

    //  function testCannotRegister() public {
    //    address newRelayer = addrSet[addrIdx++];
    //    vm.startPrank(newRelayer, newRelayer);
    //    relayerHub.register{value: 100 ether}();
    //
    //    // re-register
    //    vm.expectRevert(bytes("relayer already exist"));
    //    relayerHub.register{value: 100 ether}();
    //
    //    relayerHub.unregister();
    //    // re-unregister
    //    vm.expectRevert(bytes("relayer do not exist"));
    //    relayerHub.unregister();
    //
    //    vm.stopPrank();
    //    newRelayer = addrSet[addrIdx++];
    //    vm.startPrank(newRelayer, newRelayer);
    //
    //    // send 200 ether
    //    vm.expectRevert(bytes("deposit value is not exactly the same"));
    //    relayerHub.register{value: 200 ether}();
    //
    //    // send 10 ether
    //    vm.expectRevert(bytes("deposit value is not exactly the same"));
    //    relayerHub.register{value: 10 ether}();
    //  }
}
