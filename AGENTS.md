## Amr's standing rules

### Models and speed
- Cursor agents and every subagent: latest Grok (4.7) on **Medium** only. Never High, never Fast.
- Speed comes only from many parallel subagents.
- Grok web app serving the sdna-mcp connector runs on **Auto**, never Fast; verify Auto before each trigger.

### Acceptance
- The real test result is the acceptance criterion. Keep iterating until it actually passes. Never report done until production-ready.
- If a faster correct route exists, take it.

### AI routing (SolutionDNA / quote pipeline)
- Every AI question/answer goes server side through the Grok web app + sdna-mcp connector (server enqueues, the signed-in Grok account claims and submits). xAI API is forbidden.
- Grok replies are strict JSON parsed and validated server side.
- Grok chat shows the request and answer as a readable table plus a downloadable file, never raw JSON.
- Queries go once per section (all section items in one request/response).
- Prices: Egypt prices including local delivery, excluding VAT.

### Accounts and profiles
- Accounts: info@techwithamr.com, admin@techwithamr.com, ammr.gamal@gmail.com, rfq@techwithamr.com. None is banned; Amr switches between them by usage limits. The active account is whatever he switches to in the SolutionDNA UI, and the VPS must follow it.
- Each account has its own dedicated persistent profile; never sign one account into another's profile or mix accounts.
  - Browserbase contexts: info b6770b39, admin b38c1d2d, ammr ec6303db, rfq 67d4ccc2.
  - VPS sdna-browser-1 Chrome CDP (local only): info 9301, admin 9302, ammr 9303, rfq 9304.
- rfq@ mail lands in the admin@ inbox; read its codes there.
- Get logins/keys yourself via the browser and inboxes; don't ask Amr for keys or accounts.

### Resources
- Close every browser tab/page as soon as its job is done; keep at most one needed Grok tab per profile; release Browserbase sessions promptly so memory doesn't fill.
- A hung profile must fail fast (timeouts) and never wedge a worker.

### Secrets
- Never commit raw secrets; repos get only `.env.example` with names. Real values live in Vercel env or gitignored server .env files.
- New or recreated Vercel values are saved **encrypted, never Sensitive**.
- Never print secret values in chat, logs or reports.

### Safety
- No emails/messages to anyone; never send the Outlook draft (create only).
- No purchases or billing changes without Amr's OK.
- No manual DB row deletes; delete anything only when certain it is a true duplicate.
- Don't touch Redroid, /opt/workbot or the gemini Chrome on the VPS. Never approve a phone 'Verify it's you' prompt.

### Language
- Amr writes Egyptian Arabic; reply to him in short Egyptian Arabic.
