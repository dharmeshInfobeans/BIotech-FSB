public class CommunityAccountInfo {
@AuraEnabled
    public static Account getAccountDetail(){
        User objUser = [SELECT Id, AccountId FROM User WHERE Id =: UserInfo.getUserId()];
        LIst<Account> ObjAccount = [Select id,Name,CurrencyIsoCode from Account where ID=:objUser.AccountID];
      
        if(ObjAccount != Null && ObjAccount.size() > 0){
            
            return ObjAccount[0];
        }
        else{
            return Null;
        }
    }
}