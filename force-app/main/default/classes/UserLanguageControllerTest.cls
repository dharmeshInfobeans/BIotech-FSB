@isTest
public class UserLanguageControllerTest {
    
    @isTest
    static void testgetfreightProductList() {
        UserLanguageController cls = new UserLanguageController();
        test.startTest();
        UserLanguageController.updateUserLanguage('fr');
        test.stopTest();
        
    }
    
    @isTest
    static void testgetAvailableLanguages() {
        //UserLanguageController cls = new UserLanguageController();
        List<SiteLanguage__mdt> str1 = new List<SiteLanguage__mdt>();
        test.startTest();
        str1 = UserLanguageController.getAvailableLanguages();
        test.stopTest();
        
    }
    
    @isTest
    static void testgetUserLanguage() {
        //UserLanguageController cls = new UserLanguageController();
        String str1 = '';
        test.startTest();
        str1 = UserLanguageController.getUserLanguage();
        test.stopTest();
        
    }
}