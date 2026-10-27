public class UserRolewiseGrouping_Class {
    public static Map<String,List<User>> createUserwiseGrouping(String region){
        Map<String,List<User>> userIdUserLstMap= new Map<String,List<User>>();
        List<User> usrLst = new List<User>();
        system.debug('region'+region);
        
        String query = 'Select Id,IsActive,Employee_Code__c,UserRole.Name,ManagerId,User_Type__c,divisionT__c,Portal_User_Role__c From User Where UserRole.Name !=\'\''
        	         + ' And User_Type__c =:region'; 
        system.debug('query'+query);
        
        List<User> userLst = (List<User>) Database.query( query );  
		system.debug('userLst***'+userLst);
        
        if(region == 'Domestic'){
            if(!userLst.isEmpty()){
                for(User usr : userLst){
                    if(usr.UserRole.Name.StartsWith('SE') || usr.UserRole.Name.StartsWith('SSE') || 
                       usr.UserRole.Name.StartsWith('BDM') || usr.UserRole.Name.StartsWith('SSE/BDM')){
                           if(userIdUserLstMap.containsKey('1_SE_SSE_BDM')){
                               usrLst = userIdUserLstMap.get('1_SE_SSE_BDM');
                               usrLst.add(usr);
                           }
                           else{
                               usrLst = new List<User>();
                               usrLst.add(usr);
                               userIdUserLstMap.put('1_SE_SSE_BDM',usrLst);
                           }
                       }
                    else if(usr.UserRole.Name.StartsWith('DM')){
                        if(userIdUserLstMap.containsKey('2_DM')){
                            usrLst = userIdUserLstMap.get('2_DM');
                            usrLst.add(usr);
                        }
                        else{
                            usrLst = new List<User>();
                            usrLst.add(usr);
                            userIdUserLstMap.put('2_DM',usrLst);
                        }
                    }
                    else if(usr.UserRole.Name.StartsWith('ASM')){
                        if(userIdUserLstMap.containsKey('3_ASM')){
                            usrLst = userIdUserLstMap.get('3_ASM');
                            usrLst.add(usr);
                        }
                        else{
                            usrLst = new List<User>();
                            usrLst.add(usr);
                            userIdUserLstMap.put('3_ASM',usrLst);
                        }
                    }
                    else if(usr.UserRole.Name.StartsWith('RSM')){
                        if(userIdUserLstMap.containsKey('4_RSM')){
                            usrLst = userIdUserLstMap.get('4_RSM');
                            usrLst.add(usr);
                        }
                        else{
                            usrLst = new List<User>();
                            usrLst.add(usr);
                            userIdUserLstMap.put('4_RSM',usrLst);
                        }
                    }
                    else if(usr.UserRole.Name.StartsWith('ZDM')){
                        if(userIdUserLstMap.containsKey('5_ZDM')){
                            usrLst = userIdUserLstMap.get('5_ZDM');
                            usrLst.add(usr);
                        }
                        else{
                            usrLst = new List<User>();
                            usrLst.add(usr);
                            userIdUserLstMap.put('5_ZDM',usrLst);
                        }
                    }
                    else if(usr.UserRole.Name.StartsWith('ZSM')){
                        if(userIdUserLstMap.containsKey('6_ZSM')){
                            usrLst = userIdUserLstMap.get('6_ZSM');
                            usrLst.add(usr);
                        }
                        else{
                            usrLst = new List<User>();
                            usrLst.add(usr);
                            userIdUserLstMap.put('6_ZSM',usrLst);
                        }
                    }
                }
            }          
        }
        
     /*   else if(region == 'Turkey'){
            if(!userLst.isEmpty()){
                for(User usr : userLst){
                    if(usr.UserRole.Name.StartsWith('Sales')){
                        if(userIdUserLstMap.containsKey('1_Sales')){
                            usrLst = userIdUserLstMap.get('1_Sales');
                            usrLst.add(usr);
                        }
                        else{
                            usrLst = new List<User>();
                            usrLst.add(usr);
                            userIdUserLstMap.put('1_Sales',usrLst);
                        }
                    }
                    else if(usr.UserRole.Name.StartsWith('RSM')){//need to discuss this GD
                        if(userIdUserLstMap.containsKey('2_RSM')){
                            usrLst = userIdUserLstMap.get('2_RSM');
                            usrLst.add(usr);
                        }
                        else{
                            usrLst = new List<User>();
                            usrLst.add(usr);
                            userIdUserLstMap.put('2_RSM',usrLst);
                        }
                    }
                    else if(usr.UserRole.Name.StartsWith('Product')){
                        if(userIdUserLstMap.containsKey('3_Product')){
                            usrLst = userIdUserLstMap.get('3_Product');
                            usrLst.add(usr);
                        }
                        else{
                            usrLst = new List<User>();
                            usrLst.add(usr);
                            userIdUserLstMap.put('3_Product',usrLst);
                        }
                    }
                }
            }
        }
        else if(region == 'International'){
            if(!userLst.isEmpty()){
                for(User usr : userLst){
                    //if(usr.UserRole.Name.StartsWith('RBM')){
                    if(usr.Portal_User_Role__c == 'RBM'){//updated on 16/4
                        if(userIdUserLstMap.containsKey('1_RBM')){
                            usrLst = userIdUserLstMap.get('1_RBM');
                            usrLst.add(usr);
                        }
                        else{
                            usrLst = new List<User>();
                            usrLst.add(usr);
                            userIdUserLstMap.put('1_RBM',usrLst);
                        }
                    }
                }
            } 
        }   */
        system.debug('userIdUserLstMap in class****'+userIdUserLstMap);
        return userIdUserLstMap;
    }
}