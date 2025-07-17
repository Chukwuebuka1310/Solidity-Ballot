//SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

contract Ballot{

    error NotChairPerson();
    error AlreadyVoted(bool voted);
    error AlreadyAssignedVotingPower(uint256 weight);
    error SelfDelegation(address sender, address delegate);
    error VotingEnded();
    error votingStillOngoing();

    address immutable i_chairPerson;
    uint votingDuration;

    struct Proposals {
        string name;
        uint256 voteCount;
    }

    //Assigned to a new voter
    struct Voter{
        uint256 weight;
        bool voted;
        address delegate;
        uint256 vote;
    }

    mapping(address => Voter) public voters;

    Proposals[] public proposal; 

    //deploytime function passing a array of string called proposalNames
    constructor(string[] memory proposalNames, uint votingTime) { 

        i_chairPerson = msg.sender;  //Assigning the chair person to the sender of the contract
        voters[i_chairPerson].weight = 1; //Giving the chair person a voting power of 1 vote
        votingDuration = block.timestamp + votingTime;

        //Looping through the array of string passed in deploytime
        for(uint256 proposalIndex = 0; proposalIndex < proposalNames.length; proposalIndex++){ 

            //For each element passed to the constructor, create an instance of Proposal of the type of struct
            //Add the element into the struct created
            proposal.push(
                Proposals({
                    name: proposalNames[proposalIndex],
                    voteCount: 0
                })
            );
        }
    }


    //Give voter right to vote and can only be done by the msg.sender(ChairPerson)
    function giveRightToVote(address voter) public OnlyChairPerson{ 

        //Check the current time is still under the voting time
        if(block.timestamp > votingDuration) revert VotingEnded();

        //By default voters[voter].voted is false, but if the check in the next line return true do the revert statement.
        if(voters[voter].voted)revert AlreadyVoted(voters[voter].voted);

        if(voters[voter].weight == 0){ //Check the weight is equal to zero, if yes
            voters[voter].weight = 1; //Then make weight  one
        }else{
            revert AlreadyAssignedVotingPower(voters[voter].weight); //otherwise revert with this custom error
        }
    }

    function delegate(address to) public{ //function to give another voter your voting power.

        //Check the current time is still under the voting time
        if(block.timestamp > votingDuration) revert VotingEnded();

        //Making a full copy of the Voter Struct, and using the storage keyword to ensure that the sender(voter) 
        //get an instance of Voter in permanent memory. Thereby adding the caller to the mapping of voters
        Voter storage sender = voters[msg.sender]; 

        //Check if the new made voter(send) has a voting power(weight)
        if(sender.weight == 0) revert ("You have no right to vote");

        //Check if the new made voter(send) has already voted(since sender.voted is expected by default to be false, 
        //thefore the opposite !sender.voted is expected to be true)
        if(sender.voted) revert ("You have already voted"); //wrong

        //Check if caller of the function is the same person to whom he/she want to delegate to
        if(to == msg.sender) revert ("Self delegation is not allowed");
        
        
        /*
        Since this is delegation function(Assigning voting to someone else, its possible that, the
        person that we want to assign our vote to has assigned his to someone else, so this loop 
        ensures that no matter how long the chain is(Alice - Bob - Raymond - Kai - Caleb- .....), 
        the loop will finally find one person that didn't delegate his vote making that person the real 
        voter
        **/

        
        while(voters[to].delegate != address(0)){ //Check if the delegate's(to) property of delegate is not equal to address(0) 0x00, if yes
            
            //Get the address and assign it to to (it becomes the new addres for reference)
            //The proccess continues until delegate's(to) property of delegate is equal to address(0) 0x00
            //Then it stops.
            to = voters[to].delegate;     

            //Check if the newly assigned address is the caller of this function, 
            //if yes revert with custom error msg        
            if(to == msg.sender) revert SelfDelegation(msg.sender, to);
        }

        //After all the looping process and we finally get the voter with the 
        //delegation of an empty address, then create a full copy of Voter 
        //struct with the variable name of delegate_, then permently store(storage) the 
        //variable name in the contract
        Voter storage delegate_ = voters[to];

        //This ensures that the delegate_has a property of weight and that weight property isn't
        //lesser than 1(this give the delegate an actual voting power to acomodate your vote)
        require(delegate_.weight >= 1);

        //Assigning the properties of the sender
        sender.delegate = to;
        sender.weight = 1;

        if(delegate_.voted){ //Check if the delegated voter voted property return true, if yes

        //Then, go to the delegate voted for(indicating who him/she voted for) and add to the
        //to that person/Contract/address voteCount
            proposal[delegate_.vote].voteCount += sender.weight; 
        } else {
            //if no or any other option, just add to the delegate weight property
            delegate_.weight += sender.weight;
        }
    }

    function vote(uint256 choice) public {

        //Check the current time is still under the voting time
        if(block.timestamp > votingDuration) revert VotingEnded();
        
        //Create a full copy of the Voter struct for the sender of the contract
        Voter storage sender = voters[msg.sender];

        //Check if the caller of the fuction has voting power(weight)
        if(sender.weight < 1){
            revert ("You have no voting power");
        }

        //Check if the caller of the function has voted 
        if(sender.voted){
            revert("You have already voted");
        }

        //If the folowing conditionals above has been passed, then
        //from the Voter struct created for the sender, update the bool voted
        sender.voted = true;

        //Then assign the choice of proposal to the struct
        sender.vote = choice;

        //Then add the vote to the voteCount propertyof your choice of proposals
        proposal[choice].voteCount += sender.weight;

    }

    //Function to get the winning proposal during voting
    function winningProposal() public view returns(uint256 _winningProposal){

        //updating the winner count
        uint256 winningCount;

        //Loop to ensure that the proposal considered do not exceed the number of element in the proposal array
        for(uint p = 0; p < proposal.length; p++){

            //Check if the voteCount property of an element is greater than the winningCount
            //For the first element this will vary cause the voteCount property might be 0 or greater
            if(proposal[p].voteCount > winningCount){

                //If the above conditionals is correct, then
                //Assign the voteCount property of that element to winningCount
                winningCount = proposal[p].voteCount;

                //After the previouse line, then assign that particular element to the 
                //_winningProposal(to be returned t the caller)
                _winningProposal = p; //This line automatically return and do not need the return keyword
            }
        }
    }

    //Function to indicate the winner of the Ballot
    function winnerProposal() public view returns(string memory){

        //Check the current time is still under the voting time
        if(block.timestamp > votingDuration) {

            //Assign the call of the winningProposal function to the winner variable
            uint256 winner = winningProposal();

            //Then get the name of the proposal and return it to the caller.
            return proposal[winner].name;
        }else {
            revert votingStillOngoing();
        }

        
    }

    modifier OnlyChairPerson{
        if(i_chairPerson != msg.sender) revert NotChairPerson();
        _;
    }



}
