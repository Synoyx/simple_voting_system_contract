![Solidity](https://img.shields.io/badge/Solidity-%23363636.svg?style=for-the-badge&logo=solidity&logoColor=white) ![Ethereum](https://img.shields.io/badge/Ethereum-3C3C3D?style=for-the-badge&logo=Ethereum&logoColor=white)

# simple_voting_contract

First project for alyra course : a simple voting system contract

You can find in the contracts folder 2 files :

- Voting.sol : The exercise done by strictly following the given rules
- Voting_plus.sol : The same as previous files, with some logic / optimizations added to make it better

An interface is also present in contract folder, his usage is described in "Unit tests" section

### Voting.sol

Apart from what's asked in the exercise's statement, here is what I considered as mandatory :

- A lots of checks, to ensure that everything works well :
  - Given addresses should be real
  - You can't change the workflow status if it breaks the intended workflow (adding voters => start proposals time => end proposal time => start vote time => end vote time => compute results)
  - Also, some operations can only be made if the current workflow status is in a certain stage
  - You can't add the same address twice into the whitelist
  - You can't start proposal time without adding at least one user to the whitelist, otherwise it would be useless
  - You can't compute the winning proposal if there are no proposals
  - You can't vote twice, and you can only vote for an existing proposal
- To answer to the statement "Vote isn't secret to whitelisted users", I chose to let my voters map as private, and make a limited access getter : showCurrentVotes(). Also, I decided to make this getter output something more user friendly than default Solidity mapping logs, as there is not frond-end to do it
- I created a getter called 'showProposals', which returns a list of all proposals and their id. For me it's mandatory to make voters be able to vote. I decided to make this getter output something more user friendly than default Solidity mapping logs, as there is not frond-end to do it
- I made an enum-to-string function (\_getWorkflowStatusString()), for previous point
- I decided to make a getter for showing the winning proposal instead of making the \_winningProposalId variable public. This allows me, with a modifier, to answer only if the results has been computed, or give to the user a comprehensive message if it's not the case. I return the proposal, to show not only the winning proposal's id, but also the description
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

## Unit tests

Unit test has been done to test all external methods, but also the general workflow of voting.
There are a total of 39 unit test, made for both Voting & Voting plus.
For that purpose, I used an interface for Voting & Voting plus, that allowed me to write only once unit tests, that then can be used for both contract.

Files can be found here :

- test/Voting.t.sol : the file with all unit test. Used to test Voting contract
- test/Voting_plus.t.sol : Herits from VotingTest, to get all the unit test already done. Instead of instanciating Voting, will instanciate Voting plus. Will also override some unit test method, because voting plus has sometime a behaviour different

You can run all tests by using command 'forge test' at the root of the project.
This should result in this :

![alt text](https://i.postimg.cc/gJhwpnq9/testOk.png)

## Gas optimization

On Voting plus, I tried to make some gas optimisation. And depite having more functionnalities on voting plus, most of the method takes now less gas :

![alt text](https://i.postimg.cc/zXTcvrFT/gas-Optimization.png)
