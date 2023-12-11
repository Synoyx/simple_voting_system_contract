// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "../lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import {IVoting} from "./IVoting.i.sol";

/*
* @title A simple vote system, managed by an administrator, allowing registered users to make proposals and vote.
* @author Julien P.
*/
contract Voting is IVoting, Ownable {
    /*************************************
    *              Structs               *
    **************************************/
    struct Voter {
        bool isRegistered;
        bool hasVoted;
        uint votedProposalId;
    }

    struct Proposal {
        string description;
        uint voteCount;
    }

    enum WorkflowStatus {
        RegisteringVoters,
        ProposalsRegistrationStarted,
        ProposalsRegistrationEnded,
        VotingSessionStarted,
        VotingSessionEnded,
        VotesTallied
    }


    /*************************************
    *             Variables              *
    **************************************/

    WorkflowStatus _workflowStatus;

    mapping(address => Voter) _votersMap;
    address[] _votersWhitelist;

    mapping(uint => Proposal) _proposals;
    uint _nbProposals;

    uint _winningProposalId;

    
    /*************************************
    *              Events                *
    **************************************/

    event VoterRegistered(address voterAddress); 
    event WorkflowStatusChange(WorkflowStatus previousStatus, WorkflowStatus newStatus);
    event ProposalRegistered(uint proposalId);
    event Voted(address voter, uint proposalId);
    

    /*************************************
    *             Constructor            *
    **************************************/

    /*
    * @author Julien P.
    * @notice Starts the Ownable pattern
    */
    constructor() Ownable(msg.sender) {}
    
    
    /*************************************
    *             Modifiers              *
    **************************************/

    /*
    * @author Julien P.
    * @dev Checks if the given address belongs to the whitelist
    * @param addressToTest The address to test
    */
    modifier OnlyWhiteListedVoters(address addressToTest) {
        require(_votersMap[addressToTest].isRegistered, "You're not allowed to do that !");
        _;
    }

    /* 
    * @author Julien P.
    * @dev Checks if the current workflow status is equal to the given workflow status
    * @param status The status to compare to the current workflow status
    */
    modifier CheckStatusIsGood(WorkflowStatus status) {
        require(_workflowStatus == status, 
            string.concat("You can't do that in the current status : ", _getWorkflowStatusString()));
        _;
    }

    
    /*************************************
    *             Functions              *
    **************************************/

    /*
    * @author Julien P.
    * @dev We must let the visibility public, as the method is called internally by "registerVoters"
    * @notice
    *   Adds a voter to the list
    *   Will trigger an error if the address has already been added to the whitelist
    *   Only the contract's owner can call this method
    * @param voterAddress The address to add to the whitelist
    */
    function registerVoter(address voterAddress) public onlyOwner {
        require(voterAddress != address(0), "The given address is empty !");
        require(!_votersMap[voterAddress].isRegistered, string.concat("This address is already registered !"));

        _votersMap[voterAddress] = Voter(true, false, 0);
        _votersWhitelist.push(voterAddress);

        emit VoterRegistered(voterAddress);
    }

    /*
    * @author Julien P.
    * @notice 
    *   Adds a list of voters
    *   Will ignore the addresses already added to the whitelist, to avoir reverting the whole transaction
    *   Only the contract's owner can call this method 
    * @param votersAddresses an array of voters addresses to add to the whitelist
    */
    function registerVoters(address[] calldata votersAddresses) external onlyOwner {
        for(uint i; i < votersAddresses.length; i++) {
            if (!_votersMap[votersAddresses[i]].isRegistered) registerVoter(votersAddresses[i]);
        }
    }

    /*
    * @author Julien P.
    * @notice 
    *   Checks if the workflow status is in the right state, then start the proposal time.
    *   There must be at least one voter added in the white list to start proposal time, otherwise it's useless
    *   Only the contract's owner can call this method
    */
    function startProposalTime() external onlyOwner CheckStatusIsGood(WorkflowStatus.RegisteringVoters) {
        require(_votersWhitelist.length > 0, "You must add at least one voter to start proposal time !");

        emit WorkflowStatusChange(_workflowStatus, WorkflowStatus.ProposalsRegistrationStarted);
        _workflowStatus = WorkflowStatus.ProposalsRegistrationStarted;
    }

    /*
    * @author Julien P.
    * @notice
    *   Checks if proposals registration are started, if some proposals has been made, then stop it
    *   Only the contract's owner can call this method
    */
    function endProposalTime() external onlyOwner CheckStatusIsGood(WorkflowStatus.ProposalsRegistrationStarted) {
        require(_nbProposals > 0, "No proposal has been made yet, can't close proposal time !");

        emit WorkflowStatusChange(_workflowStatus, WorkflowStatus.ProposalsRegistrationEnded);
        _workflowStatus = WorkflowStatus.ProposalsRegistrationEnded;
    }

    /*
    * @author Julien P.
    * @notice 
    *   Checks if the workflow status is in the right state, then start the vote time
    *   Only the contract's owner can call this method
    */
    function startVoteTime() external onlyOwner CheckStatusIsGood(WorkflowStatus.ProposalsRegistrationEnded) {
        emit WorkflowStatusChange(_workflowStatus, WorkflowStatus.VotingSessionStarted);
        _workflowStatus = WorkflowStatus.VotingSessionStarted;
    }

    /*
    * @author Julien P.
    * @notice 
    *   Checks if the vote time is started, then stop it
    *   Only the contract's owner can call this method
    */
    function endVoteTime() external onlyOwner CheckStatusIsGood(WorkflowStatus.VotingSessionStarted) {
        emit WorkflowStatusChange(_workflowStatus, WorkflowStatus.VotingSessionEnded);
        _workflowStatus = WorkflowStatus.VotingSessionEnded;
    }
    
    /*
    * @author Julien P.
    * @notice 
    *   Compute the winning proposal from voters, and change the workflow status
    *   If there hasn't been any vote, or a tie vote, the last one on the list will be considered as the winning one
    *   Only the contract's owner can call this method
    * @dev We return the winning proposal id for testing purpose
    */
    function computeWinningProposal() external onlyOwner CheckStatusIsGood(WorkflowStatus.VotingSessionEnded) returns (uint) {
        // We start at 1 as, in this case, the id range goes from 1 to _nbProposals
        for (uint i = 1; i <= _nbProposals; i++) {
            // We use >= condition here to ensure that the default proposal defined before will be replaced
            if (_proposals[i].voteCount >= _proposals[_winningProposalId].voteCount) {
                _winningProposalId = i;
            }
        }
        

        // We set the status to "VotesTallied", to make the method "getWinner()" be able to work.
        emit WorkflowStatusChange(_workflowStatus, WorkflowStatus.VotesTallied);
        _workflowStatus = WorkflowStatus.VotesTallied;

        return _winningProposalId;
    }

    /*
    * @author Julien P.
    * @notice 
    *   Allows whitelisted users to make proposal, when the proposal registration is open, and if the given proposal isn't empty
    *   Only whitelisted voters can make a proposal
    * @param proposal The voter's proposal
    */
    function makeProposal(string calldata proposal) external OnlyWhiteListedVoters(msg.sender) {        
        require(_workflowStatus == WorkflowStatus.ProposalsRegistrationStarted, "The proposal time is over, you can't give your proposal anymore");
        require(bytes(proposal).length > 0, "Your proposal is empty !");

        // Incrementing proposals numbers / id & storing the proposal, starting with id 1
        _proposals[++_nbProposals] = Proposal(proposal, 0);


        emit ProposalRegistered(_nbProposals);
    }

    /*
    * @author Julien P.
    * @notice 
    *   Allows whitelisted users to vote, when voting time is active, and if he has'nt already voted
    *   Proposal ids goes from 1 to 2^256.
    *   You can use the method 'showProposals()' to get the list of all proposals and their ids
    *   Only whitelisted voters can make a vote
    * @param proposalId The voter's proposal id vote
    */
    function vote(uint proposalId) external OnlyWhiteListedVoters(msg.sender) {
        require(_workflowStatus == WorkflowStatus.VotingSessionStarted, "It's not vote time, you can't vote");
        require(!_votersMap[msg.sender].hasVoted, "You have already voted");
        require(proposalId > 0 && proposalId <= _nbProposals, "The given proposal id doesn't exists");

        _proposals[proposalId].voteCount += 1;

        _votersMap[msg.sender].votedProposalId = proposalId;
        _votersMap[msg.sender].hasVoted = true;
        
        emit Voted(msg.sender, proposalId);
    }

    /*
    * @author Julien P.
    * @notice 
    *   Returns the voted proposal, if the votes have been tallied
    *   We return the winning proposal as a displayable string, as there is no front-end
    * @return   string    The winning proposal
    */
    function getWinner() external view CheckStatusIsGood(WorkflowStatus.VotesTallied) returns (string memory) {
        return _getProposalString(_proposals[_winningProposalId], _winningProposalId);
    }

    /*
    * @author Julien P.
    * @notice 
    *   Allows registered voters to show all proposals
    *   Only whitelisted voters can show all proposals
    * @return   string[]  A well formated list of proposal ids and their description
    */
    function showProposals() external view OnlyWhiteListedVoters(msg.sender) returns (string[] memory) {
        string[] memory result = new string[](_nbProposals);

        for (uint i = 1; i <= _nbProposals; i++) {
            result[i - 1] = _getProposalString(_proposals[i], i);
        }

        return result;
    }

    /*
    * @author Julien P.
    * @notice 
    *   Allows registered voters to show votes status
    *   Only whitelisted voters can show current votes
    * @return   string[]    A well formated list of each voter and his proposal ID vote
    */
    function showCurrentVotes() external view OnlyWhiteListedVoters(msg.sender) returns (string[] memory) {
        string[] memory result = new string[](_votersWhitelist.length);

        for (uint i; i < _votersWhitelist.length; i++) {
            result[i] = _getVoterString(_votersMap[_votersWhitelist[i]], _votersWhitelist[i]);
        }

        return result;
    }
    
    /*
    * @author Julien P.
    * @notice 
    *   Get a voter by his address
    *   Trigger an error if this address isn't registered
    * @return   String The voter corresponding to the given address
    */
    function getVoter(address voterAddress) external view returns (string memory) {
        Voter memory voter = _votersMap[voterAddress];
        
        // If 'isRegistered' is false, it means that it's a default value returned, and that there is no voter with this address
        require(voter.isRegistered, "There is no registered voter with this address !");

        return _getVoterString(voter, voterAddress);
    }

    
    /*
    * @author Julien P.
    * @notice 
    *   Get a proposal by her id
    *   Trigger an error if there is no proposal with this id
    * @return   String  The proposal with the given id
    */
    function getProposal(uint proposalId) external view returns (string memory) {
        Proposal memory proposal = _proposals[proposalId];

        // If found proposal description is empty, it means that it's a default value returned, and that there is no proposal with this id
        require(bytes(proposal.description).length > 0, "There is no proposal with this id !");

        return _getProposalString(proposal, proposalId);
    }

    

    /*************************************
    *         Utility functions          *
    **************************************/

    /*
    * @author Julien P.
    * @dev Used to convert enum value to displayable string for logging purpose
    * @return   string  The displayable text corresponding to the current workflow status
    */
    function _getWorkflowStatusString() internal view returns (string memory) {
        if (_workflowStatus == WorkflowStatus.RegisteringVoters) return "Registering voters";
        if (_workflowStatus == WorkflowStatus.ProposalsRegistrationStarted) return "Proposals registration started";
        if (_workflowStatus == WorkflowStatus.ProposalsRegistrationEnded) return "Proposals registration ended";
        if (_workflowStatus == WorkflowStatus.VotingSessionStarted) return "Voting session started";
        if (_workflowStatus == WorkflowStatus.VotingSessionEnded) return "Voting session ended";
        if (_workflowStatus == WorkflowStatus.VotesTallied) return "Votes tallied";

        return "Error while cast status to string";
    }

    /*
    * @author Julien P.
    * @dev Used to convert a proposal to displayable string
    * @param
    *   Proposal    The proposal to convert
    *   uint    The proposal id
    * @return   string  The proposal in a displayable string
    */
    function _getProposalString(Proposal memory proposal, uint proposalId) internal pure returns (string memory) {
        return string.concat(
                "Proposal id : ", Strings.toString(proposalId), 
                " || proposal description : ", proposal.description);
    }

    /*
    * @author Julien P.
    * @dev Used to convert a voter to displayable string
    * @param    Voter    The voter to convert
    * @return   string  The voter in a displayable string
    */
    function _getVoterString(Voter memory voter, address voterAddress) internal pure returns (string memory) {
        return string.concat(
                "Voter : ", Strings.toHexString(uint256(uint160(voterAddress)), 20), 
                " || proposal id voted : ", 
                // If the voted proposal id equals 0, it means that the user hasn't vote
                voter.hasVoted ? Strings.toString(voter.votedProposalId) : "hasn't voted");
    }

    /*
    * @author Julien P.
    * @dev Used for testing purpose
    * @return   address  The owner's address
    */
    function getOwner() external view returns (address) {
        return owner();
    }
}