({
	doInit : function(component, event, helper) {
        debugger;
		var action = component.get("c.getAccountDetail");
        action.setCallback(this,function(response){
            if(response.getState()==='SUCCESS'){
                component.set('v.objAccount',response.getReturnValue());
           } 
        });
        $A.enqueueAction(action);
	}
})