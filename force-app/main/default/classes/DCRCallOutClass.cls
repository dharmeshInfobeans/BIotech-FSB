/****************************************************************************************
Author : Prashant Rana
Description : This class will make a callout to an external system on DCR approved
Date : 2019-04-08
*****************************************************************************************/
public class DCRCallOutClass {
    public static void  doCallOut(event eventObj){
        System.debug('Event  : '+eventObj);
        RequestWrapper wrapObj = new RequestWrapper();
        try {
            user userObj = [select id, name ,Employee_Code__c from user where id = : UserInfo.getUserId() limit 1];
          /* event eventObj = [select subject,EndDateTime,Call_Type__c,UniqueId__c,Account__r.SAP_Code__c,
                                  Account__r.BillingCity, Status__c, StartDateTime from event where id =: eventId limit 1];
           */ if(eventObj !=null){
                wrapObj.EmpCode = userObj.Employee_Code__c;
                wrapObj.EndTime = eventObj.EndDateTime.time();
                wrapObj.StartTime = eventObj.StartDateTime.time();
                wrapObj.Status = eventObj.Status__c;
                wrapObj.UniqueId = eventObj.UniqueId__c;
                wrapObj.EventDate = eventObj.StartDateTime.date();
                wrapObj.Subject = eventObj.Subject;
                wrapObj.CallType = eventObj.Call_Type__c;
                wrapObj.Location = eventObj.Account__r.BillingCity;
                wrapObj.SAPCode = eventObj.Account__r.SAP_Code__c;
                string JSONString = JSON.serialize(wrapObj); 
                HttpRequest req = new HttpRequest();
                req.setBody(JSONString);
                req.setMethod('POST');
                req.setHeader('content-type', 'application/json');
                //Get the endPoint from custom  label
                req.setEndpoint(Label.DCR_API_URL);
                Http h = new Http();
                HttpResponse res = h.send(req);
                System.debug('response from server : '+res);
                if(res.getStatusCode() == 200){
                    eventObj.API_Status__c = 'Success';
                }else {
                    eventObj.API_Status__c = 'Failure';
                }
                System.debug('event for update : '+eventObj);
                update eventObj;
            }
            
        } catch (Exception e) {
           System.debug('Error in DCR Callout class : '+e.getMessage()+', At line no : '+e.getLineNumber());
           eventObj.API_Status__c = 'Failure';
           update eventObj;
        }
    }

    //Wrapper class for request
    public class RequestWrapper{
        String Subject;
        Date EventDate;
        String SAPCode;
        String EmpCode;
        time StartTime;
        time EndTime;
        string Status;
        String CallType;
        String Location;
        String UniqueId;
    }
}