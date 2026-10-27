@isTest
public class ExpenseTrackerControllerTest {
  
    public static testmethod void TestExpense()
    {
    ExpenseTrackerController.getUserData();
        UrlConfigData__c config_data=new UrlConfigData__c(Token__c='',URL__c='http://procesys.archisys.biz/autoLogin?token=',name='ExpenseUrl');
        insert config_data;
        ExpenseTrackerController.getUrlConfigFromCS();
    }
 }