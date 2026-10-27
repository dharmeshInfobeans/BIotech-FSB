({
	addRow : function(component, event, helper) {
		var CISWrapper = component.get("v.CISWrapper");
        CISWrapper.CISItemList.push(new Object());
        component.set("v.CISWrapper",CISWrapper);
	},
    calculateTotalValue : function(component, event, helper) {
		var CISItemList = component.get("v.CISWrapper.CISItemList");
        var totalValue = 0;
        for(let i=0;i<CISItemList.length;i++){
            if(!$A.util.isEmpty(CISItemList[i].value)){
                totalValue += CISItemList[i].value;
            }
        }
        component.set("v.CISWrapper.totalValue",totalValue);
	}
})