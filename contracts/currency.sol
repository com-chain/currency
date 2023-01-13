pragma solidity  >=0.4.18 <0.4.23;

/********************************************************

This contract set is a template for currency's contracts.

The following functionality are implemented (details in the code):
- Currency administration
- Account management
- Payments
- Reverse Payment
- Automatic approval of reverse payment
- Payement on behalf of an other user


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
    if (msg.sender != owner)
        revert();  // dev: require to be owner
    _;
  }
}


/***********************************************
  Main contract.
***********************************************/
contract cccur is owned {

  /* Name and symbol (for ComChain internal use) */
  string  public name           = "";
  string  public symbol         = "";
  string  public version        = "2.0";

  /* Total amount pledged (Money supply) */
  int256  public amountPledged  = 0;

  bool public automaticUnlock = false;

  /* Tax on the transactions  */
  /*    payed to "Person" (0) account  */
  int16   public percent        = 0;
  /*    payed to "Business" (1) account */
  int16   public percentLeg     = 0;
  /* The account the tax are send to */
  address public txAddr;

  /* Ensure that the accounts have enough ether to pass transactions */
  /* For this it define the limit bellow which ether is added to the account */
  uint256 minBalanceForAccounts = 1 ether /100;
  /* And the number of ether to be added */
  uint256 public refillSupply   = 10;

  /* Panic button: allows to block any currency transfer */
  bool public actif            = true;

  /*  For initialization purpose: */
  bool firstAdmin              = true;

  /* Account property: */
  mapping (address => int256) public accountType;               // Account type 4 = Property Admin, 3 = Pledge Admin, 2 = Super Admin, 1 = Business, 0 = Personal
  mapping (address => bool) public accountStatus;               // Account status
  mapping (address => bool) public accountAlreadyUsed;          // if False the account is new
  mapping (address => int256) public balanceEL;                 // Balance in coins
  mapping (address => int256) public balanceCM;                 // Balance in Mutual credit
  mapping (address => int256) public limitCredit;               // Min limit (minimal accepted CM amount expected to be 0 or <0 )
  mapping (address => int256) public limitDebit;                // Max limit  (maximal accepted CM amount expected to be 0 or >0 )
  mapping (address => address) public requestReplacementFrom;   // Pending replacement request the key is the Account to be replaced
  mapping (address => address) public newAddress;               // Address which replaces the current one

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

  /* Token transfer */
  event Pledge(uint256 time, address indexed to, int256 received);
  event Transfer(uint256 time, address indexed from, address indexed to, int256 sent, int256 tax, int256 received);
  event TransferCredit(uint256 time, address indexed from, address indexed to, int256 sent, int256 tax, int256 received);

  /* Allowance and Authorization*/
  event Approval(uint256 time, address indexed from, address indexed to, int256 value);
  event Delegation(uint256 time, address indexed from, address indexed to, int256 value);

  event Rejection(uint256 time, address indexed from, address indexed to, int256 value);

  /* Account being replaced by a new one */
  event AccountReplaced(uint256 time, address indexed oldAdd, address indexed newAdd, int256 indexed accstatus);

  /****************************************************************************/
  /***** Contract creation *******/
  /* Initializes contract */
   constructor(string _name, string _symbol) public {
    txAddr = msg.sender;
    name = _name;
    symbol = _symbol;
    setFirstAdmin();
  }

  /* INTERNAL - Set the first super admin (2) and ensure that this account is of the good type and actif.*/
  function setFirstAdmin() internal {
    if (firstAdmin == false) revert();
    accountType[owner] = 2;
    accountStatus[owner] = true;
    use(owner);
    firstAdmin = false;
  }

  /***** Ether handling *******/
  /* The contract dispatch Eth to the account: it must be able to receive them */
  function () public payable {}

  /* In the case we need to retrieve Eth from the contract. Sent it back to the Owner */
  function repay(uint _amount) public onlyOwner {
      uint amount = _amount * 1 ether;
      owner.transfer(amount);
  }

  /***** Contract administration *******/
  /* Transfer ownership */
  function transferOwnership(address newOwner) public onlyOwner {
    accountType[newOwner] = 2;
    accountStatus[newOwner] = true;
    use(newOwner);
    owner = newOwner;
  }

  /* Manage the Automatic Unlock */
  function setAutomaticUnlock(bool newAutomaticUnlock) public onlyOwner {
    automaticUnlock = newAutomaticUnlock;
  }

  /* Set the threshold to refill an account (in 0.001 ETH - initial contract value is same as calling this function with 10)*/
  function setRefillLimit(uint256 _minimumBalance) public onlyOwner {
    minBalanceForAccounts = _minimumBalance * 1 ether / 1000;
  }

  /* Get the total amount of coin (Money supply) */
  function totalSupply() public constant returns (int256 total) {
    total = amountPledged;
  }

  /* Panic button: allows to block any currency transfer */
  function setContractStatus(bool _actif) public onlyOwner {
      actif=_actif;
  }

  /* INTERNAL - Top up function: Check that an account has enough ETH if not send some to it */
  function topUp(address _addr) internal {
    uint amount = refillSupply * minBalanceForAccounts;
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
    if (_value < 0)
        revert(); // dev: amount should be greater than 0
    if (_value > 10000)
        revert(); // dev: amount should be lower than 10000
    percent = _value;
  }

  /* Get the tax percentage for transaction to a buisness (1) account */
  function getTaxPercentLeg() public constant returns (int16) {
    return percentLeg;
  }

  /* Set the tax percentage for transaction to a buisness (1) account */
  function setTaxPercentLeg(int16 _value) public onlyOwner {
    if (_value < 0)
        revert(); // dev: amount should be greater than 0
    if (_value > 10000)
        revert(); // dev: amount should be lower than 10000
    percentLeg = _value;
  }

  /****** Account handling *******/

  /* Get the total balance of an account */
  function balanceOf(address _from) public constant returns (int256 amount){
     return  balanceEL[_from] + balanceCM[_from];
  }

  function isActive(address target) public constant returns (bool result) {
    if (requestReplacementFrom[msg.sender] != address(0))
      return false;
    if (accountStatus[target]) {
      return true;
    } else if (automaticUnlock && !accountAlreadyUsed[target]) {
      return true;
    } else {
      return false;
    }
  }

  /* change the accountAlreadyUsed */
  function use(address add) internal {
    // unlock if needed
    if (automaticUnlock && !accountAlreadyUsed[add]) {
      accountStatus[add] = true;
    }

    accountAlreadyUsed[add] = true;
  }

  /* Change account's property */
  function setAccountParams(address _targetAccount, bool _accountStatus, int256 _accountType, int256 _debitLimit, int256 _creditLimit) public {

    // Ensure that the sender is a super admin or a property admin and is not blocked
    if (msg.sender!=owner){
        if (accountType[msg.sender] < 2  || accountType[msg.sender] == 3)
            revert(); // dev: permission denied
        if (!accountStatus[msg.sender])
            revert(); // dev: disabled accounts can't set account params
    }

    if (newAddress[_targetAccount] != address(0))
        revert(); // dev: replaced account cannot be modified

    accountStatus[_targetAccount] = _accountStatus;

    // Prevent changing the Type of a super Admin (2) account
    if (accountType[_targetAccount] != 2){
        limitDebit[_targetAccount] = _debitLimit;
        limitCredit[_targetAccount] = _creditLimit;
    }

    if (_targetAccount!=owner) {
        accountType[_targetAccount] = _accountType;
    }

    use(_targetAccount);

    emit SetAccountParams(now, _targetAccount, _accountStatus, accountType[_targetAccount], limitDebit[_targetAccount],  limitCredit[_targetAccount]);

    // ensure the ETH level of the account
    refill();
    topUp(_targetAccount);
  }

  function allowReplaceBy(address target) public payable {
     if (!actif) revert();                                                      // panic lock
     if (newAddress[msg.sender] != address(0))
         revert();  // dev: already replaced account cannot be replaced again
     if (!isActive(msg.sender))
         revert();  // dev: locked account cannot be replaced
     if (accountAlreadyUsed[target] == true)
         revert();  // dev: only new account can be target of a replacement
     if (requestReplacementFrom[msg.sender] != address(0))
         revert();  // dev: replacement request ongoing from this account

     requestReplacementFrom[msg.sender] = target;  // register the request

     topUp(target);                                // ensure targuet has eth to accept the request
  }

  function CancelReplaceBy() public  {
     if (!actif) revert();                                                      // panic lock
     if (requestReplacementFrom[msg.sender] == address(0))
         revert();  // dev: no replacement request ongoing to cancel

     requestReplacementFrom[msg.sender] = address(0);
     refill();
  }


  /* replace the current account by a new one transfering its content */
  function acceptReplaceAccount(address original_account) public {
     if (!actif) revert();                                                      // panic lock
     if (requestReplacementFrom[original_account] != msg.sender)
         revert();  // dev: replacement request not initiated
     if (accountAlreadyUsed[msg.sender] == true         // only new account can be a replacement target
         || newAddress[original_account] != address(0)  // already replaced account cannot be replaced again
         || !isActive(original_account)) {              // locked account cannot be replaced
         // YYYvlab: if it is already address(0) ?
         requestReplacementFrom[original_account] = address(0);  // cancel the outdated request
     } else {
        // transfert the type (and ownership if needed)
        use(msg.sender);
        accountStatus[msg.sender] = true;
        if (original_account == owner) {                                        // if the replaced account is the contract owner transfert the priviledge
            accountType[msg.sender] = 2;
            owner = msg.sender;
        } else {
            accountType[msg.sender] = accountType[original_account];
        }

        // transfert the values and limit
        balanceEL[msg.sender] = balanceEL[original_account];
        balanceEL[original_account] = 0;
        balanceCM[msg.sender] = balanceCM[original_account];
        balanceCM[original_account] = 0;
        limitCredit[msg.sender] = limitCredit[original_account];
        limitCredit[original_account] = 0;
        limitDebit[msg.sender] = limitDebit[original_account];
        limitDebit[original_account] = 0;

        bool found = false;
        uint ii=0;
        // transfert the allowance from the replaced account
        uint map_length = allowMap[original_account].length;
        for (uint index=0; index<map_length; index++) {
            address spender = allowMap[original_account][index];
            int256 amount = allowed[original_account][spender];
            if (amount > 0) {
                allowMap[msg.sender].push(spender);
                myAllowMap[spender].push(msg.sender);
                allowed[msg.sender][spender] = amount;
                allowed[original_account][spender] = 0;
                myAllowed[spender][msg.sender] = amount;
                myAllowed[spender][original_account] = 0;
                
                found = false;
                for (ii = 0; ii<myAllowMap[spender].length -1; ii++){
                    if (!found && myAllowMap[spender][ii] == original_account){
                        found=true;
                    }

                    if (found){
                        myAllowMap[spender][ii] = myAllowMap[spender][ii+1];
                    }
                }

                if (found){
                         delete myAllowMap[spender][myAllowMap[spender].length-1]; // remove the last record from the mapping array
                         myAllowMap[spender].length--;                            // adjust the length of the mapping array
                }  
            }
        }
        for (index=0; index<map_length; index++) {
 	      delete allowMap[original_account][map_length-1-index]; // remove the last record from the mapping array   
        }
        allowMap[original_account].length=0;
        
        

        // transfert the allowance to the replaced account
        map_length = myAllowMap[original_account].length;
        for (index=0; index < map_length; index++) {
            address allower = myAllowMap[original_account][index];
            amount = myAllowed[original_account][allower];
            if (amount > 0) {
                allowMap[allower].push(msg.sender);
                myAllowMap[msg.sender].push(allower);
                allowed[allower][msg.sender] = amount;
                allowed[allower][original_account] = 0;
                myAllowed[msg.sender][allower] = amount;
                myAllowed[original_account][allower] = 0;
                
                found = false;
                for (ii = 0; ii<allowMap[allower].length -1; ii++){
                    if (!found && allowMap[allower][ii] == original_account){
                        found=true;
                    }

                    if (found){
                        allowMap[allower][ii] = allowMap[allower][ii+1];
                    }
                }

                if (found){
                         delete allowMap[allower][allowMap[allower].length-1]; // remove the last record from the mapping array
                         allowMap[allower].length--;                            // adjust the length of the mapping array
                }  
            }
        }
        for ( index=0; index<map_length; index++) {
 	      delete myAllowMap[original_account][map_length-1-index]; // remove the last record from the mapping array   
        }
        myAllowMap[original_account].length=0;

        // transfert the autorization from the replaced account
        map_length = delegMap[original_account].length;
        for (index=0; index<map_length; index++) {
            address delegate = delegMap[original_account][index];
            amount = delegated[original_account][delegate];
            if (amount > 0) {
                delegMap[msg.sender].push(delegate);
                myDelegMap[delegate].push(msg.sender);
                delegated[msg.sender][delegate] = amount;
                delegated[original_account][delegate] = 0;
                myDelegated[delegate][msg.sender] = amount;
                myDelegated[delegate][original_account] = 0;
                
                found = false;
                for (ii = 0; ii<myDelegMap[delegate].length -1; ii++){
                    if (!found && myDelegMap[delegate][ii] == original_account){
                        found=true;
                    }

                    if (found){
                        myDelegMap[delegate][ii] = myDelegMap[delegate][ii+1];
                    }
                }

                if (found){
                         delete myDelegMap[delegate][myDelegMap[delegate].length-1]; // remove the last record from the mapping array
                         myDelegMap[delegate].length--;                            // adjust the length of the mapping array
                }  
            }
        }
        
        for (index=0; index<map_length; index++) {
 	      delete delegMap[original_account][map_length-1-index]; // remove the last record from the mapping array   
        }
        delegMap[original_account].length=0;

        // transfert the autorization to the replaced account
        map_length = myDelegMap[original_account].length;
        for (index=0; index < map_length; index++) {
            address delegetor = myDelegMap[original_account][index];
            amount = myDelegated[original_account][delegetor];
            if (amount > 0) {
                delegMap[delegetor].push(msg.sender);
                myDelegMap[msg.sender].push(delegetor);
                delegated[delegetor][msg.sender] = amount;
                delegated[delegetor][original_account] = 0;
                myDelegated[msg.sender][delegetor] = amount;
                myDelegated[original_account][delegetor] = 0;
                
                found = false;
                for (ii = 0; ii<delegMap[delegetor].length -1; ii++){
                    if (!found && delegMap[delegetor][ii] == original_account){
                        found=true;
                    }

                    if (found){
                        delegMap[delegetor][ii] = delegMap[delegetor][ii+1];
                    }
                }

                if (found){
                         delete delegMap[delegetor][delegMap[delegetor].length-1]; // remove the last record from the mapping array
                         delegMap[delegetor].length--;                            // adjust the length of the mapping array
                }  
            }
        }
        
        for (index=0; index<map_length; index++) {
           delete myDelegMap[original_account][map_length-1-index]; // remove the last record from the mapping array   
        }
        myDelegMap[original_account].length=0;

        // transfert the payment requet made by the replaced account
        map_length = reqMap[original_account].length;
        for (index=0; index<map_length; index++) {
            address debitor = reqMap[original_account][index];
            amount = requested[original_account][debitor];
            if (amount > 0) {
                reqMap[msg.sender].push(debitor);
                myReqMap[debitor].push(msg.sender);
                requested[msg.sender][debitor] = amount;
                requested[original_account][debitor] = 0;
                myRequested[debitor][msg.sender] = amount;
                myRequested[debitor][original_account] = 0;
                
                found = false;
                for (ii = 0; ii<myReqMap[debitor].length -1; ii++){
                    if (!found && myReqMap[debitor][ii] == original_account){
                        found=true;
                    }

                    if (found){
                        myReqMap[debitor][ii] = myReqMap[debitor][ii+1];
                    }
                }

                if (found){
                         delete myReqMap[debitor][myReqMap[debitor].length-1]; // remove the last record from the mapping array
                         myReqMap[debitor].length--;                            // adjust the length of the mapping array
                } 
            }
        }

       for (index=0; index<map_length; index++) {
 	     delete reqMap[original_account][map_length-1-index]; // remove the last record from the mapping array   
        }
        reqMap[original_account].length=0;
        
        // transfert the payment requet made to the replaced account
        map_length = myReqMap[original_account].length;
        for (index=0; index < map_length; index++) {
            address requestor = myReqMap[original_account][index];
            amount = myRequested[original_account][requestor];
            if (amount > 0) {
                reqMap[requestor].push(msg.sender);
                myReqMap[msg.sender].push(requestor);
                requested[requestor][msg.sender] = amount;
                requested[requestor][original_account] = 0;
                myRequested[msg.sender][requestor] = amount;
                myRequested[original_account][requestor] = 0;
                
                found = false;
                for (ii = 0; ii<reqMap[requestor].length -1; ii++){
                    if (!found && reqMap[requestor][ii] == original_account){
                        found=true;
                    }

                    if (found){
                        reqMap[requestor][ii] = reqMap[requestor][ii+1];
                    }
                }

                if (found){
                         delete reqMap[requestor][reqMap[requestor].length-1]; // remove the last record from the mapping array
                         reqMap[requestor].length--;                            // adjust the length of the mapping array
                } 
            }
        }
        
       for (index=0; index<map_length; index++) {
 	      delete myReqMap[original_account][map_length-1-index]; // remove the last record from the mapping array   
        }
        myReqMap[original_account].length=0;

        // NOTE: Already payed or rejected payment request are not transfered!

        // lock the old account and emit event
        newAddress[original_account] = msg.sender;
        accountStatus[original_account] = false;
        emit AccountReplaced(now, original_account, msg.sender, accountType[msg.sender]);
     }
  }


  /****** Coin and Barter transfer *******/
  /* Coin creation (Nantissement) */
  function pledge(address _to, int256 _value)  public {
      // Check that only super admin (2) or pledge admin (3) can pledge
    if (accountType[msg.sender] < 2 || accountType[msg.sender] > 3)
        revert(); // dev: permission denied
    if (!isActive(msg.sender))
        revert(); // dev: disabled accounts can't pledge
    if (!isActive(_to)) revert();  // dev: disabled accounts can't receive pledge
    // if (balanceEL[_to] + _value < 0) revert();                                  // Check for overflows
    if (balanceEL[_to] + _value < balanceEL[_to] ) revert();                    // Check for overflows & avoid negative pledge
   // if (newAddress[_to]!=address(0)) revert();                                  // Replaced account cannot be pledged
    balanceEL[_to] += _value;                                                   // Add the amount to the recipient
    amountPledged += _value;                                                    // and to the Money supply
    use(_to);

    emit Pledge(now, _to, _value);
    // ensure the ETH level of the account
    refill();
    topUp(_to);
  }


    /* Make Direct payment in currency*/
  function transfer(address _to, int256 _value) public {
    payNant(msg.sender,_to,_value);
  }

  /* Make Direct payment in CM*/
  function transferCM(address _to, int256 _value) public {
   payCM(msg.sender,_to,_value);
  }

  /* Transfer "on behalf of" of Coin and Mutual Credit (delegation) */
  /* Make Transfer "on behalf of" in coins*/
  function transferOnBehalfOf(address _from, address _to, int256 _value)public  {
    if (delegated[_from][msg.sender] < _value) revert(); // dev: value bigger than the delegation
    payNant(_from,_to,_value);
  }

  /* Make  Transfer "on behalf of" in Mutual Credit */
  function transferCMOnBehalfOf(address _from, address _to, int256 _value)public {
    if (delegated[_from][msg.sender] < _value) revert(); // dev: value bigger than the delegation
    payCM(_from,_to,_value);
  }

  /* Transfer request of Coin and Mutual Credit (delegation & pay request)*/
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

  // Send _value Mutual Credit from address _from to the sender
  function transferCMFrom(address _from, int256 _value) public {
    if (allowed[_from][msg.sender] >= _value  && balanceCM[_from]>=_value) {
     payCM(_from, msg.sender,_value);

     // substract the value from the allowed
     updateAllowed(_from, msg.sender, -_value);

    } else {
      insertRequest(_from,  msg.sender, _value);                   // if allowed is not enough (or do not exist) create a request
    }
  }





  /* INTERNAL - Coin transfer  */
  function payNant(address _from,address _to, int256 _value) internal {
    if (!actif) revert();  // dev: panic lock

    if (!isActive(_from)) revert();  // dev: Source account is locked
    if (!isActive(_to)) revert();  // dev: Target account is locked

    // compute the tax
    int16 tax_percent = percent;
    if (accountType[_to] == 1){
        tax_percent = percentLeg;
    }
    int256 tax = (_value * tax_percent) / 10000;

    // compute the received ammount
    int256 amount = _value - tax;

    if (!checkEL(_from, amount + tax)) revert(); // dev: Not enough balance
    if (balanceEL[_to] + amount < balanceEL[_to]) revert(); // dev: overflow and negative check

    // Do the transfer
    balanceEL[_from] -= amount + tax;         // Subtract from the sender
    balanceEL[_to] += amount;
    balanceEL[txAddr] += tax;

    use(_to);
    emit Transfer(now, _from, _to, amount+tax, tax, amount);        // Notify anyone listening that this transfer took place
    // ensure the ETH level of the account
    topUp(_to);
    topUp(_from);
  }

  /* INTERNAL - Mutual Credit (Barter) transfer  */
  function payCM(address _from, address _to, int256 _value) internal {
    if (!actif) revert();  // dev: panic lock
    if (!isActive(_from)) revert();  // dev: Source account is locked
    if (!isActive(_to)) revert(); // dev: Target account is locked

    // compute the tax
    int16 tax_percent = percent;
    if (accountType[_to] == 1){
        tax_percent = percentLeg;
    }
    int256 tax = (_value * tax_percent) / 10000;

    // compute the received ammount
    int256 amount = _value - tax;

    // Check the limit & overflow
    if (!checkCMMin(_from, amount + tax)) revert();
    if (!checkCMMax(_to, amount)) revert();
    if (balanceCM[_to] + amount < balanceCM[_to]) revert(); // dev: overflow and negative check

    // Do the transfer
    balanceCM[_from] -= amount + tax;         // Subtract from the sender
    balanceCM[_to] += amount;
    balanceCM[txAddr] += tax;

    use(_to);
    emit TransferCredit(now, _from, _to, amount+tax, tax, amount);  // Notify anyone listening that this transfer took place
    // ensure the ETH level of the account
    topUp(_to);
    topUp(_from);
  }

  /* INTERNAL - Check the sender has enough coin to do the transfer */
  function checkEL(address _addr, int256 _value) internal view returns (bool)  {
    int256 checkBalance = balanceEL[_addr] - _value;
    if (checkBalance < 0) {
      revert(); // dev: Not enough balance
    } else {
      return true;
    }
  }

  /* INTERNAL - Check that the sender can send the CM amount */
  function checkCMMin(address _addr, int256 _value) internal  view returns (bool) {
    int256 checkBalance = balanceCM[_addr] - _value;
    int256 limitCM = limitCredit[_addr];
    if (checkBalance < limitCM) {
      revert(); // dev: Inferior credit limit hit
    } else {
      return true;
    }
  }

  /* INTERNAL - Check that the reciever can recieve the CM amount */
  function checkCMMax(address _addr, int256 _value) internal view returns (bool) {
    int256 checkBalance = balanceCM[_addr] + _value;
    int256 limitCM = limitDebit[_addr];
    if (checkBalance > limitCM) {
      revert(); // dev: Supperior credit limit hit
    } else {
      return true;
    }
  }


  /****** Allowance *******/
  /* Allow _spender to withdraw from your account, multiple times, up to the _value amount.  */
  /* If called again the _amount is added to the allowance, if amount is negatif the allowance is deleted  */
  function approve(address _spender, int256 _amount) public returns (bool success) {
    if (!isActive(msg.sender)) revert();  // Check the sender not to be blocked


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
    use(_spender);
    use(msg.sender);
    refill();
    topUp(_spender);
    return true;
  }

  /* INTERNAL - Allow the spender to decrasse the allowance */
  function updateAllowed(address _from, address _to, int256 _value) internal {
    if (!isActive(msg.sender)) revert();      // Ensure that accounts are not locked
    if (!isActive(_from)) revert();
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
    return myAllowMap[_spender].length;
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
    return myAllowed[_spender][_owner];
  }

  function myGetAllowance(address _spender, uint index) public constant returns (address _to) {
    return myAllowMap[_spender][index];
  }



  /****** Delegation *******/
  /* Allow _spender to pay on behalf of you from your account, multiple times, each transaction bellow the limit. */
  /* If called again the limit is replaced by the new _amount, if _amount is 0 the delegation is removed */
  function delegate(address _spender, int256 _amount) public {
    if (!isActive(msg.sender)) revert(); // dev: sender account not actif

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
    refill();
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
  /* INTERNAL - Add Request request are added by user through transferFrom/transferCMFrom*/
  function insertRequest( address _from,  address _to, int256 _amount) internal {
    if (!isActive(_to)) revert(); // Check the creator not to be blocked

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
    if (!isActive(msg.sender)) revert();               // Ensure that accounts are not locked
    if (!isActive(_to)) revert();
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


  /* Accept and pay in mutual credit a payment request (also delete the request if needed and add it to the accepted list) */
  function payRequestCM(address _to, int256 _value) public{
    payCM(msg.sender,_to,_value);
    updateRequested(msg.sender, _to, -_value);

    if (accepted[_to][msg.sender] == 0) {
         acceptedMap[_to].push(msg.sender);
    }
    accepted[_to][msg.sender] += _value;

    clear_request(msg.sender,_to);
  }


  /* Discard a payement request put it into the rejected request. */
  function cancelRequest(address _to)public {
    if (!isActive(msg.sender)) revert();
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
    
    
    refill();
  }


  /* Discard acceptation information */
  function discardAcceptedInfo(address _spender) public {
    if (!isActive(msg.sender)) revert();
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
    
    
    refill();
  }

  /* Discard rejected incormation */
  function discardRejectedInfo(address _spender)public{
    if (!isActive(msg.sender)) revert();
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
    
    refill();
  }
}
