# Newsletter System Design

**Date:** 2026-03-22  
**Status:** Approved

## Overview

A newsletter subscription system for the Glorified Notepad blog, allowing users to opt in to receive monthly email newsletters. The system supports markdown-based newsletter composition, double opt-in subscription, email delivery via Resend, and a public web archive.

## Goals

- Allow users to subscribe to newsletters via email opt-in
- Enable newsletter composition in markdown files (similar to blog posts)
- Provide a Mix task workflow for testing and sending newsletters
- Deliver emails through Resend (free tier: 3,000 emails/month)
- Maintain a public web archive of sent newsletters
- Ensure legal compliance (double opt-in, one-click unsubscribe)

## Non-Goals

- Email analytics/tracking (opens, clicks)
- Subscriber segmentation or preferences
- Newsletter scheduling/automation
- A/B testing
- Rich email templates (keep it simple markdown)

## Email Service Provider Decision

**Selected: Resend**

### Why Resend?
- **Free tier**: 3,000 emails/month, 100 emails/day (permanent, no expiration)
- Room for 300 monthly subscribers at current volume projections
- Developer-friendly REST API with Elixir library support
- Excellent deliverability with pristine shared IPs
- Simple integration, minimal configuration
- No credit card required for free tier

### Alternatives Considered:
- **Brevo**: 300 emails/day free tier, but includes branding on emails
- **Amazon SES**: $0.10/1,000 emails after 12-month free tier, more complex setup

For the anticipated "double digits" subscriber count, Resend provides the best balance of simplicity, cost (free forever), and developer experience.

## Database Schema

### `subscribers` Table

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | integer | primary key | Auto-incrementing ID |
| `email` | string | unique, not null | Subscriber email address |
| `confirmation_token` | string | unique | Token for double opt-in confirmation |
| `confirmed_at` | datetime | nullable | Timestamp when subscription confirmed (null = pending) |
| `unsubscribe_token` | string | unique | Token for one-click unsubscribe |
| `inserted_at` | datetime | not null | Record creation timestamp |
| `updated_at` | datetime | not null | Record update timestamp |

**Indexes:**
- Unique index on `email`
- Unique index on `confirmation_token`
- Unique index on `unsubscribe_token`
- Index on `confirmed_at` for querying confirmed subscribers

### `newsletters` Table

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | integer | primary key | Auto-incrementing ID |
| `slug` | string | unique, not null | URL slug (e.g., "2026-03-my-title") |
| `subject` | string | not null | Email subject line (from YAML) |
| `file_path` | string | not null | Path to markdown file |
| `sent_at` | datetime | nullable | Timestamp when sent (null = draft) |
| `recipient_count` | integer | nullable | Number of subscribers when sent |
| `inserted_at` | datetime | not null | Record creation timestamp |
| `updated_at` | datetime | not null | Record update timestamp |

**Indexes:**
- Unique index on `slug`
- Index on `sent_at` for querying sent newsletters

## File Structure

### Newsletter Storage

Newsletters are stored as markdown files in `content/newsletters/`:

```
content/
├── newsletters/
│   ├── 2026-03-my-first-newsletter.md
│   ├── 2026-04-april-update.md
│   └── ...
└── [existing blog posts]
```

### Newsletter File Format

Each newsletter is a markdown file with YAML front matter:

```markdown
---
subject: "My First Newsletter"
slug: "my-first-newsletter"
date: 2026-03-22
preview_text: "Optional preview text for email clients"
---

# Welcome to my newsletter!

Your markdown content here...

## Section heading

More content with **bold** and *italic* text.

[Links work too](https://example.com)
```

**Required YAML fields:**
- `subject` - Email subject line
- `slug` - URL slug (combined with date for full slug)
- `date` - Publication date (YYYY-MM-DD format)

**Optional YAML fields:**
- `preview_text` - Preview text shown in email client inbox

**Full slug generation:**
The full slug is generated as `{YYYY-MM}-{slug}` (e.g., `2026-03-my-first-newsletter`).

## Module Architecture

### Core Modules

#### `Indie.Newsletter`
Handles newsletter file parsing and management, similar to `Indie.Post`.

**Responsibilities:**
- Load newsletter files from `content/newsletters/`
- Parse YAML front matter and markdown content
- Validate required fields
- Generate full slugs from date + slug
- Query sent/draft newsletters

**Key functions:**
- `all/0` - Load all newsletters (sent and draft)
- `sent/0` - Load only sent newsletters (where `sent_at IS NOT NULL` in DB)
- `get_by_slug/1` - Load newsletter by full slug
- `load_from_file/1` - Parse a specific newsletter file
- `validate/1` - Validate newsletter has required fields

#### `Indie.Newsletter.EmailRenderer`
Converts markdown to email-safe HTML.

**Responsibilities:**
- Convert markdown to HTML using Earmark
- Generate email-safe HTML (inline CSS, table-based layout)
- Add unsubscribe footer with token link
- Handle preview text header
- Ensure compatibility with major email clients

**Key functions:**
- `render_email/2` - Convert newsletter + subscriber to email HTML
- `render_test_email/1` - Convert newsletter to test email HTML
- `inline_styles/1` - Apply inline CSS for email clients

**Email template structure:**
```html
<table width="100%" style="max-width: 600px; margin: 0 auto; font-family: sans-serif;">
  <tr>
    <td style="font-size: 16px; line-height: 1.6;">
      <!-- Newsletter HTML content -->
    </td>
  </tr>
  <tr>
    <td style="padding-top: 40px; border-top: 1px solid #ccc; font-size: 12px; color: #666;">
      <p>
        You're receiving this because you subscribed to Glorified Notepad's newsletter.<br>
        <a href="{unsubscribe_url}">Unsubscribe</a>
      </p>
    </td>
  </tr>
</table>
```

#### `Indie.Newsletter.WebRenderer`
Converts markdown to web HTML for archive pages.

**Responsibilities:**
- Convert markdown to HTML using Earmark
- Generate web-friendly HTML (full Tailwind CSS support)
- No email-specific constraints

**Key functions:**
- `render_web/1` - Convert newsletter to web HTML

#### `Indie.Subscribers`
Manages subscriber lifecycle (CRUD operations).

**Responsibilities:**
- Create subscribers with tokens
- Confirm subscriptions via token
- Unsubscribe via token
- Query confirmed subscribers
- Handle duplicate signups

**Key functions:**
- `create/1` - Create new subscriber with tokens
- `confirm/1` - Mark subscriber as confirmed by token
- `unsubscribe/1` - Soft delete or mark subscriber unsubscribed
- `confirmed_subscribers/0` - Get all confirmed subscribers
- `get_by_confirmation_token/1` - Find subscriber by confirmation token
- `get_by_unsubscribe_token/1` - Find subscriber by unsubscribe token
- `generate_token/0` - Generate cryptographically secure random token

#### `Indie.Newsletter.Mailer`
Resend API wrapper for email sending.

**Responsibilities:**
- Send confirmation emails (double opt-in)
- Send test emails
- Send newsletter broadcasts
- Handle Resend API errors
- Batch sending for multiple recipients

**Key functions:**
- `send_confirmation/1` - Send confirmation email to new subscriber
- `send_test/2` - Send test email (newsletter + recipient)
- `send_newsletter/2` - Send newsletter to all confirmed subscribers
- `send_batch/1` - Batch send via Resend API (up to 100 per batch)

**Configuration:**
- Resend API key stored in `RESEND_API_KEY` environment variable
- From address configured in `config/runtime.exs`

## LiveViews & Routes

### Routes

Add to `lib/indie_web/router.ex`:

```elixir
scope "/", IndieWeb do
  pipe_through :browser

  # Newsletter signup and management
  live "/newsletter", NewsletterSignupLive
  live "/newsletter/confirm/:token", NewsletterConfirmLive
  live "/newsletter/unsubscribe/:token", NewsletterUnsubscribeLive
  
  # Newsletter archive
  live "/newsletters", NewsletterArchiveLive
  live "/newsletters/:slug", NewsletterShowLive
end
```

### LiveViews

#### `IndieWeb.NewsletterSignupLive` (`/newsletter`)
Newsletter signup page with email form.

**Features:**
- Email input field
- Submit button
- Link to `/newsletters` archive
- Success message after signup
- Error handling (duplicate email, invalid format)

**Flow:**
1. User enters email and submits
2. Validate email format
3. Create subscriber with tokens (via `Indie.Subscribers.create/1`)
4. Send confirmation email (via `Indie.Newsletter.Mailer.send_confirmation/1`)
5. Show success: "Check your email to confirm your subscription"

#### `IndieWeb.NewsletterConfirmLive` (`/newsletter/confirm/:token`)
Confirmation landing page.

**Features:**
- Validates confirmation token
- Marks subscriber as confirmed
- Shows success or error message

**Flow:**
1. Extract token from URL params
2. Find subscriber by token (via `Indie.Subscribers.get_by_confirmation_token/1`)
3. Mark as confirmed (via `Indie.Subscribers.confirm/1`)
4. Show success message or invalid token error

#### `IndieWeb.NewsletterUnsubscribeLive` (`/newsletter/unsubscribe/:token`)
One-click unsubscribe page (legal requirement).

**Features:**
- Validates unsubscribe token
- Immediately unsubscribes (no confirmation needed)
- Shows success message

**Flow:**
1. Extract token from URL params
2. Find subscriber by token (via `Indie.Subscribers.get_by_unsubscribe_token/1`)
3. Unsubscribe (via `Indie.Subscribers.unsubscribe/1`)
4. Show "You've been unsubscribed" message

#### `IndieWeb.NewsletterArchiveLive` (`/newsletters`)
Archive list page showing all sent newsletters.

**Features:**
- Display all sent newsletters in reverse chronological order
- Each newsletter shows: subject, send date, recipient count
- Click to view individual newsletter

**Flow:**
1. Query sent newsletters (via `Indie.Newsletter.sent/0`)
2. Sort by `sent_at` descending
3. Render list with links to `/newsletters/{slug}`

#### `IndieWeb.NewsletterShowLive` (`/newsletters/:slug`)
Individual newsletter web view.

**Features:**
- Render newsletter as web HTML (full styling)
- Wrapped in `<Layouts.app>` component
- Similar aesthetic to blog posts

**Flow:**
1. Extract slug from URL params
2. Load newsletter (via `Indie.Newsletter.get_by_slug/1`)
3. Render web HTML (via `Indie.Newsletter.WebRenderer.render_web/1`)
4. Show 404 if not found or not sent

## Mix Tasks

### `mix newsletter.new <slug>`

Creates a new newsletter file with pre-filled YAML front matter template.

**Workflow:**
1. Validate slug (alphanumeric + hyphens only)
2. Generate filename: `{YYYY-MM}-{slug}.md` (using current date)
3. Check if file already exists (prevent overwriting)
4. Create `content/newsletters/` directory if it doesn't exist
5. Write template file with YAML front matter
6. Output: "✓ Created newsletter at: content/newsletters/{filename}"
7. Output: "Edit the file, then send with: mix newsletter.send content/newsletters/{filename}"

**Template content:**
```markdown
---
subject: "TODO: Add your newsletter subject"
slug: "{slug}"
date: {YYYY-MM-DD}
preview_text: "TODO: Optional preview text for email clients"
---

# Your newsletter title here

Write your newsletter content here in markdown...
```

**Example:**
```bash
$ mix newsletter.new april-update
✓ Created newsletter at: content/newsletters/2026-03-april-update.md
Edit the file, then send with: mix newsletter.send content/newsletters/2026-03-april-update.md
```

### `mix newsletter.send <path/to/newsletter.md>`

Tests, previews, and sends a newsletter to all confirmed subscribers.

**Workflow:**

1. **Parse & validate newsletter file**
   - Read markdown file from provided path
   - Parse YAML front matter (subject, slug, date, preview_text)
   - Validate required fields exist
   - Check if already sent (query `newsletters` table by slug)
   - If already sent, show warning and exit
   - Convert markdown to email HTML

2. **Send test email**
   - Prompt user: "Enter your test email address:"
   - Generate email HTML (via `Indie.Newsletter.EmailRenderer.render_test_email/1`)
   - Send via Resend API (via `Indie.Newsletter.Mailer.send_test/2`)
   - Output: "Test email sent to {email}. Check your inbox."

3. **Wait for approval**
   - Prompt: "Send to all subscribers? (y/n):"
   - If 'n': Exit without sending
   - If 'y': Continue to step 4

4. **Query confirmed subscribers**
   - Get all confirmed subscribers (via `Indie.Subscribers.confirmed_subscribers/0`)
   - Count subscribers
   - If zero: Output "No confirmed subscribers. Exiting." and exit
   - Prompt: "Send to {count} subscribers? (y/n):"
   - If 'n': Exit without sending
   - If 'y': Continue to step 5

5. **Send to all confirmed subscribers**
   - Generate email HTML for each subscriber (includes unique unsubscribe link)
   - Send via Resend batch API (via `Indie.Newsletter.Mailer.send_newsletter/2`)
   - Handle failures gracefully (log errors, continue with remaining)

6. **Record send in database**
   - Create `newsletters` record with:
     - slug (full `YYYY-MM-slug` format)
     - subject (from YAML)
     - file_path (provided path)
     - sent_at (current timestamp)
     - recipient_count (number of confirmed subscribers)

7. **Output summary**
   - "✓ Newsletter sent to {count} subscribers"
   - "✓ Web archive available at: /newsletters/{slug}"

**Error handling:**
- Missing file: Show error and exit
- Invalid YAML: Show parse error and exit
- Already sent: Show warning and exit
- Resend API failure: Show error, don't record send, exit
- Zero subscribers: Show warning and exit

**Example:**
```bash
$ mix newsletter.send content/newsletters/2026-03-april-update.md
Parsing newsletter: 2026-03-april-update.md
Subject: April Update
Slug: 2026-03-april-update

Enter your test email address: you@example.com
Sending test email...
✓ Test email sent to you@example.com. Check your inbox.

Send to all subscribers? (y/n): y

Querying confirmed subscribers...
Found 42 confirmed subscribers.

Send to 42 subscribers? (y/n): y

Sending newsletter...
✓ Newsletter sent to 42 subscribers
✓ Web archive available at: /newsletters/2026-03-april-update
```

## Subscriber Flow

### Signup → Confirmation

1. User visits `/newsletter`
2. User enters email address in form
3. LiveView validates email format
4. LiveView creates subscriber record:
   - Generate `confirmation_token` (32-byte secure random)
   - Generate `unsubscribe_token` (32-byte secure random)
   - Set `confirmed_at` = nil
5. Send confirmation email via Resend:
   - **From:** `newsletter@yourdomain.com`
   - **To:** `{subscriber.email}`
   - **Subject:** "Glorified Notepad - Confirm your newsletter subscription"
   - **Body:** Welcome message + big confirmation button
   - **Link:** `/newsletter/confirm/{confirmation_token}`
6. Show success message: "Check your email to confirm your subscription"
7. User clicks confirmation link in email
8. User lands on `/newsletter/confirm/{token}`
9. LiveView validates token and marks `confirmed_at` = now()
10. Show success message: "You're subscribed! You'll receive our next newsletter."

### Confirmation Email Content

**Subject:** "Glorified Notepad - Confirm your newsletter subscription"

**Body:**
```
Hi there!

Thanks for signing up for the Glorified Notepad newsletter. Click the button below to confirm your subscription:

[Confirm Subscription] (big button linking to /newsletter/confirm/{token})

You'll receive occasional updates about new posts and thoughts. No spam, no sales pitches, just good content.

If you didn't sign up for this newsletter, you can safely ignore this email.

---
Glorified Notepad
```

### Unsubscribe Flow

1. User receives newsletter email
2. Email footer contains unsubscribe link: `/newsletter/unsubscribe/{unsubscribe_token}`
3. User clicks unsubscribe link
4. User lands on `/newsletter/unsubscribe/{token}`
5. LiveView validates token and immediately unsubscribes (soft delete or mark as unsubscribed)
6. Show success message: "You've been unsubscribed. Sorry to see you go!"

**Legal compliance:**
- One-click unsubscribe (no confirmation needed)
- Immediate processing
- Every newsletter email includes unsubscribe link

## Email Rendering

### Two Rendering Modes

#### Email HTML (for Resend delivery)

**Constraints:**
- Inline CSS only (email clients strip `<style>` tags)
- Table-based layout (better email client support)
- Limited HTML tags (avoid `<div>`, modern CSS)
- Safe colors (hex codes, basic named colors)

**Features:**
- Responsive design (max-width constraint)
- Preview text in email header
- Unsubscribe link in footer
- Basic markdown support: headings, paragraphs, links, bold, italic, lists, images

**Implementation:**
- Convert markdown to HTML via Earmark
- Apply inline styles via CSS inlining
- Wrap in email-safe table layout
- Add unsubscribe footer with token link

#### Web HTML (for `/newsletters/{slug}` archive)

**Constraints:**
- None (full web page rendering)

**Features:**
- Full Tailwind CSS support
- Wrapped in `<Layouts.app>` component
- Same aesthetic as blog posts
- Standard markdown rendering via Earmark

## Resend Integration

### Configuration

**Environment variable:**
- `RESEND_API_KEY` - Resend API key (stored in `.env` or deployment config)

**From address:**
- `newsletter@yourdomain.com` (requires domain verification in Resend dashboard)

**Setup steps:**
1. Create Resend account (free tier)
2. Verify sender domain in Resend dashboard
3. Get API key from Resend dashboard
4. Add API key to environment variable

### API Calls

#### Single email send (confirmation, test)
```elixir
Resend.Emails.send(%{
  from: "newsletter@yourdomain.com",
  to: recipient_email,
  subject: subject,
  html: html_body
})
```

#### Batch send (newsletter broadcast)
```elixir
# Resend supports up to 100 recipients per batch
emails = Enum.map(subscribers, fn subscriber ->
  %{
    from: "newsletter@yourdomain.com",
    to: subscriber.email,
    subject: newsletter.subject,
    html: EmailRenderer.render_email(newsletter, subscriber)
  }
end)

# Send in batches of 100
emails
|> Enum.chunk_every(100)
|> Enum.each(fn batch ->
  Resend.Emails.send_batch(batch)
end)
```

### Error Handling

- Log failed sends (don't crash on individual failures)
- Retry transient failures (network errors, rate limits)
- Don't retry permanent failures (invalid email, bounces)
- Report failures back to Mix task user
- Don't mark newsletter as "sent" if critical failures occur

## Error Handling & Edge Cases

### Subscriber Validation

**Email format:**
- Basic regex validation (presence of `@`, domain)
- Resend will reject invalid emails at send time

**Duplicate signups:**
- Unique constraint on `email` column
- Handle gracefully:
  - If not yet confirmed: Resend confirmation email
  - If already confirmed: Show "You're already subscribed!"

**Rate limiting:**
- Add rate limiting to signup form (prevent spam/abuse)
- Use Phoenix rate limiting (e.g., 5 signups per hour per IP)

### Newsletter Validation

**Required YAML fields:**
- `subject` - Must be present
- `slug` - Must be present and URL-safe
- `date` - Must be present and valid YYYY-MM-DD format

**Duplicate slugs:**
- Check `newsletters` table before sending
- If already sent: Show error and exit
- If draft exists: Allow re-sending (update record)

**File validation:**
- File must exist at provided path
- Markdown must parse correctly (Earmark validation)

### Mix Task Safeguards

**Already sent:**
- Query `newsletters` table by slug
- If `sent_at` is not null: Show error and exit
- Prevent accidental duplicate sends

**Zero subscribers:**
- Show warning: "No confirmed subscribers. Exiting."
- Don't create newsletter record
- Don't send emails

**Missing API key:**
- Check for `RESEND_API_KEY` environment variable
- If missing: Show error and exit
- If invalid: Resend API will return error

**Resend API failures:**
- Handle HTTP errors gracefully
- Show error message to user
- Don't record send in database
- Exit cleanly

### Token Security

**Token generation:**
- Use `Ecto.UUID.generate/0` or `:crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)`
- Cryptographically secure random tokens
- 32+ bytes of entropy

**Token expiration:**
- Tokens never expire (simpler UX)
- Invalid token shows friendly error page

### Database Edge Cases

**Missing newsletter file:**
- Newsletter record exists but file deleted
- Show error when trying to view: "Newsletter file not found"

**Newsletter file without record:**
- File exists but not in database (never sent)
- Allow sending (will create record)

## Testing Strategy

### Unit Tests

**`Indie.Newsletter` module:**
- Parse valid newsletter files
- Validate YAML front matter
- Generate correct slugs
- Handle missing required fields
- Handle invalid YAML

**`Indie.Newsletter.EmailRenderer`:**
- Convert markdown to email HTML
- Apply inline CSS
- Include unsubscribe footer
- Handle special characters
- Generate valid HTML

**`Indie.Subscribers` context:**
- Create subscriber with tokens
- Confirm subscriber by token
- Unsubscribe by token
- Query confirmed subscribers
- Handle duplicate emails

**Token generation:**
- Tokens are unique
- Tokens are cryptographically secure
- Tokens are URL-safe

### Integration Tests

**Subscriber signup flow:**
- Submit form → creates database record
- Duplicate email → shows error
- Invalid email → shows validation error

**Confirmation flow:**
- Valid token → marks subscriber as confirmed
- Invalid token → shows error
- Already confirmed → idempotent

**Unsubscribe flow:**
- Valid token → unsubscribes
- Invalid token → shows error

**Newsletter parsing:**
- Read file → parse YAML → convert to HTML
- Invalid file → error handling

### LiveView Tests

**`NewsletterSignupLive`:**
- Form submission creates subscriber
- Success message displayed
- Error handling (duplicate, invalid)

**`NewsletterArchiveLive`:**
- Displays sent newsletters
- Sorted by date descending
- Links to individual newsletters

**`NewsletterShowLive`:**
- Renders newsletter HTML
- 404 for invalid slug
- Only shows sent newsletters

**Confirmation/unsubscribe pages:**
- Valid tokens work
- Invalid tokens show error

### Mix Task Tests

**`mix newsletter.new`:**
- Creates file with correct template
- Prevents overwriting existing files
- Validates slug format

**`mix newsletter.send`:**
- Mock Resend API (don't send real emails in tests)
- Validate file parsing
- Prevent duplicate sends
- Handle zero subscribers
- Record send in database

### Manual Testing Checklist

Before first production send:

- [ ] Send test email to yourself
- [ ] Verify email renders in Gmail
- [ ] Verify email renders in Apple Mail
- [ ] Verify email renders in Outlook
- [ ] Test confirmation link works
- [ ] Test unsubscribe link works
- [ ] Verify web archive looks good
- [ ] Check responsive design (mobile email)
- [ ] Verify sender domain in Resend
- [ ] Test with real subscriber (friend/alt email)

## Dependencies

### New Dependencies

Add to `mix.exs`:

```elixir
defp deps do
  [
    # Existing dependencies...
    {:resend, "~> 0.4.0"}  # Resend API client
  ]
end
```

**Note:** The `earmark` dependency is already included in your project for blog post rendering, so it will be reused for newsletter markdown parsing.

## Configuration

### Environment Variables

Add to `.env` (local) and deployment config:

```bash
RESEND_API_KEY=re_xxxxxxxxxxxxx
```

### Runtime Configuration

Add to `config/runtime.exs`:

```elixir
config :indie, Indie.Newsletter.Mailer,
  api_key: System.get_env("RESEND_API_KEY"),
  from_email: "newsletter@yourdomain.com"
```

## Migration Strategy

### Database Migrations

**Migration 1: Create `subscribers` table**
```elixir
defmodule Indie.Repo.Migrations.CreateSubscribers do
  use Ecto.Migration

  def change do
    create table(:subscribers) do
      add :email, :string, null: false
      add :confirmation_token, :string, null: false
      add :confirmed_at, :utc_datetime
      add :unsubscribe_token, :string, null: false
      
      timestamps()
    end
    
    create unique_index(:subscribers, [:email])
    create unique_index(:subscribers, [:confirmation_token])
    create unique_index(:subscribers, [:unsubscribe_token])
    create index(:subscribers, [:confirmed_at])
  end
end
```

**Migration 2: Create `newsletters` table**
```elixir
defmodule Indie.Repo.Migrations.CreateNewsletters do
  use Ecto.Migration

  def change do
    create table(:newsletters) do
      add :slug, :string, null: false
      add :subject, :string, null: false
      add :file_path, :string, null: false
      add :sent_at, :utc_datetime
      add :recipient_count, :integer
      
      timestamps()
    end
    
    create unique_index(:newsletters, [:slug])
    create index(:newsletters, [:sent_at])
  end
end
```

### Deployment Checklist

- [ ] Run migrations (`mix ecto.migrate`)
- [ ] Create `content/newsletters/` directory
- [ ] Set `RESEND_API_KEY` environment variable
- [ ] Verify sender domain in Resend dashboard
- [ ] Update site navigation to include newsletter link
- [ ] Test signup flow in production
- [ ] Send first test newsletter

## Success Metrics

- Subscriber growth (track confirmed subscribers over time)
- Newsletter open rates (if Resend tracking enabled in future)
- Web archive traffic (analytics on `/newsletters/*` pages)
- Unsubscribe rate (monitor churn)

## Future Enhancements (Out of Scope)

- Email analytics (open rates, click tracking)
- Subscriber preferences (frequency, topics)
- Automated newsletter sending (on blog post publish)
- Newsletter templates (beyond basic markdown)
- Subscriber import/export
- Archive RSS feed
- Newsletter preview page (before sending)

## Summary

This design provides a complete newsletter system for Glorified Notepad with:

- **Simple subscription**: Email opt-in with double confirmation
- **Markdown-based composition**: Familiar workflow like blog posts
- **Mix task workflow**: Test → approve → send
- **Resend integration**: Free tier, excellent deliverability
- **Web archive**: Public archive of past newsletters
- **Legal compliance**: Double opt-in, one-click unsubscribe

The system is designed for low-volume sending (monthly newsletters to double-digit subscribers) with room to scale as the audience grows.
