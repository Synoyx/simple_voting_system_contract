// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import "../lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import {console} from "../lib/forge-std/src/console.sol";
import {IVoting} from "./IVoting.i.sol";

/*
* @title A simple vote system, managed by an administrator, allowing registered users to make proposals and vote.
* @author Julien P.
*/
contract VotingPlus is IVoting {
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
        uint lastVoteTimestamp;
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
    
    address private immutable _owner = msg.sender;
    bool _forceEndVoteTimeUnlocked;

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
    *              Events                *
    **************************************/
    
    error NotOwner();
    error Unauthorized();
    error WrongStatus();
    error EmptyAddress();
    error AddressAlreadyRegistered();
    error EmptyVotersList();
    error EmptyProposalsList();
    error ForceEndVoteIsntUnlocked();
    error StringIsEmpty();
    error ProposalIdIsntValid();
    error HasAlreadyVoted();
    error VoterNotRegistered();
    
    
    /*************************************
    *             Modifiers              *
    **************************************/

    /*
    * @author Julien P.
    * @dev Checks if the given address is the owner of the contract
    * @param addressToTest The address to test
    */
    modifier OnlyOwner(address addressToTest) {
        if(_owner != addressToTest) revert NotOwner();
        _;
    }

    /*
    * @author Julien P.
    * @dev Checks if the given address belongs to the whitelist
    * @param addressToTest The address to test
    */
    modifier OnlyWhiteListedVoters(address addressToTest) {
        if(!_votersMap[addressToTest].isRegistered) revert Unauthorized();
        _;
    }

    /* 
    * @author Julien P.
    * @dev Checks if the current workflow status is equal to the given workflow status
    * @param status The status to compare to the current workflow status
    */
    modifier CheckStatusIsGood(WorkflowStatus status) {
        if(_workflowStatus != status) revert WrongStatus();
        _;
    }

    /* 
    * @author Julien P.
    * @dev Checks if the given address isn't empty
    * @param address The address to test
    */
    modifier CheckAddressNotEmpty(address addressToTest) {
        if (addressToTest == address(0)) revert EmptyAddress();
        _;
    }

    /* 
    * @author Julien P.
    * @dev Checks if the given address isn't already registered
    * @param address The address to test
    */
    modifier CheckAddressNotRegistered(address addressToTest) {
        if (_votersMap[addressToTest].isRegistered) revert AddressAlreadyRegistered();
        _;
    }

    /* 
    * @author Julien P.
    * @dev Checks if there are registered voters
    */
    modifier CheckVotersListIsntEmpty() {
        if (_votersWhitelist.length == 0) revert EmptyVotersList();
        _;
    }

    /* 
    * @author Julien P.
    * @dev Checks if there are proposals
    */
    modifier CheckProposalsListIsntEmpty() {
        if (_nbProposals == 0) revert EmptyProposalsList();
        _;
    }

    /* 
    * @author Julien P.
    * @dev Checks if force end vote is unlocked
    */
    modifier CheckForceEndVoteUnlocked() {
        if (!_forceEndVoteTimeUnlocked) revert ForceEndVoteIsntUnlocked();
        _;
    }

    /* 
    * @author Julien P.
    * @dev Checks if given string isn't empty
    * @param    string  The string to test
    */
    modifier CheckStringIsntEmpty(string calldata stringToTest) {
        if (bytes(stringToTest).length == 0) revert StringIsEmpty();
        _;
    }

    /* 
    * @author Julien P.
    * @dev Checks if given proposal id is valid
    * @param    uint  The proposal id to test
    */
    modifier CheckProposalIdIsValid(uint proposalId) {
        if (!(proposalId >= 0 && proposalId <= _nbProposals)) revert ProposalIdIsntValid();
        _;
    }

    /* 
    * @author Julien P.
    * @dev Checks if given address hasn't already voted
    * @param    address  The address to test
    */
    modifier CheckAlreadyVoted(address addressToTest) {
        if (_votersMap[addressToTest].hasVoted) revert HasAlreadyVoted();
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
    function registerVoter(address voterAddress) public 
        OnlyOwner(msg.sender) CheckAddressNotEmpty(voterAddress) CheckAddressNotRegistered(voterAddress) {
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
    function registerVoters(address[] calldata votersAddresses) external OnlyOwner(msg.sender) {
        uint length = votersAddresses.length;
        for (uint i; i < length;) {
            // We keep this condition here, even if it's on the modifier of registerVoter to avoid getting a cascade revert
            if (!_votersMap[votersAddresses[i]].isRegistered) registerVoter(votersAddresses[i]);

            unchecked { ++i; }
        }
    }

    /*
    * @author Julien P.
    * @notice 
    *   Checks if the workflow status is in the right state, then start the proposal time.
    *   There must be at least one voter added in the white list to start proposal time, otherwise it's useless
    *   Only the contract's owner can call this method
    */
    function startProposalTime() external 
        OnlyOwner(msg.sender) CheckStatusIsGood(WorkflowStatus.RegisteringVoters) CheckVotersListIsntEmpty() {
        emit WorkflowStatusChange(_workflowStatus = WorkflowStatus.ProposalsRegistrationStarted, WorkflowStatus.ProposalsRegistrationStarted);
    }

    /*
    * @author Julien P.
    * @notice
    *   Checks if proposals registration are started, if some proposals has been made, then stop it
    *   Only the contract's owner can call this method
    */
    function endProposalTime() external 
        OnlyOwner(msg.sender) CheckStatusIsGood(WorkflowStatus.ProposalsRegistrationStarted) CheckProposalsListIsntEmpty() {
        emit WorkflowStatusChange(_workflowStatus = WorkflowStatus.ProposalsRegistrationEnded, WorkflowStatus.ProposalsRegistrationEnded);
    }

    /*
    * @author Julien P.
    * @notice 
    *   Checks if the workflow status is in the right state, then start the vote time
    *   Only the contract's owner can call this method
    */
    function startVoteTime() external OnlyOwner(msg.sender) CheckStatusIsGood(WorkflowStatus.ProposalsRegistrationEnded) {
        emit WorkflowStatusChange(_workflowStatus = WorkflowStatus.VotingSessionStarted, WorkflowStatus.VotingSessionStarted);
    }

    /*
    * @author Julien P.
    * @notice 
    *   Checks if the vote time is started and if there has been votes, then stop it
    *   If you had an error "The is X missing vote" you can force the process with 'forceEndVoteTime()'
    *   Only the contract's owner can call this method
    */
    function endVoteTime() external OnlyOwner(msg.sender) CheckStatusIsGood(WorkflowStatus.VotingSessionStarted) {
        uint missingVotes = countHowManyVotesAreMissing();
        if (missingVotes != 0) {
            _forceEndVoteTimeUnlocked = true;
            console.log(string.concat("There is ", Strings.toString(missingVotes), " missing vote !"));
        } else {
            endVoteTimeAndTally();
        }
    }

    /*
    * @author Julien P.
    * @notice 
    *   Checks if the vote time is started, then stop it
    *   You can only use this method if you called 'endVoteTime()' method and had error "The is X missing vote"
    *   Only the contract's owner can call this method
    */
    function forceEndVoteTime() external 
        OnlyOwner(msg.sender) CheckStatusIsGood(WorkflowStatus.VotingSessionStarted) CheckForceEndVoteUnlocked() {
        endVoteTimeAndTally();
    }


    /*
    * @author Julien P.
    * @dev Internal method to factorize end vote time action
    */
    function endVoteTimeAndTally() internal {
        emit WorkflowStatusChange(_workflowStatus = WorkflowStatus.VotingSessionEnded, WorkflowStatus.VotingSessionEnded);

        computeWinningProposalExecution();
    }

    /*
    * @author Julien P.
    * @notice 
    *   Compute the winning proposal from voters, and change the workflow status
    *   If there is an ex-aequo situation, the first proposal to reach the max vote amount will be the winning proposal
    *   If there is only blank votes, the first proposal made will be considered as the winning one
    *   Only the contract's owner can call this method
    *   This method is called automatically when ending vote
    * @dev 
    *   We return the winning proposal id for testing purpose
    *   We kept this method to respect this common interface with Voting. But it's useless here
    */
    function computeWinningProposal() external OnlyOwner(msg.sender) CheckStatusIsGood(WorkflowStatus.VotingSessionEnded) returns (uint) {
        return computeWinningProposalExecution();
    }

    /*
    * @author Julien P.
    * @dev 
    *   I created a separated method for the computeWinningProposalLogic, due to the common
    *   interface with Voting contract, where the methode computeWinningProposal() must be external.
    *   This involves that the call of computation from endVoteTimeAndTally() is not impossible, because
    *   computation must be external. The separated internal method allows to do it
    */
    function computeWinningProposalExecution() internal returns (uint) {
        uint _winningProposalIdCopy = _winningProposalId;

        // We start at 1, as the id range is 1 to _nbProposals
        for (uint i; i <= _nbProposals;) {
            unchecked { ++i; }
            Proposal memory curProposal = _proposals[i];
            Proposal memory winningProposal = _proposals[_winningProposalIdCopy];

            // We use > condition here to ensure that the default proposal defined before will be replaced
            if (curProposal.voteCount > winningProposal.voteCount) {
                _winningProposalIdCopy = i;
            } else if (curProposal.voteCount == winningProposal.voteCount 
                && curProposal.lastVoteTimestamp <  winningProposal.lastVoteTimestamp) {
                    // If there is an ex-aequo, we take the first proposal to reach this vote amount
                    // This condition also ensure that the default _winningConditionValue won't be returned to the user
                    _winningProposalIdCopy = i;
            } else if (winningProposal.lastVoteTimestamp == 0) {
                // If the winning proposal id is the default value, replace it
                _winningProposalIdCopy = i;
            }
        }

        _winningProposalId = _winningProposalIdCopy;

        // We set the status to "VotesTallied", to make the method "getWinner()" be able to work.
        emit WorkflowStatusChange(_workflowStatus = WorkflowStatus.VotesTallied, WorkflowStatus.VotesTallied);
        return _winningProposalId;
    }

    /*
    * @author Julien P.
    * @notice 
    *   Allows whitelisted users to vote, when the proposal registration is open, and if the given proposal isn't empty
    *   Only whitelisted voters can make a proposal
    * @param proposal The voter's proposal
    */
    function makeProposal(string calldata proposal) external 
        OnlyWhiteListedVoters(msg.sender) CheckStringIsntEmpty(proposal) CheckStatusIsGood(WorkflowStatus.ProposalsRegistrationStarted) {        
        // Incrementing proposals numbers / id & storing the proposal, starting with id 1
        _proposals[++_nbProposals] = Proposal(proposal, 0, block.timestamp);


        emit ProposalRegistered(_nbProposals);
    }

    /*
    * @author Julien P.
    * @notice 
    *   Allows whitelisted users to vote, when voting time is active, and if he has'nt already voted
    *   Proposal ids goes from 1 to 2^256.
    *   You can use the method 'showProposals()' to get the list of all proposals and their ids
    *   Proposal ids goes from 1 to 2^256. We consider the 0 value as a blank vote.
    *   Only whitelisted voters can make a vote
    * @param proposalId The voter's proposal id vote
    */
    function vote(uint proposalId) external 
        OnlyWhiteListedVoters(msg.sender) CheckStatusIsGood(WorkflowStatus.VotingSessionStarted) CheckProposalIdIsValid(proposalId) CheckAlreadyVoted(msg.sender) {
        if (proposalId > 0)  _proposals[proposalId].voteCount += 1;

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
        uint _winningProposalIdCopy = _winningProposalId;
        return _getProposalString(_proposals[_winningProposalIdCopy], _winningProposalIdCopy);
    }

    /*
    * @author Julien P.
    * @notice 
    *   Allows registered voters to show all proposals
    *   Only whitelisted voters can show all proposals
    * @return   string[]  A well formated list of proposal ids and their description
    */
    function showProposals() external view OnlyWhiteListedVoters(msg.sender) returns (string[] memory) {
        uint _nbProposalsCopy = _nbProposals;
        string[] memory result = new string[](_nbProposalsCopy + 1);

        if (_nbProposalsCopy > 0) { // As we push a default value on the array, we must be sure that his size is at least 1
            // As the blanck vote is a special proposal, we add it manually
            result[0] = string.concat("Nb blanck votes : ", Strings.toString(_proposals[0].voteCount));

            for (uint i; i <= _nbProposalsCopy;) {
                unchecked { ++i; }
                result[i - 1] = _getProposalString(_proposals[i], i);
            }
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
        uint length = _votersWhitelist.length;
        string[] memory result = new string[](length);

        for (uint i; i < length;) {
            result[i] = _getVoterString(_votersMap[_votersWhitelist[i]], _votersWhitelist[i]);

            unchecked { ++i; }
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
        if(!voter.isRegistered) revert VoterNotRegistered();

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
        if(bytes(proposal.description).length == 0) revert ProposalIdIsntValid();

        return _getProposalString(proposal, proposalId);
    }
    

    /*************************************
    *         Utility functions          *
    **************************************/
    
    /*
    * @author Julien P.
    * @dev Internal method to count how many votes are missing
    * @return   uint  The number of missing votes
    */
    function countHowManyVotesAreMissing() internal view returns (uint) {
        uint missingVotes = 0;

        uint length = _votersWhitelist.length;
        for (uint i = 0; i < length - 1;) {
            if (!_votersMap[_votersWhitelist[i]].hasVoted) missingVotes++;

            unchecked { ++i; }
        }

        return missingVotes;
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
                voter.hasVoted ? (voter.votedProposalId == 0 ? " blank voted" : Strings.toString(voter.votedProposalId)) : "hasn't voted");
    }

    /*
    * @author Julien P.
    * @dev Used for testing purpose
    * @return   address  The owner's address
    */
    function getOwner() external view returns (address) {
        return _owner;
    }
}