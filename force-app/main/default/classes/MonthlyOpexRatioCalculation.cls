global class MonthlyOpexRatioCalculation {
    
    global Period last2FiscMonthStartEndDt{get;set;}
    public Static Map<String,List<User>> userIdUserLstMap= new Map<String,List<User>>();
    public List<String> roleNamelst = new List<String>();
    public Static Map<Id,User> userIdUserMap= new Map<Id,User>();
    public List<User> userLst;
    public map<string, OPEX__C> mapUniqueKey_OPEX {get;set;}
    global MonthlyOpexRatioCalculation(){
        last2FiscMonthStartEndDt = [Select Id,StartDate,EndDate,FiscalYearSettings.StartDate,FiscalYearSettings.Enddate from period where type = 'MONTH' AND StartDate = LAST_N_MONTHS:3 limit 1];
        system.debug('***last2FiscMonthStartEndDt***'+last2FiscMonthStartEndDt);
    }
    
    public void MonthlyOpexCalculation() {
        mapUniqueKey_OPEX = new map<string, OPEX__C>();
        userLst = [Select Id,IsActive,Employee_Code__c,UserRole.Name,ManagerId From User Where IsActive = true and UserRole.Name != ''];
        system.debug('userLst'+userLst);
        if(!userLst.isEmpty()){
            for(User usr : userLst){
                userIdUserMap.put(usr.Id, usr);
            } 
        }
        userIdUserLstMap = UserRolewiseGrouping_Class.createUserwiseGrouping('Domestic');
        system.debug('userIdUserLstMap in constructor***'+userIdUserLstMap);
        
        for(String roleNm : userIdUserLstMap.keySet()){
            roleNamelst.add(roleNm); 
        }
        roleNamelst.sort();
        system.debug('sorted ist'+roleNamelst);
        if(!roleNamelst.isEmpty()){
            for(String roleName : roleNamelst){
                if(userIdUserLstMap.containsKey(roleName)){
                    calculateOpexExpensesAndSalary(userIdUserLstMap.get(roleName),roleName);
                    MonthlyNetSalesCalculation(roleName);
                } 
            }
        } 
    }
    
    public void calculateOpexExpensesAndSalary(List<User> lstUser, String roleNm){
        string ownerId, EmpCode, uniqueKey, StateCode,saleemp,regions;  
        Date startDate = date.newInstance(last2FiscMonthStartEndDt.StartDate.year(),last2FiscMonthStartEndDt.StartDate.month(),last2FiscMonthStartEndDt.StartDate.day());
        system.debug('***startDate***'+startDate);
        Date endDate = date.newInstance(last2FiscMonthStartEndDt.EndDate.year(),last2FiscMonthStartEndDt.EndDate.month(),last2FiscMonthStartEndDt.EndDate.day());
        system.debug('***EndDate***'+EndDate);
        Date ExpDateFrom = startDate;
        OPEX__C opx = new OPEX__C();
        set<Id> userIds = new set<Id>();
        for(User usr : lstUser){
            userIds.add(usr.Id);
        }
        System.debug('role name from method'+roleNm);
        system.debug('user ids'+userIds);
        
        /*AggregateResult[] OPEXAggrResLst = [Select SUM(Salary__c) Sal,SUM(Team_Salary__c) TeamSal,SUM(Expense_Amount__c) ExpAmt,SUM(Team_Expense__c) TeamExp,
                                            Sales_Employee__c salesUser,Sales_Employee__r.UserRole.name roleName,Region__c From OPEX__c Where Expense_From_Date__c >=: startDate And Expense_To_Date__c <=: endDate
                                            and (Sales_Employee__r.ManagerID IN : userIds OR Sales_Employee__c IN : userIds) Group By Sales_Employee__c,Region__c,
                                           Sales_Employee__r.UserRole.name];*/
        AggregateResult[] OPEXAggrResLst = [Select SUM(Salary__c) Sal,SUM(Expense_Amount__c) ExpAmt,Sales_Employee__r.ManagerID salesUser,
                                           Region__c From OPEX__c Where Expense_From_Date__c >=: startDate And Expense_To_Date__c <=: endDate
                                            and (Sales_Employee__r.ManagerID IN : userIds) Group By Region__c,
                                           Sales_Employee__r.ManagerID];
        system.debug('aggrRes'+OPEXAggrResLst);
        String role ='';
        if(!OPEXAggrResLst.isEmpty()){
            for(AggregateResult OPEXAggrRes : OPEXAggrResLst){
                ownerId = (Id) OPEXAggrRes.get('salesUser');
                saleemp = (Id) OPEXAggrRes.get('salesUser');
                ExpDateFrom = startDate;
                system.debug('ExpDateFrom***'+ExpDateFrom);
                regions = (Id) OPEXAggrRes.get('Region__c');
                uniqueKey = (string) saleemp+'_'+(Date) startDate+'_'+(string) regions;
                system.debug('***uniqueKey***'+uniqueKey);
                opx = new OPEX__C();
                if(mapUniqueKey_OPEX.containsKey(uniqueKey)){
                    opx = mapUniqueKey_OPEX.get(uniqueKey);
                    opx.Team_Expense__c += (decimal) OPEXAggrRes.get('ExpAmt');
                    opx.Team_Salary__c += (decimal) OPEXAggrRes.get('Sal');
                   // opx.Total_Expense__c = (decimal) OPEXAggrRes.get('ExpAmt') + opx.Team_Expense__c ;
                   // opx.Total_Salary__c = (decimal) OPEXAggrRes.get('Sal') + opx.Team_Salary__c;
                }else{
                    opx.Team_Expense__c = (decimal) OPEXAggrRes.get('ExpAmt');
                    opx.Team_Salary__c = (decimal) OPEXAggrRes.get('Sal');
                   // opx.Total_Expense__c = (decimal) OPEXAggrRes.get('ExpAmt');
                   // opx.Total_Salary__c = (decimal) OPEXAggrRes.get('Sal');
                    opx.UniqueKey__c = uniqueKey;
                    mapUniqueKey_OPEX.put(opx.UniqueKey__c, opx);
                }
            }
        }
        system.debug('***mapUniqueKey_OPEX***'+mapUniqueKey_OPEX);
        try{
            upsert mapUniqueKey_OPEX.values() UniqueKey__c;
        }
        Catch(Exception e){
            System.debug('The following exception has occurred: ' + e.getMessage());
        }
    }
    
    public void MonthlyNetSalesCalculation(string userRoleName){
        Date startDate = date.newInstance(last2FiscMonthStartEndDt.StartDate.year(),last2FiscMonthStartEndDt.StartDate.month(),last2FiscMonthStartEndDt.StartDate.day());
        system.debug('***startDate***'+startDate);
        Date endDate = date.newInstance(last2FiscMonthStartEndDt.EndDate.year(),last2FiscMonthStartEndDt.EndDate.month(),last2FiscMonthStartEndDt.EndDate.day());
        system.debug('***EndDate***'+EndDate);
        system.debug('***userRoleName***'+userRoleName);
        string customerRegion = 'Domestic';
        string queryActualSelect = 'SUM(Quantity__c)Qty, SUM(Net_Value_Item__c)Amt ';
        string queryActualWhere;
        string queryActualGrpBy;
        if(userRoleName == '1_SE_SSE_BDM'){
            queryActualSelect += ',Sales_Employee__c owner,Account__r.region__c ';
            queryActualWhere = ' Billing_Date__c >=: startDate '+
                'AND Billing_Date__c <=: endDate AND Account__c != null AND Sales_Employee__c !=null AND Region_of_Customer__c =: customerRegion ';
            queryActualGrpBy ='Sales_Employee__c,Account__r.region__c ' ;
        }
        if(userRoleName == '2_DM'){
            queryActualSelect += ',Div_Manager__c owner,Account__r.region__c ';
            queryActualWhere = ' Billing_Date__c >=: startDate '+
                'AND Billing_Date__c <=: endDate AND Account__c != null AND Div_Manager__c !=null AND Region_of_Customer__c =: customerRegion ' ;
            queryActualGrpBy ='Div_Manager__c,Account__r.region__c ';
        }
        if(userRoleName == '3_ASM'){
            queryActualSelect += ',ASMs__c owner,Account__r.region__c ';
            queryActualWhere = ' Billing_Date__c >=: startDate '+
                'AND Billing_Date__c <=: endDate AND Account__c != null AND ASMs__c !=null AND Region_of_Customer__c =: customerRegion ';
            queryActualGrpBy ='ASMs__c,Account__r.region__c ';
        }
        if(userRoleName == '4_RSM'){
            queryActualSelect += ',RSM__c owner,Account__r.region__c ';
            queryActualWhere = ' Billing_Date__c >=: startDate '+
                'AND Billing_Date__c <=: endDate AND Account__c != null AND RSM__c !=null AND Region_of_Customer__c =: customerRegion ';
            queryActualGrpBy ='RSM__c,Account__r.region__c ';
        }
        if(userRoleName == '5_ZDM'){
            queryActualSelect += ',ZBMs__c owner,Account__r.region__c ';
            queryActualWhere = ' Billing_Date__c >=: startDate '+
                'AND Billing_Date__c <=: endDate AND Account__c != null AND ZBMs__c !=null AND Region_of_Customer__c =: customerRegion ';
            queryActualGrpBy ='ZBMs__c,Account__r.region__c ';
        }
        if(userRoleName == '6_ZSM'){
            queryActualSelect += ',ZSM__c owner,Account__r.region__c ';
            queryActualWhere = ' Billing_Date__c >=: startDate '+
                'AND Billing_Date__c <=: endDate AND Account__c != null AND ZSM__c !=null AND Region_of_Customer__c =: customerRegion ';
            queryActualGrpBy ='ZSM__c,Account__r.region__c ';
        } 
        
        String queryActual = 'Select ' + queryActualSelect + ' from Z_Incentive__c where '+queryActualWhere + ' Group By '+ queryActualGrpBy;
        system.debug('**queryActual***'+queryActual);
        AggregateResult[] ActualAggreRes = database.query(queryActual);
        List<OPEX__C> upsertOPEX = new List<OPEX__C>();
        string users,regions,uniqueKey;
        OPEX__c t = new OPEX__c();
        for(AggregateResult ar : ActualAggreRes)
        {
            system.debug('**mapUniqueKey_OPEX.keyset()***'+mapUniqueKey_OPEX.keyset());
            users = (Id) ar.get('owner');
            regions = (Id) ar.get('Region__c'); 
            uniqueKey = (string) users+'_'+(Date) startDate+'_'+(string) regions;
            system.debug('**uniqueKey***'+uniqueKey);
            t = new OPEX__C();
            if(mapUniqueKey_OPEX.containsKey(uniqueKey)){
                t = mapUniqueKey_OPEX.get(uniqueKey);
               
            }
            t.Net_Sales_Value__c = (Decimal) ar.get('Amt');
            t.UniqueKey__c = uniqueKey;
            mapUniqueKey_OPEX.put(t.UniqueKey__c, t);
        }
        system.debug('***mapUniqueKey_OPEX***'+mapUniqueKey_OPEX);
        try{
            if(!mapUniqueKey_OPEX.isEmpty())
            	upsert mapUniqueKey_OPEX.values() UniqueKey__c;
        }
        Catch(Exception e){
            System.debug('The following exception has occurred: ' + e.getMessage());
        }
    }
}