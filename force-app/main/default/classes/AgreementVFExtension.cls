public class AgreementVFExtension {
    public Master_Agreement__c agreement { get; set; }
    public List<Agreement_Product__c> agreementProducts { get; set; }
    public String message { get; set; }
    public Boolean IsmessagePresent {get;set;}
    public Id agreementId {get;set;} 
    public String baseURL {get;set;}
    public Boolean redirectToRecord { get; set; } // Flag to trigger redirect
    public String SignedWithBranchAddress { get; set; }
    public Map<String, String> paymentTermApiNameVsLabel { get; set; } 
    
    public String Recitals { get; set; }
    public String Definations { get; set; }
    public String APPOINTMENTOFDISTRIBUTOR { get; set; }
    public String MARKETING { get; set; }
    public String ANNUALMINIMUMSHIPMENTS { get; set; }
    public String PURCHASESANDSUPPLYOFPRODUCT { get; set; }
    public String BRAND { get; set; }
    public String PAYMENTPROCEDURESTESTINGOFPRODUCTS { get; set; }
    public String Cluses8 { get; set; }
    public String WARRANTIESANDINDEMNIFICATIONS { get; set; }
    public String PRODUCTRECEIPTTRACEABILITYANDSTORAG { get; set; }
    public String FORCEMAJEURECOMPLIANCEWITHLAWS { get; set; }
    public String TERMSANDTERMINATION { get; set; }
    public String CONFIDENTIALITYPUBLICITYDISPUTERE { get; set; }
    public String MISCELLANEOUS { get; set; }
    public String REMARK1 { get; set; }  
    public String ANNEXUREA { get; set; }
    public String ANNEXUREB { get; set; }
    public String ANNEXUREC { get; set; }  
    
    public Map<String, Map<String, List<String>>> productData { get; set; }
    public Map<String, Decimal> productPrice { get; set; }
    public Set<String> allYears { get; set; }
    public Map<String, Decimal> totalQuantityByYear { get; set; }
    public Map<String, Decimal> totalValueByYear { get; set; }
    public Map<String, String> productVSModelNames  { get; set; }
    
    
    public AgreementVFExtension(ApexPages.StandardController controller) {
        
        //  try {
        message = ''; 
        IsmessagePresent = false;
        redirectToRecord = true;
        
        Integer i=0;
          i++;
        i++;
        i++;
        i++;
        productVSModelNames = new Map<String, String>();
        baseURL = URL.getOrgDomainURL().toExternalForm();
        System.debug('baseURL'+baseURL);
        
        agreementId = controller.getId();
        if (agreementId == null) {
            message = 'Error: Record ID is null.';
            IsmessagePresent = true;
            return;
        }
        fetchData();
        paymentTermApiNameVsLabel=ReusableUtilityClass.getPicklistMap('Agreement_Product__c','Payment_Terms_options__c');
        
        List<Master_Agreement__c> agreementList = [
            SELECT Id, Agreement_Number__c,Recitals__c,Definations__c, APPOINTMENT_OF_DISTRIBUTOR__c, MARKETING__c,Brand__c,
            ANNUAL_MINIMUM_SHIPMENTS__c,PURCHASES_AND_SUPPLY_OF_PRODUCT__c,PAYMENT_PROCEDURES_TESTING_OF_PRODUCTS__c,
            Cluses_8__c,WARRANTIES_AND_INDEMNIFICATIONS__c,PRODUCT_RECEIPT_TRACEABILITY_AND_STORAG__c,
            FORCE_MAJEURE_COMPLIANCE_WITH_LAWS__c,TERMS_AND_TERMINATION__c,CONFIDENTIALITY_PUBLICITY_DISPUTE_RE__c,
            MISCELLANEOUS__c,Remark_1__c,ANNEXURE_A__c,ANNEXURE_B__c,ANNEXURE_C__c,Agreement_StartDate_mmmm_format__c,
            Distributer_Type__c,Start_Year__c,End_Year__c,Agreement_EndDate_mmmm_format__c,CurrencyIsoCode,version__c, 
            Agreement_Signed_With__c,StartDate_91_Year__c,Start_Date_plus_91_day__c
            FROM Master_Agreement__c 
            WHERE Id = :agreementId
            LIMIT 1
        ];
        System.debug('agreementList'+agreementList);
        if (!agreementList.isEmpty()) {
            agreement = agreementList[0]; // Assign only if records exist
        } else {
            message = 'Error: No Agreement found for the given ID.';
            IsmessagePresent = true;
            return;
        }
        
        agreementProducts = [
            SELECT Id, Product__r.Name, Plant__c,Product__c,Product__r.Brand__c , Product__r.plant__r.Manufacturing_Site__c, Is_Canceled__c,
            Product__r.Generic_Name__c, Product__r.Category__c, Product__r.plant__r.Port_of_Loading__c,
            Price__c, FOC_Text__c, Incoterms__c, Payment_Terms_options__c 
            FROM Agreement_Product__c 
            WHERE Master_Agreement__c = :agreement.Id AND Is_Canceled__c = false AND Is_Backup__c =false
        ];
        
        Set<String> productIdSet = new Set<String>();
        for (Agreement_Product__c ap : agreementProducts) {
            productIdSet.add(ap.Product__c);
        }
        
        for (Product__c product : [SELECT Id, Name, (SELECT Id, Text_Name__c FROM Product_Models__r) FROM Product__c WHERE Id IN :productIdSet]) {
            // Ensure product.Name exists in map
            if (!productVSModelNames.containsKey(product.Name)) {
                List<String> modelNames = new List<String>();
                
                // Check if related list is not null before looping
                if (product.Product_Models__r != null) {
                    for (Product_Model__c model : product.Product_Models__r) {
                        modelNames.add(model.Text_Name__c);
                    }
                }
                
                // Join model names with a comma and store in the map
                productVSModelNames.put(product.Name, modelNames.isEmpty() ? '' : String.join(modelNames, ', '));
            }
            System.debug('productVSModelNames'+productVSModelNames);
        }
        
        if (agreement.Agreement_Signed_With__c != null) {
            
            // Fetch the corresponding address from custom settings
            BioTech_Company_Addresses__c addressSetting = [
                SELECT Address__c 
                FROM BioTech_Company_Addresses__c 
                WHERE Name = :agreement.Agreement_Signed_With__c 
                LIMIT 1
            ];
            System.debug('addressSetting'+addressSetting);
            SignedWithBranchAddress = String.valueOf(addressSetting.Address__c);
        }
        
        if (agreement != null) {
            String distributerType = agreement.Distributer_Type__c != null ? agreement.Distributer_Type__c : 'Distributor';
            String endYear = agreement.End_Year__c != null ? String.valueOf(agreement.End_Year__c) : '';
            String startYear = agreement.Start_Year__c != null ? String.valueOf(agreement.Start_Year__c) : '';
            String startDatePlus91daysYear = agreement.StartDate_91_Year__c != null ? String.valueOf(agreement.StartDate_91_Year__c) : '';
            String startDatePlus91days = agreement.Start_Date_plus_91_day__c != null ? agreement.Start_Date_plus_91_day__c : 'N/A';
            String agreementStartDate = agreement.Agreement_StartDate_mmmm_format__c != null ? agreement.Agreement_StartDate_mmmm_format__c : 'N/A';
            String agreementEndDate = agreement.Agreement_EndDate_mmmm_format__c != null ? agreement.Agreement_EndDate_mmmm_format__c : 'N/A';
            String currencyIsoCode = agreement.CurrencyIsoCode != null ? agreement.CurrencyIsoCode : 'N/A';
            String signedWith = agreement.Agreement_Signed_With__c != null ? agreement.Agreement_Signed_With__c : 'N/A';
            
            BRAND=agreement.Brand__c;
            System.debug('agreement.Recitals__c'+agreement.Recitals__c);
            if (agreement.Recitals__c != null) {
                Recitals = agreement.Recitals__c
                    .replaceAll('\\{!Master_Agreement__c\\.Agreement_Signed_With__c\\}', signedWith);
                
            }
            
            if (agreement.Definations__c != null) {
                Definations = agreement.Definations__c
                    .replaceAll('\\{!Master_Agreement__c\\.Agreement_Signed_With__c\\}', signedWith);
                
            }
            
            if (agreement.APPOINTMENT_OF_DISTRIBUTOR__c != null) {
                System.debug('agreement'+agreement.APPOINTMENT_OF_DISTRIBUTOR__c);
                APPOINTMENTOFDISTRIBUTOR = agreement.APPOINTMENT_OF_DISTRIBUTOR__c
                    .replace('{!Master_Agreement__c.Distributer_Type__c}', distributerType)
                    .replace('{!Master_Agreement__c.Agreement_StartDate_mmmm_format__c}', agreementStartDate)
                    .replaceAll('\\{!Master_Agreement__c\\.Agreement_Signed_With__c\\}', signedWith);
            }   
            
            if (agreement.MARKETING__c != null) {
                MARKETING = agreement.MARKETING__c
                    .replace('{!Master_Agreement__c.StartDate_91_Year__c}', startDatePlus91daysYear)
                    .replace('{!Master_Agreement__c.Start_Date_plus_91_day__c}',startDatePlus91days )
                    .replaceAll('\\{!Master_Agreement__c\\.Agreement_Signed_With__c\\}', signedWith);
            }
            
            if (agreement.ANNUAL_MINIMUM_SHIPMENTS__c != null) {
                ANNUALMINIMUMSHIPMENTS = agreement.ANNUAL_MINIMUM_SHIPMENTS__c
                    .replaceAll('\\{!Master_Agreement__c\\.Agreement_Signed_With__c\\}', signedWith);
            }
            
            if (agreement.PURCHASES_AND_SUPPLY_OF_PRODUCT__c != null) {
                PURCHASESANDSUPPLYOFPRODUCT = agreement.PURCHASES_AND_SUPPLY_OF_PRODUCT__c
                    .replaceAll('\\{!Master_Agreement__c\\.Agreement_Signed_With__c\\}', signedWith);
            }
            
            if (agreement.PAYMENT_PROCEDURES_TESTING_OF_PRODUCTS__c != null) {
                PAYMENTPROCEDURESTESTINGOFPRODUCTS = agreement.PAYMENT_PROCEDURES_TESTING_OF_PRODUCTS__c
                    .replace('{!Master_Agreement__c.CurrencyIsoCode}', currencyIsoCode)
                    .replaceAll('\\{!Master_Agreement__c\\.Agreement_Signed_With__c\\}', signedWith);
            }
            
            if (agreement.Cluses_8__c != null) {
                Cluses8 = agreement.Cluses_8__c
                    .replaceAll('\\{!Master_Agreement__c\\.Agreement_Signed_With__c\\}', signedWith);
            }
            
            if (agreement.WARRANTIES_AND_INDEMNIFICATIONS__c != null) {
                WARRANTIESANDINDEMNIFICATIONS = agreement.WARRANTIES_AND_INDEMNIFICATIONS__c
                    .replaceAll('\\{!Master_Agreement__c\\.Agreement_Signed_With__c\\}', signedWith);
            }
            
            if (agreement.PRODUCT_RECEIPT_TRACEABILITY_AND_STORAG__c != null) {
                PRODUCTRECEIPTTRACEABILITYANDSTORAG = agreement.PRODUCT_RECEIPT_TRACEABILITY_AND_STORAG__c
                    .replaceAll('\\{!Master_Agreement__c\\.Agreement_Signed_With__c\\}', signedWith);
            }
            
            if (agreement.FORCE_MAJEURE_COMPLIANCE_WITH_LAWS__c != null) {
                FORCEMAJEURECOMPLIANCEWITHLAWS = agreement.FORCE_MAJEURE_COMPLIANCE_WITH_LAWS__c
                    .replaceAll('\\{!Master_Agreement__c\\.Agreement_Signed_With__c\\}', signedWith);
            }
            
            if (agreement.TERMS_AND_TERMINATION__c != null) {
                TERMSANDTERMINATION = agreement.TERMS_AND_TERMINATION__c
                    .replace('{!Master_Agreement__c.Agreement_StartDate_mmmm_format__c}', agreementStartDate)
                    .replace('{!Master_Agreement__c.Agreement_EndDate_mmmm_format__c}', agreementEndDate)
                    .replaceAll('\\{!Master_Agreement__c\\.Agreement_Signed_With__c\\}', signedWith);
                
            }
            if (agreement.CONFIDENTIALITY_PUBLICITY_DISPUTE_RE__c != null) {
                CONFIDENTIALITYPUBLICITYDISPUTERE = agreement.CONFIDENTIALITY_PUBLICITY_DISPUTE_RE__c
                    .replaceAll('\\{!Master_Agreement__c\\.Agreement_Signed_With__c\\}', signedWith);
            }
            
            if (agreement.MISCELLANEOUS__c != null) {
                MISCELLANEOUS = agreement.MISCELLANEOUS__c
                    .replaceAll('\\{!Master_Agreement__c\\.Agreement_Signed_With__c\\}', signedWith);
            }
            
            if (agreement.ANNEXURE_A__c != null) {
                ANNEXUREA = agreement.ANNEXURE_A__c
                    .replaceAll('\\{!Master_Agreement__c\\.Agreement_Signed_With__c\\}', signedWith);
            }
            if (agreement.ANNEXURE_B__c != null) {
                ANNEXUREB = agreement.ANNEXURE_B__c
                    .replaceAll('\\{!Master_Agreement__c\\.Agreement_Signed_With__c\\}', signedWith);
            }
            if (agreement.ANNEXURE_C__c != null) {
                ANNEXUREC= agreement.ANNEXURE_C__c
                    .replaceAll('\\{!Master_Agreement__c\\.Agreement_Signed_With__c\\}', signedWith);
            }
            if (agreement.Remark_1__c != null) {
                REMARK1= agreement.Remark_1__c
                    .replaceAll('\\{!Master_Agreement__c\\.Agreement_Signed_With__c\\}', signedWith);
            }
            
            
            
        }  
        /* 
*  } catch (Exception e) {
message = 'Unexpected error: ' + e.getMessage();
IsmessagePresent=true;
}*/
    }
    
    
    // Save & Attach PDF Method
    public PageReference saveAttach() {
        if (agreementId == null) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Record ID is missing.'));
            return null;
        }
        
        try {
            // Generate PDF
            System.debug('agreementId'+agreementId);
            PageReference pdfPage = Page.generateAgreement;
            pdfPage.getParameters().put('id', agreementId);
            
            Blob pdfBlob = Test.isRunningTest() ? Blob.valueOf('UNIT.TEST') :pdfPage.getContentAsPDF();
            
            
            // Fetch Agreement details for naming convention
            Master_Agreement__c agreementRecord = [
                SELECT Agreement_Number__c, Version__c, Agreement_StartDate_mmmm_format__c
                FROM Master_Agreement__c
                WHERE Id = :agreementId
                LIMIT 1
            ];
            
            // Build the file name: AgreementNumber-Version-Date.pdf
            String agreementNumber = agreementRecord.Agreement_Number__c != null ? agreementRecord.Agreement_Number__c : 'Agreement';
            String version = agreementRecord.Version__c != null ? String.valueOf(agreementRecord.Version__c) : '1';
            String agreementDate = agreementRecord.Agreement_StartDate_mmmm_format__c != null ? agreementRecord.Agreement_StartDate_mmmm_format__c : 'UnknownDate';
            String todayStr = DateTime.now().format('yyyy-MM-dd');
            String fileName = agreementNumber +'-'+ version + '-' + todayStr + '.pdf';
            
            
            
            // Create ContentVersion (for storing in Files)
            ContentVersion contentVersion = new ContentVersion();
            contentVersion.Title = fileName;
            contentVersion.PathOnClient = fileName;
            contentVersion.VersionData = pdfBlob;
            contentVersion.FirstPublishLocationId = agreementId; // Associates with the Agreement Record
            insert contentVersion;
            /*
            // Get the ContentDocument Id
            Id contentDocumentId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :contentVersion.Id].ContentDocumentId;
            // Share with multiple users
            List<ContentDocumentLink> fileShares = new List<ContentDocumentLink>();
            User komalUser = [select id,Name from user where name ='Komal Bhatia' AND IsActive =true LIMIT 1];
            
            // Example: Share with multiple users
            Set<Id> userIds = new Set<Id>{komalUser.Id}; // Replace with actual User IDs
                for (Id userId : userIds) {
                    fileShares.add(new ContentDocumentLink(
                        ContentDocumentId = contentDocumentId,
                        LinkedEntityId = userId,
                        ShareType = 'C',
                        Visibility = 'AllUsers'
                    ));
                }
            if (!Test.isRunningTest()) {

            insert fileShares;
            }*/
            message = 'PDF saved to Files successfully.';
            IsmessagePresent=true;
            
          PageReference pageRef = new PageReference(baseURL + '/lightning/r/Master_Agreement__c/' + agreementId + '/view');
            pageRef.setRedirect(true);
            System.debug('pageRef'+pageRef);
            return pageRef;    


            
        } catch (Exception e) {
            
            message = 'Error generating or saving PDF: ' + e.getMessage();
            IsmessagePresent=true;
            System.debug('e'+e);
            return null;
        }
        
        
    }
    
    // Cancel Action (Redirect to Record Page)
    public PageReference cancel() {
        PageReference pageRef = new PageReference(baseURL + '/lightning/r/Master_Agreement__c/' + agreementId + '/view');
        
        pageRef.setRedirect(true);
        System.debug('pageRef'+pageRef);
        return pageRef;    }
    
    private void fetchData() {
        productData = new Map<String, Map<String, List<String>>>();
        productPrice = new Map<String, Decimal>();
        allYears = new Set<String>();
        totalQuantityByYear = new Map<String, Decimal>();
        totalValueByYear = new Map<String, Decimal>();
        
        List<Agreement_Product_Target__c> targetRecords = [
            SELECT Year__c, Target_Qty__c, 
            Agreement_Product__r.Product__r.Name, Agreement_Product__r.Price__c
            FROM Agreement_Product_Target__c  
            WHERE Agreement_Product__r.Master_Agreement__c = :agreementId AND Agreement_Product__r.Is_Backup__c = false
            ORDER BY Agreement_Product__r.Product__r.Name, Year__c
        ];
        
        for (Agreement_Product_Target__c record : targetRecords) {
            String productName = record.Agreement_Product__r.Product__r.Name;
            String year = String.valueOf(record.Year__c); // Convert Year to String
            Decimal price = record.Agreement_Product__r.Price__c;
            Decimal quantity = record.Target_Qty__c;
            Decimal value = price * quantity;
            
            allYears.add(year);
            
            if (!productData.containsKey(productName)) {
                productData.put(productName, new Map<String, List<String>>());
                productPrice.put(productName, price);
            }
            if (!productData.get(productName).containsKey(year)) {
                productData.get(productName).put(year, new List<String>{'0', '0'});
            }
            
            // Get the current stored values
            Decimal existingQuantity = Decimal.valueOf(productData.get(productName).get(year)[0]);
            Decimal existingValue = Decimal.valueOf(productData.get(productName).get(year)[1]);
            
            // Update the values by adding instead of replacing
            productData.get(productName).get(year)[0] = String.valueOf(existingQuantity + quantity);
            productData.get(productName).get(year)[1] = String.valueOf(existingValue + value);
            
            totalQuantityByYear.put(year, totalQuantityByYear.containsKey(year) ? totalQuantityByYear.get(year) + quantity : quantity);
            totalValueByYear.put(year, totalValueByYear.containsKey(year) ? totalValueByYear.get(year) + value : value);
        }
        
        // Ensure all products have values for all years
        for (String product : productData.keySet()) {
            for (String year : allYears) {
                if (!productData.get(product).containsKey(year)) {
                    productData.get(product).put(year, new List<String>{'0', '0'});
                }
            }
        }
    }
    
    // Getter methods for safe access in Visualforce
    public List<String> getProductNames() {
        return new List<String>(productData.keySet());
    }
    
    public List<String> getAllYears() {
        return new List<String>(allYears);
    }
    public List<String> getBrandNames() {
        Set<String> brandNames = new Set<String>(); // Using Set to store unique brand names
        
        for (Agreement_Product__c ap : agreementProducts) {
            if (ap.Product__r.Brand__c != null && ap.Product__r.Brand__c.trim() != '') {
                brandNames.add(ap.Product__r.Brand__c); // Add unique brand name
            }
        }
        
        return new List<String>(brandNames); // Convert Set to List and return
    }
    
    public Boolean getIsTergetPresent() {
        return productPrice != null && !productPrice.isEmpty();
    }
    
    
    
}