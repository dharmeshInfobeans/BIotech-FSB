({
    doInit : function(component, event, helper) {
        helper.setProductOptions(component);
    },
    clearValues : function(component, event, helper) {
        var item = component.get("v.item");
        item.company = '';
        item.product = '';
        item.surguries = null;
        item.price = null;
        item.value = 0;
        component.set("v.item",item);
        //Fire Event to calculate Total
        var calcualteTotal = component.getEvent("CalculateTotal");
		calcualteTotal.fire();
    },
    
    handleValidation : function(component, event, helper) {
    	console.log('In completion');
    },
    calculateValue : function(component, event, helper) {
        var price = component.get("v.item.price");
        var surguries = component.get("v.item.surguries");
        var value = 0;
        if(!$A.util.isEmpty(surguries) && !$A.util.isEmpty(price)){
            value = price * surguries;
        }
        component.set("v.item.value",value);
        
        //Fire Event to calculate Total
        var calcualteTotal = component.getEvent("CalculateTotal");
		calcualteTotal.fire();
    },
})