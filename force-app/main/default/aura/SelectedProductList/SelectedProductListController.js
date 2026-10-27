({
	removeSelectedItem : function(component, event, helper) {
       
        console.log(component.get("v.selectedPbeRec"));
        
       	var selectItemEvent = component.getEvent("removeProductEvent");
       
        selectItemEvent.setParams({"selectedPbe": component.get('v.selectedPbeRec')});
		selectItemEvent.fire();
        
    }
})