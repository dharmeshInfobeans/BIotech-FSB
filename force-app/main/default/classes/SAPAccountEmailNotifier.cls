/**
* SAPAccountEmailNotifier
* ------------------------
* Builds and sends the "New SAP Account Request" HTML email.
* Colors, logo, and layout treatment matched exactly from the working
* "Sample Request Approved/Rejected" email template (messaging:emailTemplate).
*
* FIELD LIST: uses only fields confirmed to exist on this org via the
* verified SOQL:
*   Id, Owner.Name, Owner.Sales_District__c, Owner.Employee_Code__c,
*   Owner.L1_Manager__c, Owner.L1_Manager__r.Name, Owner.L1_Manager__r.Employee_Code__c,
*   Owner.Main_Division__c, Owner.Sub_Division__c,
*   Name, CreatedDate, BillingCity, Zone_Code__c, Zone_Name__c, Sales_District__c,
*   RSM__c, RSM__r.Name, RSM__r.Employee_Code__c,
*   ZSM__c, ZSM__r.Name, ZSM__r.Employee_Code__c, SAP_Code__c
*
* STILL PENDING (not in class - fields not yet confirmed to exist on Account):
* Ship to Code, Ship to Customer, State, Country,
* GM, NSM, DM, Global Phakic Head, GSRO. Send the real API names when you
* have them and these rows can be added the same way.
*/
public without sharing class SAPAccountEmailNotifier {
    
    // ---- Brand palette (matched exactly from the approved/rejected template) --
    private static final String COLOR_ACCENT        = '#2f4f4f'; // top/bottom bars, card header, red-alt for rejected states
    private static final String COLOR_PAGE_BG        = '#f4f6f9'; // outer page background
    private static final String COLOR_PANEL_BG       = '#dfe6ee'; // grey content panel
    private static final String COLOR_DIVIDER        = '#999999'; // divider line under panel content
    private static final String COLOR_LABEL          = '#8a97a1'; // field labels (card grid)
    private static final String COLOR_TEXT           = '#333333'; // body / field values / title
    private static final String COLOR_LINK           = '#1a73e8'; // support email link
    private static final String COLOR_FOOTER_TEXT    = '#777777'; // footer email line
    private static final String COLOR_FOOTER_MUTED   = '#999999'; // copyright line
    private static final String COLOR_FOOTER_FAINT   = '#aaaaaa'; // disclaimer line
    private static final String COLOR_CARD_BORDER    = '#dfe3e8'; // card borders
    private static final String FONT_STACK           = 'Arial, Helvetica, sans-serif';
    
    // Logo image - taken from the working Sample Request Approved/Rejected template
    private static final String LOGO_URL =
        'https://biotechcrm--testbiot.sandbox.my.salesforce.com/servlet/servlet.ImageServer?id=015C30000047jxN&oid=00DC3000002I023';
    
    /**
* Original entry point (uses actual Owner.Main_Division__c / Owner.Sub_Division__c
* from the Account record). Kept for backward compatibility.
*/
    /* public static void sendNewAccountRequestEmail(List<Id> accountIds, String toAddress, String raisedByName) {
List<Account> accounts = queryAccounts(accountIds);
if (accounts.isEmpty()) {
return;
}
sendEmailInternal(accounts, toAddress, raisedByName, null, null);
}*/
    
    /**
* Overloaded entry point: allows passing STATIC Main Division / Sub Division
* values that override whatever is on the Account Owner record.
*/
    /*    public static void sendNewAccountRequestEmail(List<Id> accountIds, String toAddress, String raisedByName, String mainDivisionOverride, String subDivisionOverride) {
List<Account> accounts = queryAccounts(accountIds);
if (accounts.isEmpty()) {
return;
}
sendEmailInternal(accounts, toAddress, raisedByName, mainDivisionOverride, subDivisionOverride);
}*/
    
/*public static void oppEmail(Id oppId,String billingCountry){
        List<SAP_Country_Config__mdt > sapCountryConfig = [select Country__c,Mis_Team_Mail__c from SAP_Country_Config__mdt];
        Map<String,String> mapOfEmail = new Map<String,String>();
        for(SAP_Country_Config__mdt sapCountry : sapCountryConfig){
            mapOfEmail.put(sapCountry.Country__c , sapCountry.Mis_Team_Mail__c);
        }
        if(mapOfEmail.containsKey(billingCountry) && mapOfEmail.get(billingCountry) != null)    sendNewAccountRequestEmail(oppId,mapOfEmail.get(billingCountry));
        
        
    }*/
    	
    
    public static void oppEmail(List<Opportunity__c> oppList){
        List<SAP_Country_Config__mdt > sapCountryConfig = [select Country__c,Mis_Team_Mail__c from SAP_Country_Config__mdt];
        Map<String,String> mapOfEmail = new Map<String,String>();
        for(SAP_Country_Config__mdt sapCountry : sapCountryConfig){
            mapOfEmail.put(sapCountry.Country__c , sapCountry.Mis_Team_Mail__c);
        }
        for(Opportunity__c opp : oppList){
            System.debug('Opp : '+ opp.Country__c);
            System.debug('mapOfEmail'+mapOfEmail);
              if(mapOfEmail.containsKey(opp.Country__c) && mapOfEmail.get(opp.Country__c) != null) sendNewAccountRequestEmail(opp.Id,mapOfEmail.get(opp.Country__c));
        }
     //   if(mapOfEmail.containsKey(billingCountry) && mapOfEmail.get(billingCountry) != null)    sendNewAccountRequestEmail(oppId,mapOfEmail.get(billingCountry));
        
        
    }
    
    
    public static void sendNewAccountRequestEmail(Id oppId, String toAddress) {
        //Opportunity__c opp = [SELECT Id,Name, TYPEOF Owner WHEN User THEN Name, Sales_District__c, Title , L1_Manager__c, L1_Manager__r.Name, L1_Manager__r.Employee_Code__c, Main_Division__c, Sub_Division__c END, Account__r.Name, Account__r.CreatedDate, Account__r.BillingCity, Account__r.BillingCountry, Account__r.Zone_Code__c, Account__r.Zone_Name__c,Account__r.SAP_Code__c, Account__r.Sales_District__c, RSM__c, RSM__r.Name, RSM__r.Title , ZSM__c, ZSM__r.Name, ZSM__r.Title , SAP_Code__c FROM Opportunity__c WHERE Id = :oppId];
        Opportunity__c opp = [SELECT Id,Name, OwnerId,Account__r.New_Owner__c,Country__c, Account__r.Name, Account__r.CreatedDate, Account__r.BillingCity, Account__r.BillingCountry, Account__r.Zone_Code__c, Account__r.Zone_Name__c,Account__r.SAP_Code__c, Account__r.Sales_District__c, RSM__c, RSM__r.Name, RSM__r.Public_Title__c , ZSM__c, ZSM__r.Name, ZSM__r.Public_Title__c , SAP_Code__c FROM Opportunity__c WHERE Id = :oppId];
       	System.debug('oppRSM --- '+opp.RSM__r.Name+'--'+opp.RSM__r.Public_Title__c);
        System.debug('oppRSM --- '+opp.ZSM__r.Name+'--'+opp.ZSM__r.Public_Title__c);
        if (opp == null) {
            return;
        }
        User owner = [SELECT Id, Name, Sales_District__c ,Public_Title__c, L1_Manager__c, L1_Manager__r.Name, L1_Manager__r.Employee_Code__c, Main_Division__c, Sub_Division__c FROM User WHERE Id = :opp.Account__r.New_Owner__c LIMIT 1];
        SAP_Country_Config__mdt  countryConfig = [SELECT Id,Operation_Admin_Name__c  FROM SAP_Country_Config__mdt  WHERE Country__c =: opp.Country__c];
        sendEmailInternal(opp,owner, countryConfig,toAddress);	
    }
    
    /** Shared SOQL query used by both entry points. */
    private static List<Account> queryAccounts(List<Id> accountIds) {
        return [
            SELECT Id,
            Owner.Name, Owner.Sales_District__c, Owner.Employee_Code__c,
            Owner.L1_Manager__c, Owner.L1_Manager__r.Name, Owner.L1_Manager__r.Employee_Code__c,
            Owner.Main_Division__c, Owner.Sub_Division__c,
            Name, CreatedDate, BillingCity,
            Zone_Code__c, Zone_Name__c, Sales_District__c,
            RSM__c, RSM__r.Name, RSM__r.Employee_Code__c,
            ZSM__c, ZSM__r.Name, ZSM__r.Employee_Code__c,
            SAP_Code__c
            FROM Account
            WHERE Id IN :accountIds
        ];
    }
    
    /** Shared email-build-and-send logic. */
    /** Shared email-build-and-send logic. */
    private static void sendEmailInternal(Opportunity__c opp,User owner,SAP_Country_Config__mdt countryConfig, String toAddress) {
        System.debug('opp'+opp+'qwduib'+'owner'+owner+'countryConfig'+countryConfig+'toAddress'+toAddress);
        System.debug('Public Title----'+owner.Public_Title__c);
        if(toAddress != null){  
            
            //Send Email
          OrgWideEmailAddress owea = new OrgWideEmailAddress();
           owea = [SELECT Id, Address, DisplayName FROM OrgWideEmailAddress WHERE Address = 'crmhelpdesk@biotechhealthcare.com' WITH SYSTEM_MODE];
            System.debug('gdyuyv'+owea);
            
          Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();

              if(owea != NULL){
                    mail.setOrgWideEmailAddressId(owea.Id);
                }
             
              List<String> toAddressList = toAddress.contains(',') ? toAddress.split(',\\s*')  : new List<String>{ toAddress };
            
            mail.setToAddresses(toAddressList);
            mail.setSubject('New Conversion ' + opp.Name + ' - City: ' + opp.Account__r.BillingCity);
            //  mail.setToAddresses(new List<String>{ toAddress });
            // mail.setSubject('New SAP Account Request' + (accounts.size() == 1 ? ' - ' + accounts[0].Name : ''));
            mail.setHtmlBody(buildEmailHtml(opp,owner,countryConfig));
            mail.setSaveAsActivity(false);
            
            try {
                Messaging.SendEmailResult[] results =
                    Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail });
                
                if (results != null && !results.isEmpty() && results[0].isSuccess()) {
                    System.debug('Email sent successfully to: ' + String.join(toAddressList, ', '));
                } else if (results != null && !results.isEmpty()) {
                    System.debug(LoggingLevel.ERROR, 'Email failed to send to: ' + String.join(toAddressList, ', '));
                    for (Messaging.SendEmailError err : results[0].getErrors()) {
                        System.debug(LoggingLevel.ERROR, 'Error message: ' + err.getMessage());
                        System.debug(LoggingLevel.ERROR, 'Status code: ' + err.getStatusCode());
                    }
                }
            } catch (Exception e) {
                // Catches hard failures that never reach SendEmailResult at all -
                // e.g. NoAccessException from restrictive Email Deliverability
                // settings, or an invalid/unverified OrgWideEmailAddress.
                System.debug(LoggingLevel.ERROR, 'Messaging.sendEmail threw an exception: ' + e.getMessage());
            }
        }
    }
    
    /**
* Builds the full HTML email body.
* mainDivisionOverride / subDivisionOverride: if provided (non-null), these
* STATIC values are shown instead of the Account Owner's actual division fields.
*/
    public static String buildEmailHtml(Opportunity__c opp,User owner,SAP_Country_Config__mdt countryConfig) {
        String requestDate = System.now().format('dd-MMM-yyyy');
        
        String cardsHtml = '';
        cardsHtml =  buildCardHtml(opp,owner,countryConfig);
        /*for (Account acc : accounts) {
cardsHtml += buildCardHtml(opp,owner, mainDivisionOverride, subDivisionOverride);
}*/
        
        return
            '<html><body style="margin:0;padding:0;font-family:' + FONT_STACK + ';background-color:' + COLOR_PAGE_BG + ';">' +
            '<table width="100%" cellpadding="0" cellspacing="0" align="center">' +
            '<tr><td align="center">' +
            
            // ---- Top accent bar + logo + title --------------------------
            '<table width="600">' +
            '<tr><td align="center" style="padding-top:30px;">' +
            '<div style="width:80px;height:4px;background-color:' + COLOR_ACCENT + ';"></div>' +
            '</td></tr>' +
            '<tr><td align="center" style="padding:10px 0;">' +
            '<img src="' + LOGO_URL + '" style="height:50px;display:block;margin:7px auto;" />' +
            '</td></tr>' +
            '<tr><td align="center" style="padding:10px 0 20px 0;">' +
            '<h3 style="margin:0;color:' + COLOR_TEXT + ';">New SAP Account Creation Request</h3>' +
            '</td></tr>' +
            '</table>' +
            
            // ---- Content box: intro panel + cards + closing -------------
            '<table width="600">' +
            '<tr><td style="background-color:' + COLOR_PANEL_BG + ';padding:25px;border-radius:4px;color:' + COLOR_TEXT + ';font-size:14px;line-height:1.6;">' +
            
            '<strong>Dear Team,</strong><br/><br/>' +
            'A new SAP Account has been created for the request submitted by <strong>' + escape(owner.Name) + '</strong> on <strong>' + requestDate + '</strong>.<br/><br/>' +
            'Please find the relevant customer details below for furthur processing.<br/><br/>' +
            
            cardsHtml +
            
            'For any queries, clarifications, or further assistance, kindly contact our support team at  ' +
            '<a href="mailto:esupport@biotechhealthcare.com" style="color:' + COLOR_LINK + ';">sfadoption@biotechhealthcare.com</a>.<br/><br/>' +
            'Thank you.<br/><br/>' +
            
            '<div style="border-top:1px solid ' + COLOR_DIVIDER + ';margin-top:10px;"></div>' +
            
            '</td></tr>' +
            '</table>' +
            
            // ---- Footer: logo + contact + legal + bottom accent bar -----
            '<table width="600">' +
            '<tr><td align="center" style="padding:20px 0px 5px;">' +
            '<img src="' + LOGO_URL + '" style="height:40px;display:block;margin:10px auto;" />' +
            '<p style="font-size:12px;color:' + COLOR_FOOTER_TEXT + ';">sfadoption@biotechhealthcare.com</p>' +
            '<p style="font-size:11px;color:' + COLOR_FOOTER_MUTED + ';">&copy; Copyright Biotech | Terms Of Use - Privacy Policy</p>' +
            '<p style="font-size:11px;color:' + COLOR_FOOTER_FAINT + ';">This email was sent from an email address that can\'t receive emails. Please don\'t reply to this email.</p>' +
            '</td></tr>' +
            '<tr><td align="center">' +
            '<div style="width:82%;height:4px;background-color:' + COLOR_ACCENT + ';"></div>' +
            '</td></tr>' +
            '</table>' +
            
            '</td></tr>' +
            '</table>' +
            '</body></html>';
    }
    
    /**
* Builds a single record card using only confirmed-real fields:
* Customer Code, Customer Name, Creation Date, City, Zone Code,
* Zone Name, Sales District, Owner's Sales District, Main/Sub
* Division, SAE/KAM/TM/RM (Owner), RSM, ZSM, L1 Manager -
* each role shown as Name (Employee Code).
*
* If mainDivisionOverride / subDivisionOverride are provided (non-null),
* they are shown instead of Owner.Main_Division__c / Owner.Sub_Division__c.
*/
    private static String buildCardHtml(Opportunity__c opp,User owner,SAP_Country_Config__mdt countryConfig) {
        String mainDivisionValue = owner?.Main_Division__c != null ? owner.Main_Division__c : '';
        String subDivisionValue  = owner?.Sub_Division__c != null ? owner.Sub_Division__c : '';
        
        return
            '<table width="100%" cellpadding="0" cellspacing="0" style="border:1px solid ' + COLOR_CARD_BORDER + ';margin-bottom:16px;background-color:#ffffff;">' +
            
            '<tr><td style="background-color:' + COLOR_ACCENT + ';padding:11px 20px;">' +
            '<span style="color:#ffffff;font-size:13px;font-weight:bold;font-family:' + FONT_STACK + ';">' +
            escape(opp.Account__r.Name) + ' &nbsp;&bull;&nbsp; Customer Code ' + val(opp.Account__r.SAP_Code__c) +
            '</span>' +
            '</td></tr>' +
            
            '<tr><td style="padding:18px 20px 6px 20px;">' +
            '<table width="100%" cellpadding="0" cellspacing="0" style="font-size:13px;font-family:' + FONT_STACK + ';">' +
            
            '<tr>' + fieldCell('Customer Code', val(opp.Account__r.SAP_Code__c)) + fieldCell('Customer Name', val(opp.Account__r.Name)) + '</tr>' +
            '<tr>' + fieldCell('Customer Code Creation Date', opp.Account__r.CreatedDate == null ? '-' : opp.Account__r.CreatedDate.format('dd-MMM-yyyy')) + fieldCell('City', val(opp.Account__r.BillingCity)) + '</tr>' +
            '<tr>' + fieldCell('Zone Code', val(opp.Account__r.Zone_Code__c)) + fieldCell('Zone Name', val(opp.Account__r.Zone_Name__c)) + '</tr>' +
            '<tr>' + fieldCell('Sales District', val(opp.Account__r.Sales_District__c)) + fieldCell('Owner Sales District', val(owner?.Sales_District__c)) + '</tr>' +
            '<tr>' + fieldCell('Main Division', val(mainDivisionValue)) + fieldCell('Sub Division', val(subDivisionValue)) + '</tr>' +
            
            '<tr>' +
            fieldCell('Requested By', nameWithCode(owner?.Name, owner?.Public_Title__c )) +
            fieldCell('Approver 1', nameWithCode(opp.RSM__r?.Name, opp.RSM__r?.Public_Title__c )) +
            '</tr>' +
            '<tr>' +
            fieldCell('Approver 2', nameWithCode(opp.ZSM__r?.Name, opp.ZSM__r?.Public_Title__c )) +
            fieldCell('Operations Admin', nameWithCode(countryConfig?.Operation_Admin_Name__c, 'Operations Admin')) +
            '</tr>' +
            
            '</table>' +
            '</td></tr>' +
            
            '</table>';
    }
    
    /** One label/value <td> in the two-column card grid. */
    private static String fieldCell(String label, String value) {
        return '<td width="50%" style="padding:7px 0;vertical-align:top;">' +
            '<span style="color:' + COLOR_LABEL + ';font-size:12px;">' + escape(label) + '</span><br/>' +
            '<span style="color:' + COLOR_TEXT + ';font-size:13px;">' + value + '</span>' +
            '</td>';
    }
    
    /** "Name (Employee Code)" - falls back to "-" when both are blank. */
    private static String nameWithCode(String name, String empCode) {
        String n = String.isBlank(name) ? '-' : escape(name);
        String c = String.isBlank(empCode) ? '-' : escape(empCode);
        if (n == '-' && c == '-') {
            return '-';
        }
        return n + ' (' + c + ')';
    }
    
    /** Blank-safe, HTML-escaped field value. */
    private static String val(String v) {
        return String.isBlank(v) ? '-' : escape(v);
    }
    
    /** Basic HTML-escape so record data can't break the markup. */
    private static String escape(String v) {
        return String.isBlank(v) ? '-' : v.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;');
    }
}