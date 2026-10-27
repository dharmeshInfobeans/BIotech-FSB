({
    
    addSubProductRow : function(component,event, helper){
        var orderProduct = component.get('v.orderProduct');
        console.log('BG >>> orderProduct : '+orderProduct);
        console.log('BG >>> orderProduct : '+orderProduct.AggrementProduct);
        var subProductItem;
        subProductItem = {};
        subProductItem.UniqueKey = this.generateRandomVal();
        subProductItem.ProductName = orderProduct.ProductName;
        subProductItem.Product = orderProduct.Product;
        subProductItem.AggrementProduct = orderProduct.AggrementProduct;
        subProductItem.ProductCode = orderProduct.ProductCode;
        subProductItem.ListPrice = orderProduct.ListPrice;
        subProductItem.SalesPrice = orderProduct.SalesPrice; 
        subProductItem.ProductFamily = orderProduct.ProductFamily;
        subProductItem.RecordId = '';
        subProductItem.currencyCode = orderProduct.currencyCode;
        
        subProductItem.Quantity =0;// orderProduct.Quantity; //Commented for setting Quantity=0 for added Sub product.
        
        if(orderProduct.Discount > 0)
            subProductItem.Discount = orderProduct.Discount;
        else
            subProductItem.Discount = 0;
        
        subProductItem.SubTotalPrice = orderProduct.SalesPrice * orderProduct.Quantity;
        
        //   if(orderProduct.Discount > 0)
        //    subProductItem.TotalPrice = orderProduct.SubTotalPrice -(orderProduct.SubTotalPrice * orderProduct.Discount/100);
        //  else
        //    subProductItem.TotalPrice = orderProduct.SubTotalPrice;
        
        
        subProductItem.TotalPrice = 0;
        
        subProductItem.SelectedPower = null;
        subProductItem.selectedaxisAngle = null ;
        subProductItem.SelectedCylendricalPower = null;
        subProductItem.ModelTxt ='';
        subProductItem.CodeTxt ='';
        orderProduct.subOrderProducts.push(subProductItem);
        component.set("v.orderProduct", orderProduct);
        this.calculateTotals(component, event, helper);
    },
    
    generateRandomVal : function(){
        return String(Math.round((new Date()).getTime() / 1000)) +  this.generateRandomString(10);
    },
    
    generateRandomString : function (length) {
        var chars = '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ';
        var result = '';
        for (var i = length; i > 0; --i) result += chars[Math.floor(Math.random() * chars.length)];
        return result;
    },
    
    calculateTotals : function(component, event, helper) {
        var subOrderProducts = component.get('v.orderProduct.subOrderProducts');
        var quantity = 0;
        var totalPrice = 0;
        for(var i=0 ; i< subOrderProducts.length; i++){
            if(!($A.util.isUndefinedOrNull(subOrderProducts[i].Quantity)) && subOrderProducts[i].Quantity!=''){
                quantity = quantity + parseInt(subOrderProducts[i].Quantity);
            }
            totalPrice += subOrderProducts[i].TotalPrice;
        }
        if(!($A.util.isUndefinedOrNull(quantity)) && quantity!='NaN' && quantity!='')
            component.set('v.totalQuantity',quantity);  
        else
            component.set('v.totalQuantity',0);
        
        component.set("v.totalPrice", totalPrice);
        
        //replicating Product Quantity to Order Quantity on any one of subproduct quantity change
        var orderProduct = component.get('v.orderProduct');
        if(quantity != 0){
            component.set('v.actualOrderQuantity',quantity);
        }
        
        orderProduct.TotalPrice =totalPrice;
        component.set('v.orderProduct', orderProduct);
    },
    
    
    
})