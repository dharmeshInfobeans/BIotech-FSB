public class AdminApprovalProcessforSampleLead {
    
    //@InvocableMethod(label='Send Sample Request for Lead Email' description='Sends an email notification for sample request line item Approval')
    public static void sendMOUEmail(Id schemeIds) {
        System.debug('schemeIds: ' + schemeIds);
        
        if (schemeIds == null) {
            return;
        }
        
        // Fetch Scheme Records
        List<Sample_Request_Header__c> schemeRecords = [
            SELECT Id, Leads__c, Leads__r.Plant__c, Leads__r.Plant_Code__c,leads__r.SAP_Code__c ,Leads__r.Name, 
                   Order_Number__c, Country__c, Remarks__c,orderNumSAP__c,Ship_to_Code__c
            FROM Sample_Request_Header__c 
            WHERE Id =:schemeIds 
            LIMIT 1
        ];
        
        if (schemeRecords.isEmpty() || schemeRecords[0].Leads__r == null) {
            System.debug('No valid scheme records or Leads__r is null.');
            return;
        }
        
        // Fetch Line Items
        List<Sample_Request_Line_Item__c> lineItems = [
            SELECT Id, Name, Dummy_Product_Description__c, Product_Code_SAP_Code__c, 
                   Diaptor__c, Product_Quantity__c
            FROM Sample_Request_Line_Item__c 
            WHERE Sample_Request_Header__c = :schemeRecords[0].Id
            ORDER BY Diaptor__c ASC
        ];
        
        // Get Org-Wide Email Address
        List<OrgWideEmailAddress> oweaList = [
            SELECT Id 
            FROM OrgWideEmailAddress 
            WHERE Address = 'crmhelpdesk@biotechhealthcare.com' 
            LIMIT 1
        ];
        
        if (oweaList.isEmpty()) {
            System.debug('No Org-Wide Email Address found.');
            return;
        }
        
        // Fetch recipient email addresses from Sales Data
        List<Sample_Request_Branch_Email__c> slsDataList = [
            SELECT Id, Branch_Email__c 
            FROM Sample_Request_Branch_Email__c 
            WHERE Branch_Name__c = :schemeRecords[0].Leads__r.Plant__c 
            AND Branch_Code__c = :schemeRecords[0].Leads__r.Plant_Code__c
        ];
        
        List<String> toAddresses = new List<String>();
        if (!slsDataList.isEmpty() && String.isNotBlank(slsDataList[0].Branch_Email__c)) {
            toAddresses = slsDataList[0].Branch_Email__c.split(',');
            System.debug('toAddresses: ' + toAddresses);
        }
        
        if (toAddresses.isEmpty()) {
            System.debug('No valid recipient emails found.');
            toAddresses.add('Gyadeen@plus91labs.com');
           return;
        }
        
        // Fetch MOU Scheme URL from custom settings
       /* Sample_request_urls__c urls = Sample_request_urls__c.getInstance('Sample request URL');
        if (urls == null || String.isBlank(urls.Admin_approval_for_lead__c)) {
            System.debug('No valid URL found.');
            return;
        }*/
        
       // String approvalUrl = urls.Admin_approval_for_lead__c + schemeRecords[0].Id;
        
      // Build HTML Email Body
String htmlBody = '<html><body>';
htmlBody += '<h3 style="font-family: Arial; font-size: 18px; font-style: italic;">Sample Order Form</h3>';
        
        // Header Table
        htmlBody += '<table border="1" cellpadding="5" cellspacing="0" style="border-collapse:collapse; font-family:Arial; width: 100%; border: 2px solid black;">';
        
        // Header section
        htmlBody += '<tr><td style="border: 1px solid black; font-weight: bold; text-align: center; vertical-align: middle;">Order Type</td><td style="border: 1px solid black; font-style: italic; text-align: center; vertical-align: middle;">SAMPLE ORDER</td></tr>';
        
        htmlBody += '<tr><td style="border: 1px solid black; font-weight: bold; text-align: center; vertical-align: middle;">Customer Name</td><td style="border: 1px solid black; text-align: center; vertical-align: middle;">' + 
            (schemeRecords[0].Leads__r.Name != null ? schemeRecords[0].Leads__r.Name : '') + '</td></tr>';
        
        htmlBody += '<tr><td style="border: 1px solid black; font-weight: bold; text-align: center; vertical-align: middle;">Customer Code</td><td style="border: 1px solid black; text-align: center; vertical-align: middle;">' + 
            (schemeRecords[0].Leads__r.SAP_Code__c != null ? schemeRecords[0].Leads__r.SAP_Code__c : '') + '</td></tr>';
        
        htmlBody += '<tr><td style="border: 1px solid black; font-weight: bold; text-align: center; vertical-align: middle;">Shipping Code</td><td style="border: 1px solid black; text-align: center; vertical-align: middle;">' + 
            (schemeRecords[0].Ship_to_Code__c != null ? schemeRecords[0].Ship_to_Code__c : '') + '</td></tr>';
        
        htmlBody += '<tr><td style="border: 1px solid black; font-weight: bold; text-align: center; vertical-align: middle;">Salesforce Order ID</td><td style="border: 1px solid black; text-align: center; vertical-align: middle;">' + 
            ('SMO_'+schemeRecords[0].Id != null ? 'SMO_'+schemeRecords[0].Id : '') + '</td></tr>';
        
        htmlBody += '<tr><td style="border: 1px solid black; font-weight: bold; text-align: center; vertical-align: middle;">SAP Order No.</td><td style="border: 1px solid black; text-align: center; vertical-align: middle;">' + 
            (schemeRecords[0].orderNumSAP__c != null ? schemeRecords[0].orderNumSAP__c : '') + '</td></tr>';
        
        htmlBody += '<tr><td style="border: 1px solid black; font-weight: bold; text-align: center; vertical-align: middle;">Branch Name & Code</td><td style="border: 1px solid black; text-align: center; vertical-align: middle;">' + 
            (schemeRecords[0].Leads__r.Plant__c != null ? schemeRecords[0].Leads__r.Plant__c : '') + '||' + 
            (schemeRecords[0].Leads__r.Plant_Code__c != null ? schemeRecords[0].Leads__r.Plant_Code__c : '') + '</td></tr>';
        
        htmlBody += '<tr><td style="border: 1px solid black; font-weight: bold; text-align: center; vertical-align: middle;">Country</td><td style="border: 1px solid black; text-align: center; vertical-align: middle;">' + 
            (schemeRecords[0].Country__c != null ? schemeRecords[0].Country__c : '') + '</td></tr>';
        
        htmlBody += '<tr><td style="border: 1px solid black; font-weight: bold; text-align: center; vertical-align: middle;">Remarks by Sals team</td><td style="border: 1px solid black; text-align: center; vertical-align: middle;">' + 
            (schemeRecords[0].Remarks__c != null ? schemeRecords[0].Remarks__c : '') + '</td></tr>';
        
        htmlBody += '</table>';
        
        // Line Items Table
        htmlBody += '<table border="1" cellpadding="5" cellspacing="0" style="border-collapse:collapse; font-family:Arial; width: 100%; border: 1px solid black;">';
        
        // Line Items Header
        htmlBody += '<tr>';
        htmlBody += '<th style="border: 1px solid black; text-align: center; vertical-align: middle;">Sl. No.</th>';
        htmlBody += '<th style="border: 1px solid black; text-align: center; vertical-align: middle;">Name</th>';
        htmlBody += '<th style="border: 1px solid black; text-align: center; vertical-align: middle;">SKU</th>';
        htmlBody += '<th style="border: 1px solid black; text-align: center; vertical-align: middle;">Diopter</th>';
        htmlBody += '<th style="border: 1px solid black; text-align: center; vertical-align: middle;">Sales Order Quantity</th>';
        htmlBody += '</tr>';
        
        // Line Items Data
        Integer counter = 1;
        for (Sample_Request_Line_Item__c item : lineItems) {
            htmlBody += '<tr>';
            htmlBody += '<td style="border: 1px solid black; text-align: center; vertical-align: middle;">' + counter + '</td>';
            htmlBody += '<td style="border: 1px solid black; text-align: center; vertical-align: middle;">' + (item.Dummy_Product_Description__c != null ? item.Dummy_Product_Description__c : '') + '</td>';
            htmlBody += '<td style="border: 1px solid black; text-align: center; vertical-align: middle;">' + (item.Product_Code_SAP_Code__c != null ? item.Product_Code_SAP_Code__c : '') + '</td>';
            htmlBody += '<td style="border: 1px solid black; text-align: center; vertical-align: middle;">' + (item.Diaptor__c != null ? item.Diaptor__c : '') + '</td>';
            htmlBody += '<td style="border: 1px solid black; text-align: center; vertical-align: middle;">' + (item.Product_Quantity__c != null ? item.Product_Quantity__c : 0) + '</td>';
            htmlBody += '</tr>';
            counter++;
        }
        
        htmlBody += '</table>';
        htmlBody += '</body></html>';


        
        // Create Email Message
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(toAddresses);
        mail.setSubject('Sample Order Creation');
        mail.setHtmlBody(htmlBody);
        mail.setOrgWideEmailAddressId(oweaList[0].Id);
        
        // Send Email
        try {
            Messaging.SendEmailResult[] results = Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{mail});
            for (Messaging.SendEmailResult result : results) {
                if (!result.isSuccess()) {
                    System.debug('Failed to send email: ' + result.getErrors()[0].getMessage());
                } else {
                    System.debug('Email sent successfully.');
                }
            }
        } catch (Exception e) {
            System.debug('Error sending email: ' + e.getMessage());
        }
    }
}