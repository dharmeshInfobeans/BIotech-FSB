({
	setProductOptions : function(component) {
        var item = component.get("v.item");
        var productPicklistValues = component.get("v.productPicklistValues");
        
        var productOptions = new Array();
        productOptions.push(productPicklistValues[0]);
        
        if(item.company != '' && item.company != undefined){
            for(let i=1;i<productPicklistValues.length;i++){
                if(productPicklistValues[i].validForOptions != undefined && productPicklistValues[i].validForOptions.indexOf(item.company) != -1){
                    productOptions.push(productPicklistValues[i]);
                }
            }
        }
        component.set("v.productOptions",productOptions);
    }
})