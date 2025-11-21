# ActiveMeeting Schema - Fireflies.ai API Documentation

_Source_: https://docs.fireflies.ai/schema/active-meeting

[Skip to main content](#content-area)

[Fireflies home page![light logo](https://mintcdn.com/firefliesai/1yZ69Sj9FG7Gc0Ag/logo/light.svg?fit=max&auto=format&n=1yZ69Sj9FG7Gc0Ag&q=85&s=89d57b6f64984918e600fab4b327d867)![dark logo](https://mintcdn.com/firefliesai/1yZ69Sj9FG7Gc0Ag/logo/dark.svg?fit=max&auto=format&n=1yZ69Sj9FG7Gc0Ag&q=85&s=46855320026ba559f9e81763bda4d1eb)](https://fireflies.ai)

Search...

⌘K

Search...

Navigation

Schema

ActiveMeeting

##### Getting Started

- [Introduction](/getting-started/introduction)
- [Quickstart](/getting-started/quickstart)
- [Chat with Fireflies AI Assistant](/getting-started/ask-docs)
- [Join the Developer Program](/getting-started/developer-program)
- [MCP Server Configuration](/getting-started/mcp-configuration)
- [LLM-based Development](/getting-started/llm-development)
- [What's New](/getting-started/whats-new)

##### Fundamentals

- [General concepts](/fundamentals/concepts)
- [Limits](/fundamentals/limits)
- [Errors](/fundamentals/errors)
- [Authorization](/fundamentals/authorization)
- [Introspection](/fundamentals/introspection)
- [Super Admin](/fundamentals/super-admin)

##### Examples

- [Overview](/examples/overview)
- [Basic](/examples/basic)
- [Advanced](/examples/advanced)

##### GraphQL API

- Query
- Mutation
- [Webhooks](/graphql-api/webhooks)

##### Realtime API

- [Overview](/realtime-api/overview)
- [Getting Started](/realtime-api/getting-started)
- [Event Schema](/realtime-api/event-schema)

##### Schema

- [ActiveMeeting](/schema/active-meeting)
- [AIFilter](/schema/aifilter)
- [Analytics](/schema/analytics)
- [AI Apps](/schema/apps)
- [App Output](/schema/app-output)
- [AudioUploadStatus](/schema/audio-upload-status)
- [Bite](/schema/bite)
- [Channel](/schema/channel)
- [MeetingAnalytics](/schema/meeting-analytics)
- [MeetingAttendee](/schema/meeting-attendee)
- [MeetingInfo](/schema/meeting-info)
- [Sentiments](/schema/sentiments)
- [Sentence](/schema/sentence)
- [Summary](/schema/summary)
- [SummarySection](/schema/summary-section)
- [Speaker](/schema/speaker)
- [Transcript](/schema/transcript)
- [User](/schema/user)
- [User Groups](/schema/user-groups)
- [User Group Member](/schema/user-group-member)
- Input

##### Miscellaneous

- [Language codes](/miscellaneous/language-codes)
- [Error codes](/miscellaneous/error-codes)

##### Additional Info

- [Deprecated](/additional-info/deprecated)
- [Changelog](/additional-info/change-log)

On this page

- [Additional Resources](#additional-resources)

[​](#param-id)

id

String

Unique identifier for the active meeting

[​](#param-title)

title

String

Title of the active meeting

[​](#param-organizer-email)

organizer\_email

String

Email address of the meeting organizer

[​](#param-meeting-link)

meeting\_link

String

The URL link to join the meeting (e.g., Zoom, Google Meet, Microsoft Teams link)

[​](#param-start-time)

start\_time

String

ISO 8601 formatted timestamp indicating when the meeting started (e.g., `2024-01-15T10:00:00.000Z`)

[​](#param-end-time)

end\_time

String

ISO 8601 formatted timestamp indicating when the meeting is scheduled to end (e.g., `2024-01-15T11:00:00.000Z`)

[​](#param-privacy)

privacy

MeetingPrivacy

Privacy setting for the meeting. Possible values:

- `link`: Anyone with the link can access
- `owner`: Only the owner can access
- `participants`: Only meeting participants can access
- `teammates_and_participants`: Team members and participants can access
- `participating_teammates`: Only teammates who participated can access
- `teammates`: All team members can access

## [​](#additional-resources) Additional Resources

[## Active Meetings Query

Query active meetings in progress](/graphql-api/query/active-meetings)[## Transcript Schema

Schema for completed meeting transcripts](/schema/transcript)

Was this page helpful?

YesNo

[Suggest edits](https://github.com/firefliesai/public-api-ff/edit/master/docs/schema/active-meeting.mdx)[Raise issue](https://github.com/firefliesai/public-api-ff/issues/new?title=Issue on docs&body=Path: /schema/active-meeting)

[Event Schema](/realtime-api/event-schema)[AIFilter](/schema/aifilter)

⌘I