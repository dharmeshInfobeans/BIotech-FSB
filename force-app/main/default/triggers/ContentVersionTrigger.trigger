trigger ContentVersionTrigger on ContentVersion (after insert) {
    DispatcherClass.run(new ContentVersionHandler(), 'ContentVersionTrigger');   
}