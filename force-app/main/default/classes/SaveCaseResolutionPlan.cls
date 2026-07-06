public with sharing class SaveCaseResolutionPlan {
    public class Request {
        @InvocableVariable(
            label='Case Id'
            description='The Id of the Case to update'
            required=true
        )
        public String recordId;

        @InvocableVariable(
            label='Resolution Plan'
            description='The drafted resolution plan text to save into AI_Resolution_Plan__c'
            required=true
        )
        public String resolutionPlan;
    }

    public class Result {
        @InvocableVariable(
            label='Is Success'
            description='Whether the Case was updated successfully'
        )
        public Boolean isSuccess;

        @InvocableVariable(
            label='Message'
            description='A short status message'
        )
        public String message;
    }

    @InvocableMethod(
        label='Save Case Resolution Plan'
        description='Writes the drafted resolution plan into the Case AI_Resolution_Plan__c field'
    )
    public static List<Result> save(List<Request> requests) {
        List<Result> results = new List<Result>();
        List<Case> toUpdate = new List<Case>();
        for (Request req : requests) {
            Result r = new Result();
            r.isSuccess = false;
            if (String.isBlank(req.recordId)) {
                r.message = 'Case Id is required.';
            } else {
                Case c = new Case(Id = req.recordId, AI_Resolution_Plan__c = req.resolutionPlan);
                toUpdate.add(c);
                r.isSuccess = true;
                r.message = 'Saved resolution plan.';
            }
            results.add(r);
        }
        if (!toUpdate.isEmpty()) {
            try {
                update as user toUpdate;
            } catch (Exception e) {
                for (Result r : results) {
                    r.isSuccess = false;
                    r.message = 'Update failed: ' + e.getMessage();
                }
            }
        }
        return results;
    }
}
