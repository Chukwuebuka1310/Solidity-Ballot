//SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

contract Ballot{

    error NotChairPerson();
    error AlreadyVoted(bool voted);
    error AlreadyAssignedVotingPower(uint256 weight);
    error SelfDelegation(address sender, address delegate);

    address immutable i_chairPerson;

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
    constructor(string[] memory proposalNames) { 

        i_chairPerson = msg.sender;  //Assigning the chair person to the sender of the contract
        voters[i_chairPerson].weight = 1; //Giving the chair person a voting power of 1 vote

        //Looping through the array of string passed in deploytime
        for(uint256 proposalIndex = 0; proposalIndex < proposalNames.length; proposalIndex++){ 

            //Add all the string passed into the array of proposals for voting
            proposal.push( 
                Proposals({
                    name: proposalNames[proposalIndex],
                    voteCount: 0
                })
            );
        }
    }

    function giveRightToVote(address voter) public OnlyChairPerson{ //Give voter right to vote and can oly be done by the msg.sender(ChairPerson)
        //By default voters[voter].voted is false, but if the check in the next line return true do the revert statement.
        if(voters[voter].voted)revert AlreadyVoted(voters[voter].voted);

        if(voters[voter].weight == 0){ //Check the weight is equal to zero, if yes
            voters[voter].weight = 1; //Then make weight  one
        }else{
            revert AlreadyAssignedVotingPower(voters[voter].weight); //otherwise revert with this custom error
        }
    }

    function delegate(address to) public{ //function to give another voter your voting power.

        //Making a full copy of the Voter Struct, and using the storage keyword to ensure that the sender(voter) 
        //get in instance of voter in permanent memory. Thereby addinf the caller to the list of voter
        Voter storage sender = voters[msg.sender]; 

        //Check if the new made voter(send) has a voting power(weight)
        if(sender.weight == 0) revert ("You have no right vote");

        //Check if the new made voter(send) has already voted(since sender.voted is expected by default to be false, 
        //thefore the opposite !sender.voted is expected to be true)
        if(sender.voted) revert ("You have already voted"); //wrong

        //Check if caller of the functin is the same person to whom he/she want to delegate to
        if(to == msg.sender) revert ("Self delegation is not allowed");
        
        
        /*
        Since this is delegation function(Assigning voting to someone else, its possible that, the
        person that we want to assign our vote to has assigned his to someone else, so this loop 
        ensures that no matter how long the chain is(Alice - Bob - Raymond - Kai - Caleb- .....), 
        the loop will finally find one person that didn't delegate his vote making thet person the real 
        voter
        **/

        
        while(voters[to].delegate != address(0)){ //Check if the delegate's(to) property of delegate is not equal to address(0) 0x00, if yes
            
            //Get the address and assign it to to (it becomes the new addres for reference)
            //The proccess continues until delegate's(to) property of delegate is equal to address(0) 0x00
            //Then it stops.
            to = voters[to].delegate;     

            //Check if the newly assigned address is to the caller of this function, 
            //if yes revert with custom error msg        
            if(to == msg.sender) revert SelfDelegation(msg.sender, to);
        }

        //After all the looping process and we finally get the voter with the 
        //delegation of an empty address, then create a full copy of Voter 
        //struct with the variable name of delegate_, then permently store(stoerage) the 
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

    modifier OnlyChairPerson{
        if(i_chairPerson != msg.sender) revert NotChairPerson();
        _;
    }

}