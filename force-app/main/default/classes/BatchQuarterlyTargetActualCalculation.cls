global class BatchQuarterlyTargetActualCalculation implements Database.Batchable<sObject>{
    
    global Database.QueryLocator start(Database.BatchableContext BC){
        return Database.getQueryLocator([Select Id,Quadrant__c,Role__c, Parameter__c,Financial_Year__c,Financial_Year__r.Start_Date__c,
                                         Financial_Year__r.End_Date__c,Product_1__c,Product_2__c,Division__c,DivisionT__c, 
                                         (select id,Points__c,KRA_Configuration__c,Achievement_to__c,Achievement_from__c 
                                          from KRA_Details__r) from KRA_Configuration__c]);
    }
    
    global void execute(Database.BatchableContext BC, List<KRA_Configuration__c> scope){
        System.debug('***In Execute method***'+scope);
        if(!scope.isEmpty()){
            for(KRA_Configuration__c KRAConfig : scope){
                if(KRAConfig.Role__c.contains(';'))
                {
                    for(String rolename :KRAConfig.Role__c.split(';'))
                    {
                        if(KRAConfig.Parameter__c == 'Product-Single' || 
                           KRAConfig.Parameter__c == 'Product-Combination'){
                                QuarterlyTargetActualCalculation QtrTgtAct = new QuarterlyTargetActualCalculation();
                                QtrTgtAct.calculateKRA(KRAConfig, rolename);
                           }
                    }
                }
                else
                {
                    if(KRAConfig.Parameter__c == 'Product-Single' || 
                       KRAConfig.Parameter__c == 'Product-Combination'){
                            QuarterlyTargetActualCalculation QtrTgtAct = new QuarterlyTargetActualCalculation();
                            QtrTgtAct.calculateKRA(KRAConfig, KRAConfig.Role__c);
                       }
                }
            }
            
            for(KRA_Configuration__c KRAConfig : scope){
                System.debug('***scope for CME-RTM***'+scope);
                if(KRAConfig.Role__c.contains(';'))
                {
                    for(String rolename :KRAConfig.Role__c.split(';'))
                    {
                        if(KRAConfig.Parameter__c == 'CME - RTM'){
                            List<String> tmpString = new list<string>();
                            System.debug('***KRAConfig.DivisionT__c***'+KRAConfig.DivisionT__c);
                            if(KRAConfig.DivisionT__c != null){
                                if(KRAConfig.DivisionT__c.contains(',')){
                                    tmpString = KRAConfig.DivisionT__c.split(','); 
                                }else {
                                    System.debug('***KRAConfig.DivisionT__c***'+KRAConfig.DivisionT__c);
                                    tmpString.add(KRAConfig.DivisionT__c);
                                }
                            }
                            QuarterlyCMERTMCalculation QtrCMERTM = new QuarterlyCMERTMCalculation();
                            QtrCMERTM.calculateCMERTM(KRAConfig, rolename, tmpString);
                        }
                    }
                }
                else
                {
                    System.debug('***Else CME-RTM***');
                    if(KRAConfig.Parameter__c == 'CME - RTM'){
                        List<String> tmpString = new list<string>();
                        System.debug('***KRAConfig.DivisionT__c***'+KRAConfig.DivisionT__c);
                        if(KRAConfig.DivisionT__c != null){
                            if(KRAConfig.DivisionT__c.contains(',')){
                                tmpString = KRAConfig.DivisionT__c.split(',');
                            } else{
                                System.debug('***KRAConfig.DivisionT__c***'+KRAConfig.DivisionT__c);
                                tmpString.add(string.valueOf(KRAConfig.DivisionT__c));
                            }
                        }
                        QuarterlyCMERTMCalculation QtrCMERTM = new QuarterlyCMERTMCalculation();
                        QtrCMERTM.calculateCMERTM(KRAConfig, KRAConfig.Role__c, tmpString);
                    }
                }
            }
            
            for(KRA_Configuration__c KRAConfig : scope){
                System.debug('***scope for Customer Category ST & EA***'+scope);
                if(KRAConfig.Role__c.contains(';'))
                {
                    for(String rolename :KRAConfig.Role__c.split(';'))
                    {
                        if(KRAConfig.Parameter__c =='Customer Category ST & EA'){
                            List<String> tmpString = new list<string>();
                            System.debug('***KRAConfig.DivisionT__c***'+KRAConfig.DivisionT__c);
                            if(KRAConfig.DivisionT__c != null){
                                if(KRAConfig.DivisionT__c.contains(',')){
                                    tmpString = KRAConfig.DivisionT__c.split(','); 
                                }else {
                                    System.debug('***KRAConfig.DivisionT__c***'+KRAConfig.DivisionT__c);
                                    tmpString.add(KRAConfig.DivisionT__c);
                                }
                            }
                            QuarterlyCustomerCategorySTandEA QtrSTEA = new QuarterlyCustomerCategorySTandEA();
                            QtrSTEA.calculateKRACustomerCategorySTandEA(KRAConfig, rolename, tmpString);
                        }
                    }
                }
                else
                {
                    System.debug('***Else Customer Category ST & EA***');
                    if(KRAConfig.Parameter__c =='Customer Category ST & EA'){
                        List<String> tmpString = new list<string>();
                        System.debug('***KRAConfig.DivisionT__c***'+KRAConfig.DivisionT__c);
                        if(KRAConfig.DivisionT__c != null){
                            if(KRAConfig.DivisionT__c.contains(',')){
                                tmpString = KRAConfig.DivisionT__c.split(',');
                            } else{
                                System.debug('***KRAConfig.DivisionT__c***'+KRAConfig.DivisionT__c);
                                tmpString.add(string.valueOf(KRAConfig.DivisionT__c));
                            }
                        }
                        QuarterlyCustomerCategorySTandEA QtrSTEA = new QuarterlyCustomerCategorySTandEA();
                        QtrSTEA.calculateKRACustomerCategorySTandEA(KRAConfig, KRAConfig.Role__c, tmpString);
                    }
                }
            }
            
            for(KRA_Configuration__c KRAConfig : scope){
                System.debug('***scope for HighPerformanceTeam***'+scope);
                if(KRAConfig.Role__c.contains(';'))
                {
                    for(String rolename :KRAConfig.Role__c.split(';'))
                    {
                        if(KRAConfig.Parameter__c =='High Performance Team'){
                            List<String> tmpString = new list<string>();
                            System.debug('***KRAConfig.DivisionT__c***'+KRAConfig.DivisionT__c);
                            if(KRAConfig.DivisionT__c != null){
                                if(KRAConfig.DivisionT__c.contains(',')){
                                    tmpString = KRAConfig.DivisionT__c.split(','); 
                                }else {
                                    System.debug('***KRAConfig.DivisionT__c***'+KRAConfig.DivisionT__c);
                                    tmpString.add(KRAConfig.DivisionT__c);
                                }
                            }
                            QuarterlyHighPerformanceTeam QtrHPT = new QuarterlyHighPerformanceTeam();
                            QtrHPT.calculateHighPerformanceTeam(KRAConfig, rolename, tmpString);
                        }
                    }
                }
                else
                {
                    System.debug('***Else HighPerformanceTeam***');
                    if(KRAConfig.Parameter__c =='High Performance Team'){
                        List<String> tmpString = new list<string>();
                        System.debug('***KRAConfig.DivisionT__c***'+KRAConfig.DivisionT__c);
                        if(KRAConfig.DivisionT__c != null){
                            if(KRAConfig.DivisionT__c.contains(',')){
                                tmpString = KRAConfig.DivisionT__c.split(',');
                            } else{
                                System.debug('***KRAConfig.DivisionT__c***'+KRAConfig.DivisionT__c);
                                tmpString.add(string.valueOf(KRAConfig.DivisionT__c));
                            }
                        }
                      QuarterlyHighPerformanceTeam QtrHPT = new QuarterlyHighPerformanceTeam();
                      QtrHPT.calculateHighPerformanceTeam(KRAConfig, KRAConfig.Role__c, tmpString);
                    }
                }
            }
            
            for(KRA_Configuration__c KRAConfig : scope){
                System.debug('***scope for Learn & Growth Training***'+scope);
                if(KRAConfig.Role__c.contains(';'))
                {
                    for(String rolename :KRAConfig.Role__c.split(';'))
                    {
                        if(KRAConfig.Parameter__c =='Learn & Growth Training'){
                            List<String> tmpString = new list<string>();
                            System.debug('***KRAConfig.DivisionT__c***'+KRAConfig.DivisionT__c);
                            if(KRAConfig.DivisionT__c != null){
                                if(KRAConfig.DivisionT__c.contains(',')){
                                    tmpString = KRAConfig.DivisionT__c.split(','); 
                                }else {
                                    System.debug('***KRAConfig.DivisionT__c***'+KRAConfig.DivisionT__c);
                                    tmpString.add(KRAConfig.DivisionT__c);
                                }
                            }
                            QuarterlyLearnandGrowthTraining QtrLGT = new QuarterlyLearnandGrowthTraining();
                           QtrLGT.calculateLearnandGrowthTraining(KRAConfig, rolename, tmpString);
                        }
                    }
                }
                else
                {
                    System.debug('***Else Learn & Growth Training***');
                    if(KRAConfig.Parameter__c =='Learn & Growth Training'){
                        List<String> tmpString = new list<string>();
                        System.debug('***KRAConfig.DivisionT__c***'+KRAConfig.DivisionT__c);
                        if(KRAConfig.DivisionT__c != null){
                            if(KRAConfig.DivisionT__c.contains(',')){
                                tmpString = KRAConfig.DivisionT__c.split(',');
                            } else{
                                System.debug('***KRAConfig.DivisionT__c***'+KRAConfig.DivisionT__c);
                                tmpString.add(string.valueOf(KRAConfig.DivisionT__c));
                            }
                        }
                      QuarterlyLearnandGrowthTraining QtrLGT = new QuarterlyLearnandGrowthTraining();
                     QtrLGT.calculateLearnandGrowthTraining(KRAConfig, KRAConfig.Role__c, tmpString);
                    }
                }
            }
        }
    }
    
    global void finish(Database.BatchableContext BC){
        System.debug('In Target vs Actual batch finish method : ');
    }
}