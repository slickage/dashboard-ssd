# Users query - Fireflies.ai API Documentation

_Source_: https://docs.fireflies.ai/graphql-api/query/users

[Skip to main content](#content-area)

[Fireflies home page![light logo](https://mintcdn.com/firefliesai/1yZ69Sj9FG7Gc0Ag/logo/light.svg?fit=max&auto=format&n=1yZ69Sj9FG7Gc0Ag&q=85&s=89d57b6f64984918e600fab4b327d867)![dark logo](https://mintcdn.com/firefliesai/1yZ69Sj9FG7Gc0Ag/logo/dark.svg?fit=max&auto=format&n=1yZ69Sj9FG7Gc0Ag&q=85&s=46855320026ba559f9e81763bda4d1eb)](https://fireflies.ai)

Search...

⌘K

Search...

Navigation

Query

Users

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
--data '{ "query": "{ users { name integrations } }" }' \
https://api.fireflies.ai/graphql
```

Response

Copy

Ask AI

```
{
"data": {
"users": [
{
"name": "Justin Fly",
"integrations": []
},
{
"name": "Peter Fire",
"integrations": []
}
]
}
}
```

## [​](#overview) Overview

The users query is designed to fetch a list of all users within the team. You can also view this list on your dashboard at [app.fireflies.ai/team](http://app.fireflies.ai/team)

## [​](#schema) Schema

Fields available to the [User](/schema/user) query

## [​](#usage-example) Usage Example

Copy

Ask AI

```
query Users {
users {
user\_id
email
name
num\_transcripts
recent\_meeting
minutes\_consumed
is\_admin
integrations
user\_groups {
id
name
handle
members {
user\_id
first\_name
last\_name
email
}
}
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
--data '{ "query": "{ users { name integrations } }" }' \
https://api.fireflies.ai/graphql
```

Response

Copy

Ask AI

```
{
"data": {
"users": [
{
"name": "Justin Fly",
"integrations": []
},
{
"name": "Peter Fire",
"integrations": []
}
]
}
}
```

## [​](#additional-resources) Additional Resources

[## User

Querying user details](/graphql-api/query/user)[## Set User Role

Use the API to set user roles](/graphql-api/mutation/set-user-role)

Was this page helpful?

YesNo

[Suggest edits](https://github.com/firefliesai/public-api-ff/edit/master/docs/graphql-api/query/users.mdx)[Raise issue](https://github.com/firefliesai/public-api-ff/issues/new?title=Issue on docs&body=Path: /graphql-api/query/users)

[User](/graphql-api/query/user)[User Groups](/graphql-api/query/user-groups)

⌘I