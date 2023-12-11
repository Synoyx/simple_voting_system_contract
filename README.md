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

On Voting plus, I tried to make some gas optimisation. And depite having more functionnalities on voting plus, most of the methods takes now less gas :

![alt text](https://i.postimg.cc/zXTcvrFT/gas-Optimization.png)

The repport take in account the sum of all calls made during the gasTestConsumptionScenario() + all the other 38 unit tests. I chose to keep it like that, as it give a more representative datas.
You can generate the repport by running "forge test --gas-report" at the root of the project.

Here is the list of optimizations done :

- Removed ownable, to use custom owner test. I made the variable immutable, this make each access to the variable cost less
- When a "primitive" state variable is used more than once in a method, made a copy of it then used it, because accessing a memory variable cost less than a storage one
- When using a for loop, don't give default value to uint i
- When using a for loop, if the condition call a method, like someArray.length, stored it in a variable before the loop, then used this variable for the condition. This avoids calling the method for every turn of the loop
- When using a for loop, incrementing i with "unchecked { ++i; }", this avoid overflow check in the EVM and save some gas
- Removed each require, to replace them with if/revert, and custom errors.
- Placed each replace required in a modifier, because modifier cost less than testing a condition at the beginning of a method
- Changed variable declaration order, to try to stack them in the same slot. Only the boolean variable allowed me to do that, other variables were too big
- When it was possible, replaced i++ by ++i, as pre-incrementation is cheaper

Here is a comparison gas consumption for each line of the repport (I only take average values):

- Deployment cost : from **1 667 885** to **1 553 170**
- Get owner : from **365** to **218**
- Register voters : from **73 376** to **72 929**. The difference is tiny because Voting plus has an additionnary test in his method
- Register voter : from **70 796** to **61 962**
- Start proposal time : from **2 976** to **21 641** I don't understand why this particular method cost so much, it's the same
- Make proposal : from **38 002** to **57 165** The difference hhere is explained by the fact that in voting plus, Proposal struct has a timestamp added. When a new proposal is made, I need to store the current timestamp in it, and this cost a lot of gas
- End proposal time : from **3 227** to **2 306**
- Start vote time : from **2 969** to **2 004**
- Vote : from **27 841** to **27 940** My assumption is that as the proposals are a little bigger struct, modifiying them cost a little more gas
- Show current votes : from **20 261** to **20 019**
- Show proposals : from **4 326** to **10 109** There are some additionary lines on voting_plus, to handle blanck votes, than explain the cost
- Get voter : from **11 073** to **11 027** There are some additionary lines on voting_plus, to handle blanck votes, than explain the cost
- Get proposal : from **3 647** to **4 386** My assumption is that as the proposals are a little bigger struct, modifiying them cost a little more gas
- End vote time + compute winning : from **20 858** to **29 623** We need to compare here endVoteTime + computeWinning from Voting, to endVoteTime in VotingPlus, as he made both in one. The supplementary cost is explained by the fact that there are additionnal test in voting plus (test missing votes)
- Get winner : from **3 483** to **2 836**
