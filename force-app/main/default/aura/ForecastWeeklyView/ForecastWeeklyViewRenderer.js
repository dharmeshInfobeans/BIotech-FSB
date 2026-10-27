({
    afterRender : function( component,event,  helper ) {
       /* console.log('after render');
        this.superAfterRender();
        var didScrolled;			
        //var div = component.find('scroll_container');
        var divObj = component.find('divScroll');
        if(!$A.util.isEmpty(divObj)){
            divObj = divObj.getElement();
            divObj.onscroll = function(){
                didScrolled = true;
            };
            console.log('div on scroll',didScrolled);
            //Interval function to check if the user scrolled or if there is a scrollbar
            var scrollCheckIntervalId = setInterval($A.getCallback(function(){
                if(didScrolled){
                    didScrolled = false;
                    console.log('***didScrolled***'+didScrolled);
                    if(divObj.scrollTop === (divObj.scrollHeight - divObj.offsetHeight)){
                        console.log('inside div if');
                        helper.getNextPage(component);
                    }
                }
            }), 5000);
            component.set('v.scrollCheckIntervalId', scrollCheckIntervalId);
        }
        */
    },
    
    unrender : function( component, helper ) {
        this.superUnrender();
        var scrollCheckIntervalId = component.get( 'v.scrollCheckIntervalId' );
        if ( !$A.util.isUndefinedOrNull( scrollCheckIntervalId ) ) {
            window.clearInterval( scrollCheckIntervalId );
        }
    } ,
    

})