// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import {Test} from "../lib/forge-std/src/Test.sol";
import "../src/Voting.sol";

contract VotingTest is Test {
    IVoting voting;
    
    address[] testAddresses = [0x9ea8922155a5cDd356Be601a2A22192CB97658d1, 0xCe6AA299dF03A62de7CAf9B3c7e05574f0ebDA4C];

    function initVoting() internal virtual {
      voting = new Voting();
    }

    function testGasConsumptionScenario() public {
      initVoting();

      voting.registerVoters(testAddresses);
      voting.registerVoter(voting.getOwner());
      voting.startProposalTime();
      voting.makeProposal("First proposal");
      voting.makeProposal("Second proposal");
      voting.endProposalTime();
      voting.startVoteTime();
      voting.vote(1);
      vm.prank(0x9ea8922155a5cDd356Be601a2A22192CB97658d1);
      voting.vote(1);
      vm.prank(0xCe6AA299dF03A62de7CAf9B3c7e05574f0ebDA4C);
      voting.vote(1);
      voting.showCurrentVotes();
      voting.showProposals();
      voting.getVoter(voting.getOwner());
      voting.getProposal(1);
      vm.prank(voting.getOwner());
      voting.endVoteTime();
      computeWinner();
      voting.getWinner();
  }

  function computeWinner() internal virtual {
      voting.computeWinningProposal();
  }

  function testAddingSingleVoterEmptyAddress() public {
    initVoting();
    vm.expectRevert();
    voting.registerVoter(address(0));
  }
  
  function testAddingSingleVoter() public {
    initVoting();
    voting.registerVoter(voting.getOwner());
    assertGt(bytes(voting.getVoter(voting.getOwner())).length, 30);
  }

  function testAddAlreadyRegistredVoter() public {
    initVoting();
    voting.registerVoter(testAddresses[0]);

    vm.expectRevert();
    voting.registerVoter(testAddresses[0]);
  }

  function testAddVoterWithoutBeingOwner() public {
    initVoting();
    vm.prank(testAddresses[0]);


    vm.expectRevert();
    voting.registerVoter(testAddresses[1]);
  }

  function testAddMultipleValidAddresses() public {
    initVoting();
    voting.registerVoters(testAddresses);
    vm.prank(testAddresses[0]);
    assertEq(voting.showCurrentVotes().length, 2);
  }

  function testAddMultipleAddressesWithEmptyArray() public {
    initVoting();

    address[] memory emptyAddressesArray = new address[](0);

    
    //We need to register our address to be able to call the method shwo currentVotes()
    voting.registerVoter(voting.getOwner());
    assertEq(voting.showCurrentVotes().length, 1);

    voting.registerVoters(emptyAddressesArray);
    
    assertEq(voting.showCurrentVotes().length, 1);
  }

  function testAddMultipleSameAddress() public {
    initVoting();

    address[] memory sameAddressesArray = new address[](2);
    sameAddressesArray[0] = testAddresses[0];
    sameAddressesArray[1] = testAddresses[0];

    voting.registerVoters(sameAddressesArray);

    vm.prank(testAddresses[0]);

    assertEq(voting.showCurrentVotes().length, 1);
  }

  function testAddMultipleVotersWithoutBeingOwner() public {
    initVoting();

    address[] memory emptyAddressesArray = new address[](0);
    vm.prank(testAddresses[0]);

    vm.expectRevert();
    voting.registerVoters(emptyAddressesArray);
  }

  function testStartProposalTimeWithoutBeingOwner() public {
    initVoting();

    vm.prank(testAddresses[0]);

    vm.expectRevert();
    voting.startProposalTime();
  }

  function testStartProposalTimeWithoutBeingInGoodStatus() public {
    initVoting();

    voting.registerVoter(voting.getOwner());
    voting.startProposalTime();

    vm.expectRevert();
    voting.startProposalTime();
  }

  function testEndProposalTimeWithoutBeingOwner() public {
    initVoting();

    voting.registerVoter(voting.getOwner());
    voting.startProposalTime();
    voting.makeProposal("ProposalTest");

    vm.prank(testAddresses[0]);
    voting.endProposalTime;
  }

  function testEndProposalTimeWithoutBeingInGoodStatus() public {
    initVoting();

    vm.expectRevert();
    voting.endProposalTime();
  }

  function testStartVoteTimeWithoutBeingOwner() public {
    initVoting();

    voting.registerVoter(voting.getOwner());
    voting.startProposalTime();
    voting.makeProposal("ProposalTest");
    voting.endProposalTime();

    vm.prank(testAddresses[0]);

    vm.expectRevert();
    voting.startVoteTime();
  }

  function testStartVoteTimeWithoutBeingInGoodStatus() public {
    initVoting();

    vm.expectRevert();
    voting.startVoteTime();
  }

  function testEndVoteTimeWithoutBeingOwner() public {
    initVoting();

    voting.registerVoter(voting.getOwner());
    voting.startProposalTime();
    voting.makeProposal("ProposalTest");
    voting.endProposalTime();
    voting.startVoteTime();
    voting.vote(1);
    
    vm.prank(testAddresses[0]);

    vm.expectRevert();
    voting.endVoteTime();
  }

  function testEndVoteTimeWithoutBeingInGoodStatus() public {
    initVoting();

    vm.expectRevert();
    voting.endVoteTime();
  }

  function testComputeWinningProposalWithoutBeingOwner() public {
    initVoting();

    voting.registerVoter(voting.getOwner());
    voting.startProposalTime();
    voting.makeProposal("ProposalTest");
    voting.endProposalTime();
    voting.startVoteTime();
    voting.vote(1);
    voting.endVoteTime();
    
    vm.prank(testAddresses[0]);

    vm.expectRevert();
    voting.computeWinningProposal();
  }

  function testComputeWinningProposalWithoutBeingInGoodStatus() public {
    initVoting();

    vm.expectRevert();
    voting.computeWinningProposal();
  }
  
  function testComputeWinningProposal() public virtual {
    initVoting();

    voting.registerVoter(voting.getOwner());
    voting.registerVoters(testAddresses);
    voting.startProposalTime();
    voting.makeProposal("ProposalTest 1");
    voting.makeProposal("ProposalTest 2");
    voting.endProposalTime();
    voting.startVoteTime();
    voting.vote(1);
    vm.prank(testAddresses[0]);
    voting.vote(1);
    vm.prank(testAddresses[1]);
    voting.vote(2);
    vm.prank(voting.getOwner());
    voting.endVoteTime();

    assertEq(voting.computeWinningProposal(), 1);
  }

  function testMakeProposalWithoutBeingRegistered() public {
    initVoting();

    // We register an address to be able to start proposalTime
    // This is not the address used for makeProposal call
    voting.registerVoter(testAddresses[1]);
    voting.startProposalTime();

    vm.expectRevert();
    voting.makeProposal("ProposalTest 1");
  }

  function testMakeProposalWithoutBeingInGoodStatus() public {
    initVoting();
    voting.registerVoter(voting.getOwner());

    vm.expectRevert();
    voting.makeProposal("Proposal Test 1");
  }

  function testMakeProposalWithEmptyString() public {
    initVoting();

    voting.registerVoter(voting.getOwner());
    voting.startProposalTime();

    vm.expectRevert();
    voting.makeProposal("");
  }

  

  function testMakeProposal() public virtual {
    initVoting();

    voting.registerVoter(voting.getOwner());
    voting.startProposalTime();

    assertEq(voting.showProposals().length, 0);

    voting.makeProposal("Proposal Test 1");

    assertEq(voting.showProposals().length, 1);
  }

  function testVoteWithoutBeingGoodStatus() public {
    initVoting();
    voting.registerVoter(voting.getOwner());
    
    vm.expectRevert();
    voting.vote(1);
  }

  function testVoteWithoutBeingRegistered() public {
    initVoting();

    // We register an address to be able to start proposalTime
    // This is not the address used for makeProposal call
    voting.registerVoter(voting.getOwner());
    voting.startProposalTime();
    voting.makeProposal("ProposalTest 1");
    voting.endProposalTime();
    voting.startVoteTime();

    vm.prank(testAddresses[0]);
    vm.expectRevert();
    voting.vote(1);
  }
  
  function testVoteWithUnexistingId() public {
    initVoting();

    voting.registerVoter(voting.getOwner());
    voting.startProposalTime();
    voting.makeProposal("ProposalTest 1");
    voting.endProposalTime();
    voting.startVoteTime();

    vm.expectRevert();
    voting.vote(2);
  }

  function testVoteTwice() public {
    initVoting();
    
    voting.registerVoter(voting.getOwner());
    voting.startProposalTime();
    voting.makeProposal("ProposalTest 1");
    voting.endProposalTime();
    voting.startVoteTime();
    voting.vote(1);

    vm.expectRevert();
    voting.vote(1);
  }
  
  function testVote() public {
    initVoting();
    
    voting.registerVoter(voting.getOwner());
    voting.startProposalTime();
    voting.makeProposal("ProposalTest 1");
    voting.endProposalTime();
    voting.startVoteTime();

    // Without vote, should display "hasn't voted"
    assertEq(voting.showCurrentVotes()[0], string.concat("Voter : ", Strings.toHexString(uint256(uint160(voting.getOwner())), 20), 
                " || proposal id voted : hasn't voted"));

    voting.vote(1);

    assertEq(voting.showCurrentVotes()[0], string.concat("Voter : ", Strings.toHexString(uint256(uint160(voting.getOwner())), 20), 
                " || proposal id voted : 1"));
  }

  function testGetWinnerWithoutBeingGoodStatus() public {
    initVoting();

    vm.expectRevert();
    voting.getWinner();
  }

  function testGetWinner() public {
    initVoting();
    
    voting.registerVoter(voting.getOwner());
    voting.startProposalTime();
    voting.makeProposal("ProposalTest 1");
    voting.makeProposal("ProposalTest 2");
    voting.endProposalTime();
    voting.startVoteTime();
    voting.vote(1);
    voting.endVoteTime();
    computeWinner();

    assertEq(voting.getWinner(), string.concat("Proposal id : 1 || proposal description : ProposalTest 1"));
  }

  function testShowProposalsWithoutBeingRegistered() public {
    initVoting();

    vm.expectRevert();
    voting.showProposals();
  }

  function testShowProposals() public virtual {
    initVoting();

    voting.registerVoter(voting.getOwner());
    
    assertEq(voting.showProposals().length, 0);

    voting.startProposalTime();
    voting.makeProposal("ProposalTest 1");
    voting.makeProposal("ProposalTest 2");
    
    assertEq(voting.showProposals().length, 2);
  }

  function testShowCurrentVotesWithoutBeingRegistered() public {
    initVoting();

    vm.expectRevert();
    voting.showCurrentVotes();
  }

  function testShowcurrentVotes() public {
    initVoting();

    voting.registerVoter(voting.getOwner());

    assertEq(voting.showCurrentVotes().length, 1);

    voting.registerVoters(testAddresses);

    assertEq(voting.showCurrentVotes().length, 3);
  }

  function testGetVoterWithUnregisteredAddress() public {
    initVoting();

    vm.expectRevert();
    voting.getVoter(testAddresses[0]);
  }

  function testGetVoter() public {
    initVoting();

    voting.registerVoter(voting.getOwner());

    assertEq(voting.getVoter(voting.getOwner()), string.concat("Voter : ", Strings.toHexString(uint256(uint160(voting.getOwner())), 20), 
                " || proposal id voted : hasn't voted"));
  }

  function testGetProposalWithInvalidId() public {
    initVoting();

    vm.expectRevert();
    voting.getProposal(1);
  }

  function testGetProposal() public {
    initVoting();

    voting.registerVoter(voting.getOwner());
    voting.startProposalTime();
    voting.makeProposal("Proposal test 1");

    assertEq(voting.getProposal(1), "Proposal id : 1 || proposal description : Proposal test 1");
  }
}