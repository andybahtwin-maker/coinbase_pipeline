import os, ssl, smtplib
from email.message import EmailMessage
from typing import List, Tuple

def load_smtp_from_env():
    host = os.getenv("SMTP_HOST") or os.getenv("MAIL_HOST") or "smtp.gmail.com"
    port = int(os.getenv("SMTP_PORT") or 587)
    user = os.getenv("SMTP_USER") or os.getenv("GMAIL_USER")
    pwd  = os.getenv("SMTP_PASS") or os.getenv("GMAIL_APP_PASSWORD")
    sender = os.getenv("EMAIL_FROM") or user
    recipient = os.getenv("EMAIL_TO") or os.getenv("RECIPIENT") or user
    if not (user and pwd and sender and recipient):
        missing = [k for k,v in [("SMTP_USER/GMAIL_USER",user), ("SMTP_PASS/GMAIL_APP_PASSWORD",pwd), ("EMAIL_FROM",sender), ("EMAIL_TO/RECIPIENT",recipient)] if not v]
        raise RuntimeError(f"Missing email env vars: {', '.join(missing)}")
    return host, port, user, pwd, sender, recipient

def send_email(subject: str, body: str, attachments: List[Tuple[str, bytes]]):
    """
    attachments: list of (filename, bytes)
    """
    host, port, user, pwd, sender, recipient = load_smtp_from_env()

    msg = EmailMessage()
    msg["Subject"] = subject
    msg["From"] = sender
    msg["To"] = recipient
    msg.set_content(body)

    for fname, blob in attachments:
        msg.add_attachment(blob, maintype="text", subtype="csv", filename=fname)

    ctx = ssl.create_default_context()
    with smtplib.SMTP(host, port) as s:
        s.starttls(context=ctx)
        s.login(user, pwd)
        s.send_message(msg)
    return f"Sent to {recipient}"
