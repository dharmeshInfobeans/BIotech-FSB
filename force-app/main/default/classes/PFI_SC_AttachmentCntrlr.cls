public class PFI_SC_AttachmentCntrlr
{
    public string totalAmount{get;set;}
    public String dateStr {get;set;}
    public Order__c orderObj {get; set;}
    public plant__c plantList {get; set;}
    public list <Order_Product__c> proList {get; set;}
    public list <Order_Product__c> proList2 {get; set;}
    public Bank_Detail__c bankDetails {get;set;}
    public master_Agreement__c MA{get;set;}
    public string display {get;set;}
    public decimal totalAmountInDecimal{get;set;}
    public Id orderRecordId {get; set;}
    public string portOfLoadingString {get;set;}   
    public String errorMessage {get;set;}   // ADDED
    
    
    public PFI_SC_AttachmentCntrlr(){
    }
    
    public void getfetchData() {
        if(orderObj != null) return;   // ADDED - skip reload if getter is called again
        try{
            
            string recordId = '';
            recordId = orderRecordId;
            system.debug('recordId '+recordId);
            // System.debug('parameters:' + ApexPages.currentPage().getParameters().get('Id'));   // CHANGED - commented out, currentPage() is null in tests/email context
            orderObj = [Select id,Vertical__c,Plant__r.Port_of_Loading__c, Plant__r.Orgin__c,Total_Qty__c,  Total_Foc_Qty__c, Fax__c, Biotech_Po_No__c,Proforma_Invoice_No__c, Name,CurrencyIsoCode,
                        Consignee_City__c,Consignee_Country__c,Consignee_Name__c,Consignee_State_Province__c,Consignee_Street__c,Consignee_Zip_Postal_Code__c, Freight_Amount_Rollup__c,contract_Date__c,PFI_Date__c,
                        Contact_Person__c,  Telephone__c,Order_Date__c, Customer_Po_No__c,Account__r.name,
                        Buyer_Account__r.Name,Account__r.BillingPostalCode, Account__r.BillingStreet,Account__r.BillingCity,
                        Account__r.BillingState,Account__r.BillingCountry,Total_Amount__c, Account__r.Contact_Person__c,
                        Account__r.First_mobile_telephone_no__c ,Destination__c,Dispatch_Through__c,    CONTRACT_NO__c,
                        Freight_Amount_SplitOrder_Based__c,
                        Account__c, Beneficiary_Name__c, Bank_Name__c,   // CHANGED - added missing fields used below
                        Order_Remarks__c  From Order__c where id=:recordId ];
            system.debug('orderObj '+orderObj);
            // dateStr = orderObj.Order_Date__c.format();
            dateStr = orderObj.Order_Date__c != null ? orderObj.Order_Date__c.format() : '';   // CHANGED - null safe
            
            // MA =[select id, name,Agreement_Signed_With__c,CurrencyIsoCode,Manner_of_Payment__c,Incoterms__c from Master_Agreement__c where Account__c =:orderObj.Account__c And Agreement_Start_Date__c <=: Date.today() And Agreement_End_Date__c >=: date.today() AND Vertical__c=: orderObj.Vertical__c AND Is_Active__c=true];
            // system.debug('MA '+MA + ' EE '+MA.Agreement_Signed_With__c +' tt '+ MA.CurrencyIsoCode);
            // portOfLoadingString = String.ValueOf(MA.Agreement_Signed_With__c).contains('Biotech Vision Care Ltd Ltd') ? 'Ahmedabad, India' : 'Roscommon, Ireland';
            
            // CHANGED - list based query so 0 or 2+ active agreements don't throw an exception
            List<Master_Agreement__c> maList = [select id, name,Agreement_Signed_With__c,CurrencyIsoCode,Manner_of_Payment__c,Incoterms__c from Master_Agreement__c where Account__c =:orderObj.Account__c And Agreement_Start_Date__c <=: Date.today() And Agreement_End_Date__c >=: date.today() AND Vertical__c=: orderObj.Vertical__c AND Is_Active__c=true ORDER BY Agreement_Start_Date__c DESC LIMIT 1];
            if(!maList.isEmpty()){
                MA = maList[0];
                system.debug('MA '+MA + ' EE '+MA.Agreement_Signed_With__c +' tt '+ MA.CurrencyIsoCode);
                portOfLoadingString = (MA.Agreement_Signed_With__c != null && String.ValueOf(MA.Agreement_Signed_With__c).contains('Biotech Vision Care Ltd Ltd')) ? 'Ahmedabad, India' : 'Roscommon, Ireland';
            }else{
                //portOfLoadingString = orderObj.Plant__r != null ? orderObj.Plant__r.Port_of_Loading__c : '';   // fallback when no active MA
            }
            system.debug('BG >>> portOfLoadingString : '+portOfLoadingString);
            //bankDetails = [select id,Address__c,Bank_Sort1st__c,Bank_sort_name__c,Sort_Code__c,Bank_Sort_Street__c,Bank_Account_no_sort__c,Bank_ROUTING_NO__c,Bank_SWIFT_CODE__c,Bank_Code__c ,Account_No__c,Bank__c,Bank_Address__c,Base_Number__c,Beneficiary_Name__c,Currency__c,Currency_Code__c,IBAN__c    ,Swift_Code__c, name from Bank_Detail__c where Beneficiary_Name__c =: MA.Agreement_Signed_With__c AND Currency__c =: MA.CurrencyIsoCode ];
            
            
            String beneficiary  = orderObj.Beneficiary_Name__c;
            String currencyCode = orderObj.CurrencyIsoCode;
            String bankName     = orderObj.Bank_Name__c;
            
            String query = 'SELECT Id, Address__c, Bank_Sort1st__c, Bank_sort_name__c, Sort_Code__c, ' +
                'Bank_Sort_Street__c, Bank_Account_no_sort__c, Bank_ROUTING_NO__c, ' +
                'Bank_SWIFT_CODE__c, Bank_Code__c, Account_No__c, Bank__c, Bank_Address__c, ' +
                'Base_Number__c, Beneficiary_Name__c, Currency__c, Currency_Code__c, IBAN__c, ' +
                'Swift_Code__c, Name FROM Bank_Detail__c ' +
                'WHERE Beneficiary_Name__c = :beneficiary AND Currency__c = :currencyCode ';
            
            if (!String.isEmpty(bankName)) {
                query += 'AND Bank__c = :bankName ';
            }
            
            List<Bank_Detail__c> bankList = Database.query(query);
            if (!bankList.isEmpty()) {
                bankDetails = bankList[0];
            }
            system.debug('bankDetails '+bankDetails);
            
            
            proList =[select Product__r.name,Total_Quantities__c, Model_Txt__c,Total_Price__c,Commercial_Quantity__c,FOC_Quantity__c,Quantity__c,Unit_Price__c,Parent_Order_Product__r.Quantity__c,Parent_Order_Product__r.Spherical_Power__c, Parent_Order_Product__r.Axis_Angle__c, Parent_Order_Product__r.Cyindrical_Power__c ,Average_Price__c, Agreement_Product__r.Incoterms__c, Agreement_Product__r.Payment_Terms_options__c  from Order_Product__c where Order__c =:orderObj.id and Is_Parent_Products__c=true  ];
            system.debug('proList '+proList);
            proList2 =[select Product__r.name, Model_Txt__c,Commercial_Quantity__c,Total_Price__c,Unit_Price__c,FOC_Quantity__c,Quantity__c,Spherical_Power__c, Axis_Angle__c, Cyindrical_Power__c,Average_Price__c   from Order_Product__c where Order__c =:orderObj.id and Is_Parent_Products__c=false ];
            system.debug('proList2 '+proList2);
            if(proList2.size() > 0){
                display = '';
            }else{
                display = 'none';
            }
            CurrencyToWordConverter nwcObj = new CurrencyToWordConverter();
            Decimal frieght = orderObj.Freight_Amount_SplitOrder_Based__c != null ? orderObj.Freight_Amount_SplitOrder_Based__c : 0;
            // totalAmountInDecimal = (orderObj.Total_Amount__c + frieght).setscale(2);
            Decimal orderTotal = orderObj.Total_Amount__c != null ? orderObj.Total_Amount__c : 0;   // ADDED
            totalAmountInDecimal = (orderTotal + frieght).setscale(2);   // CHANGED - null safe total
            totalAmount = nwcObj.getNumberTOWordConvertion(totalAmountInDecimal, orderObj.CurrencyIsoCode);
        }catch(exception e){
            errorMessage = 'Error : ' + e.getMessage() + ' (Line : ' + e.getLineNumber() + ')';   // ADDED
            system.debug('Error in construtor : '+e.getMessage()+' at line no : '+e.getLineNumber());
        }
        
    }
    
    @auraEnabled
    public static Map<string,object> getInstanceUrl(string recordId, string pdfType){
        Map<string,object> returnMap = new Map<string,object>();
        system.debug('Record : '+recordId);
        system.debug('pdfType : '+pdfType);
        order__c order = [select id, name, Status__c,PFI_Sales_Contract_status__c from order__c where Id=: recordId];
        Site mySite = [select Id from Site where Name = 'BioTech_Partner_Portal'];
        SiteDetail mySiteDetail = [select SecureURL from SiteDetail where DurableId = :mySite.Id];
        system.debug('Site Url : '+mySiteDetail);
        if(order.Status__c != 'Active'){
            returnMap.put('Status',False);
            returnMap.put('MSG','Please activate the order to generate '+pdfType);
        }else{
            if(pdfType == 'Sales Contract' && (order.PFI_Sales_Contract_status__c == null || !order.PFI_Sales_Contract_status__c.contains('Proforma Invoice'))){
                returnMap.put('Status',False);
                returnMap.put('MSG','Please generate Proforma Invoice before creating Sales Contract');
            }else{
                returnMap.put('Status',true);
                returnMap.put('url',userInfo.getUserType() == 'PowerPartner' ? mySiteDetail.SecureURL : URL.getOrgDomainUrl().toExternalForm());
            }
        }
        
        return returnMap;
    }
    /*@AuraEnabled
public static void UpdateFields(string recordId, string pdfType){
order__c order = [select id, name,PFI_Sales_Contract_status__c,PFI_Date__c,contract_Date__c from order__c where Id=: recordId];
if(order.PFI_Sales_Contract_status__c != null && order.PFI_Sales_Contract_status__c.contains(pdfType)){
return;
}
if(order.PFI_Sales_Contract_status__c != null){
order.PFI_Sales_Contract_status__c = order.PFI_Sales_Contract_status__c+';'+pdfType;
}else{
order.PFI_Sales_Contract_status__c = pdfType;
}
if(pdfType == 'Sales Contract'){
order.contract_Date__c = date.today();
order.Sales_Contract__c = true;
}else{
order.PFI_Date__c = date.today();
}
update order;
}*/
    
}