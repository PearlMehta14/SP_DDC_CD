from datetime import datetime, timezone, timedelta

# Indian Standard Time (Delhi / IST, UTC+05:30)
IST = timezone(timedelta(hours=5, minutes=30))

def ist_now() -> datetime:
    """Returns the current datetime in Delhi / Indian Standard Time (IST, UTC+05:30)."""
    return datetime.now(IST)
