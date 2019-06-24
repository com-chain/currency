pragma solidity ^0.4.11;

/********************************************************


Configuration: 

- pledge function: you have to define if it is possible to pledge negative amount
                   by switchng between the two "check for overflow" lines

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
contract Racine is owned {

  /* Name and symbol (for ComChain internal use) */
  string  public standard       = 'Racine';
  string  public name           = "Racine";
  string  public symbol         = "Racine";
  
  /* Total amount pledged (Money supply) */
  int256  public amountPledged  = 0;
  
  /* Tax on the transactions  */
  /*    payed to "Person" (0) account  */
  int16   public percent        = 0;
  /*    payed to "Business" (1) account */
  int16   public percentLeg     = 0;
  /* The account the tax are send to */
  address public txAddr;

  /* Ensure that the accounts have enough ether to pass transactions */
  /* For this it define the limit bellow which ether is added to the account */
  uint256 minBalanceForAccounts = 1000000000000000000;  
  /* And the number of ether to be added */  
  uint256 public refillSupply   = 10;
  
  /* Panic button: allows to block any currency transfert */
  bool public actif            = true;
  
  /*  For initialization purpose: */
  bool firstAdmin              = true;

  /* Account property: */
  mapping (address => int256) public accountType;               // Account type 2 = special account 1 = Business 0 = Personal
  mapping (address => bool) public accountStatus;               // Account status
  mapping (address => int256) public balanceEL;                 // Balance in coins
   
  /* Allowance, Authorization and Request:*/
  
  mapping (address => mapping (address => int256)) public allowed;     // Array of allowed payements
  mapping (address => address[]) public allowMap;
  
  mapping (address => mapping (address => int256)) public requested;   // Array of requested payments
  mapping (address => address[]) public reqMap;
  
  mapping (address => mapping (address => int256)) public delegated;    // Array of authorized accounts
  mapping (address => address[]) public delegMap;
  
  mapping (address => mapping (address => int256)) public myAllowed;     // Array of allowed payements
  mapping (address => address[]) public myAllowMap;
  
  mapping (address => mapping (address => int256)) public myRequested;   // Array of requested payments
  mapping (address => address[]) public myReqMap;
  
  mapping (address => mapping (address => int256)) public myDelegated;   // Array of authorized accounts
  mapping (address => address[]) public myDelegMap;
  
  /* Keep trace of accepted / rejected payment requests */
  mapping (address => mapping (address => int256)) accepted;    // Array of requested payments accepted
  mapping (address => address[]) public acceptedMap;
  
  mapping (address => mapping (address => int256)) rejected;    // Array of requested payments rejected
  mapping (address => address[]) public rejectedMap;

  /* Event to notify the clients */
  /* Account property */
  event SetAccountParams(uint256 time, address target, bool accstatus, int256 acctype, int256 debit, int256 credit);
  event CreditLimitChange(uint256 time, address target, int256 amount);
  event DebitLimitChange(uint256 time, address target, int256 amount);
  event Refilled(uint256 time, address target, uint256 balance, uint256 limit);
  
  /* Token transfert */
  event Pledge(uint256 time, address indexed to, int256 recieved);
  event Transfer(uint256 time, address indexed from, address indexed to, int256 sent, int256 tax, int256 recieved);
  event TransferCredit(uint256 time, address indexed from, address indexed to, int256 sent, int256 tax, int256 recieved);
  
  /* Allowance and Authorization*/
  event Approval(uint256 time, address indexed from, address indexed to, int256 value);
  event Delegation(uint256 time, address indexed from, address indexed to, int256 value);
  
  event Rejection(uint256 time, address indexed from, address indexed to, int256 value);

  /****************************************************************************/ 
  /***** Contract creation *******/
  /* Initializes contract */
   constructor(address taxAddress, int8 taxPercent, int8 taxPercentLeg) public {
    txAddr = taxAddress;
    percent = taxPercent;
    percentLeg = taxPercentLeg;
    setFirstAdmin();
  }
  
  /* INTERNAL - Set the first admin and ensure that this account is of the good type and actif.*/
  function setFirstAdmin() internal {
    if (firstAdmin == false) revert();
    accountType[owner] = 2;
    accountStatus[owner] = true;
    firstAdmin = false;
  }
  
  /***** Ether handling *******/
  /* The contract dispatch Eth to the account: it must be able to recieve them */
  function () public payable{}

  /* In the case we need to retrieve Eth from the contract. Sent it back to the Owner */
  function repay(uint _amount) public onlyOwner {
      uint amount = _amount * 1 ether;
      owner.transfer(amount); 
  }

  /***** Contract administration *******/
  /* Transfert ownership */
  function transferOwnership(address newOwner) public onlyOwner {
    accountType[newOwner] = 2;
    accountStatus[newOwner] = true;
    owner = newOwner;
  }
  
  /* Set the threshold to refill an account (in ETH)*/
  function setRefillLimit(uint256 _minimumBalance) public onlyOwner {
    minBalanceForAccounts = _minimumBalance * 1 ether;
  }

  /* Get the total amount of coin (Money supply) */
  function totalSupply() public constant returns (int256 total) {
    total = amountPledged;
  }

  /* Panic button: allows to block any currency transfert */
  function setContractStatus(bool _actif) public onlyOwner {
      actif=_actif;
  }
  
  /* INTERNAL - Top up function: Check that an account has enough ETH if not send some to it */
  function topUp(address _addr) internal {
    uint amount = refillSupply * 1 ether;
    if (_addr.balance < minBalanceForAccounts){
      if(_addr.send(amount)) {
        emit Refilled(now, _addr, _addr.balance, minBalanceForAccounts);
      }
    }
  }
  
  /* INTERNAL - Call the Top up function for the message sender */
  function refill() internal {
    topUp(msg.sender);
  }
  
  /****** Tax handling *******/
  /* Get the account to which the tax is paid */
  function getTaxAccount() public constant returns (address) {
    return txAddr;
  }

  /* Set the account to which the tax is paid */
  function setTaxAccount(address _target) public onlyOwner {
    txAddr = _target;
  }
  
  /* Get the tax percentage for transaction to a person (0) account */
  function getTaxPercent() public constant returns (int16) {
    return percent;
  }

  /* Set the tax percentage for transaction to a person (0) account */
  function setTaxPercent(int16 _value) public onlyOwner {
    if (_value < 0) revert();
    if (_value > 10000) revert();
    percent = _value;
  }
  
  /* Get the tax percentage for transaction to a buisness (1) account */
  function getTaxPercentLeg() public pure returns (int16) {
    return 0;
  }
  
  /****** Account handling *******/

  /* Get the total balance of an account */
  function balanceOf(address _from) public constant returns (int256 amount){
     return  balanceEL[_from];
  }
  
  /* Change account's property */  
  function setAccountParams(address _targetAccount, bool _accountStatus, int256 _accountType, int256 , int256 ) public {
  
    // Ensure that the sender is an admin and is not blocked
    if (msg.sender!=owner){
        if (accountType[msg.sender] < 2  || !accountStatus[msg.sender]) revert();
    }
    
    accountStatus[_targetAccount] = _accountStatus;
    
    // Prevent changing the Type of an Admin (2) account
    if (accountType[_targetAccount] != 2){
        accountType[_targetAccount] = _accountType;
        
    }
    
    emit SetAccountParams(now, _targetAccount, _accountStatus, accountType[_targetAccount], 0, 0);
    
    // ensure the ETH level of the account
    topUp(_targetAccount);
    topUp(msg.sender);
  }
  
 
  /****** Coin and Barter transfert *******/ 
  /* Coin creation (Nantissement) */
  function pledge(address _to, int256 _value)  public {
    if (accountType[msg.sender] < 2) revert();                                  // Check that only Special Accounts (2) can pledge
    if (!accountStatus[msg.sender]) revert();                                   // Check that only non-blocked account can pledge
    if (balanceEL[_to] + _value < 0) revert();                                  // Check for overflows
    // if (balanceEL[_to] + _value < balanceEL[_to] ) revert();                    // Check for overflows & avoid negative pledge
    balanceEL[_to] += _value;                                                   // Add the amount to the recipient
    amountPledged += _value;                                                    // and to the Money supply
    
    emit Pledge(now, _to, _value);
    // ensure the ETH level of the account
    topUp(_to);
    topUp(msg.sender);
  }
  
  
    /* Make Direct payment in currency*/
  function transfer(address _to, int256 _value) public {
    payNant(msg.sender,_to,_value);
  }

 
  
  /* Transfert "on behalf of" of Coin and Mutual Credit (delegation) */
  /* Make Transfert "on behalf of" in coins*/
  function transferOnBehalfOf(address _from, address _to, int256 _value)public  {
    if (delegated[_from][msg.sender] < _value) revert();
    payNant(_from,_to,_value);
  }
  


  /* Transfert request of Coin and Mutual Credit (delegation & pay request)*/
  // Send _value Coin from address _from to the sender
  function transferFrom(address _from, int256 _value) public {
   if (allowed[_from][msg.sender] >= _value && balanceEL[_from]>=_value) {
     payNant(_from, msg.sender,_value);   
     
     // substract the value from the allowed
     updateAllowed(_from, msg.sender, -_value);

    } else {
      insertRequest(_from,  msg.sender, _value);                   // if allowed is not enough (or do not exist) create a request
    }
  }
  
  
  
  
  
  
  
  /* INTERNAL - Coin transfert  */
  function payNant(address _from,address _to, int256 _value) internal {
    if (!actif) revert();  // panic lock
    if (!accountStatus[_from]) revert();  //Check neither of the Account are locked
    if (!accountStatus[_to]) revert();
    
    // compute the tax
    int16 tax_percent = percent;
    if (accountType[_to] == 1){
        tax_percent = percentLeg;
    }
    int256 tax = (_value * tax_percent) / 10000;
    
    // compute the recieved ammount
    int256 amount = _value - tax;

    if (!checkEL(_from, amount + tax)) revert(); // check coin availability
    if (balanceEL[_to] + amount < balanceEL[_to]) revert(); //overflow check
    
    // Do the transfert
    balanceEL[_from] -= amount + tax;         // Subtract from the sender
    balanceEL[_to] += amount;    
    balanceEL[txAddr] += tax;
     
    emit Transfer(now, _from, _to, amount+tax, tax, amount);        // Notify anyone listening that this transfer took place
    // ensure the ETH level of the account
    topUp(_to);
    topUp(_from);
  } 
  
 
  
  /* INTERNAL - Check the sender has enough coin to do the transfert */
  function checkEL(address _addr, int256 _value) internal view returns (bool)  {
    int256 checkBalance = balanceEL[_addr] - _value;
    if (checkBalance < 0) {
      revert();
    } else {
      return true;
    }
  }

 
  

  /****** Allowance *******/ 
  /* Allow _spender to withdraw from your account, multiple times, up to the _value amount.  */
  /* If called again the _amount is added to the allowance, if amount is negatif the allowance is deleted  */
  function approve(address _spender, int256 _amount) public returns (bool success) {
    if (!accountStatus[msg.sender]) revert(); // Check the sender not to be blocked
    if (_amount>=0){
        if ( allowed[msg.sender][_spender] == 0 ) {
            allowMap[msg.sender].push(_spender);
            myAllowMap[_spender].push(msg.sender);
        }
        allowed[msg.sender][_spender] += _amount;
        myAllowed[_spender][msg.sender] += _amount;
    } else { // delete allowance
        bool found = false;
	    uint i;
        for (i = 0; i<allowMap[msg.sender].length; i++){
                if (!found && allowMap[msg.sender][i] == _spender){
                    found=true;
                }
                
                if (found){
                    if (i < allowMap[msg.sender].length-1){
                         allowMap[msg.sender][i] = allowMap[msg.sender][i+1];
                    }
                }
        }
            
        if (found){
                 delete allowMap[msg.sender][allowMap[msg.sender].length-1]; // remove the last record from the mapping array
                 allowMap[msg.sender].length--;                            // adjust the length of the mapping array    
                 allowed[msg.sender][_spender] = 0;                          // remove the record from the mapping
        }
        
        // delete my allowance
        found = false;
        for (i = 0; i<myAllowMap[_spender].length; i++){
                if (!found && myAllowMap[_spender][i] == msg.sender){
                    found=true;
                }
                
                if (found){
                    if (i < myAllowMap[_spender].length-1){
                         myAllowMap[_spender][i] = myAllowMap[_spender][i+1];
                    }
                }
        }
            
        if (found){
                 delete myAllowMap[_spender][myAllowMap[_spender].length-1]; // remove the last record from the mapping array
                 myAllowMap[_spender].length--;                            // adjust the length of the mapping array    
                 myAllowed[_spender][msg.sender] = 0;                          // remove the record from the mapping
        }
    }
    emit Approval(now, msg.sender, _spender, _amount);
    topUp(msg.sender);
    topUp(_spender);
    return true;
  }
  
  /* INTERNAL - Allow the spender to decrasse the allowance */
  function updateAllowed(address _from, address _to, int256 _value) internal {
    if (!accountStatus[msg.sender]) revert();       // Ensure that accounts are not locked 
    if (!accountStatus[_from]) revert();   
    if (msg.sender != _to) revert();                // Ensure that the message come from the _spender
    if (_value > 0) revert();                       // Ensure that the allowance cannot de augmented
    if (allowed[_from][_to] + _value < 0) revert(); // Ensure that the resulting allowance is not <0
    allowed[_from][_to] += _value; 
    topUp(_to);
    topUp(_from);
  }
  
  /* Count the number of allowances define on the _owner account */
  function allowanceCount(address _owner) public constant returns (uint256){
    return allowMap[_owner].length;
  }

  /* Count the number of allowance that the _spender can use */
  function myAllowanceCount(address _spender) public constant returns (uint256){
    return allowMap[_spender].length;
  }
  
  /** list the allowances define on a given _owner account  **/
  function allowance(address _owner, address _spender) public constant returns (int256 remaining) {
    return allowed[_owner][_spender];
  }

  function getAllowance(address _owner, uint index) public constant returns (address _to) {
    return allowMap[_owner][index];
  }





  /** list the allowances that a _spender account can use **/
  function myAllowance(address _spender, address _owner) public constant returns (int256 remaining) {
    return allowed[_spender][_owner];
  }

  function myGetAllowance(address _spender, uint index) public constant returns (address _to) {
    return allowMap[_spender][index];
  }

  
  
  /****** Delegation *******/ 
  /* Allow _spender to pay on behalf of you from your account, multiple times, each transaction bellow the limit. */
  /* If called again the limit is replaced by the new _amount, if _amount is 0 the delegation is removed */
  function delegate(address _spender, int256 _amount) public {
    if (!accountStatus[msg.sender]) revert();
    
    if (_amount>0){
        if (delegated[msg.sender][_spender] == 0) {
          delegMap[msg.sender].push(_spender);
          myDelegMap[_spender].push(msg.sender);
        }
        delegated[msg.sender][_spender] = _amount;
        myDelegated[_spender][msg.sender] = _amount;
    } else {
        // delete delegation
        bool found = false;
	    uint i;
        for ( i = 0; i<delegMap[msg.sender].length; i++){
                if (!found && delegMap[msg.sender][i] == _spender){
                    found=true;
                }
                
                if (found){
                    if (i < delegMap[msg.sender].length-1){
                         delegMap[msg.sender][i] = delegMap[msg.sender][i+1];
                    }
                }
        }
            
        if (found){
                 delete delegMap[msg.sender][delegMap[msg.sender].length-1]; // remove the last record from the mapping array
                 delegMap[msg.sender].length--;                            // adjust the length of the mapping array    
                 delegated[msg.sender][_spender] = 0;                          // remove the record from the mapping
        }
        
        // delete my delegation
        found = false;
        for ( i = 0; i<myDelegMap[_spender].length; i++){
                if (!found && myDelegMap[_spender][i] == msg.sender){
                    found=true;
                }
                
                if (found){
                    if (i < myDelegMap[_spender].length-1){
                         myDelegMap[_spender][i] = myDelegMap[_spender][i+1];
                    }
                }
        }
            
        if (found){
                 delete myDelegMap[_spender][myDelegMap[_spender].length-1]; // remove the last record from the mapping array
                 myDelegMap[_spender].length--;                            // adjust the length of the mapping array    
                 myDelegated[_spender][msg.sender] = 0 ;                         // remove the record from the mapping
        }
        
        
    }
    topUp(msg.sender);
    topUp(_spender);
    emit Delegation(now, msg.sender, _spender, _amount);
  }
  
  /* Count the number of delegation define on the _owner account */
  function delegationCount(address _owner) public constant returns (uint256){
    return delegMap[_owner].length;
  }

  /* Count the number of delegation that the _spender can use */
  function myDelegationCount(address _spender) public constant returns (uint256){
    return myDelegMap[_spender].length;
  }
  
  /** list the delegation define on a given _owner account  **/
  function delegation(address _owner, address _spender)public  constant returns (int256 remaining) {
    return delegated[_owner][_spender];
  }

  function getDelegation(address _owner, uint index) public constant returns (address _to) {
    return delegMap[_owner][index];
  }

 
  /** list the delegations that a _spender account can use **/
  function myDelegation(address _spender, address _owner) public constant returns (int256 remaining) {
    return myDelegated[_spender][_owner];
  }

  function myGetDelegation(address _spender, uint index)public  constant returns (address _to) {
    return myDelegMap[_spender][index];
  }

  
  
  /****** Payment Request *******/ 
  /* Add Request*/
  function insertRequest( address _from,  address _to, int256 _amount) public {
    if (!accountStatus[_to]) revert(); // Check the creator not to be blocked
   
    if (requested[_from][_to] == 0) {
      reqMap[_from].push(_to);
      myReqMap[_to].push(_from);
    }
    
    if (requested[_from][_to] + _amount < 0) revert();
    requested[_from][_to] += _amount;
    myRequested[_to][_from] += _amount;
    topUp(_to);
    topUp(_from);
  }
  
  /* INTERNAL - Allow the account who pay to decrasse the request amount */
  function updateRequested(address _from, address _to, int256 _value) internal {
    if (!accountStatus[msg.sender]) revert();         // Ensure that accounts are not locked 
    if (!accountStatus[_to]) revert();   
    if (msg.sender != _from) revert();                // Ensure that the message come from the account who pay
    if (_value > 0) revert();                         // Ensure that the request cannot de augmented
    if (requested[_from][_to] + _value < 0) revert(); // Ensure that the resulting request is not <0
    requested[_from][_to] += _value;
    myRequested[_to][_from] += _value;
    topUp(_to);
    topUp(_from);
  }
  
  /* INTERNAL - Allow the account who pay to delete the request  */
  function clear_request(address _from, address _to) internal {
    if (msg.sender != _from) revert();                // Ensure that the message come from the account who pay
    bool found;
      uint i;
      if (requested[_from][_to]<=0){
            found = false;
            for (i = 0; i<reqMap[_from].length; i++){
                if (!found && reqMap[_from][i] == _to){
                    found=true;
                }
                
                if (found){
                    if (i < reqMap[_from].length-1){
                         reqMap[_from][i] = reqMap[_from][i+1];
                    }
                }
            }
            
            if (found){
                 delete reqMap[_from][reqMap[_from].length-1]; // remove the last record from the mapping array
                 reqMap[_from].length--;                            // adjust the length of the mapping array    
                 requested[_from][_to] = 0 ;                         // remove the record from the mapping
            }
      }
      
      if (myRequested[_to][_from]<=0){
            found = false;
            for (i = 0; i<myReqMap[_to].length; i++){
                if (!found && myReqMap[_to][i] == _from){
                    found=true;
                }
                
                if (found){
                    if (i < myReqMap[_to].length-1){
                         myReqMap[_to][i] = myReqMap[_to][i+1];
                    }
                }
            }
            
            if (found){
                 delete myReqMap[_to][myReqMap[_to].length-1]; // remove the last record from the mapping array
                 myReqMap[_to].length--;                       // adjust the length of the mapping array    
                 myRequested[_to][_from] = 0 ;               // remove the record from the mapping
            }
      }
    topUp(_to);
    topUp(_from);
 }
  
 /* Count the number of request define on the _owner account */
 function requestCount(address _owner) public constant returns (uint256){
    return reqMap[_owner].length;
  }

  /* Count the number of request issued by the _spender account */
  function myRequestCount(address _spender) public constant returns (uint256){
    return myReqMap[_spender].length;
  }
  


  /** list the open pay request define for a given _owner account  **/
  function request(address _owner, address _spender) public constant returns (int256 remaining) {
    return requested[_owner][_spender];
  }

  function getRequest(address _owner, uint index) public constant returns (address _to) {
    return reqMap[_owner][index];
  }


  /** list the open request that a _spender account has defined **/
  function myRequest(address _spender, address _owner) public constant returns (int256 remaining) {
    return myRequested[_spender][_owner];
  }

  function myGetRequest(address _spender, uint index) public constant returns (address _to) {
    return myReqMap[_spender][index];
  }


  /** list the accepted request which have been created by a _owner account **/ 
  function acceptedAmount(address _owner, address _spender) public constant returns (int256 remaining) {
    return accepted[_owner][_spender];
  }
  
  function acceptedCount(address _owner) public constant returns (uint256){
    return acceptedMap[_owner].length;
  }

  function getAccepted(address _owner, uint index) public constant returns (address _to) {
    return (acceptedMap[_owner][index]);
  }



  /** list the rejected request which have been created by a _owner account **/ 
  function rejectedAmount(address _owner, address _spender) public constant returns (int256 remaining) {
    return rejected[_owner][_spender];
  }

  function getRejected(address _owner, uint index) public constant returns (address _to) {
    return (rejectedMap[_owner][index]);
  }

  function rejectedCount(address _owner)public  constant returns (uint256){
    return rejectedMap[_owner].length;
  }

  
  
  /****  Request handling  ****/
  /* Accept and pay in coin a payment request (also delete the request if needed and add it to the accepted list) */
  function payRequest(address _to, int256 _value) public {
    payNant(msg.sender,_to,_value);
    updateRequested(msg.sender, _to, -_value);
    
    if (accepted[_to][msg.sender] == 0) {
         acceptedMap[_to].push(msg.sender);
    }
    accepted[_to][msg.sender] += _value;
   
    clear_request(msg.sender,_to);
  }
  
  
 
  

  /* Discard a payement request put it into the rejected request. */
  function cancelRequest(address _to)public {
    if (!accountStatus[msg.sender]) revert();
    int256 amount = requested[msg.sender][_to];
    if (amount>0){
        if (rejected[_to][msg.sender] == 0) {
               rejectedMap[_to].push(msg.sender);
        }
        
        updateRequested(msg.sender, _to, -amount);
        rejected[_to][msg.sender] += amount;
        
        emit Rejection(now, msg.sender, _to, amount);
        clear_request(msg.sender, _to);
    }
  }
  
  
  /* Discard acceptation information */
  function discardAcceptedInfo(address _spender) public {
    if (!accountStatus[msg.sender]) revert();
    bool found = false;
    for (uint i = 0; i<acceptedMap[msg.sender].length; i++){
        if (!found && acceptedMap[msg.sender][i] == _spender){
            found=true;
        }
        
        if (found){
            if (i < acceptedMap[msg.sender].length-1){
                 acceptedMap[msg.sender][i] = acceptedMap[msg.sender][i+1];
            }
        }
    }
    
    if (found){
         delete acceptedMap[msg.sender][acceptedMap[msg.sender].length-1]; // remove the last record from the mapping array
         acceptedMap[msg.sender].length--;                                 // adjust the length of the mapping array    
         accepted[msg.sender][_spender] = 0;                                // remove the record from the mapping
    }
  }
  
  /* Discard rejected incormation */
  function discardRejectedInfo(address _spender)public{
    if (!accountStatus[msg.sender]) revert();
    bool found = false;
    for (uint i = 0; i<rejectedMap[msg.sender].length; i++){
        if (!found && rejectedMap[msg.sender][i] == _spender){
            found=true;
        }
        
        if (found){
            if (i < rejectedMap[msg.sender].length-1){
                 rejectedMap[msg.sender][i] = rejectedMap[msg.sender][i+1];
            }
        }
    }
    
    if (found){
         delete rejectedMap[msg.sender][rejectedMap[msg.sender].length-1]; // remove the last record from the mapping array
         rejectedMap[msg.sender].length--;                                 // adjust the length of the mapping array    
         rejected[msg.sender][_spender] = 0;                               // remove the record from the mapping
    }
  }
}



