# -*- coding: utf-8 -*-

from .common import currency, Accounts, c

from brownie import cccur, accounts, reverts


## YYYvlab: check panic lock

def test_replace_account_standard(Accounts, c):

    owner = Accounts[0]
    john1 = Accounts[1]
    john2 = Accounts[2]    
    john3 = Accounts[3] 
    joe1 = Accounts[4]
    joe2 = Accounts[5]
    joe3 = Accounts[6]

    owner.setAccountParams(john1, True, 1, -1000, 3000)
    owner.pledge(john1, 100)
    
    # Create and check delegation
    john1.delegate(joe1, 10)
    assert c.delegationCount(john1) == 1 
    assert c.myDelegationCount(joe1) == 1
    
    # Create and check allowance
    john1.approve(joe2, 11)
    assert c.myAllowanceCount(joe2)==1
    assert c.myAllowance(joe2,john1) == 11
    assert c.allowanceCount(john1)==1
    
    # Create and check a payement request
    owner.setAccountParams(joe3, True, 1, -1000, 3000)
    joe3.transferFrom(john1,13)
    assert c.requestCount(john1)==1
    assert c.myRequestCount(joe3)==1
    assert c.myRequest(joe3,john1)==13

    john1.allowReplaceBy(john2)
    john2.acceptReplaceAccount(john1)

    assert c.accountType(john1) == 1
    assert c.accountType(john2) == 1

    assert c.balanceOf(john2) == 100
    assert c.balanceOf(john1) == 0

    assert c.accountStatus(john1) is False
    assert c.accountStatus(john2) is True

    assert c.limitCredit(john1) == 0
    assert c.limitCredit(john2) == 3000

    assert c.limitDebit(john1) == 0
    assert c.limitDebit(john2) == -1000
    
    
    assert c.delegationCount(john1) == 0  
    assert c.delegationCount(john2) == 1
    assert c.myDelegationCount(joe1) == 1  
    assert c.delegation(john1,joe1)==0
    assert c.delegation(john2,joe1)==10
    assert c.myDelegation(joe1,john1)==0
    assert c.myDelegation(joe1,john2)==10

    assert c.allowanceCount(john1) == 0  
    assert c.allowanceCount(john2) == 1
    assert c.myAllowanceCount(joe2) == 1 
    assert c.myAllowance(joe2,john1)==0
    assert c.myAllowance(joe2,john2)==11
    assert c.allowance(john1,joe2)==0
    assert c.allowance(john2,joe2)==11
    
    assert c.requestCount(john1)==0
    assert c.requestCount(john2)==1
    assert c.myRequestCount(joe3)==1
    assert c.request(john1,joe3)==0
    assert c.request(john2,joe3)==13
    assert c.myRequest(joe3,john1)==0
    assert c.myRequest(joe3,john2)==13


    with reverts("dev: already replaced account cannot be replaced again"):
        john1.allowReplaceBy(john3)


def test_replace_account_standard_with_cancel(Accounts, c):

    owner = Accounts[0]
    john1 = Accounts[1]
    john2 = Accounts[2]

    owner.setAccountParams(john1, True, 1, -1000, 3000)
    owner.pledge(john1, 100)

    john1.allowReplaceBy(john2)
    john1.CancelReplaceBy()

    john1.allowReplaceBy(john2)
    john2.acceptReplaceAccount(john1)

    assert c.accountType(john1) == 1
    assert c.accountType(john2) == 1

    assert c.balanceOf(john2) == 100
    assert c.balanceOf(john1) == 0

    assert c.accountStatus(john1) is False
    assert c.accountStatus(john2) is True

    assert c.limitCredit(john1) == 0
    assert c.limitCredit(john2) == 3000

    assert c.limitDebit(john1) == 0
    assert c.limitDebit(john2) == -1000


def test_replace_account_two_request(Accounts, c):

    owner = Accounts[0]
    john1 = Accounts[1]
    john2 = Accounts[2]

    owner.setAccountParams(john1, True, 1, -1000, 3000)
    owner.pledge(john1, 100)

    john1.allowReplaceBy(john2)

    with reverts("dev: locked account cannot be replaced"):
        john1.allowReplaceBy(john2)


def test_replace_account_cancel_request(Accounts, c):

    owner = Accounts[0]
    john1 = Accounts[1]
    john2 = Accounts[2]

    owner.setAccountParams(john1, True, 1, -1000, 3000)
    owner.pledge(john1, 100)

    john1.allowReplaceBy(john2)
    john1.CancelReplaceBy()

    with reverts("dev: replacement request not initiated"):
        john2.acceptReplaceAccount(john1)


def test_replace_account_no_previous_request(Accounts, c):

    owner = Accounts[0]
    john1 = Accounts[1]
    john2 = Accounts[2]

    owner.setAccountParams(john1, True, 1, -1000, 3000)
    owner.pledge(john1, 100)

    with reverts("dev: replacement request not initiated"):
        john2.acceptReplaceAccount(john1)


def test_replace_account_not_new_target(Accounts, c):

    owner = Accounts[0]
    john = Accounts[1]
    billy = Accounts[2]
    walter = Accounts[3]

    owner.setAccountParams(john, True, 2, -1000, 3000)
    owner.setAccountParams(billy, True, 0, -500, 1000)
    owner.pledge(john, 100)

    ## Billy is already used account
    with reverts("dev: only new account can be target of a replacement"):
        john.allowReplaceBy(billy)

    ## Walter is not yet used
    john.allowReplaceBy(walter)
    ##  .. but we'll use it
    owner.setAccountParams(walter, True, 0, -750, 1500)
    ##  .. so on acceptReplace time, do nothing and remove request
    walter.acceptReplaceAccount(john)

    ## YYYvlab: can we check directement requestReplacementFrom[john] array ?

    ## Nothing should have changed:
    assert c.accountType(john) == 2
    assert c.accountType(walter) == 0

    assert c.balanceOf(john) == 100
    assert c.balanceOf(walter) == 0

    assert c.accountStatus(john) is True
    assert c.accountStatus(walter) is True

    assert c.limitCredit(john) == 3000
    assert c.limitCredit(walter) == 1500

    assert c.limitDebit(john) == -1000
    assert c.limitDebit(walter) == -750

    

def test_replace_account_crossover(Accounts, c):

    owner = Accounts[0]
    john1 = Accounts[1]
    john2 = Accounts[2]
    walter = Accounts[3]

    owner.setAccountParams(john1, True, 2, -1000, 3000)
    owner.setAccountParams(walter, True, 0, -500, 1000)
    owner.pledge(john1, 100)

    john1.allowReplaceBy(john2)
    walter.allowReplaceBy(john2)

    john2.acceptReplaceAccount(john1)
    john2.acceptReplaceAccount(walter)

    assert c.accountType(john1) == 2
    assert c.accountType(john2) == 2

    assert c.balanceOf(john2) == 100
    assert c.balanceOf(john1) == 0

    assert c.accountStatus(john1) is False
    assert c.accountStatus(john2) is True

    assert c.limitCredit(john1) == 0
    assert c.limitCredit(john2) == 3000

    assert c.limitDebit(john1) == 0
    assert c.limitDebit(john2) == -1000


def test_replace_account_to_non_new_account(Accounts, c):

    owner = Accounts[0]
    john1 = Accounts[1]
    john2 = Accounts[2]
    walter = Accounts[3]

    owner.setAccountParams(john1, True, 1, -1000, 3000)
    owner.pledge(john1, 100)

    with reverts("dev: only new account can be target of a replacement"):
        john1.allowReplaceBy(owner)

    owner.setAccountParams(walter, True, 0, -1000, 3000)
    with reverts("dev: only new account can be target of a replacement"):
        john1.allowReplaceBy(walter)

    john1.allowReplaceBy(john2)



def test_replaced_account_not_usable(Accounts, c):

    owner = Accounts[0]
    john1 = Accounts[1]
    john2 = Accounts[2]
    walter = Accounts[3]

    owner.setAccountParams(john1, True, 1, -1000, 3000)
    owner.pledge(john1, 100)

    john1.allowReplaceBy(john2)
    john2.acceptReplaceAccount(john1)

    ## Can't set properties of a replaced account
    with reverts("dev: replaced account cannot be modified"):
        owner.setAccountParams(john1, True, 1, -1000, 3000)
