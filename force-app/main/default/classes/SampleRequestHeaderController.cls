/**
* @File Name : SampleRequestHeaderController.cls
* @Description :
* @Author :
* @Last Modified By :
* @Last Modified On : December 12, 2025
* @Modification Log :
*==============================================================================
* Ver | Date | Author | Modification
*==============================================================================
* 1.0 | December 12, 2025 |   | Initial Version
**/

public without sharing class SampleRequestHeaderController {
    
    @AuraEnabled(cacheable=true)
    public static List<String> getAllProduct(String productFamily){
        if(productFamily!=''){
            list<String> brandNameList = new List<String>();
            for(AggregateResult agr:[select  Brand__c from Product_Group__c WHERE Product_Family__c =: productFamily AND Display_on_Opportunity__c = FALSE AND IsActive__c = TRUE GROUP BY Brand__c]){
                brandNameList.add(String.valueOf(agr.get('Brand__c')));
            }
            System.debug(brandNameList);
            return brandNameList;  
        }
        return new List<String>();
    }
        @AuraEnabled(cacheable=true)
        public static String getVertical(String productFamily){
        
            List<AggregateResult> productVertical = [SELECT Vertical__c FROM Product_Group__c WHERE Product_Family__c =:productFamily AND Vertical__c != null GROUP BY Vertical__c];
            if(!productVertical.isEmpty()){
               return (String) productVertical.get(0).get('Vertical__c');
            }
            return null;
        }

    @AuraEnabled(cacheable=true)
    public static  Map<String,Integer> isOverlimit(){
        Map<String,Integer> mapOfLimit = new Map<String,Integer>{'ORTHOPAEDICS'=>0,'LIMIT'=>0};
        List<AggregateResult> results = [SELECT COUNT(Id) ApprovedQuantity, Product_M__r.Product_Group__r.Vertical__c, CALENDAR_MONTH(CreatedDate) CreatedMonth, CALENDAR_YEAR(CreatedDate) CreatedYear FROM Sample_Request_Line_Item__c WHERE Product_M__r.Product_Group__r.Vertical__c = 'ORTHOPAEDICS' AND CALENDAR_MONTH(CreatedDate) =:Date.today().month() AND CALENDAR_YEAR(CreatedDate) =:Date.today().year() AND Approval_Status__c = 'Approved'  GROUP BY Product_M__r.Product_Group__r.Vertical__c, CALENDAR_MONTH(CreatedDate), CALENDAR_YEAR(CreatedDate)];
        Product_Monthly_Sample_Limit__mdt prdLimit = [select Limit__c from Product_Monthly_Sample_Limit__mdt where DeveloperName = 'ORTHOPAEDICS'];
            if( !results.isEmpty()){
                mapOfLimit.put('ORTHOPAEDICS',(Integer) prdLimit.Limit__c - (Integer) results[0].get('ApprovedQuantity') );
            }
            else{
                mapOfLimit.put('ORTHOPAEDICS',(Integer) prdLimit.Limit__c);
            }
            if( prdLimit != null){
                mapOfLimit.put('LIMIT',(Integer) prdLimit.Limit__c);
            }
            return mapOfLimit;
            
    }
    
    @AuraEnabled(cacheable=true)
    public static List<Product_M__c> fetchProduct(String brand,String productModel,String sphericalPower,String cylinderPower,String axis,String diaptor,String country,String vertical,String language) {
        
        List<Product_M__c> productList = new List<Product_M__c>();
        String query = 'SELECT Id,Name,Product_Group__c, Dummy_Product_Description__c, Group_Name__c,Spherical_Power__c,CylinderPower__c,Axis__c,Diaptor__c,Country__c,Division__c,Product_Code__c,Dummy_Product_Code__c,Hydrophilic_Size__c,Vertical__c,Category__c,Sub_Category__c,Brand__c FROM Product_M__c WHERE Country__c=: country AND Vertical__c =: vertical AND Language__c =:language AND';
        if(String.isNotBlank(productModel)) query += ' Product_Group__c =: productModel AND';
        if(String.isNotBlank(cylinderPower)) query += ' Cylinder_Power_Formula__c =: cylinderPower AND';
        if(String.isNotBlank(axis)) query += ' Axis_Formula__c =: axis AND';
        if(String.isNotBlank(diaptor)) query += ' Diaptor_Formula__c =: diaptor AND';
        query = query.substring(0,query.length()-3);
        productList = Database.query(query);
        return productList;
    }
    @AuraEnabled(cacheable=true)
    public static List<Account> getAllRelatedAccount(Id accountId ){
        System.debug('Account Id : '+ accountId);
        return [SELECT Id,Name,BillingAddress,SAP_Code__c  FROM Account WHERE ParentId =:accountId OR Id =:accountId];
    }
    
    @AuraEnabled(cacheable=true)
    public static boolean isFileMandatory(String country){
        country = country.toUpperCase();
        List<SAP_Country_Config__mdt> sapConfig = [SELECT Is_File_Upload_Mandatory__c FROM SAP_Country_Config__mdt WHERE Country__c =: country];
        if(!sapConfig.isEmpty()) return sapConfig[0].Is_File_Upload_Mandatory__c;
        return false;
    }
    
    @AuraEnabled(cacheable=true)
    public static Map<String , List<Product_Group__c>> fetchProductModel(String brand){
        List<Product_Group__c> listOfGroupName = [SELECT Id,Group_Name__c,Backup_Lens__c FROM Product_Group__c WHERE BRAND__c =:brand AND Display_on_Opportunity__c = FALSE AND IsActive__c = TRUE];
        
        return new Map<String , List<Product_Group__c>>{'productModel' => listOfGroupName};
            }
    
    @AuraEnabled(cacheable=true)
    public Static Map<String , List<AggregateResult>> fetchDropdown( String toFetch,String brand,String productModel,String sphericalPower,String cylinderPower,String axis,String country,String vertical,String language){
        Map<String , List<AggregateResult>> mapOfDropDownValues  = new Map<String , List<AggregateResult>>();
        Map<String,String> mapOfFetchApi = new Map<String,String>{'productModel'=>'Group_Name__c' ,'sphericalPower'=>'Spherical_Power__c','cylinderPower'=>'Cylinder_Power_Formula__c' ,'axis'=>'Axis_Formula__c','diaptor'=> 'Diaptor_Formula__c'};
        String fetchApi = mapOfFetchApi.get(toFetch);
        String query = 'SELECT ' + mapOfFetchApi.get(toFetch) + ' FROM Product_M__c WHERE Country__c=: country AND Vertical__c =: vertical AND Language__c =:language AND (';
        if(String.isNotBlank(productModel)) query += ' Product_Group__c =: productModel AND';
        if(String.isNotBlank(cylinderPower)) query += ' Cylinder_Power_Formula__c =: cylinderPower AND';
        if(String.isNotBlank(axis)) query += ' Axis_Formula__c =: axis AND';
        query += ' ' + mapOfFetchApi.get(toFetch) + ' != null) GROUP BY ' + mapOfFetchApi.get(toFetch) + ' ORDER BY ' + mapOfFetchApi.get(toFetch) + ' ASC';
        System.debug('Final Query -- > ' + query);
        List<AggregateResult> dropDownList = Database.query(query);
        System.debug('Final DropDown -- > ' + dropDownList);
        if(dropDownList.size() > 0){
            mapOfDropDownValues.put(toFetch , dropDownList);
            return mapOfDropDownValues;
        }
        else{
            if(toFetch == 'productModel') return fetchDropdown('sphericalPower' , brand ,productModel, sphericalPower ,cylinderPower,axis,country,vertical,language);
            else if(toFetch == 'cylinderPower') return fetchDropdown('axis' , brand ,productModel, sphericalPower ,cylinderPower,axis,country,vertical,language);
            else if(toFetch == 'axis') return fetchDropdown('diaptor' , brand ,productModel, sphericalPower ,cylinderPower,axis,country,vertical,language);
        }
        mapOfDropDownValues.put('NoValue', new List<AggregateResult>());
        
        return mapOfDropDownValues;    
    }
    
    @AuraEnabled
    public static Map<String,Object> insertSampleRequest(String lineItems,String headerDetails){
        Map<String,Object> returnMap = new Map<String,Object>();
        List<Sample_Request_Header__c> headerList= new List<Sample_Request_Header__c>();
        User currentUser =  [SELECT Country__c,Vertical__c FROM User WHERE Id =: UserInfo.getUserId()];
        List<ProductWrapper> lineItemList = (List<ProductWrapper>) JSON.deserialize(lineItems, List<ProductWrapper>.class);
        List<Org_Role_Hierarchy_Assignment__c> rhList = [select Org_Role_Hierarchy__c, Org_Role_Hierarchy__r.RSM__c, Org_Role_Hierarchy__r.GM__c, Org_Role_Hierarchy__r.NSM__c, Org_Role_Hierarchy__r.DM__c, Org_Role_Hierarchy__r.GSRO__c, Org_Role_Hierarchy__r.AGM_PD__c, Org_Role_Hierarchy__r.AGMMEPMT__c, Org_Role_Hierarchy__r.AMM__c, Org_Role_Hierarchy__r.BDM__c, Org_Role_Hierarchy__r.BMR__c, Org_Role_Hierarchy__r.CM__c, Org_Role_Hierarchy__r.Head_PMT_PD__c, Org_Role_Hierarchy__r.HMCA__c, Org_Role_Hierarchy__r.KAM__c, Org_Role_Hierarchy__r.MME__c, Org_Role_Hierarchy__r.NMM__c, Org_Role_Hierarchy__r.PM__c, Org_Role_Hierarchy__r.RM__c, Org_Role_Hierarchy__r.RMML__c, Org_Role_Hierarchy__r.RMMMENA__c, Org_Role_Hierarchy__r.SAE__c, Org_Role_Hierarchy__r.SDE__c, Org_Role_Hierarchy__r.SEM__c, Org_Role_Hierarchy__r.SEMP__c, Org_Role_Hierarchy__r.SEMW__c, Org_Role_Hierarchy__r.SMME__c, Org_Role_Hierarchy__r.SMMNCZ__c, Org_Role_Hierarchy__r.SMMS__c, Org_Role_Hierarchy__r.SMMW__c, Org_Role_Hierarchy__r.SSE__c, Org_Role_Hierarchy__r.TM__c, Org_Role_Hierarchy__r.ZSM__c from Org_Role_Hierarchy_Assignment__c where Account__c =: lineItemList.get(0).account and Is_Active__c = true and Org_Role_Hierarchy__r.Is_Active__c = true and (Org_Role_Hierarchy__r.BDM__c = :currentUser.Id OR Org_Role_Hierarchy__r.CM__c = :currentUser.Id OR  Org_Role_Hierarchy__r.DM__c = :currentUser.Id OR Org_Role_Hierarchy__r.GM__c = :currentUser.Id OR Org_Role_Hierarchy__r.GSRO__c = :currentUser.Id OR Org_Role_Hierarchy__r.KAM__c =:currentUser.Id OR Org_Role_Hierarchy__r.NSM__c = :currentUser.Id OR Org_Role_Hierarchy__r.RM__c = :currentUser.Id OR Org_Role_Hierarchy__r.RSM__c =:currentUser.Id OR Org_Role_Hierarchy__r.SAE__c = :currentUser.Id OR Org_Role_Hierarchy__r.SDE__c = :currentUser.Id OR Org_Role_Hierarchy__r.SSE__c = :currentUser.Id OR Org_Role_Hierarchy__r.TM__c =:currentUser.Id OR  Org_Role_Hierarchy__r.ZSM__c = :currentUser.Id ) LIMIT 1];
       if(rhList.IsEmpty()){
                        rhList =  [select Org_Role_Hierarchy__c, Org_Role_Hierarchy__r.RSM__c,  Org_Role_Hierarchy__r.GM__c, Org_Role_Hierarchy__r.NSM__c, Org_Role_Hierarchy__r.DM__c, Org_Role_Hierarchy__r.GSRO__c, Org_Role_Hierarchy__r.AGM_PD__c, Org_Role_Hierarchy__r.AGMMEPMT__c, Org_Role_Hierarchy__r.AMM__c, Org_Role_Hierarchy__r.BDM__c, Org_Role_Hierarchy__r.BMR__c, Org_Role_Hierarchy__r.CM__c, Org_Role_Hierarchy__r.Head_PMT_PD__c, Org_Role_Hierarchy__r.HMCA__c, Org_Role_Hierarchy__r.KAM__c, Org_Role_Hierarchy__r.MME__c, Org_Role_Hierarchy__r.NMM__c, Org_Role_Hierarchy__r.PM__c, Org_Role_Hierarchy__r.RM__c, Org_Role_Hierarchy__r.RMML__c, Org_Role_Hierarchy__r.RMMMENA__c, Org_Role_Hierarchy__r.SAE__c, Org_Role_Hierarchy__r.SDE__c, Org_Role_Hierarchy__r.SEM__c, Org_Role_Hierarchy__r.SEMP__c, Org_Role_Hierarchy__r.SEMW__c, Org_Role_Hierarchy__r.SMME__c, Org_Role_Hierarchy__r.SMMNCZ__c, Org_Role_Hierarchy__r.SMMS__c, Org_Role_Hierarchy__r.SMMW__c, Org_Role_Hierarchy__r.SSE__c, Org_Role_Hierarchy__r.TM__c, Org_Role_Hierarchy__r.ZSM__c from Org_Role_Hierarchy_Assignment__c where Account__c =:  lineItemList.get(0).account and Org_Role_Hierarchy__r.Division__c = 'GT' AND Org_Role_Hierarchy__r.Sub_Division__c = 'GT' LIMIT 1];
                    }
        List<User> countryAdmin = [SELECT Id FROM User WHERE Name LIKE '%Mehul Asnani%' LIMIT 1];
      	/* List<AggregateResult> numberOfOrthoProductApproved = [SELECT COUNT(Id) approvedQuantity, Product_M__r.Product_Group__r.Vertical__c FROM Sample_Request_Line_Item__c where CreatedDate >=THIS_MONTH AND Product_M__r.Product_Group__r.Vertical__c = 'OPHTHALMOLOGY'  Group BY Product_M__r.Product_Group__r.Vertical__c ];
        if(!numberOfOrthoProductApproved.isEmpty() && (Integer) numberOfOrthoProductApproved[0].get('approvedQuantity') > 55){
            if(countryAdmin.isEmpty()){
                returnMap.put('status','warning');
                returnMap.put('warning','Orthopedics monthly limit of 75 approved quantities has been exceeded; the request will be routed to CMD for approval.');
            }
        }*/
        if(countryAdmin.isEmpty()){
            returnMap.put('status','warning');
            returnMap.put('warning','CMD is not configured. Please contact your administrator to resolve this.');
        }
        else if(rhList.isEmpty()){
            System.debug('Testing : '+rhList);
            returnMap.put('status','warning');
            returnMap.put('warning','Customer Mapping is not configured for this account. Please configure it before creating a sample request.');
        }
        else{
            List<Approval_Level__c> approvalLevelList = [SELECT Level__c,Role__c,Approval_Limit__c,Priority__c FROM Approval_Level__c WHERE Approval_Configuration__r.Name =: currentUser.Country__c AND Approval_Configuration__r.Vertical__c =: currentUser.Vertical__c AND Approval_Configuration__r.Start_Date__c <=: Date.today() AND Approval_Configuration__r.End_Date__c >=: Date.today() AND Approval_Configuration__r.Active__c = TRUE ORDER BY Level__c ASC];
            if(!approvalLevelList.isEmpty()){
                try{
                    
                    List<sObject> recordToInsert = new List<sObject>();
                    List<Sample_Request_Line_Item__c> lineItemRecords = new List<Sample_Request_Line_Item__c>();
                    String externalId=String.valueOf((Math.round(Math.random() * 899999) + 100000));
                    Sample_Request_Header__c parenRef=new Sample_Request_Header__c(Parent_Ref__c=externalId);
                    Sample_Request_Header__c header=(Sample_Request_Header__c) JSON.deserialize(headerDetails,Sample_Request_Header__c.class);
                    header.Parent_Ref__c=externalId;
                    header.Approval_Status__c = 'In-progress';
                    header.Date__c = System.today();
                    recordToInsert.add(header);
                    for(ProductWrapper item:lineItemList){
                        System.debug(item.country);
                        for(Integer i = 0;i<item.quantity;i++){
                            Sample_Request_Line_Item__c lineItem = new Sample_Request_Line_Item__c();
                            lineItem.Sample_Request_Header__r=parenRef;
                            lineItem.Product_M__c=item.productId;
                            lineItem.Dummy_Product_Description__c = item.dummyProductDescription ?? '';
                            lineItem.Group_Name__c = item.groupName ?? '';
                            lineItem.Spherical_power__c = item.sphericalPower ?? '';
                            lineItem.Cylinder_Power__c = item.cylinderPower ?? '';
                            lineItem.Axis__c = item.axis ?? '';
                            lineItem.Diaptor__c = item.diaptor ?? '';
                            lineItem.Country__c = item.country ?? null;
                            lineItem.Divison__c = item.division ?? '';
                            lineItem.Hydrophilic_Size__c = item.hydrophilicSize ?? '';
                            lineItem.Business_Vertical__c = item.businessVertical ?? '';
                            lineItem.Category__c = item.category ?? '';
                            lineItem.Sub_Category__c = item.subCategory ?? '';
                            lineItem.Brand__c = item.brand ?? '';
                            lineItem.Product_Code_SAP_Code__c = item.productCodeSapCode ?? '';
                            lineItem.Dummy_ID_Code__c = item.dummyProductCode ?? '';
                            lineItem.Product_Quantity__c=1;
                            lineItem.Is_Backup__c = item.backUp ?? false;
                            lineItem.Account__c = item.account ?? '';
                            lineItem.Approval_Status__c = 'In-progress';
                            lineItem.Product_Group__c = item.productGroup ?? null;
                            recordToInsert.add(lineItem);
                            lineItemRecords.add(lineItem);
                        }
                    }
                    if(!recordToInsert.isEmpty()){
                        Database.SaveResult[] results = Database.insert(recordToInsert,true);
                        if(!results.isEmpty() && results[0].isSuccess()){
                            try{
                                SampleRequestApprovalProcess.createApprovalChain(rhList,currentUser.Country__c,currentUser.Vertical__c,header.Id,lineItemRecords,countryAdmin.get(0).Id);
                            }
                            catch(Exception notifEx){
                                System.debug('Error creating approval chain / sending custom notification: ' + notifEx.getMessage());
                                System.debug(notifEx.getLineNumber());
                            }
                            returnMap.put('status','Success');
                            returnMap.put('recordId',header.Id);
                        }
                        else{
                            returnMap.put('status','Error');
                            returnMap.put('error', results[0].getErrors()[0].getMessage()); 
                            System.debug('record'+results[0].getErrors()[0].getMessage());
                        }
                    }                 
                }
                catch(Exception e){
                    returnMap.put('status','Error');
                    returnMap.put('error',e.getMessage());
                    System.debug(e.getMessage());
                    System.debug(e.getLineNumber());
                }
            }
            else{
                returnMap.put('status','warning');
                returnMap.put('warning','The Delegation of Authority (DOA) for your region or vertical has not been set up. Please reach out to your administrator to configure the necessary settings before proceeding.');
            }
        }
        return returnMap;    
    }

    // ── Custom labels ──────────────────────────────────────────
    @AuraEnabled(cacheable=true)
    public static SampleTranslation2__c getCustomLabels() {
        String language = UserInfo.getLanguage();
        return SampleTranslation2__c.getValues(language);
    }

    // ── File upload (files staged on the client before the record exists) ──
    @AuraEnabled
    public static void uploadFiles(Id recordId, String filesJson){
        List<FileWrapper> fileList = (List<FileWrapper>) JSON.deserialize(filesJson, List<FileWrapper>.class);
        List<ContentVersion> cvList = new List<ContentVersion>();
        for(FileWrapper f : fileList){
            ContentVersion cv = new ContentVersion();
            cv.Title = f.fileName;
            cv.PathOnClient = f.fileName;
            cv.VersionData = EncodingUtil.base64Decode(f.base64Data);
            cv.FirstPublishLocationId = recordId;
            cvList.add(cv);
        }
        if(!cvList.isEmpty()){
            insert cvList;
        }
    }

    public class FileWrapper {
        @AuraEnabled public String fileName;
        @AuraEnabled public String base64Data;
    }

    public class ProductWrapper {
        @AuraEnabled public Id productId;
        @AuraEnabled public Double quantity;
        @AuraEnabled public String groupName;
        @AuraEnabled public String sphericalPower;
        @AuraEnabled public String cylinderPower;
        @AuraEnabled public String axis;
        @AuraEnabled public String diaptor;
        @AuraEnabled public String country;
        @AuraEnabled public String division;
        @AuraEnabled public String hydrophilicSize;
        @AuraEnabled public String businessVertical;
        @AuraEnabled public String category;
        @AuraEnabled public String subCategory;
        @AuraEnabled public String brand;
        @AuraEnabled public String dummyProductDescription;
        @AuraEnabled public String productCodeSapCode;
        @AuraEnabled public String dummyProductCode;
        @AuraEnabled public Boolean backup;
        @AuraEnabled public Id account;
        @AuraEnabled public Id productGroup;
    }
}