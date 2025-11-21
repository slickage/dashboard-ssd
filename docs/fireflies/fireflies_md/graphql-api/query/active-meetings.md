# Active Meetings query - Fireflies.ai API Documentation

_Source_: https://docs.fireflies.ai/graphql-api/query/active-meetings

[Skip to main content](#content-area)

[Fireflies home page![light logo](https://mintcdn.com/firefliesai/1yZ69Sj9FG7Gc0Ag/logo/light.svg?fit=max&auto=format&n=1yZ69Sj9FG7Gc0Ag&q=85&s=89d57b6f64984918e600fab4b327d867)![dark logo](https://mintcdn.com/firefliesai/1yZ69Sj9FG7Gc0Ag/logo/dark.svg?fit=max&auto=format&n=1yZ69Sj9FG7Gc0Ag&q=85&s=46855320026ba559f9e81763bda4d1eb)](https://fireflies.ai)

Search...

⌘K

Search...

Navigation

Query

Active Meetings

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

  - [Active Meetings](/graphql-api/query/active-meetings)
  - [Analytics](/graphql-api/query/analytics)
  - [AI Apps](/graphql-api/query/apps)
  - [User](/graphql-api/query/user)
  - [Users](/graphql-api/query/users)
  - [User Groups](/graphql-api/query/user-groups)
  - [Transcript](/graphql-api/query/transcript)
  - [Transcripts](/graphql-api/query/transcripts)
  - [Bite](/graphql-api/query/bite)
  - [Bites](/graphql-api/query/bites)
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

curl

javascript

python

java

Copy

Ask AI

```
curl -X POST \
-H "Content-Type: application/json" \
-H "Authorization: Bearer your\_api\_key" \
--data '{ "query": "query ActiveMeetings { active\_meetings { id title organizer\_email meeting\_link start\_time } }" }' \
https://api.fireflies.ai/graphql
```

Response

Copy

Ask AI

```
{
"data": {
"active\_meetings": [
{
"id": "meeting-id-1",
"title": "Team Standup",
"organizer\_email": "user@example.com",
"meeting\_link": "https://zoom.us/j/123456789",
"start\_time": "2024-01-15T10:00:00.000Z"
},
{
"id": "meeting-id-2",
"title": "Client Review",
"organizer\_email": "user@example.com",
"meeting\_link": "https://meet.google.com/abc-defg-hij",
"start\_time": "2024-01-15T14:30:00.000Z"
}
]
}
}
```

## [​](#overview) Overview

The active\_meetings query is designed to fetch a list of meetings that are currently active (in progress). This endpoint allows you to monitor ongoing meetings for users in your team.

## [​](#arguments) Arguments

[​](#param-email)

email

String

Filter active meetings by a specific user’s email address.**Permission requirements:**

- **Regular users**: Can only query their own active meetings (must pass their own email or omit this field)
- **Admins**: Can query active meetings for any user in their team

If this field is omitted, the query returns active meetings for the authenticated user.The email must be valid and belong to a user in the same team as the requester.

## [​](#schema) Schema

Fields available to the [ActiveMeeting](/schema/active-meeting) query

## [​](#usage-example) Usage Example

Copy

Ask AI

```
query ActiveMeetings($email: String) {
active\_meetings(input: { email: $email }) {
id
title
organizer\_email
meeting\_link
start\_time
end\_time
privacy
}
}
```

curl

javascript

python

java

Copy

Ask AI

```
curl -X POST \
-H "Content-Type: application/json" \
-H "Authorization: Bearer your\_api\_key" \
--data '{ "query": "query ActiveMeetings { active\_meetings { id title organizer\_email meeting\_link start\_time } }" }' \
https://api.fireflies.ai/graphql
```

Response

Copy

Ask AI

```
{
"data": {
"active\_meetings": [
{
"id": "meeting-id-1",
"title": "Team Standup",
"organizer\_email": "user@example.com",
"meeting\_link": "https://zoom.us/j/123456789",
"start\_time": "2024-01-15T10:00:00.000Z"
},
{
"id": "meeting-id-2",
"title": "Client Review",
"organizer\_email": "user@example.com",
"meeting\_link": "https://meet.google.com/abc-defg-hij",
"start\_time": "2024-01-15T14:30:00.000Z"
}
]
}
}
```

## [​](#error-codes) Error Codes

List of possible error codes that may be returned by the `active_meetings` query. Full list of error codes can be found [here](/miscellaneous/error-codes).


object\_not\_found (user)

The user email you are trying to query does not exist or is not in the same team as the requesting user.



require\_elevated\_privilege

You do not have permission to query active meetings for other users. Regular users can only query their own active meetings. Admin privileges are required to query other users’ active meetings.

## [​](#additional-resources) Additional Resources

[## Transcripts

Query completed meetings and transcripts](/graphql-api/query/transcripts)[## Add to Live Meeting

Join an active meeting with Fireflies.ai bot](/graphql-api/mutation/add-to-live)

Was this page helpful?

YesNo

[Suggest edits](https://github.com/firefliesai/public-api-ff/edit/master/docs/graphql-api/query/active-meetings.mdx)[Raise issue](https://github.com/firefliesai/public-api-ff/issues/new?title=Issue on docs&body=Path: /graphql-api/query/active-meetings)

[Advanced](/examples/advanced)[Analytics](/graphql-api/query/analytics)

⌘I