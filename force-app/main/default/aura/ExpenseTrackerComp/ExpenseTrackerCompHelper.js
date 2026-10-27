({
	onInit : function(component, event) {
	 var action = component.get("c.getUserData");
     var action2 = component.get("c.getUrlConfigFromCS");
     action.setCallback(this,function(response){
     	var state =  response.getState();
         if(state === "SUCCESS"){
             var retVal = response.getReturnValue();
             console.log("FROM APEX 1-->"+JSON.stringify(retVal));

           
         }
     });
      action2.setCallback(this,function(response2){
     	var state =  response2.getState();
         if(state === "SUCCESS"){
             var retVal = response2.getReturnValue();
             console.log("FROM APEX 2-->"+JSON.stringify(retVal));

           
         }
     });
     $A.enqueueAction(action);
     $A.enqueueAction(action2);
	}
})