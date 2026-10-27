public class StockManagementController {
   
    @auraEnabled
    public static List<Account> getCurrentUserAccounts(){
       
        List<Account> lstAccount = new List<Account>();
        id loggedInUserId = userInfo.getUserId();
        id contactId = null;
        id accountId=null;
        system.debug(LoggingLevel.Error,'loggedInUserId>>'+loggedInUserId);
        if(loggedInUserId!=null)
        {
            User userRecord = [select contactId, IsPortalEnabled, Profile.Name from user where id=:loggedInUserId];
           
            if(userRecord.IsPortalEnabled){
                contactId= userRecord.contactId;
                contact conRecord = [select AccountId from contact where id=:contactId limit 1];
                accountId = conRecord!=null?conRecord.AccountId:null;
                Account acc = [SELECT Id, Name,CurrencyIsoCode FROM Account WHERE id =: accountId Limit 1];
                lstAccount.add(acc);
            }else{
                if(userRecord.Profile.Name.contains('System Administrator')){
                    lstAccount = [SELECT Id,Name, CurrencyIsoCode FROM Account];
                }else{
                    lstAccount = [SELECT Id,Name,CurrencyIsoCode FROM Account WHERE OwnerId=:userRecord.id];    
                }
            }
           
        }
       
        return lstAccount;
    }
   
    @AuraEnabled
    public static List<DAPWrapper> getPageData(integer selectedYear, string accountId)
    {
        system.debug(LoggingLevel.Error,'accountId>>'+accountId);
        List<DAPWrapper> dsmWrapperLSt = new List<DAPWrapper>();
        map<id, DAPWrapper> mapDAPWrapper_byProdId = new map<id, DAPWrapper>();
        map<id, map<integer, Dealer_Actual_Sales__c>> map_Apid_Das_byMonth = new map<id, map<integer, Dealer_Actual_Sales__c>>();
        if(accountId != null)
        {  
            Date startDate = Date.newInstance(selectedYear, 01, 01);
            Date endDate = Date.newInstance(selectedYear, 12, 31);
            system.debug(LoggingLEvel.Error,'selectedYear>>'+selectedYear);
            system.debug(LoggingLEvel.Error,'startDate>>'+startDate);
            system.debug(LoggingLEvel.Error,'endDate>>'+endDate);
            List<DAPWrapper> wrapperLst = new List<DAPWrapper>();
            set<id> masterAgreementProductIdSet = new set<id>();
            List<Master_Agreement__c> masterAgreementLst = [select id,Agreement_Start_Date__c, Agreement_End_Date__c,(select Id,Product__c,Product__r.name,Master_Agreement__c,
                                                                       Master_Agreement__r.Agreement_Start_Date__c,
                                                                       Master_Agreement__r.Agreement_End_Date__c,
                                                                       Account__c,Average_Quantity_Till_Date__c,Difference__c,Ideal_Stock_Required__c,
                                                                       Open_Order_Quantity__c,Opening_Stock__c,Stock_In_Transit__c ,Total_Country_Stock__c, Flag__c from Agreement_Products__r order by  Master_Agreement__r.Agreement_Start_Date__c DESC)//order by  Product__r.name ASC
                                                            from Master_Agreement__c where Account__c = :accountId AND
                                                            ( (Calendar_Year(Agreement_Start_Date__c)=:selectedYear OR  
                                                               Calendar_Year(Agreement_End_Date__c)=:selectedYear ))
                                                            order by Agreement_Start_Date__c asc];//desc
            map<id, Master_Agreement__c> map_MasterAgreemetns = new map<id, Master_Agreement__c>();
            map_MasterAgreemetns.putall(masterAgreementLst);
            system.debug(LoggingLEvel.Error,'masterAgreementLst>>size>>'+masterAgreementLst.size());
           
           
           
            map<Id, Agreement_Product__c> apMap = new map<Id, Agreement_Product__c>();
            if(!masterAgreementLst.isEmpty())
            {
                for(Master_Agreement__c ma : masterAgreementLst)
                {
                    
            Date todaysDate = Date.today();
            if(Test.isRunningTest() ||  (todaysDate >= ma.Agreement_Start_Date__c && todaysDate <= ma.Agreement_End_Date__c)){
                    System.debug('Ma related Ap size:'+ma.Agreement_Products__r.size());
                    if(!ma.Agreement_Products__r.isEmpty())
                    {
                        // apMap.putAll(ma.Agreement_Products__r);
                        for(Agreement_Product__c apRecord : ma.Agreement_Products__r){
                            if(!apMap.containsKey(apRecord.id)){
                                system.debug('ma:: '+ma);
                                apMap.put(apRecord.Id, apRecord);
                            }
                        }
                    }
                }}
            }
            System.debug('apMapFirst:: '+apMap);
            system.debug(LoggingLEvel.Error,'apLst>>size>>'+apMap.values().size());
           
            List<Dealer_Actual_Sales__c> dasLst = [select Id,Account__c, Sold_Quantity__c, Actual_Sales_Month__c, Start_Date__c, Agreement_Product__c, Product__c
                                                   from Dealer_Actual_Sales__c where Agreement_Product__c in :apMap.KeySet() /*AND Actual_Sales_Year__c =: String.Valueof(selectedYear)*/ order by Start_Date__c ASC];
           
            System.debug('dasLst::'+dasLst);
           
            List<Integer> monthLst= new List<integer>{1,2,3,4,5,6,7,8,9,10,11,12};
               
                map<Id,List<Dealer_Actual_Sales__c>> mapDAS_ByApId = new map<Id, List<Dealer_Actual_Sales__c>>();
           
            List<Dealer_Actual_Sales__c>lstDAS = new List<Dealer_Actual_Sales__c>();
           
            for(Dealer_Actual_Sales__c das : dasLst){
               
                if(mapDAS_ByApId.containsKey(das.Agreement_Product__c)){
                    lstDAS = mapDAS_ByApId.get(das.Agreement_Product__c);
                    lstDAS.add(das);
                    mapDAS_ByApId.put(das.Agreement_Product__c, lstDAS);
                   
                }else{
                    lstDAS.add(das);
                    mapDAS_ByApId.put(das.Agreement_Product__c ,lstDAS);
                    System.debug('mapDAS_ByApId'+mapDAS_ByApId);
                }
               
               
                System.debug('==>'+das);
                map<integer, Dealer_Actual_Sales__c> map_monthwiseDAS;
                if(map_Apid_Das_byMonth.containsKey(das.Agreement_Product__c)){
                    map_monthwiseDAS  = new  map<integer, Dealer_Actual_Sales__c>();
                    map_monthwiseDAS = map_Apid_Das_byMonth.get(das.Agreement_Product__c);
                   
                    if( das.Actual_Sales_Month__c !=null && !map_monthwiseDAS.containsKey(integer.valueof(das.Actual_Sales_Month__c))){
                        map_monthwiseDAS.put(integer.valueof(das.Actual_Sales_Month__c), das);
                        system.debug('DAS added 1');
                       
                    }
                   
                }else{
                   
                    map_monthwiseDAS  = new  map<integer, Dealer_Actual_Sales__c>();
                    if(das.Actual_Sales_Month__c !=null && !map_monthwiseDAS.containsKey(integer.valueof(das.Actual_Sales_Month__c))){
                        map_monthwiseDAS.put(integer.valueof(das.Actual_Sales_Month__c), das);
                    }
                   
                }
               
                map_Apid_Das_byMonth.put(das.Agreement_Product__c, map_monthwiseDAS);
               
            }
            System.debug('map_Apid_Das_byMonth:: '+map_Apid_Das_byMonth);
            //Current Aggrement Products map by product id
            map<id, Agreement_Product__c> productWiseBaseAp = new map<id, Agreement_Product__c>();
            for(Agreement_Product__c apRecord : apMap.values()){
                if( Test.isRunningTest() || (date.today() >= apRecord.Master_Agreement__r.Agreement_Start_Date__c &&  date.today() <= apRecord.Master_Agreement__r.Agreement_End_Date__c)){
                    productWiseBaseAp.put(apRecord.Product__c, apRecord);
                }
                if(Test.isRunningTest() ){
                    productWiseBaseAp.put(apRecord.Product__c, apRecord);
                }
            }
           
           
            List<Agreement_Product__c> lstAgreementProduct = apMap.values();
            //Bubble sort start
            //Bubble sort required for continuation of agrmment. and to make merge happen in the curent(agreement in whose start and end date todays date comes in between) agreement
            Agreement_Product__c apRecordTemp;
            integer ApListSize = lstAgreementProduct.size();
           
            for(integer i=0; i<ApListSize-1; i++){
                for(integer j=0; j<ApListSize-i-1;j++){
                    if(lstAgreementProduct[j].Master_Agreement__r.Agreement_Start_Date__c <lstAgreementProduct[j+1].Master_Agreement__r.Agreement_Start_Date__c){
                        apRecordTemp = lstAgreementProduct[j];
                        lstAgreementProduct[j] = lstAgreementProduct[j+1];
                        lstAgreementProduct[j+1] = apRecordTemp;
                    }
                }
            }
            //Bubble Sort End
           
           
           
            integer j;
            for(j = 0 ; j< lstAgreementProduct.size(); j++){
                Agreement_Product__c apRecord = lstAgreementProduct[j];
               
                DAPWrapper dapWrapperOld = new DAPWrapper();
                System.debug('masterAgreementLst.size()>1:: '+(masterAgreementLst.size()>1));
                System.debug(' mapDAPWrapper_byProdId.containsKey(apRecord.Product__c):: '+ mapDAPWrapper_byProdId.containsKey(apRecord.Product__c));
                if(masterAgreementLst.size()>1 && mapDAPWrapper_byProdId.containsKey(apRecord.Product__c)){//&& mapDAPWrapper_byProdId.get(apRecord.Product__c).masterAgrId == apRecord.Master_Agreement__c
                    System.debug('OldWrapper:: '+mapDAPWrapper_byProdId.get(apRecord.Product__c));
                    System.debug('New Record:: '+apRecord);
                    //if duplicate row found for  found
                   
                   
                   
                    System.debug('Second AP: '+apRecord);
                   
                    map<integer, Dealer_Actual_Sales__c> mapDas_byMonth = new map<integer, Dealer_Actual_Sales__c>();
                    mapDas_byMonth = map_Apid_Das_byMonth.get(apRecord.id);                    
                   
                    System.debug('mapDas_byMonth1:: '+mapDas_byMonth);
                    dapWrapperOld =  mapDAPWrapper_byProdId.get(apRecord.Product__c);
                    System.debug('Old DAP Wrapper record:: '+dapWrapperOld);
                    integer i= 0;
                    Date temp;
                    for(DASWrapper oldDasRecord : dapWrapperOld.dasWrapperLst){
                        //Replace das in old record in between new ap start and end date.
                        if(oldDasRecord != null && oldDasRecord.onlyInitialised != null && oldDasRecord.onlyInitialised && apRecord !=null &&
                           apRecord.Master_Agreement__c !=null  &&
                           apRecord.Master_Agreement__r.Agreement_End_Date__c != null &&
                           (i+1) <= apRecord.Master_Agreement__r.Agreement_End_Date__c.month()){
                               
                               DASWrapper daswrapper = new DASWrapper();
                               System.debug('mapDas_byMonth:: '+mapDas_byMonth);
                               System.debug('Value of i:'+i);
                               if(mapDas_byMonth != null && mapDas_byMonth.containsKey(i+1)){
                                   System.debug('ap has saved das for month :: '+mapDas_byMonth.get(i+1));
                                   //initialize wrapper with saved Actual sales
                                   Dealer_Actual_Sales__c das = mapDas_byMonth.get(i+1);
                                   daswrapper.month = monthLst[i];
                                   
                                   daswrapper.soldQuantity = das.Sold_Quantity__c;      
                                   daswrapper.startDate = Date.newInstance(selectedYear, i+1, 1);
                                   daswrapper.uniqueKey = String.valueOf(apRecord.Id)+String.valueOf(daswrapper.startDate);
                                   daswrapper.accountId = accountId;
                                   daswrapper.apId = apRecord.Id;
                                   daswrapper.prodcutId = dapWrapperOld.productId;
                                   daswrapper.masterAgrId = (apRecord.Master_Agreement__c!=null)?apRecord.Master_Agreement__c:null;
                                   if( Date.today().year() == selectedYear && ((i == Date.today().month()) || ((i+1) == Date.today().month())))
                                       daswrapper.isEditable=true;
                                   else
                                       daswrapper.isEditable=false;
                                   System.debug('monthLst[j]'+monthLst[i]+' -jVal'+i);
                               }else{
                                   //initialize wrapper with dummy values
                                   System.debug('monthLst[i]'+monthLst[i]+' -iVal'+i);
                                   daswrapper.month =monthLst[i];
                                   daswrapper.onlyInitialised = true;
                                   daswrapper.soldQuantity = 0;
                                   daswrapper.startDate = Date.newInstance(selectedYear, i+1, 1);
                                   daswrapper.uniqueKey = String.valueOf(apRecord.Id)+String.valueOf(daswrapper.startDate);
                                   daswrapper.accountId = dapWrapperOld.accountId;
                                   daswrapper.apId = apRecord.Id;
                                   daswrapper.prodcutId =  apRecord.Product__c;
                                   daswrapper.masterAgrId = (apRecord.Master_Agreement__c!=null)?apRecord.Master_Agreement__c:null;

                                                               
                                   Date currentMonthEditable = Date.newInstance(apRecord.Master_Agreement__r.Agreement_End_Date__c.Year(), (i), apRecord.Master_Agreement__r.Agreement_End_Date__c.day());
                                   Date previousMonthEditable = currentMonthEditable.addMonths(-1);
                                   
                                   if( Date.today().year() == selectedYear && ((currentMonthEditable.month() == Date.today().month()) || (previousMonthEditable.month() == Date.today().month()))){
                                       daswrapper.isEditable=true;
                                       System.debug('In True');
                                   }else{
                                      daswrapper.isEditable=false;
                                   }
                                   
                               }  
                               System.debug('daswrapper:: '+daswrapper+'    Value of i'+i);
                               
                               dapWrapperOld.dasWrapperLst[i] = daswrapper;
                               
                           }
                        i = i+1;
                    }
                   
                    mapDAPWrapper_byProdId.put(apRecord.Product__c, dapWrapperOld);
                   
                }else{
                   
                    DAPWrapper dapWrapper = new DAPWrapper();
                    dapWrapper.agreementCount = masterAgreementLst.size();
                    dapWrapper.agreementStartDate =  apRecord.Master_Agreement__r.Agreement_Start_Date__c;
                    dapWrapper.agreementEndDate = apRecord.Master_Agreement__r.Agreement_End_Date__c;
                    dapWrapper.productName = apRecord.Product__r.Name;
                    if(apRecord.Product__c != null){
                        dapWrapper.productId = apRecord.Product__c;
                    }else{
                        System.debug('AP with null productId'+apRecord);
                    }
                    dapWrapper.accountId = accountId;
                    if(apRecord.Opening_Stock__c == null){
                        dapWrapper.openingStock = 0;
                    }else{
                        dapWrapper.openingStock = apRecord.Opening_Stock__c;
                    }
                   
                    dapWrapper.totalInCountrySalesTillDate = apRecord.Total_Country_Stock__c;                  
                    dapWrapper.averageQuantityTillDate = apRecord.Average_Quantity_Till_Date__c;
                    dapWrapper.idealStockRequred = apRecord.Ideal_Stock_Required__c;
                    if(apRecord.Open_Order_Quantity__c == null){
                        dapWrapper.openOrdersWithBioTech = 0;
                    }else{
                        dapWrapper.openOrdersWithBioTech =apRecord.Open_Order_Quantity__c;
                    }
                    if(apRecord.Stock_In_Transit__c == null){
                        dapWrapper.stockInTransit =0;
                    }else{
                        dapWrapper.stockInTransit =  apRecord.Stock_In_Transit__c;
                    }
                    dapWrapper.difference = apRecord.Difference__c;
                    dapWrapper.apId = apRecord.Id;
                    dapWrapper.masterAgrId = (apRecord.Master_Agreement__c!=null)?apRecord.Master_Agreement__c:null;
                   
                   
                    List<DASWrapper> dsaWrapperLSt = new List<DASWrapper>();
                    map<integer, Dealer_Actual_Sales__c> mapDas_byMonth = new map<integer, Dealer_Actual_Sales__c>();
                    mapDas_byMonth = map_Apid_Das_byMonth.get(apRecord.id);                    
                   
                   
                    for(integer i=1; i<=12; i++) {
                        DASWrapper daswrapper = new DASWrapper();
                       
                        if(mapDas_byMonth != null && mapDas_byMonth.containsKey(i)){
                            //initialize wrapper with saved Actual sales
                            Dealer_Actual_Sales__c das = mapDas_byMonth.get(i);
                            daswrapper.month = integer.valueOf(das.Actual_Sales_Month__c);
                            daswrapper.soldQuantity = das.Sold_Quantity__c;      
                            daswrapper.startDate = Date.newInstance(selectedYear, i+1, 1);
                            daswrapper.uniqueKey = String.valueOf(apRecord.Id)+String.valueOf(daswrapper.startDate);
                            daswrapper.accountId = accountId;
                            daswrapper.apId = apRecord.Id;
                            daswrapper.prodcutId = dapWrapper.productId;
                            daswrapper.masterAgrId = (apRecord.Master_Agreement__c!=null)?apRecord.Master_Agreement__c:null;
                            System.debug('AGREEMENT END DATE:: '+ apRecord.Master_Agreement__r.Agreement_End_Date__c);
                           
    if( Date.today().year() == selectedYear && i-1 < apRecord.Master_Agreement__r.Agreement_End_Date__c.month() && i+2 > apRecord.Master_Agreement__r.Agreement_End_Date__c.month() && apRecord.Master_Agreement__r.Agreement_End_Date__c.month() == Date.today().month() && !(apRecord.Master_Agreement__r.Agreement_End_Date__c.month() < Date.today().month())){
    daswrapper.isEditable=true;
}else if( Date.today().year() == selectedYear && ((i == Date.today().month()) || ((i+1) == Date.today().month()))){// && ((i+1) < apRecord.Master_Agreement__r.Agreement_End_Date__c.month()) && !(apRecord.Master_Agreement__r.Agreement_End_Date__c.month() < Date.today().month())
    daswrapper.isEditable=true;
}else if( Date.today().year() == selectedYear && i == apRecord.Master_Agreement__r.Agreement_End_Date__c.month() && Date.today().month() == apRecord.Master_Agreement__r.Agreement_End_Date__c.month()+1){// &&  Date.today().month() != apRecord.Master_Agreement__r.Agreement_End_Date__c.month()
    //Logic for making month editable if agreement ends in last month then only one month last month should be editable
    daswrapper.isEditable=true;
}
                            
                                        
                            
                        }else{
                            //initialize wrapper with dummy values
                            daswrapper.month=i;//monthLst[i-1];
                            daswrapper.onlyInitialised = true;
                            daswrapper.soldQuantity = 0;
                            daswrapper.startDate = Date.newInstance(selectedYear, i+1, 1);
                            daswrapper.uniqueKey = String.valueOf(apRecord.Id)+String.valueOf(daswrapper.startDate);
                            daswrapper.accountId = dapWrapper.accountId;
                            daswrapper.apId = apRecord.Id;
                            daswrapper.prodcutId =  apRecord.Product__c;
                            daswrapper.masterAgrId = (apRecord.Master_Agreement__c!=null)?apRecord.Master_Agreement__c:null;
                            if( Date.today().year() == selectedYear && ((i+1 == Date.today().month()) || ((i) == Date.today().month())))
                                daswrapper.isEditable=true;
                            else{
                                daswrapper.isEditable=false;
                            }
                        }  
                       
                        dsaWrapperLSt.add(daswrapper);
                       
                    }
                    dapWrapper.dasWrapperLst = dsaWrapperLSt;  
                    mapDAPWrapper_byProdId.put(apRecord.Product__c, dapWrapper);
                    System.debug('dsaWrapperLSt:: '+dsaWrapperLSt);
                    // dsmWrapperLSt.add(dapWrapper);
                }
            }            
        }
       
        System.debug('mapDAPWrapper_byProdId.Values():: '+mapDAPWrapper_byProdId.Values());
        return mapDAPWrapper_byProdId.Values();
    }
   
    @AuraEnabled
    public static void upsertDSMandDASRecords(String wrapperString)
    {
        System.debug('wrapperString:: '+wrapperString);  
        List<DAPWrapper> wrapperLst = new List<DAPWrapper>();
        if( !String.isEmpty(wrapperString) && wrapperString.length()>0)
            wrapperLst = (List<DAPWrapper>)JSON.deserialize(wrapperString,List<DAPWrapper>.class);    
        system.debug(LoggingLEvel.Error,'wrapperLst>>'+wrapperLst);
        List<Agreement_Product__c> listToUpsertDSM = new List<Agreement_Product__c>();
        List<Dealer_Actual_Sales__c> listToUpsertDAS = new List<Dealer_Actual_Sales__c>();
        for(DAPWrapper wrapper : wrapperLSt)
        {
            Agreement_Product__c dsmToUpsert = new Agreement_Product__c();
            dsmToUpsert.Product__c = wrapper.productId;
            dsmToUpsert.Opening_Stock__c = wrapper.openingStock;
            dsmToUpsert.Account__c = wrapper.accountId;
            dsmToUpsert.Average_Quantity_Till_Date__c = wrapper.averageQuantityTillDate;
            dsmToUpsert.Ideal_Stock_Required__c = wrapper.idealStockRequred;
            dsmToUpsert.Open_Order_Quantity__c = wrapper.openOrdersWithBioTech;
            dsmToUpsert.Stock_In_Transit__c = wrapper.stockInTransit;
            dsmToUpsert.Master_Agreement__c =  wrapper.masterAgrId;
            dsmToUpsert.Id = wrapper.apId;
           
            listToUpsertDSM.add(dsmToUpsert);
        }
       
        if(listToUpsertDSM.size()>0){
            upsert listToUpsertDSM;
        }
       
        map<id,Agreement_Product__c> apIdDSMMap = new map<id,Agreement_Product__c>();
        for(Agreement_Product__c apInstance: listToUpsertDSM)
        {
            apIdDSMMap.put(apInstance.id, apInstance);
        }
        system.debug(LoggingLEvel.Error,'apIdDSMMap>>'+apIdDSMMap);
        for(DAPWrapper wrapper : wrapperLSt)
        {
            List<DASWrapper> daswrapperLst = wrapper.dasWrapperLst;
            system.debug(LoggingLEvel.Error,'daswrapperLst>>'+daswrapperLst);
            if(daswrapperLst!=null && !daswrapperLst.isEmpty())
            {
                for(DASWrapper wrapperInstance : daswrapperLst)
                {
                    System.debug('Ap Wise DAS:: '+wrapperInstance);
                    id apId = wrapperInstance.apId;//apIdDSMMap.containsKey(wrapperInstance.apId)?apIdDSMMap.get(wrapperInstance.apId).Id:null;
                    system.debug(LoggingLEvel.Error,'apId>>'+apId);
                    if(apId!=null)
                    {
                        Dealer_Actual_Sales__c das = new Dealer_Actual_Sales__c();
                        das.Sold_Quantity__c = wrapperInstance.soldQuantity;
                        das.Start_Date__c = wrapperInstance.startDate;
                        das.Unique_Key__c=  wrapperInstance.uniqueKey;
                        das.Agreement_Product__c = apId;
                        das.Account__c = wrapperInstance.accountId;
                        das.Product__c = wrapperInstance.prodcutId;
                        das.Actual_Sales_Month__c = wrapperInstance.month;
                        das.Actual_Sales_Date__c =  date.newInstance(das.Start_Date__c.year(),  wrapperInstance.month, 1);
                       
                        if(wrapperInstance.recordId!=null)
                            das.Id =  wrapperInstance.recordId;
                        listToUpsertDAS.add(das);    
                    }
                }
            }
        }
        system.debug('listToUpsertDAS>>'+listToUpsertDAS);    
        if(listToUpsertDAS.size()>0){
            upsert listToUpsertDAS Unique_Key__c;
        }
    }
   
    @AuraEnabled
    public static Order__c placeOrder(string accountId, string CurrencyIsoCode, boolean flag) {
        System.debug('accountId::'+accountId);
        Order__c ordRec;
        if(flag){
            try{
                ordRec = [select id,Account__c from order__C where status__c='Draft' and Account__c =: accountId];
            }catch (Exception e) {
               
                if(ordRec!=null) {
                    return ordRec;
                } else {
                    ordRec = new Order__c();
                    ordRec.Account__c = accountId;
                    ordRec.order_date__c = date.today();
                    ordRec.Status__c = 'Draft';
                    ordRec.Is_it_ok_to_cancel_old_Draft_Orders__c = true;
                    ordRec.CurrencyIsoCode = CurrencyIsoCode;
                    insert ordRec;
                }
            }      
        }else if(!flag){
            List<Order__c> lstOrderToUpdate = new List<Order__c>();
            for(Order__c  order : [select id,Account__c, Status__c from order__C where status__c='Draft' and Account__c =: accountId and Order_Product_Count__c !=0]){
                if(order.Status__c == 'Draft'){
                    order.Status__c = 'Cancel';
                    lstOrderToUpdate.add(order);
                }
            }
            if(lstOrderToUpdate.size()>0){
                update lstOrderToUpdate;
            }
            try{
                ordRec = [select id,Account__c from order__C where status__c='Draft' and Account__c =: accountId];
            }catch (Exception e) {
               
                if(ordRec!=null) {
                    return ordRec;
                } else {
                    ordRec = new Order__c();
                    ordRec.Account__c = accountId;
                    ordRec.order_date__c = date.today();
                    ordRec.Status__c = 'Draft';
                    ordRec.Is_it_ok_to_cancel_old_Draft_Orders__c = true;
                    ordRec.CurrencyIsoCode = CurrencyIsoCode;
                    insert ordRec;
                }
            }  
        }
       
        /*  */
        return ordRec;
    }
   
   
    public static DAPWrapper getDSMWrapper(Agreement_Product__c ap, Id accountId, integer[] monthLst, integer selectedYear){
       
        system.debug('In product present if>>'+ap.Product__r.Name);
       
        DAPWrapper dapWrapper = new DAPWrapper();
        dapWrapper.productName = ap.Product__r.Name;
        dapWrapper.productId = ap.Product__c;
        dapWrapper.accountId = accountId;
        dapWrapper.openingStock = 0;
        dapWrapper.totalInCountrySalesTillDate = 0;
        dapWrapper.averageQuantityTillDate = 0;
        dapWrapper.idealStockRequred = 0;
        dapWrapper.openOrdersWithBioTech = 0;
        dapWrapper.stockInTransit = 0;
        dapWrapper.difference = 0;
        dapWrapper.apId = ap.Id;
        dapWrapper.masterAgrId = (ap.Master_Agreement__c!=null)?ap.Master_Agreement__c:null;
       
       
        List<DASWrapper> dsaWrapperLSt = new List<DASWrapper>();
       
        for(integer i=0;i<12;i++) {
            DASWrapper daswrapper = new DASWrapper();
            daswrapper.month = monthLst[i];
            daswrapper.soldQuantity = 0;
            daswrapper.startDate = Date.newInstance(selectedYear, i+1, 1);
            daswrapper.uniqueKey = String.valueOf(ap.Id)+String.valueOf(daswrapper.startDate);
            daswrapper.accountId = accountId;
            daswrapper.apId = ap.Id;
            daswrapper.prodcutId = dapWrapper.productId;
            daswrapper.masterAgrId = (ap.Master_Agreement__c!=null)?ap.Master_Agreement__c:null;
           
            if( Date.today().year() == selectedYear && ((i == Date.today().month()) || ((i+1) == Date.today().month())))
                daswrapper.isEditable=true;
            else
                daswrapper.isEditable=false;    
            dsaWrapperLSt.add(daswrapper);
        }
        dapWrapper.dasWrapperLst = dsaWrapperLSt;
       
        return dapWrapper;
    }
   
    //Dealer Agreement Product Wrapper
    public class DAPWrapper
    {
       
        @AuraEnabled
        public integer agreementCount;
       
        @AuraEnabled
        public date agreementStartDate;
       
        @AuraEnabled
        public date agreementEndDate;
       
        @AuraEnabled
        public id accountId;
       
        @AuraEnabled
        public String productName;
        @AuraEnabled
        public String productId;
        @AuraEnabled
        public id recordId;
        @AuraEnabled
        public Decimal openingStock;
        @AuraEnabled
        public Decimal totalInCountrySalesTillDate;
        @AuraEnabled
        public Decimal averageQuantityTillDate;
        @AuraEnabled
        public Decimal idealStockRequred;
        @AuraEnabled
        public Decimal openOrdersWithBioTech;
        @AuraEnabled
        public Decimal stockInTransit;
        @AuraEnabled
        public Decimal difference;
        @AuraEnabled
        public String apId;
       
        @AuraEnabled
        public List<DASWrapper> dasWrapperLst;
       
        @AuraEnabled
        public Id masterAgrId;
    }
   
    //Dealer Actual Sales Wrapper
    public class DASWrapper
    {
       
        @AuraEnabled
        public boolean onlyInitialised;
        @AuraEnabled
        public Id accountId;
        @AuraEnabled
        public Id recordId;
        @AuraEnabled
        public String apId;
        @AuraEnabled
        public integer month;
        @AuraEnabled
        public Decimal soldQuantity;
        @AuraEnabled
        public date startDate;
        @AuraEnabled
        public String uniqueKey;
        @AuraEnabled
        public id prodcutId;
        @AuraEnabled
        public boolean isEditable;
        @AuraEnabled
        public Id masterAgrId;        
    }
    @AuraEnabled
    public static integer getDraftOrderCount(string accountId){
       
        List<Order__c> lstDraftOrders = new List<Order__c>();
       
        try{
            lstDraftOrders = [SELECT Id FROM Order__c WHERE Account__c =: accountId and Status__c ='Draft' and Order_Product_Count__c !=0]; //order product count=0 filter because when no product is added to order user should user it same order
        }catch(Exception e){
            return lstDraftOrders.size();
        }
       
       
        return lstDraftOrders.size();
       
       
    }  
}