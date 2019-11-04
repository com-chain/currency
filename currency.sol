pragma solidity ^0.4.11;

/********************************************************


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
  The existing interface must remain unchanged !
***********************************************/
contract coeur is owned {

  /* Name and symbol (for ComChain internal use) */
  string  public standard       = 'Coeur';
  string  public name           = "Coeur";
  string  public symbol         = "Coeur";
  
  /* Total amount pledged (Money supply) */
  int256  public amountPledged  = 0;
  
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
  
  /*  melting property */
  uint256 partenaire_association_taux = 50;   // % transmis
  uint256 partenaire_employe_taux = 25;       // % transmis
  uint256 fonte_taux = 5;                     // % fonte
  
  

  /* Account property: */
  mapping (address => int256) public accountType;               // Account type 2 = special account 1 = Business 0 = Personal 3=association
  mapping (address => bool) public accountStatus;               // Account status
  mapping (address => int256) public  balanceEL ;               // Balance in coins
  mapping (address => bool) internal embeded;                     // Account already embeded
  address[] internal members;                                   // list of members
  uint256 member_number =0;
 

  /* Event to notify the clients */
  /* Account property */
  event SetAccountParams(uint256 time, address target, bool accstatus, int256 acctype, int256 debit, int256 credit);
  event Refilled(uint256 time, address target, uint256 balance, uint256 limit);
  
  /* Token transfert */
  event Pledge(uint256 time, address indexed to, int256 recieved);
  event Transfer(uint256 time, address indexed from, address indexed to, int256 sent, int256 tax, int256 recieved);
 

 
 
 
  /****************************************************************************/ 
  /***** Contract creation *******/
  /* Initializes contract */
   constructor(address taxAddress, int8 , int8 ) public {
    txAddr = taxAddress;
    
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
  function getTaxPercent() public pure returns (int16) {
    return 0;
  }

  /* Set the tax percentage for transaction to a person (0) account */
  function setTaxPercent(int16) public view onlyOwner {
    revert();
  }
  
  /* Get the tax percentage for transaction to a buisness (1) account */
  function getTaxPercentLeg() public pure returns (int16) {
    return 0;
  }
  
  /* Set the tax percentage for transaction to a buisness (1) account */ 
  function setTaxPercentLeg(int16) public view onlyOwner {
    revert();
  }
  
  /******** Gestion fonte ***************/
  /* Get the melting through transfert from "partnair" (1) to "association" (3) */
  function GetTransferedRatePartAsso() public constant returns (int256) {
    return int256(partenaire_association_taux);
  }
  /* Set  the melting through transfert from "partnair" (1) to "association" (3) */
  function SetTransferedRatePartAsso(int256 _value) public onlyOwner {
    if (_value<0 || _value>100) revert();
    partenaire_association_taux = uint256(_value);
  }
  
  /* Get the melting through transfert from "partnair" (1) to "employee" (0) */
  function GetTransferedRatePartEmploy() public constant returns (int256) {
    return int256(partenaire_employe_taux);
  }
  /* Set  the melting through transfert from "partnair" (1) to "employee" (0) */
  function SetTransferedRatePartEmploy(int256 _value) public onlyOwner {
    if (_value<0 || _value>100) revert();
    partenaire_employe_taux = uint256(_value);
  }
  
  /* Get the melting Rate */
  function GetMeltingRateAsso() public constant returns (int256) {
    return int256(fonte_taux);
  }
  
  /* Set  the melting rate*/
  function SetMeltingRate(int256 _value) public onlyOwner {
    if (_value<0 || _value>100) revert();
    fonte_taux = uint256(_value);
  }
  
  
   /***Member counting***/
  function  embed(address _member) internal {
    if (!embeded[_member]){
        embeded[_member] = true;
        member_number = members.push(_member);
    }
  }
   
  
  function melt() public onlyOwner {
        for (uint i=0; i<member_number; i++) {
           balanceEL[members[i]] -= (int256(fonte_taux) * balanceEL[members[i]])/100;
        }
        
        // adjust the total of coin 
        amountPledged-= (int256(fonte_taux) * amountPledged)/100;
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
        if (accountType[msg.sender] != 2  || !accountStatus[msg.sender]) revert();
    }
    
    accountStatus[_targetAccount] = _accountStatus;
    
    // Prevent changing the Type of an Admin (2) account
    if (accountType[_targetAccount] != 2){
    
        // 0-benevole
        // 1-partenaire/employe
        // 2-admin
        // 3-association
    
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
    if (accountType[msg.sender] != 2) revert();                                 // Check that only Special Accounts (2) can pledge
    if (!accountStatus[msg.sender]) revert();                                   // Check that only non-blocked account can pledge
    if (accountType[_to] != 3) revert();                                        // Only the "association" (3) can recieve pledge  
    if (!accountStatus[_to]) accountStatus[_to]=true;                           // unlock destinary account if needed
    if (balanceEL[_to] + _value < 0) revert();                                  // Check for overflows
    balanceEL[_to] += _value;                                                   // Add the amount to the recipient
    amountPledged += _value;                                                    // and to the Money supply
    embed(_to);                                                                 // ensure the account is listed for the coin melting
    emit Pledge(now, _to, _value);
    // ensure the ETH level of the account
    topUp(_to);
    topUp(msg.sender);
  }
  
  
    /* Make Direct payment in currency*/
  function transfer(address _to, int256 _value) public {
    payNant(msg.sender,_to,_value);
  }

  /* Make Direct payment in CM*/
  function transferCM(address , int256 ) public pure{
   // No CM
   revert();
  }
  
  /* Transfert "on behalf of" of Coin and Mutual Credit (delegation) */
  /* Make Transfert "on behalf of" in coins*/
  function transferOnBehalfOf(address , address , int256 )public pure {
    // No Delegation
   revert();
  }
  
  /* Make  Transfert "on behalf of" in Mutual Credit */
  function transferCMOnBehalfOf(address , address , int256 )public pure{
    // No CM
   revert();
  }

  /* Transfert request of Coin and Mutual Credit (delegation & pay request)*/
  // Send _value Coin from address _from to the sender
  function transferFrom(address , int256 ) public pure {
   // No Request
   revert();
  }
  
  // Send _value Mutual Credit from address _from to the sender
  function transferCMFrom(address , int256 ) public pure{
    // No Request
   revert();
  }
  
  
  
  
  
  /* INTERNAL - Coin transfert  */
  function payNant(address _from,address _to, int256 _value) internal {
    if (!actif) revert();                                                       // panic lock
    if (!accountStatus[_from]) revert();                                        // Check sender is not locked
    
    
    int256 transmitted = _value;
   
   
    if (accountType[_from] == 3){                                               // Assoc (3) -> benevole (0)
        if (accountType[_to] != 0) revert();
    }
    
    if (accountType[_from] == 0){                                               // benevole (0) -> parteneair (1)
        if (accountType[_to] != 1) revert();
    }
    
    if (accountType[_from] == 1){                                               //  parteneair (1) ->
        if (accountType[_to] == 3) {                                            // -> association (3) avec fonte
            transmitted = (int256(partenaire_association_taux)*_value)/100;
        } else if (accountType[_to] == 0) {                                     // -> employe  (0) avec fonte
            transmitted = (int256(partenaire_employe_taux)*_value)/100;
        } else revert();                              
    }
    
    if (!checkEL(_from, _value)) revert();                                      // check coin availability
    if (balanceEL[_to] + transmitted < balanceEL[_to]) revert();                // overflow check
    
    // Do the transfert
    balanceEL[_from] -= _value ;                                                // Subtract from the sender
    balanceEL[_to] += transmitted;                                              // add to the destinary
    amountPledged -= _value - transmitted;                                      // adjust the total coin
    
    if (!accountStatus[_to]) accountStatus[_to]=true;                           // unlock destinary account if needed 
    emit Transfer(now, _from, _to, _value, 0, transmitted);                     // Notify anyone listening that this transfer took place
   
    embed(_to);                                                                 // ensure the account is listed for the coin melting
    topUp(_to);                                                                 // ensure the ETH level of the account
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
  function approve(address, int256) public pure returns (bool success) {
    return false;
  }
  

  
  /* Count the number of allowances define on the _owner account */
  function allowanceCount(address ) public pure returns (uint256){
    return 0;
  }

  /* Count the number of allowance that the _spender can use */
  function myAllowanceCount(address ) public pure returns (uint256){
    return 0;
  }
  
  /** list the allowances define on a given _owner account  **/
  function allowance(address , address ) public pure returns (int256 remaining) {
    return 0;
  }

  function getAllowance(address , uint ) public pure returns (address _to) {
     return address(0); 
  }

  /** list the allowances that a _spender account can use **/
  function myAllowance(address , address ) public pure returns (int256 remaining) {
    return 0;
  }

  function myGetAllowance(address , uint ) public pure returns (address _to) {
     return address(0); 
  }

  
  
  /****** Delegation *******/ 
  /* Allow _spender to pay on behalf of you from your account, multiple times, each transaction bellow the limit. */
  /* If called again the limit is replaced by the new _amount, if _amount is 0 the delegation is removed */
  function delegate(address , int256 ) public pure {
    revert();
  }
  
  /* Count the number of delegation define on the _owner account */
  function delegationCount(address ) public pure  returns (uint256){
    return 0;
  }

  /* Count the number of delegation that the _spender can use */
  function myDelegationCount(address ) public pure  returns (uint256){
    return 0;
  }
  
  /** list the delegation define on a given _owner account  **/
  function delegation(address , address )public  pure  returns (int256 remaining) {
    return 0;
  }

  function getDelegation(address , uint ) public pure  returns (address _to) {
     return address(0); 
  }

  /** list the delegations that a _spender account can use **/
  function myDelegation(address , address ) public pure  returns (int256 remaining) {
    return 0;
  }

  function myGetDelegation(address , uint )public  pure  returns (address _to) {
    return address(0); 
  }

  
  
  /****** Payment Request *******/ 
  /* Add Request*/
  function insertRequest( address ,  address , int256 ) public pure {
    revert();
  }

  

  
 /* Count the number of request define on the _owner account */
 function requestCount(address ) public pure  returns (uint256){
    return 0;
  }

  /* Count the number of request issued by the _spender account */
  function myRequestCount(address ) public pure  returns (uint256){
    return 0;
  }
  


  /** list the open pay request define for a given _owner account  **/
  function request(address , address ) public pure  returns (int256 remaining) {
    return 0;
  }

  function getRequest(address , uint ) public pure  returns (address _to) {
    return address(0); 
  }


  /** list the open request that a _spender account has defined **/
  function myRequest(address , address ) public pure  returns (int256 remaining) {
    return 0;
  }

  function myGetRequest(address , uint ) public pure  returns (address _to) {
    return address(0); 
  }


  /** list the accepted request which have been created by a _owner account **/ 
  function acceptedAmount(address , address ) public pure  returns (int256 remaining) {
    return 0;
  }
  
  function acceptedCount(address ) public pure  returns (uint256){
    return 0;
  }

  function getAccepted(address , uint ) public pure  returns (address _to) {
    return address(0); 
  }



  /** list the rejected request which have been created by a _owner account **/ 
  function rejectedAmount(address , address ) public pure  returns (int256 remaining) {
    return 0;
  }

  function getRejected(address , uint ) public pure  returns (address) {
   return address(0); 
  }

  function rejectedCount(address )public  pure  returns (uint256){
    return 0;
  }

  
  
  /****  Request handling  ****/
  /* Accept and pay in coin a payment request (also delete the request if needed and add it to the accepted list) */
  function payRequest(address , int256 ) public pure {
    revert();
  }
  
  
  /* Accept and pay in mutual credit a payment request (also delete the request if needed and add it to the accepted list) */
  function payRequestCM(address , int256 ) public pure{
    revert();
  }
  

  /* Discard a payement request put it into the rejected request. */
  function cancelRequest(address )public pure{
    revert();
  }
  
  
  /* Discard acceptation information */
  function discardAcceptedInfo(address ) public pure{
    revert();
  }
  
  /* Discard rejected incormation */
  function discardRejectedInfo(address ) public pure{
    revert();
  }
}



