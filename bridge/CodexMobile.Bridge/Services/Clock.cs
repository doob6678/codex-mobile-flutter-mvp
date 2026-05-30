namespace CodexMobile.Bridge.Services;

public interface IClock
{
    DateTimeOffset Now { get; }
}

public sealed class SystemClock : IClock
{
    public DateTimeOffset Now => DateTimeOffset.UtcNow;
}

public sealed class ManualClock : IClock
{
    public ManualClock(DateTimeOffset now)
    {
        Now = now;
    }

    public DateTimeOffset Now { get; private set; }

    public void Advance(TimeSpan amount)
    {
        Now = Now.Add(amount);
    }
}
