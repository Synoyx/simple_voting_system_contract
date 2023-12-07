![Solidity](https://img.shields.io/badge/Solidity-%23363636.svg?style=for-the-badge&logo=solidity&logoColor=white) ![Ethereum](https://img.shields.io/badge/Ethereum-3C3C3D?style=for-the-badge&logo=Ethereum&logoColor=white)

# simple_voting_contract

First project for alyra course : a simple voting system contract

You can find in the contracts folder 2 files :

- Voting.sol : The exercise done by strictly following the given rules
- Voting_plus.sol : The same as previous files, with some logic / optimizations added to make it better

### Voting.sol

Apart from what's asked in the exercise's statement, here is what I considered as mandatory :

- A lots of checks, to ensure that everything works well :
  - Given addresses should be real
  - You can't change the workflow status if it breaks the intended workflow (adding voters => start proposals time => end proposal time => start vote time => end vote time => compute results)
  - Also, some operations can only be made if the current workflow status is in a certain stage
  - You can't compute the winning proposal if there are no proposals
  - You can't vote twice, and you can only vote for an existing proposal
- To answer to the statement "Vote isn't secret to whitelisted users", I chose to let my voters map as private, and make a limited access getter : showCurrentVotes(). Also, I decided to make this getter output something more user friendly than default Solidity mapping logs
- I created a getter called 'showProposals', which returns a list of all proposals and their id. For me it's mandatory to make voters be able to vote
- I made an enum-to-string function (\_getWorkflowStatusString()), for previous point
- I decided to make a getter for showing the winning proposal instead of making the \_winningProposalId variable public. This allows me, with a modifier, to answer only if the results has been computed, or give to the user a comprehensive message if it's not the case
- As the statement wasn't clear on this point, I gave the possibility when adding voters to provide a list, or a single address. The list method will loop over the list and use the single-address method.
- To compute the winning proposal, as it's the simple version I just take the proposal with the most votes, lastly added (due to how I made the algorithm)
- To easily check proposals, and store them efficiently, I decided to store them in a mapping, with an incrementing id as key. I store the number of proposal (\_nbProposals) in a separated variable, which allows me to simply loop over the keys, as the id goes from 1 to \_nbProposals.

### Voting_plus.sol

For this version, I decided to add following logics :

- When the administrator wants to end voting time, the operation will fail if there are voters that didn't vote. Calling this method and getting an error message saying that there are missing votes will switch a boolean, unlocking a method "forceEndVoteTime()"
- Added a method "forceEndVoteTime()" to be able to close vote time even if not every voter has vote
- If there is an tie vote during vote tally, the winning proposal will be the first to reach the maximum vote amount. To do that, I added a property "lastVoteTimestamp" on the Proposal struct
- I now allow the voters to vote 0, which is a blank vote. It will allow the administrator to see that everyone has voted. It won't change anything to the results, except if there are only blank votes : if everyone made a blank vote, the administrator will be able to compute results, and the winning proposal will be the first proposed (tie vote situation)
- As there is no point of making 2 separate phases for ending vote time and tally votes, the computation of winning proposal will occur automatically when administrator closes vote time. This avoids a useless transaction cost.
