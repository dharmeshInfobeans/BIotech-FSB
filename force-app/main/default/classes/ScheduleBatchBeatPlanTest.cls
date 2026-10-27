@istest
public class ScheduleBatchBeatPlanTest {
    static testmethod void test1(){
        event evobj = new event();
        evobj.subject = 'test';
        evobj.Visit_Date__c = date.today();
        evobj.StartDateTime = system.now();
        evobj.EndDateTime = system.now();
        insert evobj;
        ScheduleBatchBeatPlan obj = new ScheduleBatchBeatPlan();
        obj.execute(null); 
    }
}