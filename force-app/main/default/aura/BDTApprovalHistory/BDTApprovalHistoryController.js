({
	doInit : function(component, event, helper) {
        debugger;
		var action = component.get("c.getListOfApproval");
        action.setCallback(this,function(response){
            if(response.getState()==='SUCCESS'){
                
                component.set('v.approveList',response.getReturnValue());
                //component.set('v.isRsm',response.getReturnValue().isrsmUser);
                console.log(response.getReturnValue());
            } 
        });
        $A.enqueueAction(action);
	}
})