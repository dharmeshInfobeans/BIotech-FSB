global class QuarterlyOTCalculation {
    
    global Period last2FiscQaurterStartEndDt{get;set;}
    public map<string, KRA_Calculation__c> mapUniqueKey_KRA {get;set;}
    public List<User> userLst;
    public Static Map<String,List<User>> userIdUserLstMap= new Map<String,List<User>>();
    public List<String> roleNamelst = new List<String>();
    public Static Map<Id,User> userIdUserMap= new Map<Id,User>();
    
    global QuarterlyOTCalculation(){
        last2FiscQaurterStartEndDt = [Select Id,StartDate,EndDate,FiscalYearSettings.StartDate,FiscalYearSettings.Enddate from period where type = 'QUARTER' AND /*StartDate = LAST_N_FISCAL_QUARTERS:2 AND*/ 
                                      StartDate = LAST_QUARTER];
        system.debug('***last2FiscQaurterStartEndDt***'+last2FiscQaurterStartEndDt);
    }
    
    
    public static void KRACalculateOT() {
        Map<String,List<User>> userIdUserLstMap = UserRolewiseGrouping_Class.createUserwiseGrouping('Domestic');
        system.debug('userIdUserLstMap in constructor***'+userIdUserLstMap);
        List<String> roleNamelst = new List<String>();
        for(String roleNm : userIdUserLstMap.keySet()){
            roleNamelst.add(roleNm); 
        }
        roleNamelst.sort();
        system.debug('sorted ist'+roleNamelst);
        
        list<KRA_Configuration__c> lstKRAConfiguration = [Select Id,Quadrant__c,Role__c, Parameter__c,Financial_Year__c,Financial_Year__r.Start_Date__c,
                                         Financial_Year__r.End_Date__c,Product_1__c,Product_2__c,Division__c,DivisionT__c, 
                                         (select id,Points__c,KRA_Configuration__c,Achievement_to__c,Achievement_from__c 
                                          from KRA_Details__r) from KRA_Configuration__c where Parameter__c='Operation Discpline(OT)'];
        
        if(!roleNamelst.isEmpty()){
            for(String roleName : roleNamelst){
                if(userIdUserLstMap.containsKey(roleName)){
                    calculateOT(userIdUserLstMap.get(roleName),roleName, lstKRAConfiguration);
                } 
            }
        } 
    }
    
    public static void calculateOT(List<User> lstUser, String roleNm, list<KRA_Configuration__c> lstKRAConfiguration){
        Period last2FiscQaurterStartEndDt = [Select Id,StartDate,EndDate,FiscalYearSettings.StartDate,FiscalYearSettings.Enddate from period where type = 'QUARTER' AND /*StartDate = LAST_N_FISCAL_QUARTERS:2 AND*/ 
                                      StartDate = Last_QUARTER];
        Date startDate = date.newInstance(last2FiscQaurterStartEndDt.StartDate.year(),last2FiscQaurterStartEndDt.StartDate.month(),last2FiscQaurterStartEndDt.StartDate.day());
        system.debug('***startDate***'+startDate);
        Date endDate = date.newInstance(last2FiscQaurterStartEndDt.EndDate.year(),last2FiscQaurterStartEndDt.EndDate.month(),last2FiscQaurterStartEndDt.EndDate.day());
        system.debug('***EndDate***'+EndDate);
        
        set<Id> userIds = new set<Id>();
        for(User usr : lstUser){
            userIds.add(usr.Id);
        }
       
        map<Id, User> mapUser = new map<Id, User>([Select Id , divisionT__c from User where id=: userIds]);
        
        //Get targets
        string Calltype = 'OT';
        string queryOTTargetSelect = 'SUM(Target__c)target , Sales_Employee__c, Sales_Employee__r.UserRole.Name roleName ';
        string queryOTTargetWhere = ' Sales_Employee__c=:userIds AND Start_Date__c >=: startDate AND End_Date__c <=: endDate AND Target_Type__c =: Calltype ';
        string queryOTTargetGrpBy ='Sales_Employee__c,Sales_Employee__r.UserRole.Name ';
        String queryOTTarget = 'Select ' + queryOTTargetSelect + ' from KRA_Target__c where '+queryOTTargetWhere + ' Group By '+ queryOTTargetGrpBy;
        system.debug('**queryOTTarget***'+queryOTTarget);
        AggregateResult[] OTTargetAggreRes = database.query(queryOTTarget);
        
        
        //Get Actuals
        string Status = 'Approved';
        string queryOTActivitySelect = 'Count(Id)cnt, Sales_Employee__c owner ';
        string queryOTActivityWhere = ' Visit_Date__c >=: startDate AND Visit_Date__c <=: endDate' +' AND Call_Type__c =: Calltype AND Status__c =: Status';
        string queryOTActivityGrpBy = 'Sales_Employee__c';
        
        String queryOTActivity = 'Select ' + queryOTActivitySelect + ' from Event where Sales_Employee__c =: userIds and ' 
            + queryOTActivityWhere + ' Group By '+ queryOTActivityGrpBy;
        
        //Get Self Event Opens
        AggregateResult[] selfOTActivityAggr = database.query(queryOTActivity);
        system.debug('***selfOTActivityAggr***'+selfOTActivityAggr);
        system.debug('**roleNm***'+roleNm);
        
        //Get Team Actuals
        queryOTActivitySelect = 'Count(Id) cnt, Sales_Employee__r.managerId owner ';
        queryOTActivityGrpBy = 'Sales_Employee__r.managerId';
        queryOTActivity = 'Select ' + queryOTActivitySelect + ' from Event where Sales_Employee__r.managerId =: userIds and ' 
            + queryOTActivityWhere + ' Group By '+ queryOTActivityGrpBy;
        system.debug('**queryOTActivity***'+queryOTActivity);
        AggregateResult[] teamOTActivityAggr = database.query(queryOTActivity);
        system.debug('***teamOTActivityAggr***'+teamOTActivityAggr);
		
        //Get team KRA calculations
        String queryKRACalculation = 'Select SUM(Total_Actuals__c)cnt, Sales_Employee__r.managerId owner from KRA_Calculation__c where Sales_Employee__r.managerId=:userIds group By Sales_Employee__r.managerId';
        AggregateResult[] kraCalOTAggr = database.query(queryKRACalculation);
        system.debug('***kraCalOTAggr***'+kraCalOTAggr);
        
        map<string, integer> mapUser_SelfActual = new map<string, integer>();
        map<string, integer> mapUser_TeamActual = new map<string, integer>();
        string ownerId, uniqueKey, salesEmp, roleName,division; 
        string parameter = 'Operation Discpline(OT)';
        list<KRA_Calculation__c> lstKRACal = new list<KRA_Calculation__c>();
        for(AggregateResult OTTarget : OTTargetAggreRes){
            KRA_Calculation__c kraCalc = new KRA_Calculation__c();
            //kracalc.KRA_Configuration__c = KRAConfig.Id;
            kraCalc.Start_Date__c = last2FiscQaurterStartEndDt.StartDate;
            kraCalc.End_Date__c = last2FiscQaurterStartEndDt.EndDate;
            kraCalc.OwnerId = (ID) OTTarget.get('Sales_Employee__c');
            salesEmp = (Id) OTTarget.get('Sales_Employee__c');
            roleName = (string) OTTarget.get('roleName');
            division = mapUser.get(salesEmp).divisionT__c;
            kraCalc.Target__c = (Decimal) OTTarget.get('target');
            //kraCalc.Team_Target__c = 0;
            
            kraCalc.Sales_Employee__c = (ID) OTTarget.get('Sales_Employee__c');
            uniqueKey = (string) salesEmp+'_'+(Date) startDate+'_'+(string) parameter;
            kraCalc.UniqueKey__c = uniqueKey;
			kraCalc.Self_Actual__c = 0;
            kraCalc.Team_Actual__c = 0;
            
             for (AggregateResult selfAr : selfOTActivityAggr)  {
                 if((string)selfAr.get('owner') == salesEmp){
                     kraCalc.Self_Actual__c = (decimal) selfAr.get('cnt');
                     break;
                 }
                 System.debug('cnt:-' + selfAr.get('cnt'));
             }
            
            for (AggregateResult teamAr : teamOTActivityAggr)  {
                if((string)teamAr.get('owner') == salesEmp){
                    //kraCalc.Team_Actual__c = (decimal) teamAr.get('cnt');
                    break;
                }
            }
            
            for (AggregateResult kraAggr : kraCalOTAggr)  {
                if((string) kraAggr.get('owner') == salesEmp){
                    kraCalc.Team_Actual__c = (decimal) kraAggr.get('cnt');
                    break;
                }
            }
            
            
            //Find allocated KRA configuration
            for(KRA_Configuration__c kraConfig : lstKRAConfiguration){
                for(string role : kraConfig.Role__c.split(';')){
                    if(roleName !=null 
                       && roleName.contains(role) 
                       && kraConfig.DivisionT__c !=null 
                       && (division.contains(kraConfig.DivisionT__c) || kraConfig.DivisionT__c.contains(division))) {
                           kracalc.KRA_Configuration__c = KRAConfig.Id;
                           decimal totalActual = kracalc.Team_Actual__c + kracalc.Self_Actual__c;
                           system.debug('***role***'+role);
                           if(role != 'RSM') {
                               system.debug('***Inside if***');
                               kracalc.Actual__c = kracalc.Self_Actual__c;  
                           } else {
                               system.debug('***Inside else***');
                               kracalc.Actual__c = totalActual; 
                           }
                           kracalc.Percentage__c = (kracalc.Actual__c / kracalc.Target__c) * 100;
                           for(KRA_Parameter_Detail__c kra :  kraConfig.KRA_Details__r) {
                               if((kracalc.Percentage__c > 100 && kra.Achievement_from__c == 100) 
                                  || (kracalc.Percentage__c >= kra.Achievement_from__c && kracalc.Percentage__c <= kra.Achievement_to__c)){
                                      kracalc.Points__c = kra.Points__c;
                                      break;
                                  } 
                           }
                           break;
                       }
                }
            }            
            lstKRACal.add(kracalc); 
        }
  		
        upsert lstKRACal UniqueKey__c;
        system.debug('***lstKRACal ***'+lstKRACal);
        
        
    }
    
    
   /* 
    public AggregateResult[] QuarterlyOTTarget(KRA_Configuration__c KRAConfig, string rolename,List<string> Div){
        Date startDate = date.newInstance(last2FiscQaurterStartEndDt.StartDate.year(),last2FiscQaurterStartEndDt.StartDate.month(),last2FiscQaurterStartEndDt.StartDate.day());
        system.debug('***startDate***'+startDate);
        Date endDate = date.newInstance(last2FiscQaurterStartEndDt.EndDate.year(),last2FiscQaurterStartEndDt.EndDate.month(),last2FiscQaurterStartEndDt.EndDate.day());
        system.debug('***EndDate***'+EndDate);
        string queryOTTargetDivision ='';
        if(Div.size() > 0){
            integer cnt =1;
            system.debug('***Div.size()***'+Div.size());
            for(string divs : Div){
                queryOTTargetDivision += 'Sales_Employee__r.DivisionT__C like \''+divs+'%\'';
                if(cnt < Div.size()){
                    queryOTTargetDivision +=' OR ';
                } 
                system.debug('***Div***'+Div);
                cnt++;
            }
        }
        system.debug('***queryOTTargetDivision***'+queryOTTargetDivision);
        string targettype = 'OT';
        string queryOTTargetSelect = 'SUM(Target__c)target ';
        string queryOTTargetWhere;
        string queryOTTargetGrpBy;
        
        if(rolename == 'RSM'){
            queryOTTargetSelect += ',Sales_Employee__c ';
            queryOTTargetWhere = ' Sales_Employee__r.UserRole.Name LIKE \''+rolename+'%\' AND'+' Start_Date__c >=: startDate '+
                'AND End_Date__c <=: endDate ' + 'AND Target_Type__c =: targettype ';
            queryOTTargetGrpBy ='Sales_Employee__c ';
        }else {
            queryOTTargetSelect += ',Sales_Employee__c ';
            queryOTTargetWhere = ' Sales_Employee__r.UserRole.Name LIKE \''+rolename+'%\' AND'+' Start_Date__c >=: startDate '+'AND End_Date__c <=: endDate AND (' + queryOTTargetDivision +') AND Target_Type__c =: targettype ';
            queryOTTargetGrpBy ='Sales_Employee__c ';
        }
        String queryOTTarget = 'Select ' + queryOTTargetSelect + ' from KRA_Target__c where '+queryOTTargetWhere + ' Group By '+ queryOTTargetGrpBy;
        system.debug('**queryOTTarget***'+queryOTTarget);
        AggregateResult[] OTTargetAggreRes = database.query(queryOTTarget);
        system.debug('***OTTargetAggreRes***'+OTTargetAggreRes);
        return OTTargetAggreRes;
    }
    
    public AggregateResult[] QuarterlyOTActivity(KRA_Configuration__c KRAConfig, string rolename, List<string> Div){
        Date startDate = date.newInstance(last2FiscQaurterStartEndDt.StartDate.year(),last2FiscQaurterStartEndDt.StartDate.month(),last2FiscQaurterStartEndDt.StartDate.day());
        system.debug('***startDate***'+startDate);
        Date endDate = date.newInstance(last2FiscQaurterStartEndDt.EndDate.year(),last2FiscQaurterStartEndDt.EndDate.month(),last2FiscQaurterStartEndDt.EndDate.day());
        system.debug('***EndDate***'+EndDate);
        string queryOTActivityDivision ='';
        if(Div.size() > 0){
            integer cnt =1;
            system.debug('***Div.size()***'+Div.size());
            for(string divs : Div){
                queryOTActivityDivision += 'Sales_Employee__r.DivisionT__C like \''+divs+'%\'';
                if(cnt < Div.size()){
                    queryOTActivityDivision +=' OR ';
                } 
                system.debug('***Div***'+Div);
                cnt++;
            }
        }
        system.debug('***queryOTActivityDivision***'+queryOTActivityDivision);
        string Calltype = 'OT';
        string Status = 'Approved';
        
        string queryOTActivitySelect = 'Count(Id)cnt ';
        string queryOTActivityWhere;
        string queryOTActivityGrpBy;
        system.debug('***KRAConfig.Role__c***'+KRAConfig.Role__c);
        system.debug('***rolename***'+rolename);
        
        if(rolename == 'RSM'){
            queryOTActivitySelect += ',Sales_Employee__c owner ';
            queryOTActivityWhere = ' Sales_Employee__r.UserRole.Name LIKE \''+rolename+'%\' AND' +' Visit_Date__c >=: startDate '+
                'AND Visit_Date__c <=: endDate AND Call_Type__c =: Calltype AND Status__c =: Status ';
            queryOTActivityGrpBy ='Sales_Employee__c ';
        } else{
            queryOTActivitySelect += ',Sales_Employee__c owner ';
            queryOTActivityWhere = ' Sales_Employee__r.UserRole.Name LIKE \''+rolename+'%\' AND (' + queryOTActivityDivision +') AND Visit_Date__c >=: startDate '+
                'AND Visit_Date__c <=: endDate AND Call_Type__c =:Calltype AND Status__c =:Status ';
            queryOTActivityGrpBy ='Sales_Employee__c ';
        }
        
        String queryOTActivity = 'Select ' + queryOTActivitySelect + ' from Event where '+queryOTActivityWhere + ' Group By '+ queryOTActivityGrpBy;
        system.debug('**queryOTActivity***'+queryOTActivity);
        AggregateResult[] OTActivityAggreRes = database.query(queryOTActivity);
        system.debug('***OTActivityAggreRes***'+OTActivityAggreRes);
        return OTActivityAggreRes;
    }
    
    public void calculateOT(KRA_Configuration__c KRAConfig, string rolename, List<string> Div) {
        Date startDate = date.newInstance(last2FiscQaurterStartEndDt.StartDate.year(),last2FiscQaurterStartEndDt.StartDate.month(),last2FiscQaurterStartEndDt.StartDate.day());
        system.debug('***startDate***'+startDate);
        Date endDate = date.newInstance(last2FiscQaurterStartEndDt.EndDate.year(),last2FiscQaurterStartEndDt.EndDate.month(),last2FiscQaurterStartEndDt.EndDate.day());
        system.debug('***EndDate***'+EndDate);
        string ownerId, uniqueKey, saleemp; 
        string parameter = 'Operation Discpline(OT)';
        List<KRA_Calculation__c> lstKRACal= new List<KRA_Calculation__c>();
        List<KRA_Parameter_Detail__c> KRAParam = KRAConfig.KRA_Details__r;
        KRA_Calculation__c kracalc = new KRA_Calculation__c();
        AggregateResult[] OTTargetars = QuarterlyOTTarget(KRAConfig,rolename,Div);
        AggregateResult[] OTActivityars = QuarterlyOTActivity(KRAConfig,rolename,Div);
        
        for(AggregateResult OTTarget :OTTargetars){
            kracalc = new KRA_Calculation__c();
            kracalc.KRA_Configuration__c = KRAConfig.Id;
            kracalc.Start_Date__c = last2FiscQaurterStartEndDt.StartDate;
            kracalc.End_Date__c = last2FiscQaurterStartEndDt.EndDate;
            kracalc.OwnerId = (ID) OTTarget.get('Sales_Employee__c');
            saleemp = (Id) OTTarget.get('Sales_Employee__c');
            kracalc.Target__c = (Decimal) OTTarget.get('target');
            kracalc.Sales_Employee__c = (ID) OTTarget.get('Sales_Employee__c');
            uniqueKey = (string) saleemp+'_'+(Date) startDate+'_'+(string) parameter;
            kracalc.UniqueKey__c = uniqueKey;
            for(AggregateResult OTActivity : OTActivityars){
                if(OTTarget.get('Sales_Employee__c') == OTActivity.get('owner')){
                   // if(rolename == 'RSM'){
                        kracalc.Self_Actual__c = (Integer) OTActivity.get('cnt');
                    //}else{
                       // kracalc.Actual__c = (Integer) OTActivity.get('cnt');
                      //  kracalc.Self_Actual__c = (Integer) OTActivity.get('cnt');
                    //}
                    kracalc.Percentage__c = ((Integer) OTActivity.get('cnt') / (Decimal) OTTarget.get('target')) * 100;
                    for(KRA_Parameter_Detail__c kra :  KRAParam) {
                        if((kracalc.Percentage__c > 100 && kra.Achievement_from__c == 100) 
                           || (kracalc.Percentage__c >= kra.Achievement_from__c && kracalc.Percentage__c <= kra.Achievement_to__c)){
                               kracalc.Points__c = kra.Points__c;
                               break;
                           } 
                    }
                }
            }
            lstKRACal.add(kracalc); 
        }
        insert lstKRACal;
    }
    
    public void KRAOTRollupCalculation() {
        mapUniqueKey_KRA = new map<string, KRA_Calculation__c>();
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
                    calculateOTRollupwise(userIdUserLstMap.get(roleName),roleName);
                } 
            }
        } 
    } */
    
   /* public void calculateOTRollupwise(List<User> lstUser, String roleNm){
        string ownerId, uniqueKey, saleemp; 
        Date startDate = date.newInstance(last2FiscQaurterStartEndDt.StartDate.year(),last2FiscQaurterStartEndDt.StartDate.month(),last2FiscQaurterStartEndDt.StartDate.day());
        system.debug('***startDate***'+startDate);
        Date endDate = date.newInstance(last2FiscQaurterStartEndDt.EndDate.year(),last2FiscQaurterStartEndDt.EndDate.month(),last2FiscQaurterStartEndDt.EndDate.day());
        system.debug('***EndDate***'+EndDate);
        Date ExpDateFrom = startDate;
        string parameter = 'Operation Discpline(OT)';
        KRA_Calculation__c kracal = new KRA_Calculation__c();
        set<Id> userIds = new set<Id>();
        for(User usr : lstUser){
            userIds.add(usr.Id);
        }
        System.debug('role name from method'+roleNm);
        system.debug('user ids'+userIds);
        AggregateResult[] OTRollupAggrResLst = [Select SUM(Self_Actual__c) selfact, Sales_Employee__r.ManagerID salesUser From KRA_Calculation__c 
                                                Where Start_Date__c >=: startDate And End_Date__c <=: endDate AND Parameter__c = 'Operation Discpline(OT)'
                                                AND (Sales_Employee__r.ManagerID IN : userIds) Group By Sales_Employee__r.ManagerID];
        system.debug('OTRollupAggrResLst'+OTRollupAggrResLst);
        List<KRA_Configuration__c> KRAConfigList = new List<KRA_Configuration__c>();
        KRAConfigList = [Select Id,Quadrant__c,Role__c, Parameter__c,Division__c,DivisionT__c, 
                         (select id,Points__c,KRA_Configuration__c,Achievement_to__c,Achievement_from__c 
                          from KRA_Details__r) from KRA_Configuration__c where Parameter__c = 'Operation Discpline(OT)'];
        
        if(!OTRollupAggrResLst.isEmpty()){
            for(AggregateResult OTAggrRes : OTRollupAggrResLst){
                saleemp = (Id) OTAggrRes.get('salesUser');
                uniqueKey = (string) saleemp+'_'+(Date) startDate+'_'+(string) parameter;
                system.debug('***uniqueKey***'+uniqueKey);
                kracal = new KRA_Calculation__c();
                if(mapUniqueKey_KRA.containsKey(uniqueKey)){
                    kracal = mapUniqueKey_KRA.get(uniqueKey);
                    kracal.Team_Actual__c += (decimal) OTAggrRes.get('selfact');
                 */   
                    /*if(kracal.Self_Actual__c != null && kracal.Team_Actual__c != null){
                        kracal.Total_Actual__c = kracal.Self_Actual__c + kracal.Team_Actual__c;
                    }else if(kracal.Self_Actual__c != null && kracal.Team_Actual__c == null){
                        kracal.Total_Actual__c = kracal.Self_Actual__c;
                    }else if(kracal.Team_Actual__c != null && kracal.Self_Actual__c == null){
                        kracal.Total_Actual__c = kracal.Team_Actual__c;
                    }
                    system.debug('self actuals'+kracal.Self_Actual__c);
                    system.debug('kracal.Team_Actual__c'+kracal.Team_Actual__c);
                    kracal.Total_Actual__c = kracal.Self_Actual__c + kracal.Team_Actual__c;*/
                   /* if(roleNm == '4_RSM'){
                        kracal.Actual__c = kracal.Total_Actual__c;
                    }else{
                        kracal.Actual__c = kracal.Self_Actual__c;
                    }*/
                   /* if(kracal.Actual__c !=null && kracal.Target__c != null){
                        kracal.Percentage__c = (kracal.Actual__c / kracal.Target__c) * 100;
                    } else if(kracal.Actual__c ==null && kracal.Target__c != null){
                        kracal.Percentage__c = kracal.Target__c * 100;
                    } else if(kracal.Actual__c != null && kracal.Target__c == null){
                        kracal.Percentage__c = kracal.Actual__c * 100;
                    }*/
                   // kracal.Percentage__c = (kracal.Actual__c / kracal.Target__c) * 100;
                   /* for(KRA_Configuration__c kraConfig : KRAConfigList){
                        for(KRA_Parameter_Detail__c kraparams : kraConfig.KRA_Details__r){
                            if((kracal.Percentage__c > 100 && kraparams.Achievement_from__c == 100) 
                               || (kracal.Percentage__c >= kraparams.Achievement_from__c && kracal.Percentage__c <= kraparams.Achievement_to__c)){
                                   kracal.Points__c = kraparams.Points__c;	
                               }
                        }
                    }
                }else{
                    kracal.Team_Actual__c += (decimal) OTAggrRes.get('selfact');*/
                    /*if(roleNm != '4_RSM'){
                        kracal.Team_Actual__c += (decimal) OTAggrRes.get('selfact');
                    }else{
                        kracal.Team_Actual__c += (decimal) OTAggrRes.get('Teamact');
                    }*/
                    //kracal.Team_Actual__c = (decimal) OTAggrRes.get('selfact');
                    /*if(kracal.Self_Actual__c != null && kracal.Team_Actual__c != null){
                        kracal.Total_Actual__c = kracal.Self_Actual__c + kracal.Team_Actual__c;
                    }else if(kracal.Self_Actual__c != null && kracal.Team_Actual__c == null){
                        kracal.Total_Actual__c = kracal.Self_Actual__c;
                    }else if(kracal.Team_Actual__c != null && kracal.Self_Actual__c == null){
                        kracal.Total_Actual__c = kracal.Team_Actual__c;
                    }
                    system.debug('self actuals else'+kracal.Self_Actual__c);
                    system.debug('kracal.Team_Actual__c else'+kracal.Team_Actual__c);
                    if(kracal.Self_Actual__c == null){
                       kracal.Self_Actual__c = 0; 
                    }
                    kracal.Total_Actual__c = kracal.Self_Actual__c + kracal.Team_Actual__c;
                    system.debug('roleNm'+roleNm);*/
                  /*  if(roleNm == '4_RSM'){
                        kracal.Actual__c = kracal.Total_Actual__c;
                    }else{
                        kracal.Actual__c = kracal.Self_Actual__c;
                    }
                    if(kracal.Actual__c !=null && kracal.Target__c != null){
                        kracal.Percentage__c = (kracal.Actual__c / kracal.Target__c) * 100;
                    } else if(kracal.Actual__c ==null && kracal.Target__c != null){
                        kracal.Percentage__c = kracal.Target__c * 100;
                    } else if(kracal.Actual__c != null && kracal.Target__c == null){
                        kracal.Percentage__c = kracal.Actual__c * 100;
                    }*/
                  /*  for(KRA_Configuration__c kraConfig : KRAConfigList){
                        for(KRA_Parameter_Detail__c kraparams : kraConfig.KRA_Details__r){
                            if((kracal.Percentage__c > 100 && kraparams.Achievement_from__c == 100) 
                               || (kracal.Percentage__c >= kraparams.Achievement_from__c && kracal.Percentage__c <= kraparams.Achievement_to__c)){
                                   kracal.Points__c = kraparams.Points__c;	
                               }
                        }
                    }
                    kracal.UniqueKey__c = uniqueKey;
                    mapUniqueKey_KRA.put(kracal.UniqueKey__c, kracal);
                }
            }
        }
        system.debug('***mapUniqueKey_KRA***'+mapUniqueKey_KRA);
        try{
            upsert mapUniqueKey_KRA.values() UniqueKey__c;
        }
        Catch(Exception e){
            System.debug('The following exception has occurred: ' + e.getMessage());
        }
    }*/
}