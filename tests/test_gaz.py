# -*- coding: utf-8 -*-

from .common import currency, Accounts, c, isolation

from brownie import cccur, accounts, reverts


def test_set_account_param(Accounts, currency):
    ''' Check account is refilled when his param are sets'''
    owner = Accounts[0]
    john = accounts[1]
    joe = Accounts[2]
    john.transfer(currency, john.balance())
    assert john.balance()==0
    assert currency.balance()>100000000000000000
                            
    
    ## edit account property
    owner.setAccountParams(john, True, 0, 3000, -1000)
    assert john.balance()==100000000000000000
    
def test_set_account_param_owner(Accounts, currency):
    ''' Check admin is refilled when setting account param'''
    Owner = Accounts[0] # for contract operation
    owner = accounts[0] # for eth transfert
    john = accounts[1]
    joe = Accounts[2]
    
    owner.transfer(currency, owner.balance() - 10000000000000000)
    assert owner.balance()==10000000000000000
    assert currency.balance()>100000000000000000
    
    ## edit account property
    Owner.setAccountParams(john, True, 0, 3000, -1000)
    assert owner.balance()>10000000000000000
    
def test_pledge_and_pay(Accounts, currency):
    ''' Check account is refilled when it recieve pledge or payment'''
    Owner = Accounts[0] # for contract operation
    owner = accounts[0] # for eth transfert
    john = accounts[1]
    joe = Accounts[2]
    
    accounts[3].transfer(currency, accounts[3].balance()-100000000000000000)
    assert currency.balance()>100000000000000000
    
    Owner.setAccountParams(john, True, 0, 3000, -1000)
    john.transfer(currency, john.balance())
    assert john.balance()==0
    
    ## pledge account
    Owner.pledge(john, 100)
    assert john.balance()==100000000000000000
    
    ## pay account
    john.transfer(currency, john.balance())
    Owner.setAccountParams(joe, True, 0, 3000, -1000)
    Owner.pledge(joe, 100)
    
    joe.transfer(john,100) 
    assert john.balance()==100000000000000000
    
    ## pay account CM
    john.transfer(currency, john.balance())
    Owner.setAccountParams(joe, True, 0, 3000, -1000)
    joe.transferCM(john,100) 
    assert john.balance()==100000000000000000
    
def test_pledge_admin(Accounts, currency):
    ''' Check admin is refilled when pledging an account'''
    Owner = Accounts[0] # for contract operation
    owner = accounts[0] # for eth transfert
    john = Accounts[1]
    accounts[3].transfer(currency, accounts[3].balance()-100000000000000000)
    assert currency.balance()>100000000000000000
    
    Owner.setAccountParams(john, True, 0, 3000, -1000)
    owner.transfer(currency, owner.balance() - 10000000000000000)
    assert owner.balance()==10000000000000000 # limit for the refill 
    assert currency.balance()>100000000000000000
    Owner.pledge(john, 100)
    assert owner.balance()>10000000000000000
    
def test_pay_sender(Accounts, currency):
    ''' Check sender is refilled when transfering token'''
    Owner = Accounts[0]
    john = Accounts[1]
    joe = accounts[2] # for eth transfert
    Joe = Accounts[2] # for contract operation
   
    Owner.setAccountParams(john, True, 0, 3000, -1000)
    Owner.setAccountParams(Joe, True, 0, 3000, -1000)
    Owner.pledge(Joe, 100)
    joe.transfer(currency, joe.balance() - 10000000000000000)
    assert joe.balance()==10000000000000000 # limit for the refill 
    assert currency.balance()>100000000000000000
    Joe.transfer(john,100) 
    assert joe.balance()>10000000000000000
    
    joe.transfer(currency, joe.balance() - 10000000000000000)
    Joe.transferCM(john,100) 
    assert joe.balance()>10000000000000000


    
def test_pledge_and_pay(Accounts, currency):
    ''' Check that the account designed to replace the account get gas, idem when cancelling a request '''
    owner = Accounts[0]
    john1 = accounts[1]
    John1 = Accounts[1]
    john2 = accounts[2]
    John2 = Accounts[2]
    accounts[3].transfer(currency, accounts[3].balance()-100000000000000000)
    assert currency.balance()>100000000000000000
    
    #target account is new with no gas
    john2.transfer(currency, john2.balance())
    assert john2.balance()==0
    
    # account to replace has fund, is unlocked and has gas
    owner.setAccountParams(john1, True, 1, 3000, -1000)
    owner.pledge(john1, 100)

    # allow to replkace should refill John2
    John1.allowReplaceBy(John2)
    assert john2.balance()==100000000000000000
    
    # cancelling the request should refill John1
    john1.transfer(currency, john1.balance()-10000000000000000)
    assert currency.balance()>100000000000000000
    John1.CancelReplaceBy()
    assert john1.balance()>10000000000000000



