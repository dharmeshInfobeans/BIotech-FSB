@isTest
public class BitSetTest {
   @TestSetup
    static void makeData(){
      
    }
    
     public static testmethod void methodName(){
         List<Integer> nList=new List<Integer>{1,2,3,4,5};
         BitSet.testBits('abcd',nList);
     }
}