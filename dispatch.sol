pragma solidity ^0.4.11;

/********************************************************

This contract recive eth and dispatch them to a list of contracts.

*********************************************************/


/***********************************************
  Define owned contract and onlyOwner modifier
***********************************************/
contract owned {
  address public owner;

  constructor() public{
    owner = msg.sender;
  }
  
  function isOwner(address _user) public constant returns (bool) {
    return _user==owner;
  }

  modifier onlyOwner {
    if (msg.sender != owner) revert();
    _;
  }
}


/***********************************************
  Main contract. 
***********************************************/
contract dispatch is owned {

  // list of targets
  address[] target_addresses;
  
  
  /***** Contract administration *******/
  /* Transfert ownership */
  function transferOwnership(address newOwner) public onlyOwner {
    accountType[newOwner] = 2;
    accountStatus[newOwner] = true;
    owner = newOwner;
  }
  
  
  /*** Targets administrations ****/
   /* Count the number of Targets  */
  function targetCount() public constant onlyOwner returns (uint256){
    return target_addresses.length;
  }
  
  /* Get target at index  */
  function getTarget(uint index) public constant onlyOwner returns (address target) {
    return target_addresses[index];
  }

  
  /* Add new target ***/
  function addTarget(address newTarget) public onlyOwner {
    bool found = false;
    uint i;
    for (i = 0; i<target_addresses.length; i++){
        if (!found && target_addresses[i] == target){
            found=true;
        }
    }
    
    if (!found){
        target_addresses.push(target);
    }
  }
  
  
  /* remove existing target */
  function removeTarget(address target) public onlyOwner {
    bool found = false;
    uint i;
    for (i = 0; i<target_addresses.length; i++){
        if (!found && target_addresses[i] == target){
            found=true;
        }

        if (found && i < target_addresses.length-1){
            target_addresses[i] = target_addresses[i+1];
        }
    }

    if (found){
        delete target_addresses[target_addresses.length-1]; // remove the last record from the array
    }
  }
  
  
  /* In the case we need to retrieve Eth from the contract. Sent it back to the Owner */
  function repay(uint _amount) public onlyOwner {
      uint amount = _amount * 1 ether;
      owner.transfer(amount); 
  }
  
  /***** Ether handling *******/
  /* The contract dispatch Eth: it must be able to recieve them */
  function () public payable{
    //msg.value
  
    uint[] balances;
    uint max_balance=0;
    uint i;
    for (i = 0; i<target_addresses.length; i++){
        uint curr_balance = target_addresses[i].balance;
        balances.push(curr_balance);
        if (max_balance<curr_balance) {
            max_balance=curr_balance;
        }
    }
    max_balance = max_balance+1;
    uint total=0;
    for (i = 0; i<target_addresses.length; i++){
        balances[i] = max_balance - balances[i];
        total = total + balances[i];
    }
    
    uint base_amount = msg.value;
    for (i = 0; i<target_addresses.length; i++){
        target_addresses.send((base_amount*balances[i])/total)
    }
    
    base_amount = this.value;  // in solidity 0.5 => address(this)
    for (i = 0; i<target_addresses.length; i++){
        target_addresses.send((base_amount*balances[i])/total)
    }
    
  }

 



