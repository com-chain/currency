# -*- coding: utf-8 -*-

from .common import currency, Accounts, c, isolation

from brownie import cccur, accounts, reverts

def test_request_NANT(Accounts, c):
    owner = Accounts[0]
    john = Accounts[1]
    joe = Accounts[2]
    
    owner.setAccountParams(joe, True, 0, 3000, -1000)
    assert c.allowanceCount(john) == 0
    assert c.myAllowanceCount(joe) == 0
    assert c.allowance(john,joe) == 0
    
    with reverts("dev: Check the creator not to be blocked"):
        john.transferFrom(joe, 100)
        
    owner.setAccountParams(john, True, 0, 3000, -1000)
    
    # setup Payment Request
    john.transferFrom(joe, 100)
    
    assert c.myRequestCount(john) == 1
    assert c.myGetRequest(john,0) == accounts[2] 
    assert c.myRequest(john, joe) == 100
    
    assert c.requestCount(joe) == 1
    assert c.getRequest(joe,0) == accounts[1]
    assert c.request(joe, john) == 100
    
def test_request_CM(Accounts, c):
    owner = Accounts[0]
    john = Accounts[1]
    joe = Accounts[2]
    
    owner.setAccountParams(joe, True, 0, 3000, -1000)
    assert c.allowanceCount(john) == 0
    assert c.myAllowanceCount(joe) == 0
    assert c.allowance(john,joe) == 0
    
    with reverts("dev: Check the creator not to be blocked"):
        john.transferCMFrom(joe, 100)
        
    owner.setAccountParams(john, True, 0, 3000, -1000)
    
    # setup Payment Request
    john.transferCMFrom(joe, 100)
    
    assert c.myRequestCount(john) == 1
    assert c.myGetRequest(john,0) == accounts[2] 
    assert c.myRequest(john, joe) == 100
    
    assert c.requestCount(joe) == 1
    assert c.getRequest(joe,0) == accounts[1]
    assert c.request(joe, john) == 100
    
    
    
def test_update_request(Accounts, c):   
    owner = Accounts[0]
    john = Accounts[1]
    joe = Accounts[2]
    owner.setAccountParams(joe, True, 0, 3000, -1000)
    owner.setAccountParams(john, True, 0, 3000, -1000)

    # setup Payment Request
    john.transferFrom(joe, 100)
    assert c.myRequestCount(john) == 1
    assert c.myGetRequest(john,0) == accounts[2] 
    assert c.myRequest(john, joe) == 100
    
    assert c.requestCount(joe) == 1
    assert c.getRequest(joe,0) == accounts[1]
    assert c.request(joe, john) == 100
    
    
    # update Request
    john.transferFrom(joe, 100)
    assert c.myRequestCount(john) == 1
    assert c.myGetRequest(john,0) == accounts[2] 
    assert c.myRequest(john, joe) == 200
    
    assert c.requestCount(joe) == 1
    assert c.getRequest(joe,0) == accounts[1]
    assert c.request(joe, john) == 200
    
    john.transferCMFrom(joe, 100)    
    assert c.myRequestCount(john) == 1
    assert c.myGetRequest(john,0) == accounts[2] 
    assert c.myRequest(john, joe) == 300
    
    assert c.requestCount(joe) == 1
    assert c.getRequest(joe,0) == accounts[1]
    assert c.request(joe, john) == 300
    
    #cannot lower the request
    with reverts("dev: overflow and negative check"):
        john.transferFrom(joe, -100)    
    
    with reverts("dev: overflow and negative check"):
        john.transferCMFrom(joe, -100)  
    
def test_refuse_request(Accounts, c):   
    owner = Accounts[0]
    john = Accounts[1]
    joe = Accounts[2]
    owner.setAccountParams(joe, True, 0, 3000, -1000)
    owner.setAccountParams(john, True, 0, 3000, -1000)
    john.transferFrom(joe, 100)
    assert c.myRequestCount(john) == 1
    assert c.myGetRequest(john,0) == accounts[2] 
    assert c.myRequest(john, joe) == 100
    assert c.requestCount(joe) == 1
    assert c.getRequest(joe,0) == accounts[1]
    assert c.request(joe, john) == 100
    
    joe.cancelRequest(john)
    assert c.myRequestCount(john) == 0
    assert c.myRequest(john, joe) == 0
    assert c.requestCount(joe) == 0
    assert c.request(joe, john) == 0
    
    
    
def test_pay_request(Accounts, c):   
    owner = Accounts[0]
    john = Accounts[1]
    joe = Accounts[2]
    owner.setAccountParams(joe, True, 0, 3000, -1000)
    owner.setAccountParams(john, True, 0, 3000, -1000)

    # setup Payment Request
    john.transferFrom(joe, 100)
    assert c.myRequestCount(john) == 1
    assert c.myGetRequest(john,0) == accounts[2] 
    assert c.myRequest(john, joe) == 100
    
    assert c.requestCount(joe) == 1
    assert c.getRequest(joe,0) == accounts[1]
    assert c.request(joe, john) == 100
    
    owner.setAccountParams(john, False, 0, 3000, -1000)


    
    with reverts("dev: Target account is locked"):
        joe.payRequest(john,50) 
    with reverts("dev: Target account is locked"):
        joe.payRequestCM(john,50) 
   
    owner.setAccountParams(joe, False, 0, 3000, -1000)
    owner.setAccountParams(john, True, 0, 3000, -1000)
    with reverts("dev: Source account is locked"):
        joe.payRequest(john,50) 
    with reverts("dev: Source account is locked"):
        joe.payRequestCM(john,50) 

    owner.setAccountParams(joe, True, 0, 3000, -1000)
    with reverts("dev: Not enough balance"):
        joe.payRequest(john,50) 
    
    owner.pledge(joe,100)
    
    owner.setContractStatus(False)   
    with reverts("dev: panic lock"):
        joe.payRequest(john,50) 
    with reverts("dev: panic lock"):
        joe.payRequestCM(john,50) 
    owner.setContractStatus(True)  
    
    
    joe.payRequest(john,50) 
    assert c.myRequestCount(john) == 1
    assert c.myGetRequest(john,0) == accounts[2] 
    assert c.myRequest(john, joe) == 50
    
    assert c.requestCount(joe) == 1
    assert c.getRequest(joe,0) == accounts[1]
    assert c.request(joe, john) == 50
    
    joe.payRequestCM(john,25) 
    assert c.myRequestCount(john) == 1
    assert c.myGetRequest(john,0) == accounts[2] 
    assert c.myRequest(john, joe) == 25
    
    assert c.requestCount(joe) == 1
    assert c.getRequest(joe,0) == accounts[1]
    assert c.request(joe, john) == 25
    
    # Check more than expected
    with reverts("dev: Ensure that the resulting request is not <0"):
        joe.payRequest(john,50) 
    with reverts("dev: Ensure that the resulting request is not <0"):
        joe.payRequestCM(john,50) 
   
    # check cleaning  
    joe.payRequest(john,25) 
    assert c.myRequestCount(john) == 0
    assert c.myRequest(john, joe) == 0
    
    assert c.requestCount(joe) == 0
    assert c.request(joe, john) == 0
   
def test_info_request(Accounts, c):  
    owner = Accounts[0]
    john = Accounts[1]
    joe = Accounts[2]
    owner.setAccountParams(joe, True, 0, 3000, -1000)
    owner.setAccountParams(john, True, 0, 3000, -1000)
    john.transferFrom(joe, 100)
    joe.cancelRequest(john)
    
    assert c.rejectedCount(john) == 1
    assert c.getRejected(john,0) == accounts[2]
    assert c.rejectedAmount(john,joe) == 100
    
    john.transferFrom(joe, 10)
    
    owner.setAccountParams(joe, False, 0, 3000, -1000)
    with reverts(""):
        joe.cancelRequest(john)
    owner.setAccountParams(joe, True, 0, 3000, -1000)
    
    
    joe.cancelRequest(john)
    
    assert c.rejectedCount(john) == 1
    assert c.getRejected(john,0) == accounts[2]
    assert c.rejectedAmount(john,joe) == 110
    
    
    owner.setAccountParams(john, False, 0, 3000, -1000)
    with reverts(""):
        john.discardRejectedInfo(joe)
    owner.setAccountParams(john, True, 0, 3000, -1000)
    
    john.discardRejectedInfo(joe)
    assert c.rejectedCount(john) == 0
    assert c.rejectedAmount(john,joe) == 0
    
    
    
    # Partial pay
    owner.pledge(joe,100)
    john.transferFrom(joe, 20)
    joe.payRequest(john,11) 
    
    assert c.myRequestCount(john) == 1
    assert c.myGetRequest(john,0) == accounts[2] 
    assert c.myRequest(john, joe) == 9
    
    assert c.requestCount(joe) == 1
    assert c.getRequest(joe,0) == accounts[1]
    assert c.request(joe, john) == 9
    
    assert c.acceptedCount(john) == 1
    assert c.getAccepted(john,0) == accounts[2]
    assert c.acceptedAmount(john,joe) == 11
    
    # Full pay
    joe.payRequest(john,9) 
    
    assert c.acceptedCount(john) == 1
    assert c.getAccepted(john,0) == accounts[2]
    assert c.acceptedAmount(john,joe) == 20
    
    owner.setAccountParams(john, False, 0, 3000, -1000)
    with reverts(""):
        john.discardAcceptedInfo(joe)
    owner.setAccountParams(john, True, 0, 3000, -1000)
    
    
    john.discardAcceptedInfo(joe)
    assert c.acceptedCount(john) == 0
    assert c.acceptedAmount(john,joe) == 0
    
    
    
   

