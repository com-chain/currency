pragma solidity ^0.4.18;

/********************************************************

This contract recive eth and dispatch them to a list of contracts.

*********************************************************/


/***********************************************
  Define owned contract and onlyOwner modifier
***********************************************/
contract owned {
  address public owner;

 function owned() public{
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
  uint max_add = 10;
  
  event UnableToDispatchTo(uint256 time, address target);
  event Recieved(uint256 time, uint amount);
  
  
  /***** Contract administration *******/
  /* Transfert ownership */
  function transferOwnership(address newOwner) public onlyOwner {
    owner = newOwner;
  }
  
  
  /*** Targets administrations ****/
   /* Count the number of Targets  */
  function targetCount() public constant returns (uint256){
    return target_addresses.length;
  }
  
  /* Get target at index  */
  function getTarget(uint index) public constant returns (address target) {
    return target_addresses[index];
  }

  
  /* Add new target ***/
  function addTarget(address newTarget) public onlyOwner {
      
    if (target_addresses.length>=max_add){
        revert();
    }
    
    bool found = false;
    uint i;
    for (i = 0; i<target_addresses.length; i++){
        if (!found && target_addresses[i] == newTarget){
            found=true;
        }
    }
    
    if (!found){
        target_addresses.push(newTarget);
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
        target_addresses.length--;
    }
  }
  
  
  /* In the case we need to retrieve Eth from the contract. Sent it back to the Owner */
  function repay(uint _amount) public onlyOwner {
      uint amount = _amount * 1 ether;
      if(amount> this.balance){
          amount= this.balance;
      }
      owner.transfer(amount); 
  }
  
  /***** Ether handling *******/
  /* The contract dispatch Eth: it must be able to recieve them */
  function () public payable {
    Recieved(now, msg.value/(1 ether));
  
    uint add_number = target_addresses.length;
    if (add_number>0) {
    
        uint256[] memory  balances = new uint256[](add_number);
        uint256 max_balance=0;
        uint i;
        for (i = 0; i<add_number; i++){
        uint256 curr_balance = target_addresses[i].balance;
        balances[i]=curr_balance;
        if (max_balance<curr_balance) {
            max_balance=curr_balance;
        }
    }
    max_balance = max_balance+1;
    uint256 total=0;
    for (i = 0; i<target_addresses.length; i++){
        balances[i] = max_balance + 1 - balances[i];
        total = total + balances[i];
    }
    
    uint256 base_amount = msg.value;
    for (i = 0; i<target_addresses.length; i++){
       if (! target_addresses[i].send((base_amount*balances[i])/total)){
          UnableToDispatchTo(now, target_addresses[i]); //0.4.21 add emit
       }
    }
    
    base_amount = this.balance;  // in solidity 0.5 => address(this)
    if (base_amount> 1 ether){
       for (i = 0; i<target_addresses.length; i++){
          if (! target_addresses[i].send((base_amount*balances[i])/total)){
             UnableToDispatchTo(now, target_addresses[i]); //0.4.21 add emit
          }
       }
    }
    }
    
  }
}
 



------------------------
dispatch contract



[ { "constant": true, "inputs": [ { "name": "_user", "type": "address" } ], "name": "isOwner", "outputs": [ { "name": "", "type": "bool", "value": false } ], "payable": false, "stateMutability": "view", "type": "function" }, { "constant": false, "inputs": [ { "name": "_amount", "type": "uint256" } ], "name": "repay", "outputs": [], "payable": false, "stateMutability": "nonpayable", "type": "function" }, { "constant": false, "inputs": [ { "name": "newTarget", "type": "address" } ], "name": "addTarget", "outputs": [], "payable": false, "stateMutability": "nonpayable", "type": "function" }, { "constant": true, "inputs": [], "name": "owner", "outputs": [ { "name": "", "type": "address", "value": "0x4868db83bcf1a129eac577d4d1ad0fd5676176c6" } ], "payable": false, "stateMutability": "view", "type": "function" }, { "constant": true, "inputs": [], "name": "targetCount", "outputs": [ { "name": "", "type": "uint256", "value": "0" } ], "payable": false, "stateMutability": "view", "type": "function" }, { "constant": false, "inputs": [ { "name": "target", "type": "address" } ], "name": "removeTarget", "outputs": [], "payable": false, "stateMutability": "nonpayable", "type": "function" }, { "constant": true, "inputs": [ { "name": "index", "type": "uint256" } ], "name": "getTarget", "outputs": [ { "name": "target", "type": "address", "value": "0x" } ], "payable": false, "stateMutability": "view", "type": "function" }, { "constant": false, "inputs": [ { "name": "newOwner", "type": "address" } ], "name": "transferOwnership", "outputs": [], "payable": false, "stateMutability": "nonpayable", "type": "function" }, { "payable": true, "stateMutability": "payable", "type": "fallback" }, { "anonymous": false, "inputs": [ { "indexed": false, "name": "time", "type": "uint256" }, { "indexed": false, "name": "target", "type": "address" } ], "name": "UnableToDispatchTo", "type": "event" } ]




