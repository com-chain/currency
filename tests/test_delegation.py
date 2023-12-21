# -*- coding: utf-8 -*-

from .common import currency, Accounts, c, isolation

from brownie import cccur, accounts, reverts

def test_set_delegation(Accounts, c):
    owner = Accounts[0]
    john = Accounts[1]
    joe = Accounts[2]
    
    owner.setAccountParams(joe, True, 1, 3000, -1000)
    assert c.delegationCount(john) == 0
    assert c.myDelegationCount(joe) == 0
    assert c.delegation(john,joe) == 0
    
    with reverts("dev: sender account not actif"):
        john.delegate(joe, 100)
        
    owner.setAccountParams(john, True, 1, 3000, -1000)
    
    # setup delegation
    john.delegate(joe, 100)
    
    assert c.delegationCount(john) == 1
    assert c.getDelegation(john,0) == accounts[2] 
    assert c.delegation(john, joe) == 100
    
    assert c.myDelegationCount(joe) == 1
    assert c.myGetDelegation(joe,0) == accounts[1]
    assert c.myDelegation(joe, john) == 100
    
def test_update_delegation(Accounts, c):   
    owner = Accounts[0]
    john = Accounts[1]
    joe = Accounts[2]
    
    owner.setAccountParams(john, True, 1, 3000, -1000)
    owner.setAccountParams(joe, True, 1, 3000, -1000)
    
    # setup delegation
    john.delegate(joe, 100) 
    
    assert c.delegationCount(john) == 1
    assert c.getDelegation(john,0) == accounts[2]
    assert c.delegation(john, joe) == 100
    
    # update delegation
    john.delegate(joe, 200) 
    assert c.delegationCount(john) == 1
    assert c.delegation(john, joe) == 200
    
    assert c.myDelegationCount(joe) == 1
    assert c.myDelegation(joe, john) == 200
    
    # delete delegation
    john.delegate(joe, 0) 
    assert c.delegationCount(john) == 0
    assert c.delegation(john, joe) == 0
    assert c.myDelegationCount(joe) == 0
    assert c.myDelegation(joe, john) == 0


def test_pay_nant_delegation(Accounts, c): 
    owner = Accounts[0]
    john = Accounts[1]
    joe = Accounts[2]
    gill = Accounts[3]

    owner.setAccountParams(john, True, 0, 3000, -1000)
    owner.setAccountParams(joe, True, 0, 3000, -1000)
    owner.setAccountParams(gill, True, 0, 3000, -1000)
    owner.pledge(john,10000)
    john.delegate(joe, 100) 
    
    joe.transferOnBehalfOf(john,gill,100)
    assert c.balanceEL(john) == 9900
    assert c.balanceEL(joe) == 0
    assert c.balanceEL(gill) == 100
    assert c.balanceOf(john) == 9900
    assert c.balanceOf(joe) == 0
    assert c.balanceOf(gill) == 100
    
    
    joe.transferOnBehalfOf(john,gill,100)
    assert c.balanceEL(john) == 9800
    assert c.balanceEL(joe) == 0
    assert c.balanceEL(gill) == 200
    
    with reverts("dev: value bigger than the delegation"):
        joe.transferOnBehalfOf(john,gill,101)
    
def test_pay_cm_delegation(Accounts, c): 
    owner = Accounts[0]
    john = Accounts[1]
    joe = Accounts[2]
    gill = Accounts[3]

    owner.setAccountParams(john, True, 0, 3000, -1000)
    owner.setAccountParams(joe, True, 0, 3000, -1000)
    owner.setAccountParams(gill, True, 0, 3000, -1000)
    john.delegate(joe, 100) 
    
    joe.transferCMOnBehalfOf(john,gill,100)
    assert c.balanceCM(john) == -100
    assert c.balanceCM(joe) == 0
    assert c.balanceCM(gill) == 100
    assert c.balanceOf(john) == -100
    assert c.balanceOf(joe) == 0
    assert c.balanceOf(gill) == 100
    
    
    joe.transferCMOnBehalfOf(john,gill,100)
    assert c.balanceCM(john) == -200
    assert c.balanceCM(joe) == 0
    assert c.balanceCM(gill) == 200
    
    with reverts("dev: value bigger than the delegation"):
        joe.transferCMOnBehalfOf(john,gill,101)   
