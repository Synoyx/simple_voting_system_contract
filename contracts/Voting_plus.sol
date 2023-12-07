// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "hardhat/console.sol";

/*
* @title A simple vote system, managed by an administrator, allowing registered users to make proposals and vote.
* @author Julien P.
*/
contract Voting is Ownable {
    /*************************************
    *             Variables              *
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

    WorkflowStatus _workflowStatus;

    mapping(address => Voter) _votersMap;
    address[] _votersWhitelist;

    mapping(uint => Proposal) _proposals;
    uint _nbProposals;
    Proposal _winningProposal;

    bool _forceEndVoteTimeUnlocked;

    
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
    * @dev Starting the Ownable pattern
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
    * @dev Adds a voter to the list
    * @notice Only the contract's owner can call this method
    * @param voterAddress The address to add to the whitelist
    */
    function registerVoter(address voterAddress) public onlyOwner {
        require(voterAddress != address(0), "The given address is empty !");

        _votersMap[voterAddress] = Voter(true, false, 0);
        _votersWhitelist.push(voterAddress);

        emit VoterRegistered(voterAddress);
    }

    /*
    * @author Julien P.
    * @dev add a list of voters
    * @notice Only the contract's owner can call this method 
    * @param votersAddresses an array of voters addresses to add to the whitelist
    */
    function registerVoters(address[] calldata votersAddresses) external onlyOwner {
        for(uint i = 0; i < votersAddresses.length - 1; i++) {
            registerVoter(votersAddresses[i]);
        }
    }

    /*
    * @author Julien P.
    * @dev Checks if the workflow status is in the right state, then start the proposal time.
    * @notice Only the contract's owner can call this method
    */
    function startProposalTime() external onlyOwner CheckStatusIsGood(WorkflowStatus.RegisteringVoters) {
        emit WorkflowStatusChange(_workflowStatus, WorkflowStatus.ProposalsRegistrationStarted);
        _workflowStatus = WorkflowStatus.ProposalsRegistrationStarted;
    }

    /*
    * @author Julien P.
    * @dev Checks if proposals registration are started, then stop it
    * @notice Only the contract's owner can call this method
    */
    function endProposalTime() external onlyOwner CheckStatusIsGood(WorkflowStatus.ProposalsRegistrationStarted) {
        require(_nbProposals > 0, "No proposal has been made yet, can't close proposal time !");

        emit WorkflowStatusChange(_workflowStatus, WorkflowStatus.ProposalsRegistrationEnded);
        _workflowStatus = WorkflowStatus.ProposalsRegistrationEnded;
    }

    /*
    * @author Julien P.
    * @dev Checks if the workflow stats is in the right state, then start the vote time
    * @notice Only the contract's owner can call this method
    */
    function startVoteTime() external onlyOwner CheckStatusIsGood(WorkflowStatus.ProposalsRegistrationEnded) {
        emit WorkflowStatusChange(_workflowStatus, WorkflowStatus.VotingSessionStarted);
        _workflowStatus = WorkflowStatus.VotingSessionStarted;
    }

    /*
    * @author Julien P.
    * @dev Checks if the vote time is started, then stop it
    * @notice Only the contract's owner can call this method
    * @notice If there are missing votes, the method won't do anything. You must use forceEndVoteTime() to end vote time even with voters that didn't vote
    */
    function endVoteTime() external onlyOwner CheckStatusIsGood(WorkflowStatus.VotingSessionStarted) {
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
    * @dev Checks if the vote time is started, then stop it
    * @notice Only the contract's owner can call this method
    * @notice Will end vote time even if there are voters that didn't vote yet. You must try to call 'endVoteTime()' first before forcing
    */
    function forceEndVoteTime() external onlyOwner CheckStatusIsGood(WorkflowStatus.VotingSessionStarted) {
        require(_forceEndVoteTimeUnlocked, "You must try to use 'endVoteTime' first, that is safer");
        
        endVoteTimeAndTally();
    }

    function endVoteTimeAndTally() internal onlyOwner {
        emit WorkflowStatusChange(_workflowStatus, WorkflowStatus.VotingSessionEnded);
        _workflowStatus = WorkflowStatus.VotingSessionEnded;

        computeWinningProposal();
    }

    /*
    * @author Julien P.
    * @dev Compute the winning proposal from voters, and change the workflow status
    * @notice Only the contract's owner can call this method
    * @notice If there is an ex-aequo situation, the first proposal to reach the max vote amount will be the winning proposal
    * @notice If there is only blank votes, the first proposal made will be considered as the winning one
    */
    function computeWinningProposal() internal onlyOwner {
        _winningProposal = Proposal("", 0, block.timestamp);

        // We start at 1, as the id range is 1 to _nbProposals
        for (uint i = 1; i < _nbProposals; i++) {
            // We use > condition here to ensure that the default proposal defined before will be replaced
            if (_proposals[i].voteCount > _winningProposal.voteCount) {
                _winningProposal = _proposals[i];
            } else if (_proposals[i].voteCount == _winningProposal.voteCount 
                && _proposals[i].lastVoteTimestamp < _winningProposal.lastVoteTimestamp) {
                    // If there is an ex-aequo, we take the first proposal to reach this vote amount
                    // This condition also ensure that the default _winningConditionValue won't be returned to the user
                    _winningProposal = _proposals[i];
            }
        }

        // We set the status to "VotesTallied", to make the method "getWinner()" be able to work.
        emit WorkflowStatusChange(_workflowStatus, WorkflowStatus.VotesTallied);
        _workflowStatus = WorkflowStatus.VotesTallied;
    }

    /*
    * @author Julien P.
    * @dev Allows whitelisted users to vote, when the proposal registration is open
    * @notice Only whitelisted voters can make a proposal
    * @param proposal The voter's proposal
    */
    function makeProposal(string calldata proposal) external OnlyWhiteListedVoters(msg.sender) {        
        require(_workflowStatus == WorkflowStatus.ProposalsRegistrationStarted, "The proposal time is over, you can't give your proposal anymore");
        require(bytes(proposal).length > 0, "Your proposal is empty !");

        // Creating new proposal
        Proposal memory newProposal = Proposal(proposal, 0, block.timestamp);

        // Incrementing proposals numbers / id & storing the proposal, starting with id 1
        _proposals[++_nbProposals] = newProposal;


        emit ProposalRegistered(_nbProposals);
    }

    /*
    * @author Julien P.
    * @dev Allows whitelisted users to vote, when voting time is active, and if he has'nt already voted
    * @notice Only whitelisted voters can make a vote
    * @param proposalId The voter's proposal id vote
    */
    function vote(uint proposalId) external OnlyWhiteListedVoters(msg.sender) {
        require(_workflowStatus == WorkflowStatus.VotingSessionStarted, "It's not vote time, you can't vote");
        require(!_votersMap[msg.sender].hasVoted, "You have already voted");
        require(proposalId > 0 && proposalId <= _nbProposals, "The given proposal id doesn't exists");

        _proposals[proposalId].voteCount += 1;

        _votersMap[msg.sender].hasVoted = true;
        _votersMap[msg.sender].votedProposalId = proposalId;
        
        emit Voted(msg.sender, proposalId);
    }

    /*
    * @author Julien P.
    * @dev Returns the voted proposal, if the votes have been tallied
    */
    function getWinner() external view CheckStatusIsGood(WorkflowStatus.VotesTallied) returns (Proposal memory) {
        return _winningProposal;
    }

    /*
    * @author Julien P.
    * @notice Allows registered voters to show all proposals
    * @notice Only whitelisted voters can show all proposals
    */
    function showProposals() external view OnlyWhiteListedVoters(msg.sender) returns (string[] memory) {
        string[] memory result = new string[](_nbProposals);

        for (uint i = 0; i < _nbProposals - 1; i++) {
            result[i] = string.concat(
                "Proposal id : ", Strings.toString(i), 
                "  proposal description : ", _proposals[i].description);
        }

        return result;
    }
    
    /*
    * @author Julien P.
    * @dev Allows registered voters to show votes status
    * @notice Only whitelisted voters can show current votes
    */
    function showCurrentVotes() external view OnlyWhiteListedVoters(msg.sender) returns (string[] memory) {
        string[] memory result = new string[](_votersWhitelist.length);

        for (uint i = 0; i < _votersWhitelist.length - 1; i++) {
            result[i] = string.concat(
                "Voter : ", Strings.toHexString(uint256(uint160(_votersWhitelist[i])), 20), 
                "  proposal id voted : ", Strings.toString(_votersMap[_votersWhitelist[i]].votedProposalId));
        }

        return result;
    }

    
    /*
    * @author Julien P.
    * @notice Get a voter by his address
    * @notice Trigger an error if this address isn't registered
    */
    function getVoter(address voterAddress) external view returns (Voter memory) {
        Voter memory result = _votersMap[voterAddress];
        
        // If 'isRegistered' is false, it means that it's a default value returned, and that there is no voter with this address
        require(result.isRegistered, "There is no registered voter with this address !");

        return result;
    }

    
    /*
    * @author Julien P.
    * @notice Get a proposal by her id
    * @notice Trigger an error if there is no proposal with this id
    */
    function getProposal(uint proposalId) external view returns (Proposal memory) {
        Proposal memory result = _proposals[proposalId];

        // If found proposal description is empty, it means that it's a default value returned, and that there is no proposal with this id
        require(bytes(result.description).length == 0, "There is no proposal with this id !");

        return result;
    }
    

    /*************************************
    *         Utility functions          *
    **************************************/

    /*
    * @author Julien P.
    * @dev Used to convert enum value to displayable string for logging purpose
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
    
    function countHowManyVotesAreMissing() internal view returns (uint) {
        uint missingVotes = 0;

        for (uint i = 0; i < _votersWhitelist.length - 1; i++) {
            if (!_votersMap[_votersWhitelist[i]].hasVoted) missingVotes++;
        }

        return missingVotes;
    }
}