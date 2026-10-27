public without sharing class EventApprovalController {

    public Id recordId { get; set; }
    public Event eventData { get; set; }
    public User managerUser { get; set; }
    public string thanksurl { get; set; }
    public string publicurl { get; set; }
    public string recordname { get; set; }
    
    public string approverfirstname { get; set; }
    public string approverLastname { get; set; }

    // Dynamic fields
    public String sapCode { get; set; }
    public String ceCisRating { get; set; }
    public String phakicRating { get; set; }
    public String activitydate { get; set; }
    public String countryname { get; set; }
    public String statename { get; set; }
    public String cityname { get; set; }
    public String streetname { get; set; }
    public String name { get; set; }
    public String url { get; set; }
    public String Description { get; set; }
    public String customercommnet { get; set; }
    public String subject { get; set; }
    public String calltype { get; set; }
    public String subcalltype { get; set; }
  

    /*---------------------------------------------
     CONSTRUCTOR – Load Event + Manager + Files
     ---------------------------------------------*/
    public EventApprovalController() {

        recordId = ApexPages.currentPage().getParameters().get('id');
         eventData = new Event();
         customer_creation_url__c urls = customer_creation_url__c.getValues('Customer Creation urls');
         thanksurl = urls.Thank_you_url__c;

        if (recordId == null) {
            ApexPages.addMessage(new ApexPages.Message(
                ApexPages.Severity.ERROR, 'Record ID is missing.'));
            return;
        }

        try {
            // Load event with Lead & Account fields
            List<Event> eventList = [
                SELECT Id, Subject, Description, Type,Call_Type__c, Visit_Date__c, Status__c,
                       ActivityDate, Country__c, State__c, BillingCity__c,Requester_Comment__c,
                       Sub_Call_Type__c,BillingStreet__c, DCR_Description__c,

                       // Owner
                       OwnerId,
                       Owner.FirstName, Owner.LastName,
                      Owner.Email,
                       // Lead values
                       Leads__r.SAP_Code__c,
                       Leads__r.Country__c,
                       Leads__r.Billing_State__c,
                       Leads__r.CE_CIS_Rating__c,
                      Leads__r.Billing_City__c,
                      Leads__r.Billing_Street__c,
                       Account__r.BillingCountry,
                    Account__r.BillingState,
                   Account__r.BillingCity,
                   Account__r.BillingStreet,
                Leads__r.Name,
                Account__r.Name,
                       Leads__r.Phakic_Rating__c,
                    Public_File_Url__c,
                   File_Name__c,
                       Account__r.SAP_Code__c,
                       Account__r.CE_CIS_Rating__c,
                       Account__r.Phakic_Rating__c,

                       CreatedBy.Email, CreatedBy.Name
                FROM Event
                WHERE Id = :recordId
                LIMIT 1 ALL ROWS
            ];

            if (eventList.isEmpty()) {
                ApexPages.addMessage(new ApexPages.Message(
                    ApexPages.Severity.ERROR, 'Event record not found.'));
                return;
            }

            eventData = eventList[0];
            publicurl = eventData.Public_File_Url__c;
            name = eventData.File_Name__c;
            activitydate = formatDate(eventData.ActivityDate);
            Description = eventData.DCR_Description__c;
            customercommnet = eventData.Requester_Comment__c;
            subject =     eventData.Subject;
            calltype = eventData.Call_Type__c;
            subcalltype = eventData.Sub_Call_Type__c;

            assignDynamicLeadAccountFields();

            // Fetch Manager
            if (eventData.OwnerId != null) {
                managerUser = [
                    SELECT Id,Reporting_manager_for_Inclining_branding__r.firstName, Reporting_manager_for_Inclining_branding__r.LastName, Email
                    FROM User
                    WHERE Id = :eventData.OwnerId
                    LIMIT 1
                ];
                if (managerUser.Reporting_manager_for_Inclining_branding__r != null) {
                    
                    approverfirstname = String.isNotBlank(
                        managerUser.Reporting_manager_for_Inclining_branding__r.FirstName
                    ) ? managerUser.Reporting_manager_for_Inclining_branding__r.FirstName : '';
                    
                    approverLastname = String.isNotBlank(
                        managerUser.Reporting_manager_for_Inclining_branding__r.LastName
                    ) ? managerUser.Reporting_manager_for_Inclining_branding__r.LastName : '';
                }

            }

        } catch (Exception e) {
            ApexPages.addMessage(new ApexPages.Message(
                ApexPages.Severity.ERROR, 'Error loading event data: ' + e.getMessage()));
        }
    }
    
     public static String formatDate(Date inputDate) {
        if (inputDate == null) {
            return '';
        }
        Datetime dt = Datetime.newInstance(inputDate, Time.newInstance(0, 0, 0, 0));
        return dt.format('dd/MM/yyyy');
    }

    /*---------------------------------------------
         Dynamic SAP Code / Ratings Logic
     ---------------------------------------------*/
    private void assignDynamicLeadAccountFields() {

        // SAP Code
        if (eventData.Leads__r != null && String.isNotBlank(eventData.Leads__r.SAP_Code__c)) {
            sapCode     = eventData.Leads__r.SAP_Code__c;
            
        } else if (eventData.Account__r != null && String.isNotBlank(eventData.Account__r.SAP_Code__c)) {
            sapCode     = eventData.Account__r.SAP_Code__c;
            
        } else {
            sapCode     = '';
           
        }
        
        if(eventData.Leads__r != null){
            recordname = eventData.Leads__r.Name;
            countryname = eventData.Leads__r.Country__c;
            statename   = eventData.Leads__r.Billing_State__c;
            Cityname    = eventData.Leads__r.Billing_City__c;
            streetname  = eventData.Leads__r.Billing_Street__c;
        }else if(eventData.Account__r != null){
            recordname = eventData.Account__r.Name;
            countryname = eventData.Account__r.BillingCountry;
            statename   = eventData.Account__r.BillingState;
            Cityname    = eventData.Account__r.BillingCity;
            streetname  = eventData.Account__r.BillingStreet;
        }else{
            countryname = '';
            statename   = '';
            Cityname    = '';
            streetname  = '';
        }

        
        

        // CE-CIS Rating
        if (eventData.Leads__r != null && eventData.Leads__r.CE_CIS_Rating__c != null) {
            ceCisRating = eventData.Leads__r.CE_CIS_Rating__c;
        } else if (eventData.Account__r != null && eventData.Account__r.CE_CIS_Rating__c != null) {
            ceCisRating = eventData.Account__r.CE_CIS_Rating__c;
        } else {
            ceCisRating = '';
        }

        // Phakic Rating
        if (eventData.Leads__r != null && eventData.Leads__r.Phakic_Rating__c != null) {
            phakicRating = eventData.Leads__r.Phakic_Rating__c;
        } else if (eventData.Account__r != null && eventData.Account__r.Phakic_Rating__c != null) {
            phakicRating = eventData.Account__r.Phakic_Rating__c;
        } else {
            phakicRating = '';
        }
    }
    /*---------------------------------------------
     Approve / Reject (JS RemoteAction)
     ---------------------------------------------*/
    @RemoteAction
    public static Map<String, Object> ManagerApprovalMethod(String action, String comment, String recordId, String roleKey) {

        Map<String, Object> resultMap = new Map<String, Object>();

        try {
            Event ev = [
                SELECT Id,OwnerId,Owner.Email,Createdby.Reporting_manager_for_Inclining_branding__r.FirstName,Createdby.Reporting_manager_for_Inclining_branding__r.LastName, Approval_Status__c, CreatedBy.Email, Subject
                FROM Event
                WHERE Id = :recordId
                LIMIT 1
            ];

            if (ev.Approval_Status__c == 'Approved') {
                resultMap.put('status', 'error');
                resultMap.put('message', 'This Activity has already been approved.');
                return resultMap;
            }

            if (ev.Approval_Status__c == 'Rejected') {
                resultMap.put('status', 'error');
                resultMap.put('message', 'This Activity has already been rejected.');
                return resultMap;
            }

            Event upd = new Event(Id = recordId);
            

            if (action == 'Approve'){
                 upd.Approval_Status__c = 'Approved';
            }else if (action == 'Reject'){
                upd.Approval_Status__c = 'Rejected';
            }
                
            upd.approver_comment__c = comment;
            update upd;
            
            
            
            if (action == 'Reject') {
                sendRejectionMail(ev);
            }else if (action == 'Approve') {
                sendApprovedMail(ev);
            }

            resultMap.put('status', 'success');
            resultMap.put('message', action + ' submitted successfully.');
            return resultMap;

        } catch (Exception e) {
            resultMap.put('status', 'error');
            resultMap.put('message', 'Error: ' + e.getMessage());
            return resultMap;
        }
    }
    
    public static void sendApprovedMail(Event ev) {
        
        OrgWideEmailAddress owe = [
            SELECT Id FROM OrgWideEmailAddress
            WHERE Address = 'crmhelpdesk@biotechhealthcare.com'
            LIMIT 1
        ];

    Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();

   mail.setToAddresses(new String[] { ev.Owner.Email });
   //mail.setToAddresses(new String[] {'hitarth@creatiquetech.com'});
          
  mail.setSubject('Approved your Approval');
    mail.setOrgWideEmailAddressId(owe.Id);

    mail.setHtmlBody(
        'Hello,<br/><br/>' +
        'Your colleague has <b>approved</b> the activity: <b>' +
        ev.Subject + '</b>.<br/><br/>' +
        'No further action is required from your side.<br/><br/>' +
        'Thanks,<br/>' +
        ev.CreatedBy.Reporting_manager_for_Inclining_branding__r.FirstName + ' ' +
        ev.CreatedBy.Reporting_manager_for_Inclining_branding__r.LastName
    );

    Messaging.sendEmail(
        new Messaging.SingleEmailMessage[] { mail }
    );
}

    
    public static void sendRejectionMail(Event ev) {

    In_Clining_Branding_site_url__c urls = In_Clining_Branding_site_url__c.getValues('In Clining Branding');

        String pageurl = urls.reporty_user_page__c + ev.Id;
        
         OrgWideEmailAddress owe = [
            SELECT Id FROM OrgWideEmailAddress
            WHERE Address = 'crmhelpdesk@biotechhealthcare.com'
            LIMIT 1
        ];
        

    Messaging.SingleEmailMessage mail =  new Messaging.SingleEmailMessage();

   mail.setToAddresses(new String[] { ev.Owner.Email });
   // mail.setToAddresses(new String[] {'hitarth@creatiquetech.com'});
         
   mail.setSubject('Rejected – Your Approval');
    mail.setOrgWideEmailAddressId(owe.Id);

    mail.setHtmlBody(
        'Hello,<br/><br/>' +
        'Your colleague has <b>rejected</b> the activity: <b>' +
        ev.Subject + '</b>.<br/><br/>' +
        'If you want to re-submit this activity for approval, ' +
        'please click the link below:<br/><br/>' +
        '<a href="' + pageurl + '">Re-submit Approval</a><br/><br/>' +
        'Thanks,<br/>'+
        ev.Createdby.Reporting_manager_for_Inclining_branding__r.FirstName +' '+ ev.Createdby.Reporting_manager_for_Inclining_branding__r.LastName
    );
        

    Messaging.sendEmail(
        new Messaging.SingleEmailMessage[] { mail }
    );
}


    /*---------------------------------------------
     Helper: For emails if needed later
     ---------------------------------------------*/
  public static void sendApprovalEmail(Event ev) {
    try {
        system.debug('sendApprovalEmail'+ ev);

        User managerUser = [
            SELECT Id, Reporting_manager_for_Inclining_branding__r.FirstName, Reporting_manager_for_Inclining_branding__r.LastName, Reporting_manager_for_Inclining_branding__r.Email
            FROM User
            WHERE Id = :ev.OwnerId
            LIMIT 1
        ];
         In_Clining_Branding_site_url__c urls =
            In_Clining_Branding_site_url__c.getValues('In Clining Branding');

        String pageurl = urls.Page_Url__c + ev.Id;
        
        
        OrgWideEmailAddress owe = [
            SELECT Id FROM OrgWideEmailAddress
            WHERE Address = 'crmhelpdesk@biotechhealthcare.com'
            LIMIT 1
        ];

        // 5️⃣ Email Body
        String body = generateEmailBody(ev, managerUser, pageurl);

        // 6️⃣ Send Email
        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        
        email.setToAddresses(new String[] { managerUser.Reporting_manager_for_Inclining_branding__r.Email});
        //email.setToAddresses(new String[] {'varish@creatiquetech.com'});
        
        email.setSubject('In Clinic Branding Approval Request');
        email.setPlainTextBody(body);
        email.setOrgWideEmailAddressId(owe.Id);

        Messaging.sendEmail(new Messaging.SingleEmailMessage[] { email });

    } catch (Exception e) {
        System.debug('Email failed: ' + e.getMessage());
        System.debug('Line Number: ' + e.getLineNumber());
        System.debug('Stack Trace: ' + e.getStackTraceString());
    }

}

   public static String generateEmailBody(Event ev,user managerUser, string url) {

    String managerName = managerUser != null ? managerUser.Reporting_manager_for_Inclining_branding__r.FirstName + ' ' + managerUser.Reporting_manager_for_Inclining_branding__r.LastName : 'Manager';
    String teamMemberName = ev.Owner != null ? ev.Owner.FirstName + ' ' + ev.Owner.LastName : 'Team Member';

    return ''
    + 'Hello ' + managerName + ',\n\n'
    + 'Your team member, ' + teamMemberName + ', has submitted a request for approval of an In-Clinic Branding activity that has been completed.\n\n'
    + 'Please review the details and the attached document using the link below, and share your comments (if any), along with your approval or rejection, so the task can be closed successfully.\n\n'
    + 'Link: ' + url + '\n\n'
    + 'Regards,\n'
    + 'Biotech Healthcare,\n\n'
    + '(This is an auto-generated notification from the Salesforce system. Please do not reply to this email.)';
}
}