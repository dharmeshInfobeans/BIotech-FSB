/************************************************************************
Author : Prashant Rana
Description : This test class will cover DCR Callout class
Date : 2019-04-09
Coverage : 96%
**************************************************************************/
@istest
public class DCRCallOutClassTest {
    @IsTest
    static void methodName(){
        
        Test.startTest();
        event obj = new event();
        obj.subject = 'test';
        obj.startDateTime = system.now();
        obj.endDateTime = System.now().addDays(1);
        obj.Checkout__Latitude__s = 77.0000;
        obj.Checkout__Longitude__s = 24.0000;
        obj.Status__c = 'Approved';
        insert obj;

        CIty__c robj = new CIty__c();
        robj.country_key__c = 'IN';
        robj.Name = 'Maharashtra';
        robj.Region_Code__c = 'DL';

        insert robj;

        Account accObj = new Account();
        
        accObj.Name = 'Test';
        accObj.AccountNumber = '12345678';
        accObj.Region__c = robj.Id;
        accObj.Street_2__c = 'street2';
        accObj.Street_3__c = 'street3';
        accObj.Street_4__c = 'street4';
        accObj.Street_5__c = 'street5';
        accObj.Country_Key__c='IN';
        accObj.City__c='mumbai';
        accObj.City_postal_code__c='400001';
        accObj.Medical_Registration_No__c = '123';
        accObj.GSTIN_No__c='GSTIN2343423456';
        insert accObj;

        Test.setMock(HttpCalloutMock.Class, new DCRCallOutMockTest());
        DCRCallOutClass.doCallOut(obj);
        String CRON_EXP = '0 0 0 28 2 ? 2022';
        system.schedule('jobName', CRON_EXP, new BatchDCRCallOutSchedule());
        Test.stopTest();
        
    }
}