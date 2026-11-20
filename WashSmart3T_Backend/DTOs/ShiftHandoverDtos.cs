namespace WashSmart.API.DTOs;

public class SubmitShiftHandoverRequest
{
    public string? Note { get; set; }
}

public class ConfirmShiftHandoverRequest
{
    public string? ManagerNote { get; set; }
}

public class RejectShiftHandoverRequest
{
    public string Reason { get; set; } = string.Empty;
}
