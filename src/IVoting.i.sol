// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

/*
* @author Julien P.
* @dev 
*   This interface is primaraly used for testing purpose.
*   It allows me to run the same test code on both Voting and Voting plus contracts,
*   making gas consumption comparison more realistic, and allow me to use the same
*   unit test for both contracts.
*/
interface IVoting {
    function getOwner() external view returns (address);
    function registerVoter(address voterAddress) external;
    function registerVoters(address[] calldata votersAddresses) external;
    function startProposalTime() external;
    function endProposalTime() external;
    function startVoteTime() external;
    function endVoteTime() external;
    function makeProposal(string calldata proposal) external;
    function vote(uint proposalId) external;
    function computeWinningProposal() external returns (uint);
    function getWinner() external view returns (string memory);
    function showProposals() external view returns (string[] memory);
    function showCurrentVotes() external view returns (string[] memory);
    function getVoter(address voterAddress) external view returns (string memory);
    function getProposal(uint proposalId) external view returns (string memory);
}