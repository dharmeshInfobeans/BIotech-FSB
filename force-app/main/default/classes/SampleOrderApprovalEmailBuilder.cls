public class SampleOrderApprovalEmailBuilder {
    
    public static void sendApprovalEmail(Id headerId) {
        Sample_Request_Header__c sampleRecord = [SELECT Id,Name,Approval_Status__c,Bill_To_Code__c,Ship_To_Code__c,TYPEOF Owner
        WHEN User THEN Name, Email, Employee_Code__c
        ELSE Name
    END,Opportunity__r.Account__r.Name,Opportunity__r.Account__r.SAP_Code__c,Opportunity__r.Account__r.Branch_Code__c,Opportunity__r.Account__r.Branch_Name__c,orderNumSAP__c,BackUp_Order_Number__c,Country__c,Remarks__c FROM Sample_Request_Header__c WHERE ID =: headerId];
        if(sampleRecord.Opportunity__r.Account__r.Branch_Code__c != null && sampleRecord.Opportunity__r.Account__r.Branch_Name__c != null){
            List<Sample_Request_Line_Item__c> lineItemList = [SELECT Id,Name,Is_BackUp__c,Sample_Request_Header__c,Brand__c,Product_Name__c,Group_Name__c,Diaptor__c,Product_Quantity__c,Sample_Request_Header__r.Opportunity__r.Account__r.Name,Sample_Request_Header__r.Opportunity__r.Account__r.SAP_Code__c FROM Sample_Request_Line_Item__c WHERE Sample_Request_Header__c =: headerId ];
            List<Approval_Chain__c> approvalChainList=[SELECT Id,Approver__c,Approver__r.Name,Role__c,Status__c FROM Approval_Chain__c  WHERE Sample_Request_Header__c =: headerId AND Status__c ='Approved'];
            Sample_Request_Branch_Email__c branchEmailRecord = [select id,Branch_Email__c from Sample_Request_Branch_Email__c WHERE Branch_Code__c =:sampleRecord.Opportunity__r.Account__r.Branch_Code__c AND Branch_Name__c =:sampleRecord.Opportunity__r.Account__r.Branch_Name__c LIMIT 1];
            //Sample_Request_Branch_Email__c branchEmailRecord = [select id,Branch_Email__c from Sample_Request_Branch_Email__c WHERE Branch_Code__c ='1335' AND Branch_Name__c = 'BIOTECH CFA - AHMEDABAD'];
            if(!lineItemList.isEmpty() && !approvalChainList.isEmpty() && branchEmailRecord != null && branchEmailRecord.Branch_Email__c != ''){
                Map<String,List<GroupedItem>> groupedItemMap = groupLineItems(lineItemList);
                List<GroupedItem> groupedItems = groupedItemMap.get('Non-BackUp-Item');
                List<GroupedItem> backUpGroupedItems = groupedItemMap.get('BackUp-Item');
                List<Approval_Chain__c> approvedList = new List<Approval_Chain__c>();
                for (Approval_Chain__c ac : approvalChainList) {
                    if (ac.Status__c == 'Approved') {
                        approvedList.add(ac);
                    }
                }
                
                Boolean isApproved = (sampleRecord.Approval_Status__c == 'Approved');
                
                String subject = isApproved ? 'Your Sample Request ' + sampleRecord.Name + ' Has Been Approved' : 'Your Sample Request ' + sampleRecord.Name + ' Has Been Rejected';
                
                String htmlBody = buildHtml(sampleRecord, groupedItems,backUpGroupedItems, approvedList, isApproved);
                OrgWideEmailAddress[] owea = [SELECT Id FROM OrgWideEmailAddress WHERE Address = 'crmhelpdesk@biotechhealthcare.com' LIMIT 1];
                Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                List<String> toAddresses = new List<String>();
                
                if (String.isNotBlank(branchEmailRecord.Branch_Email__c)) {
                    for (String addr : branchEmailRecord.Branch_Email__c.split(',')) {
                        if (String.isNotBlank(addr)) {
                            toAddresses.add(addr.trim());
                        }
                    }
                }
                mail.setToAddresses(toAddresses);
                if (!owea.isEmpty()) mail.setOrgWideEmailAddressId(owea[0].Id);
                mail.setSubject(subject);
                mail.setHtmlBody(htmlBody);
                mail.setSaveAsActivity(false);
                mail.setTreatTargetObjectAsRecipient(true);
                
                Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail });
            }
        }
    }
    
    private static String buildHtml(Sample_Request_Header__c  h, List<GroupedItem> groupedItems, List<GroupedItem> backUpGroupedItems, List<Approval_Chain__c> approvedList, Boolean isApproved ) {
        String statusLabel     = isApproved ? 'Approved'   : 'Rejected';
        String statusColor     = isApproved ? '#2f4f4f'    : '#cc0000';
        String titleText       = isApproved ? 'Sample Request Approved' : 'Sample Request Rejected';
        String openingLine     = isApproved ? 'We are pleased to inform you that your Sample Request' : 'We regret to inform you that your Sample Request';
        String midLine         = isApproved ? 'has been reviewed and successfully' : 'has been reviewed and';
        
        String logoUrl = 'https://biotechcrm.my.salesforce.com/servlet/servlet.ImageServer?id=0156F00000Hv2U6&oid=00D6F000002VrjCUAS';
        String viewUrl = 'https://biotechcrm.lightning.force.com/' + h.Id;
        
        String branchDisplay = safe(h.Opportunity__r.Account__r.Branch_Name__c)+ (String.isNotBlank(h.Opportunity__r.Account__r.Branch_Code__c) ? ' | ' + h.Opportunity__r.Account__r.Branch_Code__c : '');
        
        // Owner is a polymorphic relationship, so custom fields (Employee_Code__c) can't be
        // dot-walked at compile time even though TYPEOF populated them at query time.
        // Pull them out dynamically via getSObject()/get().
        String requestedByName = '';
        String employeeCode = '';
        if (h.Owner != null) {
            requestedByName = (String) h.getSObject('Owner').get('Name');
            employeeCode = (String) h.getSObject('Owner').get('Employee_Code__c');
        }
        
        String html = '';
        
        html += '<!DOCTYPE html>'
            +  '<html><body style="margin:0;padding:0;font-family:Arial,sans-serif;background-color:#f4f6f9;">'
            +  '<table width="100%" cellpadding="0" cellspacing="0" align="center">'
            +  '<tr><td align="center">';
        
        html += '<table width="600" cellpadding="0" cellspacing="0">'
            +  '<tr><td align="center" style="padding-top:30px;">'
            +  '<div style="width:80px;height:4px;background-color:#2f4f4f;"></div>'
            +  '</td></tr>'
            +  '<tr><td align="center" style="padding:10px 0;">'
            +  '<img src="' + logoUrl + '" style="height:70px;display:block;margin:7px auto;" />'
            +  '</td></tr>'
            +  '<tr><td align="center" style="padding:10px 0 20px 0;">'
            +  '<h3 style="margin:0;color:#333;">' + titleText + '</h3>'
            +  '</td></tr>'
            +  '</table>';
        
        html += '<table width="600" cellpadding="0" cellspacing="0">'
            +  '<tr>'
            +  '<td style="background-color:#dfe6ee;padding:25px;border-radius:4px;color:#333;font-size:14px;line-height:1.6;">';
        
        html += '<strong>Re: Sample Request ' + escHtml(h.Name) + ' | ' + escHtml(h.Opportunity__r.Account__r.Branch_Name__c)  +',</strong><br/><br/>'
            +  openingLine + ' <strong>' + escHtml(h.Name) + '</strong> '
            +  midLine + ' '
            +  '<strong style="color:' + statusColor + ';">' + statusLabel + '</strong>.<br/><br/>';
        
        Boolean backupExists = String.isNotBlank(h.BackUp_Order_Number__c);
        
        html += '<strong style="font-size:13px;color:#2f4f4f;">Sample Request Details</strong><br/><br/>'
            +  '<table width="100%" cellpadding="0" cellspacing="0" border="1" bordercolor="#b0bec5" style="border-collapse:collapse;font-size:13px;margin-bottom:16px;">'
            +  detailRow('Order Type', safe('Sample Order'), false)
            +  detailRow('Requested By', safe(requestedByName), true)
            +  detailRow('Employee Code', safe(employeeCode), false)
            +  detailRow('Customer Name', safe(h.Opportunity__r.Account__r.Name), true)
            +  detailRow('Customer Code', safe(h.Bill_To_Code__c), false)
            +  detailRow('Shipping Code', safe(h.Ship_To_Code__c), true)
            +  detailRow('SAP Order No.', safe(h.orderNumSAP__c), false)
            +  (backupExists ? detailRow('Backup Order No.', safe(h.BackUp_Order_Number__c), true) : '')
            +  detailRow('Branch Name &amp; Code', branchDisplay, !backupExists)
            +  detailRow('Country', safe(h.Country__c), backupExists)
            +  detailRow('Remarks', safe(h.Remarks__c), !backupExists)
            +  '</table>';
        
        html += '<strong style="font-size:13px;color:#2f4f4f;">Order Items</strong><br/><br/>'
            +  '<table width="100%" cellpadding="0" cellspacing="0" border="1" bordercolor="#b0bec5" '
            +  'style="border-collapse:collapse;font-size:13px;margin-bottom:16px;">'
            +  '<tr>'
            +  thCell('Sl. No.')
            +  thCell('Product Name')
            +  thCell('SKU')
            +  thCell('Diopter')
            +  thCell('Qty')
            +  '</tr>';
        
        if (groupedItems.isEmpty()) {
            html += '<tr><td colspan="5" style="padding:10px;text-align:center;color:#999;font-style:italic;">'
                +  'No line items found.</td></tr>';
        } else {
            Integer slNo = 1;
            for (GroupedItem item : groupedItems) {
                String bg = (Math.mod(slNo, 2) == 0) ? '#f5f7fa' : '#ffffff';
                html += '<tr style="background:' + bg + ';">'
                    +  tdCell(String.valueOf(slNo))
                    +  tdCell(escHtml(item.productName))
                    +  tdCell(escHtml(item.sku))
                    +  tdCell(item.diopter != null ? String.valueOf(item.diopter) : '-')
                    +  '<td style="padding:6px 10px;border:1px solid #b0bec5;text-align:center;font-weight:bold;">'
                    +  item.quantity + '</td>'
                    +  '</tr>';
                slNo++;
            }
        }
        html += '</table>';
        
        
        // BackUp Table
        
        if (!backUpGroupedItems.isEmpty()) {
            html += '<strong style="font-size:13px;color:#2f4f4f;">BackUp Order Items</strong><br/><br/>'
                +  '<table width="100%" cellpadding="0" cellspacing="0" border="1" bordercolor="#b0bec5" '
                +  'style="border-collapse:collapse;font-size:13px;margin-bottom:16px;">'
                +  '<tr>'
                +  thCell('Sl. No.')
                +  thCell('Product Name')
                +  thCell('SKU')
                +  thCell('Diopter')
                +  thCell('Qty')
                +  '</tr>';
            Integer slNo = 1;
            for (GroupedItem item : backUpGroupedItems) {
                String bg = (Math.mod(slNo, 2) == 0) ? '#f5f7fa' : '#ffffff';
                html += '<tr style="background:' + bg + ';">'
                    +  tdCell(String.valueOf(slNo))
                    +  tdCell(escHtml(item.productName))
                    +  tdCell(escHtml(item.sku))
                    +  tdCell(item.diopter != null ? String.valueOf(item.diopter) : '-')
                    +  '<td style="padding:6px 10px;border:1px solid #b0bec5;text-align:center;font-weight:bold;">'
                    +  item.quantity + '</td>'
                    +  '</tr>';
                slNo++;
            }
            html += '</table>';
        }
        
        html += '<strong style="font-size:13px;color:#2f4f4f;">Approval Summary</strong><br/><br/>'
            +  '<table width="100%" cellpadding="0" cellspacing="0" border="1" bordercolor="#b0bec5" '
            +  'style="border-collapse:collapse;font-size:13px;margin-bottom:20px;">'
            +  '<tr>'
            +  thCell('Sl. No.')
            +  thCell('Approver Name')
            +  thCell('Designation')
            +  '</tr>';
        
        if (approvedList.isEmpty()) {
            html += '<tr><td colspan="4" style="padding:10px;text-align:center;color:#999;font-style:italic;">'
                +  'No approvals recorded yet.</td></tr>';
        } else {
            Integer aNo = 1;
            for (Approval_Chain__c ac : approvedList) {
                String bg = (Math.mod(aNo, 2) == 0) ? '#f5f7fa' : '#ffffff';
                //String approvedDate = ac.Approved_Date__c != null ? ac.Approved_Date__c.format() : '-';
                
                html += '<tr style="background:' + bg + ';">'
                    +  tdCell(String.valueOf(aNo))
                    +  '<td style="padding:6px 10px;border:1px solid #b0bec5;font-weight:bold;">'
                    +  escHtml(ac.Approver__r.Name) + '</td>'
                    +  '<td style="padding:6px 10px;border:1px solid #b0bec5;">'
                    +  escHtml(ac.Role__c) + '</td>'
                    /* +  '<td style="padding:6px 10px;border:1px solid #b0bec5;text-align:center;color:#555;">'
+  approvedDate + '</td>'*/
                    +  '</tr>';
                aNo++;
            }
        }
        html += '</table>';
        
        html += 'You can view the complete details of your request by clicking the button below:<br/><br/>'
            +  '<a href="' + viewUrl + '" '
            +  'style="display:inline-block;background-color:#2f4f4f;color:#ffffff;padding:10px 20px;'
            +  'text-decoration:none;border-radius:3px;font-size:14px;">'
            +  'View Sample Request</a><br/><br/>'
            +  'Should you have any questions or require further assistance, please do not hesitate to contact '
            +  'our support team '
            +  '<br/><br/>Thank you.<br/><br/>'
            +  '<div style="border-top:1px solid #999;margin-top:10px;"></div>';
        
        html += '</td></tr></table>';
        
        html += '<table width="600" cellpadding="0" cellspacing="0">'
            +  '<tr><td align="center" style="padding:20px 0 5px;">'
            +  '<img src="' + logoUrl + '" style="height:60px;display:block;margin:10px auto;" />'
            +  '<p style="font-size:12px;color:#777;">sfadoption@biotechhealthcare.com</p>'
            +  '<p style="font-size:11px;color:#999;">&#169; Copyright Biotech | Terms Of Use - Privacy Policy</p>'
            +  '<p style="font-size:11px;color:#aaa;">This email was sent from an email address that can\'t receive emails. Please don\'t reply to this email.</p>'
            +  '</td></tr>'
            +  '<tr><td align="center">'
            +  '<div style="width:82%;height:4px;background-color:#2f4f4f;"></div>'
            +  '</td></tr>'
            +  '</table>';
        
        html += '</td></tr></table></body></html>';
        
        return html;
    }
    
    private static Map<String,List<GroupedItem>> groupLineItems(List<Sample_Request_Line_Item__c> lineItemList) {
        Map<String, GroupedItem> groupMap = new Map<String, GroupedItem>();
        Map<String, GroupedItem> backUpMap = new Map<String, GroupedItem>();
        if (lineItemList != null) {
            for (Sample_Request_Line_Item__c li : lineItemList) {
                if(!li.Is_Backup__c){
                    String key = safe(li.Group_Name__c) + '||' + safe(li.Brand__c) + '||' + safe(String.valueOf(li.Diaptor__c));
                    
                    if (groupMap.containsKey(key)) {
                        groupMap.get(key).quantity += (li.Product_Quantity__c != null ? Integer.valueOf(li.Product_Quantity__c) : 0);
                    } else {
                        groupMap.put(key, new GroupedItem(
                            li.Group_Name__c,
                            li.Brand__c,
                            li.Diaptor__c,
                            li.Product_Quantity__c != null ? Integer.valueOf(li.Product_Quantity__c) : 0
                        ));
                    }
                }
                else{
                    String key = safe(li.Group_Name__c) + '||' + safe(li.Brand__c) + '||' + safe(String.valueOf(li.Diaptor__c));
                    
                    if (backUpMap.containsKey(key)) {
                        backUpMap.get(key).quantity += (li.Product_Quantity__c != null ? Integer.valueOf(li.Product_Quantity__c) : 0);
                    } else {
                        backUpMap.put(key, new GroupedItem(
                            li.Group_Name__c,
                            li.Brand__c,
                            li.Diaptor__c,
                            li.Product_Quantity__c != null ? Integer.valueOf(li.Product_Quantity__c) : 0
                        ));
                    }
                }
            }
        }
        Map<String,List<GroupedItem>> mapOfLineItem = new Map<String,List<GroupedItem>>{'Non-BackUp-Item'=>groupMap.values(),'BackUp-Item'=>backUpMap.values()};
            return mapOfLineItem;
    }
    
    private static String detailRow(String label, String value, Boolean shaded) {
        String labelBg = shaded ? '#3d6363' : '#2f4f4f';
        String valueBg = shaded ? '#f5f7fa' : '#ffffff';
        return '<tr>'
            + '<td style="background:' + labelBg + ';color:#ffffff;font-weight:bold;'
            + 'padding:7px 10px;border:1px solid #b0bec5;width:38%;">' + label + '</td>'
            + '<td style="background:' + valueBg + ';color:#333333;'
            + 'padding:7px 10px;border:1px solid #b0bec5;">' + value + '</td>'
            + '</tr>';
    }
    
    private static String thCell(String label) {
        return '<th style="background:#2f4f4f;color:#ffffff;padding:7px 10px;'
            + 'text-align:left;font-weight:bold;border:1px solid #2f4f4f;">' + label + '</th>';
    }
    
    private static String tdCell(String value) {
        return '<td style="padding:6px 10px;border:1px solid #b0bec5;color:#333;">' + value + '</td>';
    }
    
    private static String safe(String val) {
        return val != null ? val : '';
    }
    
    private static String escHtml(String val) {
        if (val == null) return '';
        return val.replace('&',  '&amp;')
            .replace('<',  '&lt;')
            .replace('>',  '&gt;')
            .replace('"',  '&quot;')
            .replace('\'', '&#39;');
    }
    
    public class GroupedItem {
        public String  productName { get; set; }
        public String  sku         { get; set; }
        public String diopter     { get; set; }
        public Integer quantity    { get; set; }
        
        public GroupedItem(String productName, String sku, String diopter, Integer quantity) {
            this.productName = productName;
            this.sku         = sku;
            this.diopter     = diopter;
            this.quantity    = quantity;
        }
    }
}