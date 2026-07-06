public with sharing class GetCaseDetailsForAgent {
    public class Request {
        @InvocableVariable(
            label='Case Id'
            description='The Id of the Case to read'
            required=true
        )
        public String recordId;
    }

    public class Result {
        @InvocableVariable(
            label='Case Id'
            description='The Id of the Case that was read'
        )
        public String recordId;

        @InvocableVariable(
            label='Case Number'
            description='The Case number'
        )
        public String caseNumber;

        @InvocableVariable(
            label='Subject'
            description='The Case subject'
        )
        public String subject;

        @InvocableVariable(
            label='Description'
            description='The Case description'
        )
        public String description;

        @InvocableVariable(
            label='Status'
            description='The Case status'
        )
        public String status;

        @InvocableVariable(
            label='Priority'
            description='The Case priority'
        )
        public String priority;

        @InvocableVariable(
            label='Account Name'
            description='The related Account name'
        )
        public String accountName;

        @InvocableVariable(
            label='Found'
            description='Whether the Case was found'
        )
        public Boolean found;
    }

    @InvocableMethod(
        label='Get Case Details For Agent'
        description='Reads a Case and its related Account for the service assist agent'
    )
    public static List<Result> getDetails(List<Request> requests) {
        List<Result> results = new List<Result>();
        for (Request req : requests) {
            Result r = new Result();
            r.recordId = req.recordId;
            r.found = false;
            if (String.isNotBlank(req.recordId)) {
                List<Case> cases = [
                    SELECT Id, CaseNumber, Subject, Description, Status, Priority, Account.Name
                    FROM Case
                    WHERE Id = :req.recordId
                    WITH USER_MODE
                    LIMIT 1
                ];
                if (!cases.isEmpty()) {
                    Case c = cases[0];
                    r.caseNumber = c.CaseNumber;
                    r.subject = c.Subject;
                    r.description = c.Description;
                    r.status = c.Status;
                    r.priority = c.Priority;
                    r.accountName = (c.Account != null) ? c.Account.Name : null;
                    r.found = true;
                }
            }
            results.add(r);
        }
        return results;
    }
}
