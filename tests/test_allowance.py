# -*- coding: utf-8 -*-

from .common import currency, Accounts, c

from brownie import cccur, accounts, reverts

def test_set_allowance(Accounts, c):
    owner = Accounts[0]
    john = Accounts[1]
    joe = Accounts[2]
    
    owner.setAccountParams(joe, True, 1, 3000, -1000)
    assert c.allowanceCount(john) == 0
    assert c.myAllowanceCount(joe) == 0
    assert c.allowance(john,joe) == 0
    
    with reverts("dev: sender account not actif"):
        john.approve(joe, 100)
        
    owner.setAccountParams(john, True, 1, 3000, -1000)
    
    # setup allowance
    john.approve(joe, 100)
    
    assert c.allowanceCount(john) == 1
    assert c.getAllowance(john,0) == accounts[2] 
    assert c.allowance(john, joe) == 100
    
    assert c.myAllowanceCount(joe) == 1
    assert c.myGetAllowance(joe,0) == accounts[1]
    assert c.myAllowance(joe, john) == 100
    
def test_update_allowance(Accounts, c):   
    owner = Accounts[0]
    john = Accounts[1]
    joe = Accounts[2]
    
    owner.setAccountParams(john, True, 1, 3000, -1000)
    owner.setAccountParams(joe, True, 1, 3000, -1000)
    
    # setup allowance
    john.approve(joe, 100) 
    
    assert c.allowanceCount(john) == 1
    assert c.getAllowance(john,0) == accounts[2] 
    assert c.allowance(john, joe) == 100
    
    # update allowance
    john.approve(joe, 300) 
    assert c.allowanceCount(john) == 1
    assert c.allowance(john, joe) == 400
    
    assert c.myAllowanceCount(joe) == 1
    assert c.myAllowance(joe, john) == 400
    
    # delete allowance
    john.approve(joe, -1) 
    assert c.allowanceCount(john) == 0
    assert c.allowance(john, joe) == 0
    assert c.myAllowanceCount(joe) == 0
    assert c.myAllowance(joe, john) == 0
