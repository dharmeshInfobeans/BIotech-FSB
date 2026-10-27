public class AdminApprovalProcessforSampleAccount {
    
    //@InvocableMethod(label='Send sample request for Account Email' description='Sends an email notification for sample request line item Approval')
    public static void sendMOUEmail(Id schemeIds) {
        try {
            if (schemeIds == null) {
                System.debug('⚠️ No scheme IDs provided.');
                return;
            }
            
            // ✅ Fetch Scheme Records
            List<Sample_Request_Header__c> schemeRecords = [
                SELECT Id, Customer__c,Bill_To_Code__c,Customer__r.SAP_code__c, Customer__r.Branch_Code__c, 
                Customer__r.Branch_Name__c, OrderId__c, Order_Number__c,orderNumSAP__C,ship_to_code__c,
                Country__c, Remarks__c, Customer__r.Name
                FROM Sample_Request_Header__c 
                WHERE Id =:schemeIds 
                LIMIT 1
            ];
            
            if (schemeRecords.isEmpty()) {
                System.debug('⚠️ No scheme records found.');
                return;
            }
            
            Sample_Request_Header__c schemeRecord = schemeRecords[0];
            if (schemeRecord.Customer__r == null) {
                System.debug('⚠️ Customer information is missing in the scheme record.');
                return;
            }
            
            // ✅ Fetch Line Items
            List<Sample_Request_Line_Item__c> lineItems = [
                SELECT Id, Name, Dummy_Product_Description__c, Product_Code_SAP_Code__c, 
                Diaptor__c, Product_Quantity__c 
                FROM Sample_Request_Line_Item__c 
                WHERE Sample_Request_Header__c = :schemeRecord.Id
                ORDER BY Diaptor__c ASC
            ];
            
            if (lineItems.isEmpty()) {
                System.debug('⚠️ No line items found for the scheme.');
            }
            
            // ✅ Get Org-Wide Email Address
            List<OrgWideEmailAddress> oweaList = [
                SELECT Id FROM OrgWideEmailAddress 
                WHERE Address = 'crmhelpdesk@biotechhealthcare.com' 
                LIMIT 1
            ];
            if (oweaList.isEmpty()) {
                System.debug('⚠️ No Org-Wide Email Address found.');
                return;
            }
            
            
            // Fetch recipient email addresses from Sales Data
            List<Sample_Request_Branch_Email__c> slsDataList = [
                SELECT Id, Branch_Email__c 
                FROM Sample_Request_Branch_Email__c 
                WHERE Branch_Name__c = :schemeRecords[0].Customer__r.Branch_Name__c 
                AND Branch_Code__c = :schemeRecords[0].Customer__r.Branch_Code__c
            ];
            
            List<String> toAddresses = new List<String>();
            if (!slsDataList.isEmpty() && String.isNotBlank(slsDataList[0].Branch_Email__c)) {
                toAddresses = slsDataList[0].Branch_Email__c.split(',');
                System.debug('toAddresses: ' + toAddresses);
            }
            
            if (toAddresses.isEmpty()) {
                System.debug('⚠️ No recipient email address found.');
                toAddresses.add('Gyadeen@plus91labs.com');
                return;
            }
            
            // ✅ Build HTML Email Body 
            String htmlBody = '<html><body>';
            htmlBody += '<h3 style="font-family: Arial; font-size: 18px; font-style: italic;">Sample Order Form</h3>';
            // Header Table
            htmlBody += '<table border="1" cellpadding="5" cellspacing="0" style="border-collapse:collapse; font-family:Arial; width: 100%; border: 1px solid black;">';
            
            
            // ✅ First Table (Order Details)
            htmlBody += '<table border="1" cellpadding="5" cellspacing="0" style="border-collapse:collapse; font-family:Arial; width: 100%; text-align: center; border: 2px solid #000;">';
            htmlBody += '<tr><td style="border: 1px solid black; font-weight: bold; text-align: center; vertical-align: middle;"><b>Order Type</b></td><td colspan="4" style="border: 1px solid black; text-align: center; vertical-align: middle;">SAMPLE ORDER</td></tr>';
            htmlBody += '<tr><td style="border: 1px solid black; font-weight: bold; text-align: center; vertical-align: middle;"><b>Customer Name</b></td><td colspan="4" style="border: 1px solid black; text-align: center; vertical-align: middle;">' + (schemeRecord.Customer__r.Name != null ? String.valueOf(schemeRecord.Customer__r.Name) : '') + '</td></tr>';
            htmlBody += '<tr><td style="border: 1px solid black; font-weight: bold; text-align: center; vertical-align: middle;"><b>Customer Code</b></td><td colspan="4" style="border: 1px solid black; text-align: center; vertical-align: middle;">' + (schemeRecord.Customer__r.SAP_code__c != null ? String.valueOf(schemeRecord.Customer__r.SAP_code__c) : '') + '</td></tr>';
            htmlBody += '<tr><td style="border: 1px solid black; font-weight: bold; text-align: center; vertical-align: middle;"><b>Shipping Code</b></td><td colspan="4" style="border: 1px solid black; text-align: center; vertical-align: middle;">' + (schemeRecord.Bill_To_Code__c != null ? String.valueOf(schemeRecord.Bill_To_Code__c) : '') + '</td></tr>';
            htmlBody += '<tr><td style="border: 1px solid black; font-weight: bold; text-align: center; vertical-align: middle;"><b>Salesforce Order ID</b></td><td colspan="4" style="border: 1px solid black; text-align: center; vertical-align: middle;">' + ('SMO_'+schemeRecord.Id != null ? String.valueOf('SMO_'+schemeRecord.Id) : '') + '</td></tr>';
            htmlBody += '<tr><td style="border: 1px solid black; font-weight: bold; text-align: center; vertical-align: middle;"><b>SAP Order No.</b></td><td colspan="4" style="border: 1px solid black; text-align: center; vertical-align: middle;">' + (schemeRecord.orderNumSAP__c != null ? String.valueOf(schemeRecord.orderNumSAP__c) : '') + '</td></tr>';
            htmlBody += '<tr><td style="border: 1px solid black; font-weight: bold; text-align: center; vertical-align: middle;"><b>Branch Name & Code</b></td><td colspan="4" style="border: 1px solid black; text-align: center; vertical-align: middle;">' + 
                (schemeRecord.Customer__r.Branch_Name__c != null ? String.valueOf(schemeRecord.Customer__r.Branch_Name__c) : '') + ' || ' + 
                (schemeRecord.Customer__r.Branch_Code__c != null ? String.valueOf(schemeRecord.Customer__r.Branch_Code__c) : '') + '</td></tr>';
            htmlBody += '<tr><td style="border: 1px solid black; font-weight: bold; text-align: center; vertical-align: middle;"><b>Country</b></td><td colspan="4" style="border: 1px solid black; text-align: center; vertical-align: middle;">' + (schemeRecord.Country__c != null ? String.valueOf(schemeRecord.Country__c) : '') + '</td></tr>';
            htmlBody += '<tr><td style="border: 1px solid black; font-weight: bold; text-align: center; vertical-align: middle;"><b>Remarks by Sals team</b></td><td colspan="4" style="border: 1px solid black; text-align: center; vertical-align: middle;">' + (schemeRecord.Remarks__c != null ? String.valueOf(schemeRecord.Remarks__c) : '') + '</td></tr>';
            htmlBody += '</table>';
            
            
            // ✅ Second Table (Line Items)
            htmlBody += '<table border="1" cellpadding="5" cellspacing="0" style="border-collapse:collapse; font-family:Arial; width: 100%; border: 1px solid black;">';
            
            // ✅ Line Items Header
            htmlBody += '<tr style="background-color:#f2f2f2; font-weight:bold;">';
            htmlBody += '<th style="border: 1px solid black; text-align: center; vertical-align: middle;">Sl. No.</th>';
            htmlBody += '<th style="border: 1px solid black; text-align: center; vertical-align: middle;">Name</th>';
            htmlBody += '<th style="border: 1px solid black; text-align: center; vertical-align: middle;">SKU</th>';
            htmlBody += '<th style="border: 1px solid black; text-align: center; vertical-align: middle;">Diopter</th>';
            htmlBody += '<th style="border: 1px solid black; text-align: center; vertical-align: middle;">Sales Order Quantity</th>';
            htmlBody += '</tr>';
            
            // ✅ Line Items Data
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
            
            // ✅ Send Email
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setToAddresses(toAddresses);
            mail.setSubject('Sample Order Creation');
            mail.setHtmlBody(htmlBody);
            mail.setOrgWideEmailAddressId(oweaList[0].Id);
            
            Messaging.SendEmailResult[] results = Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
            
            // ✅ Handle Email Response
            for (Messaging.SendEmailResult result : results) {
                if (!result.isSuccess()) {
                    for (Messaging.SendEmailError error : result.getErrors()) {
                        System.debug('❌ Failed to send email: ' + error.getMessage());
                    }
                } else {
                    System.debug('✅ Email sent successfully.');
                }
            }
        } catch (Exception e) {
            System.debug('❌ Exception: ' + e.getMessage());
            
        }
    }
}