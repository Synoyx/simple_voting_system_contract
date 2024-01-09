// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import {Test} from "../lib/forge-std/src/Test.sol";
import "../src/Voting_plus.sol";
import "./Voting.t.sol";

contract VotingPlusTest is VotingTest {
  function initVoting() internal override {
    voting = new VotingPlus();
  }

  
  /*
  * @author Julien P.
  * @dev In voting plus, endVoteTime() automatically launch computeWinningProposal()
  */
  function computeWinner() internal override {
    // Do nothing
  }

  /*
  * @author Julien P.
  * @dev In voting plus, endVoteTime() automatically launch computeWinningProposal()
  */
  function testComputeWinningProposal() public override {
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
  }

  /*
  * @author Julien P.
  * @dev In voting plus, showProposals() returns an additionary line for blank votes, so we expert an array of 2 elements
  */
  function testMakeProposal() public override {
    initVoting();

    voting.registerVoter(voting.getOwner());
    voting.startProposalTime();

    assertEq(voting.showProposals().length, 1);

    voting.makeProposal("Proposal Test 1");

    assertEq(voting.showProposals().length, 2);
  }

  /*
  * @author Julien P.
  * @dev In voting plus, showProposals() returns an additionary line for blank votes, so we expert an array of 2 elements
  */
  function testShowProposals() public override {
    initVoting();

    voting.registerVoter(voting.getOwner());
    
    assertEq(voting.showProposals().length, 1);

    voting.startProposalTime();
    voting.makeProposal("ProposalTest 1");
    voting.makeProposal("ProposalTest 2");
    
    assertEq(voting.showProposals().length, 3);
  }
}