pragma solidity ^0.4.11;

/********************************************************

This contract is designed to store hash in behalf of 
an account. 

The intended usage is that a document is crypted with a 
symetric key derived from the account's private key,
then stored on IPFS and the IPFS hash is stored in this 
contract.

Retriving the document is done by getting the hash from 
this contract, get the IPFS corresponding document, then
decypher it using the (key derrived from the) private key.

*********************************************************/


contract ipfsStorage {

  /******** Arrays and lists ********/
  mapping (address => string) public contactsOf;
  mapping (address => string) public memosOf;
  /**********************************/
  
  /* This generates a public event on the blockchain that will notify clients */
  event Transfer(uint256 time, address indexed from, address indexed to, int256 sent, int256 tax, int256 recieved);

  /* Initializes contract */
  function _template_() {
  }

  function () payable{}

  /* Get the ipfshash of an account */
  function contactsOf(address _from) constant returns (string amount){
     return  contactsOf[_from];
  }
  
  /* Get the ipfshash of an account */
  function memosOf(address _from) constant returns (string amount){
     return  memosOf[_from];
  }
  
  /* Set account contatcs ipfshash */  
  function setAccountContacts(string _contacts) {
    contactsOf[msg.sender] = _contacts;
  }
  
  /* Set account memos ipfshash */  
  function setAccountMemos(string _contacts) {
    memosOf[msg.sender] = _contacts;
  }
  
}
